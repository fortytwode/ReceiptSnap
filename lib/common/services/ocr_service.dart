import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result of OCR processing
class OcrResult {
  final String? merchant;
  final DateTime? date;
  final double? amount;
  final String? currency;
  final String rawText;
  final double confidence;

  const OcrResult({
    this.merchant,
    this.date,
    this.amount,
    this.currency,
    required this.rawText,
    this.confidence = 0.0,
  });

  @override
  String toString() =>
      'OcrResult(merchant: $merchant, date: $date, amount: $amount, currency: $currency)';
}

/// Service for OCR text recognition and parsing
class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process an image and extract receipt data
  Future<OcrResult> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final rawText = recognizedText.text;
      debugPrint('OCR Raw Text:\n$rawText');

      // Parse the raw text
      final merchant = _extractMerchant(recognizedText);
      final date = _extractDate(rawText);
      final (amount, currency) = _extractAmountAndCurrency(rawText);

      return OcrResult(
        merchant: merchant,
        date: date,
        amount: amount,
        currency: currency,
        rawText: rawText,
        confidence: _calculateConfidence(merchant, date, amount),
      );
    } catch (e) {
      debugPrint('OCR Error: $e');
      return OcrResult(rawText: '', confidence: 0.0);
    }
  }

  /// Extract merchant name - usually the first prominent text block
  String? _extractMerchant(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    // Look at the first few text blocks for the merchant name
    // Usually it's at the top and is prominent (larger text)
    for (final block in recognizedText.blocks.take(3)) {
      final text = block.text.trim();
      // Skip if it looks like a date, number, or common header
      if (_looksLikeMerchant(text)) {
        // Clean up the merchant name
        return _cleanMerchantName(text);
      }
    }

    // Fallback: just use the first non-empty line
    final firstLine = recognizedText.text.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty && line.trim().length > 2,
          orElse: () => '',
        );
    return firstLine.isNotEmpty ? _cleanMerchantName(firstLine) : null;
  }

  bool _looksLikeMerchant(String text) {
    // Skip if it's mostly numbers
    final digitCount = text.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount > text.length * 0.5) return false;

    // Skip common non-merchant headers
    final lower = text.toLowerCase();
    final skipWords = ['receipt', 'invoice', 'date', 'time', 'tel', 'fax', 'www'];
    if (skipWords.any((w) => lower.startsWith(w))) return false;

    // Must have at least 2 characters
    return text.length >= 2;
  }

  String _cleanMerchantName(String text) {
    // Take first line if multiline
    var cleaned = text.split('\n').first.trim();
    // Remove common suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s*(Ltd|LLC|Inc|Corp|GmbH|S\.?A\.?)\.?\s*$', caseSensitive: false), '').trim();
    // Limit length
    if (cleaned.length > 50) cleaned = cleaned.substring(0, 50);
    return cleaned;
  }

  /// Extract date from text using various formats
  DateTime? _extractDate(String text) {
    // Common date patterns
    final datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})'),
      // YYYY/MM/DD or YYYY-MM-DD
      RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})'),
      // Month DD, YYYY
      RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false),
      // DD Month YYYY
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{4})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          return _parseMatchedDate(match, pattern);
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  DateTime? _parseMatchedDate(RegExpMatch match, RegExp pattern) {
    final patternStr = pattern.pattern;

    // DD/MM/YYYY format
    if (patternStr.contains(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})')) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      // Handle ambiguous dates (could be MM/DD/YYYY in US)
      if (day <= 12 && month <= 12) {
        // Assume DD/MM/YYYY for non-US
        return DateTime(year, month, day);
      }
      return DateTime(year, month > 12 ? day : month, month > 12 ? month : day);
    }

    // YYYY/MM/DD format
    if (patternStr.contains(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})')) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }

    // Month name formats
    if (patternStr.contains('Jan|Feb')) {
      final monthNames = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };

      String? monthStr;
      int? day, year;

      for (var i = 1; i <= match.groupCount; i++) {
        final g = match.group(i)!;
        final monthKey = g.toLowerCase().substring(0, 3);
        if (monthNames.containsKey(monthKey)) {
          monthStr = monthKey;
        } else if (g.length == 4) {
          year = int.parse(g);
        } else {
          day = int.parse(g);
        }
      }

      if (monthStr != null && day != null && year != null) {
        return DateTime(year, monthNames[monthStr]!, day);
      }
    }

    return null;
  }

  /// Extract amount and currency from text
  (double?, String?) _extractAmountAndCurrency(String text) {
    // Currency keywords to look for near amounts
    final currencyPatterns = {
      'RSD': RegExp(r'RSD|РСД|din|динар', caseSensitive: false),
      'USD': RegExp(r'\$|USD|US\s*Dollar', caseSensitive: false),
      'EUR': RegExp(r'€|EUR|Euro', caseSensitive: false),
      'GBP': RegExp(r'£|GBP|Pound', caseSensitive: false),
      'INR': RegExp(r'₹|INR|Rupee', caseSensitive: false),
      'JPY': RegExp(r'¥|JPY|Yen', caseSensitive: false),
      'CNY': RegExp(r'¥|CNY|Yuan|RMB', caseSensitive: false),
    };

    // Keywords that indicate a total
    final totalKeywords = [
      'total', 'ukupno', 'suma', 'subtotal', 'amount', 'due', 'pay',
      'grand total', 'net', 'balance', 'итого', 'всего', '合計', '总计',
      'gesamt', 'summe', 'montant', 'totale', 'vrednost',
    ];

    // Find all amounts in the text
    final amountPattern = RegExp(r'[\$€£¥₹]?\s*(\d{1,3}(?:[,.\s]\d{3})*(?:[,.]\d{1,2})?)\s*(?:RSD|USD|EUR|GBP|INR|JPY)?', caseSensitive: false);
    final matches = amountPattern.allMatches(text);

    double? largestAmount;
    double? totalAmount;
    String? detectedCurrency;

    // Detect currency from text
    for (final entry in currencyPatterns.entries) {
      if (entry.value.hasMatch(text)) {
        detectedCurrency = entry.key;
        break;
      }
    }

    // Look for amounts near "total" keywords
    final lowerText = text.toLowerCase();
    for (final keyword in totalKeywords) {
      final keywordIndex = lowerText.indexOf(keyword);
      if (keywordIndex != -1) {
        // Look for amount within 50 chars after the keyword
        final searchArea = text.substring(
          keywordIndex,
          (keywordIndex + 100).clamp(0, text.length),
        );
        final match = amountPattern.firstMatch(searchArea);
        if (match != null) {
          final amount = _parseAmount(match.group(1)!);
          if (amount != null && amount > 0) {
            totalAmount = amount;
            break;
          }
        }
      }
    }

    // Also find the largest amount as fallback
    for (final match in matches) {
      final amount = _parseAmount(match.group(1)!);
      if (amount != null && (largestAmount == null || amount > largestAmount)) {
        largestAmount = amount;
      }
    }

    // Prefer total keyword match, fallback to largest
    final finalAmount = totalAmount ?? largestAmount;

    return (finalAmount, detectedCurrency);
  }

  double? _parseAmount(String amountStr) {
    try {
      // Remove currency symbols and whitespace
      var cleaned = amountStr.replaceAll(RegExp(r'[\$€£¥₹\s]'), '');

      // Handle different decimal separators
      // If there's a comma followed by exactly 2 digits at the end, it's decimal
      if (RegExp(r',\d{2}$').hasMatch(cleaned)) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Otherwise, remove commas as thousand separators
        cleaned = cleaned.replaceAll(',', '');
      }

      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  double _calculateConfidence(String? merchant, DateTime? date, double? amount) {
    var score = 0.0;
    if (merchant != null && merchant.isNotEmpty) score += 0.3;
    if (date != null) score += 0.3;
    if (amount != null && amount > 0) score += 0.4;
    return score;
  }

  /// Close the text recognizer when done
  void dispose() {
    _textRecognizer.close();
  }
}

/// Provider for OcrService
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(() => service.dispose());
  return service;
});
