import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'mock_data.dart';
import 'storage_service.dart';

/// Authentication service
class AuthService {
  final ApiClient _api;
  final StorageService _storage;

  AuthService(this._api, this._storage);

  /// Login anonymously (creates a device-based session)
  Future<User> loginAnonymous() async {
    if (ApiConfig.mockMode) {
      // Generate a unique device ID if not exists
      var userId = _storage.userId;
      if (userId == null) {
        userId = const Uuid().v4();
        await _storage.setUserId(userId);
      }
      await _storage.setAuthToken(MockData.mockToken);
      return MockData.mockUser.copyWith(id: userId);
    }

    final response = await _api.post(ApiConfig.authAnonymous);
    final data = response.data as Map<String, dynamic>;

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;

    await _storage.setAuthToken(token);
    await _storage.setUserId(user.id);
    if (user.name != null) await _storage.setUserName(user.name!);
    if (user.email != null) await _storage.setUserEmail(user.email!);

    return user;
  }

  /// Login with email
  Future<User> loginWithEmail(String email) async {
    if (ApiConfig.mockMode) {
      await _storage.setAuthToken(MockData.mockToken);
      await _storage.setUserId(MockData.mockUserId);
      await _storage.setUserEmail(email);
      return MockData.mockUser.copyWith(email: email);
    }

    final response = await _api.post(
      ApiConfig.authLogin,
      data: {'email': email},
    );
    final data = response.data as Map<String, dynamic>;

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;

    await _storage.setAuthToken(token);
    await _storage.setUserId(user.id);
    if (user.name != null) await _storage.setUserName(user.name!);
    await _storage.setUserEmail(email);

    return user;
  }

  /// Get current user from storage
  User? getCurrentUser() {
    final userId = _storage.userId;
    if (userId == null) return null;

    return User(
      id: userId,
      name: _storage.userName,
      email: _storage.userEmail,
      defaultCurrency: _storage.defaultCurrency,
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _storage.authToken != null;

  /// Logout
  Future<void> logout() async {
    await _storage.clearAuthToken();
    // Keep userId for anonymous re-auth
  }

  /// Update user currency preference
  Future<void> updateDefaultCurrency(String currency) async {
    await _storage.setDefaultCurrency(currency);
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthService(api, storage);
});
