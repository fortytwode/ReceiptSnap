import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/models.dart';
import '../../../common/services/services.dart';

/// Auth state
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final StorageService _storage;

  AuthNotifier(this._authService, this._storage) : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      state = state.copyWith(user: currentUser);
    }
  }

  Future<void> loginAnonymous() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.loginAnonymous();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.loginWithEmail(email);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateDefaultCurrency(String currency) async {
    await _authService.updateDefaultCurrency(currency);
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(defaultCurrency: currency),
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }

  String get defaultCurrency => state.user?.defaultCurrency ?? _storage.defaultCurrency;
}

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(authService, storage);
});
