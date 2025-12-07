import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// Storage keys
class StorageKeys {
  static const String onboardingCompleted = 'onboarding_completed';
  static const String authToken = 'auth_token';
  static const String userId = 'user_id';
  static const String defaultCurrency = 'default_currency';
  static const String userName = 'user_name';
  static const String userEmail = 'user_email';
}

/// Storage service for persistent data
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Onboarding
  bool get isOnboardingCompleted =>
      _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _prefs.setBool(StorageKeys.onboardingCompleted, value);

  // Auth
  String? get authToken => _prefs.getString(StorageKeys.authToken);

  Future<void> setAuthToken(String token) =>
      _prefs.setString(StorageKeys.authToken, token);

  Future<void> clearAuthToken() => _prefs.remove(StorageKeys.authToken);

  // User
  String? get userId => _prefs.getString(StorageKeys.userId);

  Future<void> setUserId(String id) =>
      _prefs.setString(StorageKeys.userId, id);

  String? get userName => _prefs.getString(StorageKeys.userName);

  Future<void> setUserName(String name) =>
      _prefs.setString(StorageKeys.userName, name);

  String? get userEmail => _prefs.getString(StorageKeys.userEmail);

  Future<void> setUserEmail(String email) =>
      _prefs.setString(StorageKeys.userEmail, email);

  // Currency
  String get defaultCurrency =>
      _prefs.getString(StorageKeys.defaultCurrency) ?? 'USD';

  Future<void> setDefaultCurrency(String currency) =>
      _prefs.setString(StorageKeys.defaultCurrency, currency);

  // Clear all
  Future<void> clearAll() => _prefs.clear();
}

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});
