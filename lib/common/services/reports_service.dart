import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'database_service.dart';
import 'mock_data.dart';
import 'receipts_service.dart';

/// Reports service for managing expense reports
class ReportsService {
  final ApiClient _api;
  final DatabaseService _db;

  ReportsService(this._api, this._db);

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
}

/// Provider for ReportsService
final reportsServiceProvider = Provider<ReportsService>((ref) {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(databaseServiceProvider);
  return ReportsService(api, db);
});
