import 'package:equatable/equatable.dart';

enum OcrStatus {
  pendingOcr,
  needsConfirmation,
  confirmed;

  static OcrStatus fromString(String value) {
    switch (value) {
      case 'pending_ocr':
        return OcrStatus.pendingOcr;
      case 'needs_confirmation':
        return OcrStatus.needsConfirmation;
      case 'confirmed':
        return OcrStatus.confirmed;
      default:
        return OcrStatus.pendingOcr;
    }
  }

  String toJson() {
    switch (this) {
      case OcrStatus.pendingOcr:
        return 'pending_ocr';
      case OcrStatus.needsConfirmation:
        return 'needs_confirmation';
      case OcrStatus.confirmed:
        return 'confirmed';
    }
  }

  String get displayName {
    switch (this) {
      case OcrStatus.pendingOcr:
        return 'Processing';
      case OcrStatus.needsConfirmation:
        return 'Needs Review';
      case OcrStatus.confirmed:
        return 'Confirmed';
    }
  }
}

class Receipt extends Equatable {
  final String id;
  final String imageUrl;
  final String? merchant;
  final DateTime? date;
  final double? amount;
  final String? currency;
  final String? category;
  final String? note;
  final OcrStatus ocrStatus;
  final String? reportId;
  final DateTime createdAt;

  const Receipt({
    required this.id,
    required this.imageUrl,
    this.merchant,
    this.date,
    this.amount,
    this.currency,
    this.category,
    this.note,
    required this.ocrStatus,
    this.reportId,
    required this.createdAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      merchant: json['merchant'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      currency: json['currency'] as String?,
      category: json['category'] as String?,
      note: json['note'] as String?,
      ocrStatus: OcrStatus.fromString(json['ocrStatus'] as String? ?? 'pending_ocr'),
      reportId: json['reportId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'merchant': merchant,
      'date': date?.toIso8601String(),
      'amount': amount,
      'currency': currency,
      'category': category,
      'note': note,
      'ocrStatus': ocrStatus.toJson(),
      'reportId': reportId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Receipt copyWith({
    String? id,
    String? imageUrl,
    String? merchant,
    DateTime? date,
    double? amount,
    String? currency,
    String? category,
    String? note,
    OcrStatus? ocrStatus,
    String? reportId,
    DateTime? createdAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      note: note ?? this.note,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      reportId: reportId ?? this.reportId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isInReport => reportId != null;

  String get formattedAmount {
    if (amount == null) return '-';
    final currencySymbol = _getCurrencySymbol(currency ?? 'USD');
    return '$currencySymbol${amount!.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'INR':
        return '\u20B9';
      case 'JPY':
        return '\u00A5';
      default:
        return currency;
    }
  }

  @override
  List<Object?> get props => [
        id,
        imageUrl,
        merchant,
        date,
        amount,
        currency,
        category,
        note,
        ocrStatus,
        reportId,
        createdAt,
      ];
}
