import 'package:intl/intl.dart';

/// Date formatting utilities
class DateFormatters {
  static final DateFormat yMMMd = DateFormat.yMMMd();
  static final DateFormat yMMMMd = DateFormat.yMMMMd();
  static final DateFormat yMd = DateFormat.yMd();
  static final DateFormat MMMd = DateFormat.MMMd();
  static final DateFormat MMMM = DateFormat.MMMM();
  static final DateFormat y = DateFormat.y();

  static String formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return yMMMd.format(date);
  }

  static String formatDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${yMMMd.format(start)} - ${yMMMd.format(end)}';
    }
    if (start != null) {
      return 'From ${yMMMd.format(start)}';
    }
    return 'Until ${yMMMd.format(end!)}';
  }

  static String getMonthYear(DateTime date) {
    return '${MMMM.format(date)} ${y.format(date)}';
  }
}

/// Currency formatting utilities
class CurrencyFormatters {
  static String formatAmount(double? amount, String? currency) {
    if (amount == null) return '-';
    final symbol = getCurrencySymbol(currency ?? 'USD');
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static String getCurrencySymbol(String currency) {
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
}
