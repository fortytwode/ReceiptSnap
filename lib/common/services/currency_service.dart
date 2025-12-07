import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currency conversion service with exchange rates
/// Rates are relative to USD (1 USD = X currency)
class CurrencyService {
  // Exchange rates relative to USD (approximate rates - can be updated)
  static const Map<String, double> _ratesVsUsd = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 149.50,
    'CAD': 1.36,
    'AUD': 1.53,
    'CHF': 0.88,
    'CNY': 7.24,
    'INR': 83.12,
    'MXN': 17.15,
    'BRL': 4.97,
    'KRW': 1320.0,
    'SGD': 1.34,
    'HKD': 7.82,
    'NOK': 10.65,
    'SEK': 10.42,
    'DKK': 6.88,
    'NZD': 1.63,
    'ZAR': 18.65,
    'RUB': 92.50,
    'TRY': 28.90,
    'THB': 35.50,
    'RSD': 108.50,
  };

  /// Get all supported currencies
  List<String> get supportedCurrencies => _ratesVsUsd.keys.toList();

  /// Convert an amount from one currency to another
  double convert({
    required double amount,
    required String from,
    required String to,
  }) {
    if (from == to) return amount;

    final fromRate = _ratesVsUsd[from.toUpperCase()];
    final toRate = _ratesVsUsd[to.toUpperCase()];

    if (fromRate == null || toRate == null) {
      // Unknown currency, return original amount
      return amount;
    }

    // Convert to USD first, then to target currency
    final amountInUsd = amount / fromRate;
    return amountInUsd * toRate;
  }

  /// Convert an amount to USD
  double toUsd(double amount, String currency) {
    return convert(amount: amount, from: currency, to: 'USD');
  }

  /// Convert an amount from USD to a target currency
  double fromUsd(double amount, String targetCurrency) {
    return convert(amount: amount, from: 'USD', to: targetCurrency);
  }

  /// Get the exchange rate from one currency to another
  double getRate({required String from, required String to}) {
    return convert(amount: 1.0, from: from, to: to);
  }

  /// Get formatted conversion string
  String formatConversion({
    required double amount,
    required String from,
    required String to,
  }) {
    final converted = convert(amount: amount, from: from, to: to);
    final toSymbol = getCurrencySymbol(to);
    return '$toSymbol${converted.toStringAsFixed(2)}';
  }

  /// Get currency symbol for a currency code
  String getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'JPY':
      case 'CNY':
        return '\u00A5';
      case 'INR':
        return '\u20B9';
      case 'KRW':
        return '\u20A9';
      case 'RUB':
        return '\u20BD';
      case 'THB':
        return '\u0E3F';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'NZD':
        return 'NZ\$';
      case 'HKD':
        return 'HK\$';
      case 'SGD':
        return 'S\$';
      case 'CHF':
        return 'CHF ';
      case 'RSD':
        return 'RSD ';
      case 'MXN':
        return 'MX\$';
      case 'BRL':
        return 'R\$';
      case 'ZAR':
        return 'R';
      case 'TRY':
        return '\u20BA';
      default:
        return '$currency ';
    }
  }

  /// Convert all amounts in a map of currency totals to a single currency
  double convertTotalsToCurrency(
    Map<String, double> totalsByCurrency,
    String targetCurrency,
  ) {
    double total = 0;
    for (final entry in totalsByCurrency.entries) {
      total += convert(
        amount: entry.value,
        from: entry.key,
        to: targetCurrency,
      );
    }
    return total;
  }

  /// Format a total in a target currency with conversion
  String formatConvertedTotal(
    Map<String, double> totalsByCurrency,
    String targetCurrency,
  ) {
    final total = convertTotalsToCurrency(totalsByCurrency, targetCurrency);
    final symbol = getCurrencySymbol(targetCurrency);
    return '$symbol${total.toStringAsFixed(2)}';
  }
}

/// Provider for CurrencyService
final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService();
});
