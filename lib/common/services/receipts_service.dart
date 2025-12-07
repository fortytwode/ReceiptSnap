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

  // In-memory mock storage - only used when mockMode = true
  static List<Receipt>? _mockReceiptsStorage;

  static List<Receipt> get mockReceipts {
    _mockReceiptsStorage ??= List.from(MockData.mockReceipts);
    return _mockReceiptsStorage!;
  }

  /// Get all receipts with optional filters
  /// By default, hides receipts that are already in a report (unless status='in_report')
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
      } else {
        // Default: hide receipts that are already in a report
        results = results.where((r) => r.reportId == null).toList();
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

  /// Infer category from merchant name
  String _inferCategory(String? merchant) {
    if (merchant == null) return 'Other';
    final lower = merchant.toLowerCase();

    // Common category mappings
    if (lower.contains('hotel') ||
        lower.contains('inn') ||
        lower.contains('lodge') ||
        lower.contains('airbnb') ||
        lower.contains('smeštaj')) {
      return 'Lodging';
    }
    if (lower.contains('uber') ||
        lower.contains('lyft') ||
        lower.contains('taxi') ||
        lower.contains('bolt')) {
      return 'Transportation';
    }
    if (lower.contains('airline') ||
        lower.contains('flight') ||
        lower.contains('delta') ||
        lower.contains('united') ||
        lower.contains('american')) {
      return 'Travel';
    }
    if (lower.contains('starbucks') ||
        lower.contains('coffee') ||
        lower.contains('cafe') ||
        lower.contains('restaurant') ||
        lower.contains('food') ||
        lower.contains('doručak')) {
      return 'Food & Drink';
    }
    if (lower.contains('office') ||
        lower.contains('staples') ||
        lower.contains('depot')) {
      return 'Office Supplies';
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
}

/// Provider for ReceiptsService
final receiptsServiceProvider = Provider<ReceiptsService>((ref) {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(databaseServiceProvider);
  final ocr = ref.watch(ocrServiceProvider);
  return ReceiptsService(api, db, ocr);
});
