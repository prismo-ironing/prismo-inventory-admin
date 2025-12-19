import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/manager_auth_service.dart';
import '../models/manager.dart';

/// Manager auth service provider
final managerAuthServiceProvider = Provider<ManagerAuthService>((ref) {
  return ManagerAuthService();
});

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(managerAuthServiceProvider);
  return AuthNotifier(authService, ref);
});

/// Current manager provider
final currentManagerProvider = Provider<Manager?>((ref) {
  final authService = ref.watch(managerAuthServiceProvider);
  return authService.currentManager;
});

/// Auth status enum
enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Auth state class
class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.errorMessage,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.authenticated() : this(status: AuthStatus.authenticated);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.error(String errorMessage) : this(
    status: AuthStatus.error,
    errorMessage: errorMessage,
  );

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => status == AuthStatus.error;
}

/// Auth notifier - manages auth state
class AuthNotifier extends StateNotifier<AuthState> {
  final ManagerAuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(const AuthState.loading()) {
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    final authState = await _authService.getAuthState();
    final isLoggedIn = authState['isLoggedIn'] as bool;

    print('AUTH_PROVIDER: Checking saved auth state - isLoggedIn: $isLoggedIn');

    if (isLoggedIn) {
      final success = await _restoreManagerProfile();
      if (success) {
        state = const AuthState.authenticated();
        print('AUTH_PROVIDER: Successfully restored manager authentication');
      } else {
        await _authService.logout();
        state = const AuthState.unauthenticated();
        print('AUTH_PROVIDER: Failed to restore manager, cleared auth state');
      }
    } else {
      state = const AuthState.unauthenticated();
      print('AUTH_PROVIDER: No saved authentication found');
    }
  }

  Future<bool> _restoreManagerProfile() async {
    try {
      final success = await _authService.refreshManagerProfile();
      if (success) {
        _ref.invalidate(currentManagerProvider);
        return true;
      }
      return false;
    } catch (e) {
      print('AUTH_PROVIDER: Error restoring manager profile: $e');
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();

    try {
      final success = await _authService.login(
        email: email,
        password: password,
      );

      if (success) {
        state = const AuthState.authenticated();
        _ref.invalidate(currentManagerProvider);
        return true;
      } else {
        state = const AuthState.unauthenticated();
        return false;
      }
    } catch (e) {
      state = AuthState.error(e.toString());
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = const AuthState.loading();
    await _authService.logout();
    state = const AuthState.unauthenticated();
    _ref.invalidate(currentManagerProvider);
  }

  /// Clear error state
  void clearError() {
    if (state.hasError) {
      state = const AuthState.unauthenticated();
    }
  }

  /// Start phone number verification
  /// Note: We don't change the auth state during this process to avoid
  /// rebuilding the widget tree and losing the callback context
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(String) onError,
  }) async {
    // Don't set state to loading - this would cause widget rebuild
    // state = const AuthState.loading();
    bool codeSentCalled = false;

    try {
      print('AUTH_PROVIDER: Starting phone verification for: $phoneNumber');
      
      final verificationId = await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('AUTH_PROVIDER: Phone verification completed automatically');
        },
        verificationFailed: (FirebaseAuthException e) {
          print('AUTH_PROVIDER: Phone verification failed: ${e.message}');
          // Don't change state here either - let the UI handle the error
          onError(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!codeSentCalled) {
            codeSentCalled = true;
            print('AUTH_PROVIDER: Code sent callback triggered, verificationId: $verificationId');
            // Don't change state - just call the callback
            onCodeSent(verificationId, resendToken);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('AUTH_PROVIDER: Phone verification timeout for: $verificationId');
        },
      );

      // For web, the verificationId is returned directly from the JS function
      // Only call onCodeSent if it hasn't been called yet
      if (verificationId != null && !codeSentCalled) {
        codeSentCalled = true;
        print('AUTH_PROVIDER: Verification ID returned directly: $verificationId');
        // Don't change state - just call the callback
        onCodeSent(verificationId, null);
      }
      
      print('AUTH_PROVIDER: verifyPhoneNumber completed, codeSentCalled: $codeSentCalled');
    } catch (e) {
      print('AUTH_PROVIDER: Phone verification error: $e');
      onError(e.toString());
    }
  }

  /// Complete phone number sign in with verification code
  /// Returns true if existing manager logged in, false if new user needs registration
  Future<bool> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phoneNumber,
  }) async {
    // Don't change state to loading here - let the UI handle it
    try {
      final success = await _authService.signInWithPhoneNumber(
        verificationId: verificationId,
        smsCode: smsCode,
        name: name,
        phoneNumber: phoneNumber,
      );

      if (success) {
        state = const AuthState.authenticated();
        _ref.invalidate(currentManagerProvider);
        return true;
      } else {
        // New user - needs registration (don't change state yet)
        return false;
      }
    } catch (e) {
      print('AUTH_PROVIDER: signInWithPhoneNumber error: $e');
      state = AuthState.error(e.toString());
      return false;
    }
  }
  
  /// Register new manager with phone number
  Future<bool> registerManager({
    required String phoneNumber,
    required String name,
  }) async {
    try {
      final success = await _authService.registerWithPhone(
        phoneNumber: phoneNumber,
        name: name,
      );

      if (success) {
        state = const AuthState.authenticated();
        _ref.invalidate(currentManagerProvider);
        return true;
      } else {
        state = const AuthState.unauthenticated();
        return false;
      }
    } catch (e) {
      print('AUTH_PROVIDER: registerManager error: $e');
      state = AuthState.error(e.toString());
      return false;
    }
  }
}

