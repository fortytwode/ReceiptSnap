import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'database_service.dart';
import 'mock_data.dart';
import 'ocr_service.dart';

/// Receipts service for managing receipt data
class ReceiptsService {
  final ApiClient _api;
  final DatabaseService _db;
  final OcrService _ocr;

  ReceiptsService(this._api, this._db, this._ocr);

  /// Get IDs of submitted reports (to filter out their receipts from home screen)
  Future<Set<String>> _getSubmittedReportIds() async {
    if (ApiConfig.mockMode) {
      // In mock mode, check MockData reports
      return MockData.mockReports
          .where((r) => r.status != ReportStatus.draft)
          .map((r) => r.id)
          .toSet();
    }
    return await _db.getSubmittedReportIds();
  }

  // In-memory mock storage - only used when mockMode = true
  static List<Receipt>? _mockReceiptsStorage;

  static List<Receipt> get mockReceipts {
    _mockReceiptsStorage ??= List.from(MockData.mockReceipts);
    return _mockReceiptsStorage!;
  }

  /// Get all receipts with optional filters
  /// By default, hides receipts that are in SUBMITTED reports (but shows those in draft reports)
  Future<List<Receipt>> getReceipts({
    String? status,
    String? search,
  }) async {
    // Get submitted report IDs to filter them out
    final submittedReportIds = await _getSubmittedReportIds();

    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      var results = List<Receipt>.from(mockReceipts);

      // Filter by status
      if (status != null && status.isNotEmpty) {
        switch (status.toLowerCase()) {
          case 'new':
          case 'pending_ocr':
            results = results
                .where((r) => r.ocrStatus == OcrStatus.pendingOcr)
                .toList();
            break;
          case 'needs_review':
          case 'needs_confirmation':
            results = results
                .where((r) => r.ocrStatus == OcrStatus.needsConfirmation)
                .toList();
            break;
          case 'confirmed':
            results = results
                .where((r) => r.ocrStatus == OcrStatus.confirmed && r.reportId == null)
                .toList();
            break;
          case 'in_report':
            // Show only receipts in DRAFT reports (not submitted)
            results = results
                .where((r) => r.reportId != null && !submittedReportIds.contains(r.reportId))
                .toList();
            break;
        }
      } else {
        // Default: hide receipts that are in SUBMITTED reports
        // Show: receipts not in any report OR receipts in draft reports
        results = results
            .where((r) => r.reportId == null || !submittedReportIds.contains(r.reportId))
            .toList();
      }

      // Filter by search
      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        results = results
            .where((r) =>
                (r.merchant?.toLowerCase().contains(query) ?? false) ||
                (r.category?.toLowerCase().contains(query) ?? false) ||
                (r.note?.toLowerCase().contains(query) ?? false))
            .toList();
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    }

    // Use local database
    var results = await _db.getReceipts(status: status, search: search);

    // Filter out receipts in submitted reports (unless specifically requesting them)
    if (status != 'in_submitted_report') {
      if (status == 'in_report') {
        // Show only receipts in draft reports
        results = results
            .where((r) => r.reportId != null && !submittedReportIds.contains(r.reportId))
            .toList();
      } else if (status == null || status.isEmpty) {
        // Default: hide receipts in submitted reports
        results = results
            .where((r) => r.reportId == null || !submittedReportIds.contains(r.reportId))
            .toList();
      }
    }

