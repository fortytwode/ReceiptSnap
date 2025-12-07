/// API Configuration
///
/// Update these values when connecting to a real backend.
class ApiConfig {
  /// Base URL for the API
  /// TODO: Update this with your actual backend URL
  static const String baseUrl = 'https://api.receiptsnap.test';

  /// Enable mock mode to use fake data instead of real API calls
  /// When false, uses local SQLite database for persistence
  static const bool mockMode = false;

  /// Use demo data on first launch (populates some sample receipts)
  static const bool useDemoData = false;

  /// API timeout in seconds
  static const int timeout = 30;

  /// Endpoints
  static const String authAnonymous = '/auth/anonymous';
  static const String authLogin = '/auth/login';
  static const String receipts = '/receipts';
  static const String reports = '/reports';
}
