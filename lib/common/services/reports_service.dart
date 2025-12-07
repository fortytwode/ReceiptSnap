import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'database_service.dart';
import 'mock_data.dart';
import 'receipts_service.dart';
import 'storage_service.dart';

/// Reports service for managing expense reports
class ReportsService {
  final ApiClient _api;
  final DatabaseService _db;
  final StorageService _storage;

  ReportsService(this._api, this._db, this._storage);

  // In-memory mock storage
  static List<Report>? _mockReports;

  List<Report> get _reports {
    _mockReports ??= List.from(MockData.mockReports);
    return _mockReports!;
  }

  /// Get all reports with optional filters
  Future<List<Report>> getReports({String? status}) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      var results = List<Report>.from(_reports);

      if (status != null && status.isNotEmpty) {
        final reportStatus = ReportStatus.fromString(status);
        results = results.where((r) => r.status == reportStatus).toList();
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    }

    return await _db.getReports(status: status);
  }

  /// Get a single report by ID
  Future<Report> getReport(String id) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final report = _reports.firstWhere(
        (r) => r.id == id,
        orElse: () => throw Exception('Report not found'),
      );
      return report;
    }

    final report = await _db.getReport(id);
    if (report == null) throw Exception('Report not found');
    return report;
  }

  /// Create a new report
  Future<Report> createReport({
    required String title,
    DateTime? startDate,
    DateTime? endDate,
    required List<String> receiptIds,
    String? approverEmail,
    String currency = 'USD',
  }) async {
    final reportId = const Uuid().v4();

    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 500));

      // Get receipts by IDs from mock data
      final receipts = ReceiptsService.mockReceipts
          .where((r) => receiptIds.contains(r.id))
          .toList();

      final total = receipts.fold<double>(
        0,
        (sum, r) => sum + (r.amount ?? 0),
      );

      final newReport = Report(
        id: reportId,
        title: title,
        status: ReportStatus.draft,
        receipts: receipts,
        totalAmount: total,
        currency: currency,
        comment: null,
        approverEmail: approverEmail,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
      );

      // Update receipts to link to this report
      for (final receiptId in receiptIds) {
        final index = ReceiptsService.mockReceipts
            .indexWhere((r) => r.id == receiptId);
        if (index != -1) {
          ReceiptsService.mockReceipts[index] =
              ReceiptsService.mockReceipts[index]
                  .copyWith(reportId: newReport.id);
        }
      }

      _reports.insert(0, newReport);
      return newReport;
    }

    // Get receipts from database
    final availableReceipts = await _db.getAvailableReceipts();
    final receipts = availableReceipts
        .where((r) => receiptIds.contains(r.id))
        .toList();

    final total = receipts.fold<double>(
      0,
      (sum, r) => sum + (r.amount ?? 0),
    );

    final newReport = Report(
      id: reportId,
      title: title,
      status: ReportStatus.draft,
      receipts: receipts,
      totalAmount: total,
      currency: currency,
      comment: null,
      approverEmail: approverEmail,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );

    // Save report and link receipts
    await _db.insertReport(newReport);
    await _db.linkReceiptsToReport(receiptIds, reportId);

    return newReport;
  }

  /// Submit a report
  Future<Report> submitReport(String id) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));

      final index = _reports.indexWhere((r) => r.id == id);
      if (index != -1) {
        final updated = _reports[index].copyWith(status: ReportStatus.submitted);
        _reports[index] = updated;
        return updated;
      }
      throw Exception('Report not found');
    }

    final report = await _db.getReport(id);
    if (report == null) throw Exception('Report not found');

    final updated = report.copyWith(status: ReportStatus.submitted);
    await _db.updateReport(updated);
    return updated;
  }

  /// Update a report
  Future<Report> updateReport(Report report) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));

      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _reports[index] = report;
        return report;
      }
      throw Exception('Report not found');
    }

    await _db.updateReport(report);
    return report;
  }

  /// Delete a report (draft only)
  Future<void> deleteReport(String id) async {
    if (ApiConfig.mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));

      final report = _reports.firstWhere((r) => r.id == id);

      // Unlink receipts
      for (final receipt in report.receipts) {
        final index = ReceiptsService.mockReceipts
            .indexWhere((r) => r.id == receipt.id);
        if (index != -1) {
          ReceiptsService.mockReceipts[index] =
              ReceiptsService.mockReceipts[index].copyWith(reportId: null);
        }
      }

      _reports.removeWhere((r) => r.id == id);
      return;
    }

    await _db.deleteReport(id);
  }

  /// Export reports to CSV (placeholder)
  Future<void> exportCsv() async {
    // TODO: Implement CSV export
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Get or create the active (draft) report
  /// Creates a new report named after current month if none exists
  Future<Report> getOrCreateActiveReport() async {
    final activeId = _storage.activeReportId;

    // Check if we have an active report
    if (activeId != null) {
      try {
        final report = await getReport(activeId);
        // Only return if it's still a draft
        if (report.status == ReportStatus.draft) {
          return report;
        }
      } catch (e) {
        // Report not found or error, create new one
      }
    }

    // Create a new active report
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now);
    final title = '$monthName ${now.year} Expenses';

    final report = await createReport(
      title: title,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0), // Last day of month
      receiptIds: [],
    );

    await _storage.setActiveReportId(report.id);
    return report;
  }

  /// Add a receipt to the active report
  Future<Report> addReceiptToActiveReport(String receiptId) async {
    final report = await getOrCreateActiveReport();

    // Link the receipt to this report
    if (ApiConfig.mockMode) {
      final receiptIndex = ReceiptsService.mockReceipts
          .indexWhere((r) => r.id == receiptId);
      if (receiptIndex != -1) {
        ReceiptsService.mockReceipts[receiptIndex] =
            ReceiptsService.mockReceipts[receiptIndex]
                .copyWith(reportId: report.id);
      }

      // Update report with new receipt
      final reportIndex = _reports.indexWhere((r) => r.id == report.id);
      if (reportIndex != -1) {
        final updatedReceipts = List<Receipt>.from(_reports[reportIndex].receipts);
        final receipt = ReceiptsService.mockReceipts
            .firstWhere((r) => r.id == receiptId);
        updatedReceipts.add(receipt);

        final total = updatedReceipts.fold<double>(
          0,
          (sum, r) => sum + (r.amount ?? 0),
        );

        _reports[reportIndex] = _reports[reportIndex].copyWith(
          receipts: updatedReceipts,
          totalAmount: total,
        );
        return _reports[reportIndex];
      }
    } else {
      await _db.linkReceiptsToReport([receiptId], report.id);
    }

    return await getReport(report.id);
  }

  /// Called after submitting a report - creates new active report
  Future<void> onReportSubmitted(String reportId) async {
    final currentActiveId = _storage.activeReportId;
    if (currentActiveId == reportId) {
      // Clear active report - next getOrCreateActiveReport will create new one
      await _storage.setActiveReportId(null);
    }
  }
}

/// Provider for ReportsService
final reportsServiceProvider = Provider<ReportsService>((ref) {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(databaseServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return ReportsService(api, db, storage);
});