    return results;
  }

  /// Get a single receipt by ID
  Future<Receipt> getReceipt(String id) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final receipt = mockReceipts.firstWhere(
        (r) => r.id == id,
        orElse: () => throw Exception('Receipt not found'),
      );
      return receipt;
    }

    final receipt = await _db.getReceipt(id);
    if (receipt == null) throw Exception('Receipt not found');
    return receipt;
  }

  /// Upload a new receipt image
  Future<Receipt> uploadReceipt(File imageFile) async {
    // Create new receipt with pending status
    final newReceipt = Receipt(
      id: const Uuid().v4(),
      imageUrl: imageFile.path, // Store local path
      merchant: null,
      date: null,
      amount: null,
      currency: null,
      category: null,
      note: null,
      ocrStatus: OcrStatus.pendingOcr,
      reportId: null,
      createdAt: DateTime.now(),
    );

    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(seconds: 1));
      mockReceipts.insert(0, newReceipt);
      return newReceipt;
    }

    // Save to local database
    await _db.insertReceipt(newReceipt);
    return newReceipt;
  }

  /// Process receipt with OCR
  Future<Receipt> processReceiptWithOcr(String id) async {
    final receipt = await getReceipt(id);
    final imageFile = File(receipt.imageUrl);

    // Run OCR on the image
    OcrResult ocrResult;
    try {
      if (await imageFile.exists()) {
        debugPrint('Running OCR on: ${receipt.imageUrl}');
        ocrResult = await _ocr.processImage(imageFile);
        debugPrint('OCR Result: $ocrResult');
      } else {
        debugPrint('Image file does not exist: ${receipt.imageUrl}');
        ocrResult = const OcrResult(rawText: '');
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
      ocrResult = const OcrResult(rawText: '');
    }

    // Create updated receipt with OCR results
    final updated = Receipt(
      id: id,
      imageUrl: receipt.imageUrl,
      merchant: ocrResult.merchant ?? 'Unknown Merchant',
      date: ocrResult.date ?? DateTime.now(),
      amount: ocrResult.amount, // May be null if not detected
      currency: ocrResult.currency, // May be null if not detected
      category: _inferCategory(ocrResult.merchant),
      ocrStatus: OcrStatus.needsConfirmation,
      reportId: null,
      createdAt: receipt.createdAt,
    );

    if (ApiConfig.mockMode) {
      final index = mockReceipts.indexWhere((r) => r.id == id);
      if (index != -1) {
        mockReceipts[index] = updated;
      }
      return updated;
    }

    await _db.updateReceipt(updated);
    return updated;
  }

  /// Infer category from merchant name using common patterns
  String _inferCategory(String? merchant) {
    if (merchant == null || merchant.isEmpty) return 'Other';
    final lower = merchant.toLowerCase();

    // Lodging - Hotels, Airbnb, etc.
    if (lower.contains('hotel') ||
        lower.contains('inn') ||
        lower.contains('lodge') ||
        lower.contains('motel') ||
        lower.contains('airbnb') ||
        lower.contains('vrbo') ||
        lower.contains('marriott') ||
        lower.contains('hilton') ||
        lower.contains('hyatt') ||
        lower.contains('sheraton') ||
        lower.contains('westin') ||
        lower.contains('holiday inn') ||
        lower.contains('best western') ||
        lower.contains('radisson') ||
        lower.contains('smeštaj') ||
        lower.contains('hostel')) {
      return 'Lodging';
    }

    // Transportation - Rideshare, Taxi, Parking, Gas
    if (lower.contains('uber') ||
        lower.contains('lyft') ||
        lower.contains('taxi') ||
        lower.contains('cab') ||
        lower.contains('bolt') ||
        lower.contains('grab') ||
        lower.contains('parking') ||
        lower.contains('garage') ||
        lower.contains('gas') ||
        lower.contains('shell') ||
        lower.contains('exxon') ||
        lower.contains('chevron') ||
        lower.contains('bp') ||
        lower.contains('mobil') ||
        lower.contains('petrol') ||
        lower.contains('fuel') ||
        lower.contains('metro') ||
        lower.contains('subway') ||
        lower.contains('transit') ||
        lower.contains('bus') ||
        lower.contains('train') ||
        lower.contains('rail')) {
      return 'Transportation';
    }

    // Travel - Airlines, etc.
    if (lower.contains('airline') ||
        lower.contains('airways') ||
        lower.contains('flight') ||
        lower.contains('delta') ||
        lower.contains('united') ||
        lower.contains('american') ||
        lower.contains('southwest') ||
        lower.contains('jetblue') ||
        lower.contains('spirit') ||
        lower.contains('frontier') ||
        lower.contains('alaska') ||
        lower.contains('lufthansa') ||
        lower.contains('british') ||
        lower.contains('air france') ||
        lower.contains('emirates') ||
        lower.contains('qatar') ||
        lower.contains('expedia') ||
        lower.contains('booking') ||
        lower.contains('kayak') ||
        lower.contains('airport')) {
      return 'Travel';
    }

    // Food & Drink - Restaurants, Coffee, Fast food
    if (lower.contains('starbucks') ||
        lower.contains('coffee') ||
        lower.contains('cafe') ||
        lower.contains('café') ||
        lower.contains('restaurant') ||
        lower.contains('food') ||
        lower.contains('grill') ||
        lower.contains('kitchen') ||
        lower.contains('diner') ||
        lower.contains('bistro') ||
        lower.contains('bar') ||
        lower.contains('pub') ||
        lower.contains('mcdonald') ||
        lower.contains('burger') ||
        lower.contains('pizza') ||
        lower.contains('subway') ||
        lower.contains('chipotle') ||
        lower.contains('taco') ||
        lower.contains('wendy') ||
        lower.contains('chick-fil-a') ||
        lower.contains('kfc') ||
        lower.contains('popeye') ||
        lower.contains('dunkin') ||
        lower.contains('panera') ||
        lower.contains('bakery') ||
        lower.contains('doručak') ||
        lower.contains('ručak') ||
        lower.contains('večera') ||
        lower.contains('uber eats') ||
        lower.contains('doordash') ||
        lower.contains('grubhub') ||
        lower.contains('deliveroo')) {
      return 'Food & Drink';
    }

    // Office Supplies
    if (lower.contains('office') ||
        lower.contains('staples') ||
        lower.contains('depot') ||
        lower.contains('supply') ||
        lower.contains('paper') ||
        lower.contains('print') ||
        lower.contains('fedex') ||
        lower.contains('ups') ||
        lower.contains('kinkos')) {
      return 'Office Supplies';
    }

    // Entertainment
    if (lower.contains('cinema') ||
        lower.contains('movie') ||
        lower.contains('theater') ||
        lower.contains('theatre') ||
        lower.contains('concert') ||
        lower.contains('ticket') ||
        lower.contains('museum') ||
        lower.contains('zoo') ||
        lower.contains('park') ||
        lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('hulu') ||
        lower.contains('disney')) {
      return 'Entertainment';
    }

    // Utilities
    if (lower.contains('electric') ||
        lower.contains('power') ||
        lower.contains('utility') ||
        lower.contains('water') ||
        lower.contains('gas company') ||
        lower.contains('internet') ||
        lower.contains('phone') ||
        lower.contains('mobile') ||
        lower.contains('verizon') ||
        lower.contains('at&t') ||
        lower.contains('t-mobile') ||
        lower.contains('comcast') ||
        lower.contains('spectrum')) {
      return 'Utilities';
    }

    return 'Other';
  }

  /// Legacy method name for backwards compatibility
  Future<Receipt> pollForOcrCompletion(
    String id, {
    int maxAttempts = 30,
    Duration interval = const Duration(seconds: 1),
  }) async {
    return processReceiptWithOcr(id);
  }

  /// Update a receipt
  Future<Receipt> updateReceipt(Receipt receipt) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = mockReceipts.indexWhere((r) => r.id == receipt.id);
      if (index != -1) {
        mockReceipts[index] = receipt;
        return receipt;
      }
      throw Exception('Receipt not found');
    }

    await _db.updateReceipt(receipt);
    return receipt;
  }

  /// Delete a receipt
  Future<void> deleteReceipt(String id) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      mockReceipts.removeWhere((r) => r.id == id);
      return;
    }

    await _db.deleteReceipt(id);
  }

  /// Get receipts available for adding to a report
  Future<List<Receipt>> getAvailableForReport() async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return mockReceipts
          .where((r) =>
              r.ocrStatus == OcrStatus.confirmed && r.reportId == null)
          .toList();
    }

    return await _db.getAvailableReceipts();
  }

  /// Create a manual receipt entry (for cash expenses without a receipt image)
  Future<Receipt> createManualEntry({
    required String merchant,
    required double amount,
    required String currency,
    required DateTime date,
    String? category,
    String? note,
  }) async {
    final newReceipt = Receipt(
      id: const Uuid().v4(),
      imageUrl: '', // No image for manual entries
      merchant: merchant,
      date: date,
      amount: amount,
      currency: currency,
      category: category ?? 'Other',
      note: note,
      ocrStatus: OcrStatus.confirmed, // Manual entries are already confirmed
      reportId: null,
      createdAt: DateTime.now(),
    );

    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      mockReceipts.insert(0, newReceipt);
      return newReceipt;
    }

    await _db.insertReceipt(newReceipt);
    return newReceipt;
  }
}

/// Provider for ReceiptsService
final receiptsServiceProvider = Provider<ReceiptsService>((ref) {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(databaseServiceProvider);
  final ocr = ref.watch(ocrServiceProvider);
  return ReceiptsService(api, db, ocr);
});
