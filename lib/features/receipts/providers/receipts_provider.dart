import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/models.dart';
import '../../../common/services/services.dart';

/// Receipts list state
class ReceiptsState {
  final List<Receipt> receipts;
  final bool isLoading;
  final String? error;
  final String? statusFilter;
  final String? searchQuery;

  const ReceiptsState({
    this.receipts = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.searchQuery,
  });

  ReceiptsState copyWith({
    List<Receipt>? receipts,
    bool? isLoading,
    String? error,
    String? statusFilter,
    String? searchQuery,
  }) {
    return ReceiptsState(
      receipts: receipts ?? this.receipts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Receipts list notifier
class ReceiptsNotifier extends StateNotifier<ReceiptsState> {
  final ReceiptsService _service;

  ReceiptsNotifier(this._service) : super(const ReceiptsState()) {
    loadReceipts();
  }

  Future<void> loadReceipts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final receipts = await _service.getReceipts(
        status: state.statusFilter,
        search: state.searchQuery,
      );
      state = state.copyWith(receipts: receipts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadReceipts();
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status);
    loadReceipts();
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
    loadReceipts();
  }

  void clearFilters() {
    state = state.copyWith(statusFilter: null, searchQuery: null);
    loadReceipts();
  }
}

/// Provider for receipts list
final receiptsProvider =
    StateNotifierProvider<ReceiptsNotifier, ReceiptsState>((ref) {
  final service = ref.watch(receiptsServiceProvider);
  return ReceiptsNotifier(service);
});

/// Upload receipt state
class UploadReceiptState {
  final bool isUploading;
  final bool isProcessing;
  final Receipt? receipt;
  final String? error;
  final String statusMessage;

  const UploadReceiptState({
    this.isUploading = false,
    this.isProcessing = false,
    this.receipt,
    this.error,
    this.statusMessage = '',
  });

  UploadReceiptState copyWith({
    bool? isUploading,
    bool? isProcessing,
    Receipt? receipt,
    String? error,
    String? statusMessage,
  }) {
    return UploadReceiptState(
      isUploading: isUploading ?? this.isUploading,
      isProcessing: isProcessing ?? this.isProcessing,
      receipt: receipt ?? this.receipt,
      error: error,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// Upload receipt notifier
class UploadReceiptNotifier extends StateNotifier<UploadReceiptState> {
  final ReceiptsService _service;

  UploadReceiptNotifier(this._service) : super(const UploadReceiptState());

  Future<Receipt?> uploadReceipt(File imageFile) async {
    state = state.copyWith(
      isUploading: true,
      error: null,
      statusMessage: 'Uploading receipt...',
    );

    try {
      final receipt = await _service.uploadReceipt(imageFile);

      state = state.copyWith(
        isUploading: false,
        isProcessing: true,
        statusMessage: 'Reading your receipt...',
      );

      // Poll for OCR completion
      final processedReceipt = await _service.pollForOcrCompletion(receipt.id);

      state = state.copyWith(
        isProcessing: false,
        receipt: processedReceipt,
        statusMessage: 'Done!',
      );

      return processedReceipt;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        isProcessing: false,
        error: e.toString(),
        statusMessage: 'Error processing receipt',
      );
      return null;
    }
  }

  void reset() {
    state = const UploadReceiptState();
  }
}

/// Provider for upload receipt
final uploadReceiptProvider =
    StateNotifierProvider<UploadReceiptNotifier, UploadReceiptState>((ref) {
  final service = ref.watch(receiptsServiceProvider);
  return UploadReceiptNotifier(service);
});

/// Single receipt provider
final receiptDetailProvider =
    FutureProvider.family<Receipt, String>((ref, id) async {
  final service = ref.watch(receiptsServiceProvider);
  return service.getReceipt(id);
});

/// Available receipts for report provider
final availableReceiptsProvider = FutureProvider<List<Receipt>>((ref) async {
  final service = ref.watch(receiptsServiceProvider);
  return service.getAvailableForReport();
});
