import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'database_service.dart';
import 'mock_data.dart';

/// Receipts service for managing receipt data
class ReceiptsService {
  final ApiClient _api;
  final DatabaseService _db;

  ReceiptsService(this._api, this._db);

  // In-memory mock storage - only used when mockMode = true
  static List<Receipt>? _mockReceiptsStorage;

  static List<Receipt> get mockReceipts {
    _mockReceiptsStorage ??= List.from(MockData.mockReceipts);
    return _mockReceiptsStorage!;
  }

  /// Get all receipts with optional filters
  Future<List<Receipt>> getReceipts({
    String? status,
    String? search,
  }) async {
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
            results = results.where((r) => r.reportId != null).toList();
            break;
        }
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
    return await _db.getReceipts(status: status, search: search);
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

  /// Poll for OCR completion (simulates backend OCR processing)
  Future<Receipt> pollForOcrCompletion(
    String id, {
    int maxAttempts = 30,
    Duration interval = const Duration(seconds: 1),
  }) async {
    // Simulate OCR processing - in production this would call the backend
    await Future.delayed(const Duration(seconds: 2));

    // Simulated extracted data
    final updated = Receipt(
      id: id,
      imageUrl: (await getReceipt(id)).imageUrl,
      merchant: 'Scanned Merchant',
      date: DateTime.now(),
      amount: 0.00, // User will enter
      currency: 'USD',
      category: 'Other',
      ocrStatus: OcrStatus.needsConfirmation,
      reportId: null,
      createdAt: DateTime.now(),
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
}

/// Provider for ReceiptsService
final receiptsServiceProvider = Provider<ReceiptsService>((ref) {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(databaseServiceProvider);
  return ReceiptsService(api, db);
});
