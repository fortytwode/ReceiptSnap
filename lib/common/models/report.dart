import 'package:equatable/equatable.dart';
import 'receipt.dart';

enum ReportStatus {
  draft,
  submitted,
  approved,
  rejected;

  static ReportStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return ReportStatus.draft;
      case 'submitted':
        return ReportStatus.submitted;
      case 'approved':
        return ReportStatus.approved;
      case 'rejected':
        return ReportStatus.rejected;
      default:
        return ReportStatus.draft;
    }
  }

  String toJson() {
    switch (this) {
      case ReportStatus.draft:
        return 'draft';
      case ReportStatus.submitted:
        return 'submitted';
      case ReportStatus.approved:
        return 'approved';
      case ReportStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.approved:
        return 'Approved';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }
}

class Report extends Equatable {
  final String id;
  final String title;
  final ReportStatus status;
  final List<Receipt> receipts;
  final double totalAmount;
  final String currency;
  final String? comment;
  final String? approverEmail;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.title,
    required this.status,
    required this.receipts,
    required this.totalAmount,
    required this.currency,
    this.comment,
    this.approverEmail,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      title: json['title'] as String,
      status: ReportStatus.fromString(json['status'] as String? ?? 'draft'),
      receipts: (json['receipts'] as List<dynamic>?)
              ?.map((e) => Receipt.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      comment: json['comment'] as String?,
      approverEmail: json['approverEmail'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.toJson(),
      'receipts': receipts.map((r) => r.toJson()).toList(),
      'totalAmount': totalAmount,
      'currency': currency,
      'comment': comment,
      'approverEmail': approverEmail,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Report copyWith({
    String? id,
    String? title,
    ReportStatus? status,
    List<Receipt>? receipts,
    double? totalAmount,
    String? currency,
    String? comment,
    String? approverEmail,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return Report(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      receipts: receipts ?? this.receipts,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      comment: comment ?? this.comment,
      approverEmail: approverEmail ?? this.approverEmail,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Calculate total dynamically from receipts, grouped by currency
  Map<String, double> get totalsByCurrency {
    final totals = <String, double>{};
    for (final receipt in receipts) {
      if (receipt.amount != null && receipt.amount! > 0) {
        final curr = receipt.currency ?? 'USD';
        totals[curr] = (totals[curr] ?? 0) + receipt.amount!;
      }
    }
    return totals;
  }

  /// Get the calculated total (sum of all receipt amounts, regardless of currency)
  double get calculatedTotal {
    return receipts.fold<double>(
      0,
      (sum, r) => sum + (r.amount ?? 0),
    );
  }

  String get formattedTotal {
    final totals = totalsByCurrency;

    // If no receipts with amounts, show zero in report currency
    if (totals.isEmpty) {
      final currencySymbol = _getCurrencySymbol(currency);
      return '$currencySymbol${0.toStringAsFixed(2)}';
    }

    // If all receipts are in the same currency, show that
    if (totals.length == 1) {
      final curr = totals.keys.first;
      final amount = totals[curr]!;
      final currencySymbol = _getCurrencySymbol(curr);
      return '$currencySymbol${amount.toStringAsFixed(2)}';
    }

    // Multiple currencies - show the first one with indicator
    final firstCurrency = totals.keys.first;
    final firstAmount = totals[firstCurrency]!;
    final currencySymbol = _getCurrencySymbol(firstCurrency);
    return '$currencySymbol${firstAmount.toStringAsFixed(2)} +';
  }

  /// Get formatted breakdown of all currency totals
  String get formattedTotalBreakdown {
    final totals = totalsByCurrency;
    if (totals.isEmpty) return 'No amounts';

    return totals.entries.map((e) {
      final symbol = _getCurrencySymbol(e.key);
      return '$symbol${e.value.toStringAsFixed(2)}';
    }).join(' + ');
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
      case 'RSD':
        return 'RSD ';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'CHF':
        return 'CHF ';
      default:
        return '$currency ';
    }
  }

  int get receiptCount => receipts.length;

  @override
  List<Object?> get props => [
        id,
        title,
        status,
        receipts,
        totalAmount,
        currency,
        comment,
        approverEmail,
        startDate,
        endDate,
        createdAt,
      ];
}
