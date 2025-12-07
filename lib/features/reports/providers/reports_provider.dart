import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/models.dart';
import '../../../common/services/services.dart';

/// Reports list state
class ReportsState {
  final List<Report> reports;
  final bool isLoading;
  final String? error;
  final String? statusFilter;

  const ReportsState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
  });

  ReportsState copyWith({
    List<Report>? reports,
    bool? isLoading,
    String? error,
    String? statusFilter,
  }) {
    return ReportsState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

/// Reports list notifier
class ReportsNotifier extends StateNotifier<ReportsState> {
  final ReportsService _service;

  ReportsNotifier(this._service) : super(const ReportsState()) {
    loadReports();
  }

  Future<void> loadReports() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reports = await _service.getReports(
        status: state.statusFilter,
      );
      state = state.copyWith(reports: reports, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadReports();
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status);
    loadReports();
  }

  void clearFilters() {
    state = state.copyWith(statusFilter: null);
    loadReports();
  }
}

/// Provider for reports list
final reportsProvider =
    StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  final service = ref.watch(reportsServiceProvider);
  return ReportsNotifier(service);
});

/// Create report state
class CreateReportState {
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedReceiptIds;
  final String? approverEmail;
  final String currency;
  final bool isCreating;
  final Report? createdReport;
  final String? error;

  const CreateReportState({
    this.title = '',
    this.startDate,
    this.endDate,
    this.selectedReceiptIds = const [],
    this.approverEmail,
    this.currency = 'USD',
    this.isCreating = false,
    this.createdReport,
    this.error,
  });

  CreateReportState copyWith({
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? selectedReceiptIds,
    String? approverEmail,
    String? currency,
    bool? isCreating,
    Report? createdReport,
    String? error,
  }) {
    return CreateReportState(
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedReceiptIds: selectedReceiptIds ?? this.selectedReceiptIds,
      approverEmail: approverEmail ?? this.approverEmail,
      currency: currency ?? this.currency,
      isCreating: isCreating ?? this.isCreating,
      createdReport: createdReport ?? this.createdReport,
      error: error,
    );
  }
}

/// Create report notifier
class CreateReportNotifier extends StateNotifier<CreateReportState> {
  final ReportsService _service;

  CreateReportNotifier(this._service) : super(const CreateReportState());

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void setApproverEmail(String? email) {
    state = state.copyWith(approverEmail: email);
  }

  void setCurrency(String currency) {
    state = state.copyWith(currency: currency);
  }

  void toggleReceipt(String receiptId) {
    final ids = List<String>.from(state.selectedReceiptIds);
    if (ids.contains(receiptId)) {
      ids.remove(receiptId);
    } else {
      ids.add(receiptId);
    }
    state = state.copyWith(selectedReceiptIds: ids);
  }

  void selectAllReceipts(List<String> receiptIds) {
    state = state.copyWith(selectedReceiptIds: receiptIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedReceiptIds: []);
  }

  Future<Report?> createReport() async {
    if (state.title.isEmpty) {
      state = state.copyWith(error: 'Please enter a title');
      return null;
    }

    if (state.selectedReceiptIds.isEmpty) {
      state = state.copyWith(error: 'Please select at least one receipt');
      return null;
    }

    state = state.copyWith(isCreating: true, error: null);

    try {
      final report = await _service.createReport(
        title: state.title,
        startDate: state.startDate,
        endDate: state.endDate,
        receiptIds: state.selectedReceiptIds,
        approverEmail: state.approverEmail,
        currency: state.currency,
      );

      state = state.copyWith(
        isCreating: false,
        createdReport: report,
      );

      return report;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const CreateReportState();
  }
}

/// Provider for create report
final createReportProvider =
    StateNotifierProvider<CreateReportNotifier, CreateReportState>((ref) {
  final service = ref.watch(reportsServiceProvider);
  return CreateReportNotifier(service);
});

/// Single report provider
final reportDetailProvider =
    FutureProvider.family<Report, String>((ref, id) async {
  final service = ref.watch(reportsServiceProvider);
  return service.getReport(id);
});

/// Submit report state
class SubmitReportState {
  final bool isSubmitting;
  final Report? submittedReport;
  final String? error;

  const SubmitReportState({
    this.isSubmitting = false,
    this.submittedReport,
    this.error,
  });
}

/// Submit report notifier
class SubmitReportNotifier extends StateNotifier<SubmitReportState> {
  final ReportsService _service;

  SubmitReportNotifier(this._service) : super(const SubmitReportState());

  Future<Report?> submitReport(String id) async {
    state = const SubmitReportState(isSubmitting: true);

    try {
      final report = await _service.submitReport(id);
      // Clear active report so a new one is created next time
      await _service.onReportSubmitted(id);
      state = SubmitReportState(submittedReport: report);
      return report;
    } catch (e) {
      state = SubmitReportState(error: e.toString());
      return null;
    }
  }
}

/// Provider for submit report
final submitReportProvider =
    StateNotifierProvider<SubmitReportNotifier, SubmitReportState>((ref) {
  final service = ref.watch(reportsServiceProvider);
  return SubmitReportNotifier(service);
});
