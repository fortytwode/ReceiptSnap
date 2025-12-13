import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Local SQLite database service for persistent storage
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'receipt_snap.db';
  static const int _dbVersion = 1;

  // Table names
  static const String receiptsTable = 'receipts';
  static const String reportsTable = 'reports';
  static const String reportReceiptsTable = 'report_receipts';

  /// Get database instance (singleton)
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Receipts table
    await db.execute('''
      CREATE TABLE $receiptsTable (
        id TEXT PRIMARY KEY,
        imageUrl TEXT NOT NULL,
        merchant TEXT,
        date TEXT,
        amount REAL,
        currency TEXT,
        category TEXT,
        note TEXT,
        ocrStatus TEXT NOT NULL,
        reportId TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Reports table
    await db.execute('''
      CREATE TABLE $reportsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        currency TEXT NOT NULL,
        comment TEXT,
        approverEmail TEXT,
        startDate TEXT,
        endDate TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
      'CREATE INDEX idx_receipts_reportId ON $receiptsTable(reportId)',
    );
    await db.execute(
      'CREATE INDEX idx_receipts_ocrStatus ON $receiptsTable(ocrStatus)',
    );
    await db.execute(
      'CREATE INDEX idx_reports_status ON $reportsTable(status)',
    );
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  // ============ RECEIPTS ============

  /// Insert a new receipt
  Future<void> insertReceipt(Receipt receipt) async {
    final db = await database;
    await db.insert(
      receiptsTable,
      _receiptToMap(receipt),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all receipts with optional filters
  /// By default, hides receipts that are in submitted reports
  Future<List<Receipt>> getReceipts({
    String? status,
    String? search,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null && status.isNotEmpty) {
      switch (status.toLowerCase()) {
        case 'draft':
          // Show receipts NOT in any report
          whereClause += ' AND reportId IS NULL';
          break;
        case 'pending_ocr':
          whereClause += ' AND ocrStatus = ?';
          whereArgs.add('pending_ocr');
          break;
        case 'needs_confirmation':
          whereClause += ' AND ocrStatus = ?';
          whereArgs.add('needs_confirmation');
          break;
        case 'confirmed':
          whereClause += ' AND ocrStatus = ? AND reportId IS NULL';
          whereArgs.add('confirmed');
          break;
        case 'in_report':
          // Only show receipts in DRAFT reports (not submitted)
          whereClause += ' AND reportId IS NOT NULL';
          break;
        case 'in_submitted_report':
          // Only show receipts in submitted reports
          whereClause += ' AND reportId IS NOT NULL';
          break;
      }
    } else {
      // Default: hide receipts that are in submitted reports
      // We'll filter this in code after fetching since we need to check report status
    }

    if (search != null && search.isNotEmpty) {
      whereClause += ' AND (merchant LIKE ? OR category LIKE ? OR note LIKE ?)';
      final searchPattern = '%$search%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern]);
    }

    final maps = await db.query(
      receiptsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );

    return maps.map(_receiptFromMap).toList();
  }

  /// Get a single receipt by ID
  Future<Receipt?> getReceipt(String id) async {
    final db = await database;
    final maps = await db.query(
      receiptsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return _receiptFromMap(maps.first);
  }

  /// Update a receipt
  Future<void> updateReceipt(Receipt receipt) async {
    final db = await database;
    await db.update(
      receiptsTable,
      _receiptToMap(receipt),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  /// Delete a receipt
  Future<void> deleteReceipt(String id) async {
    final db = await database;
    await db.delete(
      receiptsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get receipts available for reports (confirmed, not in any report)
  Future<List<Receipt>> getAvailableReceipts() async {
    final db = await database;
    final maps = await db.query(
      receiptsTable,
      where: 'ocrStatus = ? AND reportId IS NULL',
      whereArgs: ['confirmed'],
      orderBy: 'createdAt DESC',
    );

    return maps.map(_receiptFromMap).toList();
  }

  /// Link receipts to a report
  Future<void> linkReceiptsToReport(List<String> receiptIds, String reportId) async {
    final db = await database;
    final batch = db.batch();

    for (final id in receiptIds) {
      batch.update(
        receiptsTable,
        {'reportId': reportId},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Unlink receipts from a report
  Future<void> unlinkReceiptsFromReport(String reportId) async {
    final db = await database;
    await db.update(
      receiptsTable,
      {'reportId': null},
      where: 'reportId = ?',
      whereArgs: [reportId],
    );
  }

  // ============ REPORTS ============

  /// Insert a new report
  Future<void> insertReport(Report report) async {
    final db = await database;
    await db.insert(
      reportsTable,
      _reportToMap(report),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all reports with optional filters
  Future<List<Report>> getReports({String? status}) async {
    final db = await database;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (status != null && status.isNotEmpty) {
      whereClause = 'status = ?';
      whereArgs = [status];
    }

    final maps = await db.query(
      reportsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );

    // Get receipts for each report
    List<Report> reports = [];
    for (final map in maps) {
      final reportId = map['id'] as String;
      final receiptMaps = await db.query(
        receiptsTable,
        where: 'reportId = ?',
        whereArgs: [reportId],
      );
      final receipts = receiptMaps.map(_receiptFromMap).toList();
      reports.add(_reportFromMap(map, receipts));
    }

    return reports;
  }

  /// Get IDs of all submitted (non-draft) reports
  Future<Set<String>> getSubmittedReportIds() async {
    final db = await database;
    final maps = await db.query(
      reportsTable,
      columns: ['id'],
      where: 'status != ?',
      whereArgs: ['draft'],
    );
    return maps.map((m) => m['id'] as String).toSet();
  }

  /// Get IDs of all draft reports
  Future<Set<String>> getDraftReportIds() async {
    final db = await database;
    final maps = await db.query(
      reportsTable,
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['draft'],
    );
    return maps.map((m) => m['id'] as String).toSet();
  }

  /// Get a single report by ID
  Future<Report?> getReport(String id) async {
    final db = await database;
    final maps = await db.query(
      reportsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final receiptMaps = await db.query(
      receiptsTable,
      where: 'reportId = ?',
      whereArgs: [id],
    );
    final receipts = receiptMaps.map(_receiptFromMap).toList();

    return _reportFromMap(maps.first, receipts);
  }

  /// Update a report
  Future<void> updateReport(Report report) async {
    final db = await database;
    await db.update(
      reportsTable,
      _reportToMap(report),
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  /// Delete a report
  Future<void> deleteReport(String id) async {
    final db = await database;
    // First unlink receipts
    await unlinkReceiptsFromReport(id);
    // Then delete report
    await db.delete(
      reportsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============ HELPERS ============

  Map<String, dynamic> _receiptToMap(Receipt receipt) {
    return {
      'id': receipt.id,
      'imageUrl': receipt.imageUrl,
      'merchant': receipt.merchant,
      'date': receipt.date?.toIso8601String(),
      'amount': receipt.amount,
      'currency': receipt.currency,
      'category': receipt.category,
      'note': receipt.note,
      'ocrStatus': receipt.ocrStatus.toJson(),
      'reportId': receipt.reportId,
      'createdAt': receipt.createdAt.toIso8601String(),
    };
  }

  Receipt _receiptFromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as String,
      imageUrl: map['imageUrl'] as String,
      merchant: map['merchant'] as String?,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      amount: map['amount'] as double?,
      currency: map['currency'] as String?,
      category: map['category'] as String?,
      note: map['note'] as String?,
      ocrStatus: OcrStatus.fromString(map['ocrStatus'] as String),
      reportId: map['reportId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> _reportToMap(Report report) {
    return {
      'id': report.id,
      'title': report.title,
      'status': report.status.toJson(),
      'totalAmount': report.totalAmount,
      'currency': report.currency,
      'comment': report.comment,
      'approverEmail': report.approverEmail,
      'startDate': report.startDate?.toIso8601String(),
      'endDate': report.endDate?.toIso8601String(),
      'createdAt': report.createdAt.toIso8601String(),
    };
  }

  Report _reportFromMap(Map<String, dynamic> map, List<Receipt> receipts) {
    return Report(
      id: map['id'] as String,
      title: map['title'] as String,
      status: ReportStatus.fromString(map['status'] as String),
      receipts: receipts,
      totalAmount: map['totalAmount'] as double,
      currency: map['currency'] as String,
      comment: map['comment'] as String?,
      approverEmail: map['approverEmail'] as String?,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clear all data (for testing/logout)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(receiptsTable);
    await db.delete(reportsTable);
  }
}

/// Provider for DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
