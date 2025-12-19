import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../config/api_config.dart';
import '../models/manager.dart';

/// Manager Authentication Service (Web-only)
/// Uses JavaScript Firebase SDK for phone authentication
class ManagerAuthService {
  final http.Client _client;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Manager? _currentManager;

  ManagerAuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Get current authenticated manager
  Manager? get currentManager => _currentManager;

  /// Check if user is currently authenticated
  bool get isAuthenticated => _currentManager != null;

  /// Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  /// Stream of Firebase auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Common headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // =====================================================
  // EMAIL/PASSWORD AUTHENTICATION
  // =====================================================

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      print('MANAGER_AUTH: Logging in manager: $email');

      final loginData = {
        'email': email,
        'password': password,
      };

      final response = await _client.post(
        Uri.parse(ApiConfig.managerEmailLoginUrl),
        headers: _headers,
        body: jsonEncode(loginData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['manager'] != null) {
          _currentManager = Manager.fromJson(responseData['manager']);
          print('MANAGER_AUTH: Login successful for manager: ${_currentManager!.id}');
          await _saveAuthState(true, 'email');
          return true;
        } else {
          throw Exception(responseData['message'] ?? 'Login failed');
        }
      } else if (response.statusCode == 401) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Invalid email or password';
        print('MANAGER_AUTH: Login failed - invalid credentials');
        throw Exception(errorMessage);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Login failed. Please try again.';
        print('MANAGER_AUTH: Login failed: ${response.statusCode} $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('MANAGER_AUTH: Login error: $e');
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        throw Exception('Unable to connect to server. Please check your internet connection.');
      }
      rethrow;
    }
  }

  // =====================================================
  // PHONE NUMBER AUTHENTICATION (Web - JavaScript interop)
  // =====================================================

  /// Verify phone number and send OTP using JavaScript Firebase SDK
  Future<String?> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      final formattedPhoneNumber = _validateAndFormatPhoneNumber(phoneNumber);
      if (formattedPhoneNumber == null) {
        verificationFailed(FirebaseAuthException(
          code: 'invalid-phone-number',
          message: 'Invalid phone number format. Please include country code (e.g., +919876543210)',
        ));
        return null;
      }

      print('MANAGER_AUTH: Starting phone verification for: $formattedPhoneNumber');

      // Use JavaScript Firebase SDK for phone verification
      final verificationId = await _sendPhoneVerificationJS(formattedPhoneNumber);
      
      if (verificationId != null) {
        print('MANAGER_AUTH: SMS sent successfully, verification ID: $verificationId');
        codeSent(verificationId, null);
        return verificationId;
      } else {
        throw Exception('Failed to send verification code');
      }
    } catch (e) {
      print('MANAGER_AUTH: Phone verification error: $e');
      verificationFailed(FirebaseAuthException(
        code: 'verification-failed',
        message: e.toString(),
      ));
      rethrow;
    }
  }

  /// Call JavaScript sendPhoneVerification function from index.html
  Future<String?> _sendPhoneVerificationJS(String phoneNumber) async {
    try {
      print('MANAGER_AUTH: Calling JS sendPhoneVerification...');
      
      // Check if the function exists
      final hasFunction = js_util.hasProperty(html.window, 'sendPhoneVerification');
      if (!hasFunction) {
        throw Exception('sendPhoneVerification function not found. Check index.html setup.');
      }
      
      // Call the JavaScript function and await the Promise
      final promise = js_util.callMethod(html.window, 'sendPhoneVerification', [phoneNumber]);
      final result = await js_util.promiseToFuture(promise);
      
      return result?.toString();
    } catch (e) {
      print('MANAGER_AUTH: JS sendPhoneVerification error: $e');
      rethrow;
    }
  }

  /// Sign in with phone number using OTP code
  /// Returns true if existing manager logged in, false if new user (needs registration)
  Future<bool> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      print('MANAGER_AUTH: Verifying SMS code for phone: $phoneNumber');

      // Verify the code with JavaScript Firebase
      await _verifyPhoneCodeJS(smsCode);
      
      print('MANAGER_AUTH: Phone authentication successful for: $phoneNumber');

      // Try to login with existing manager first
      final existingManager = await _tryLoginWithPhone(phoneNumber);
      
      if (existingManager) {
        await _saveAuthState(true, 'phone');
        print('MANAGER_AUTH: Existing manager logged in successfully!');
        return true;
      }
      
      // If name is provided, register new manager
      if (name.isNotEmpty) {
        final registered = await registerWithPhone(phoneNumber: phoneNumber, name: name);
        if (registered) {
          await _saveAuthState(true, 'phone');
          print('MANAGER_AUTH: New manager registered successfully!');
          return true;
        }
      }
      
      // No existing manager and no name provided - return false to indicate new user
      print('MANAGER_AUTH: New user - registration required');
      return false;
    } catch (e) {
      print('MANAGER_AUTH: Phone sign-in error: $e');
      rethrow;
    }
  }
  
  /// Try to login with existing manager (phone only, no registration)
  Future<bool> _tryLoginWithPhone(String phoneNumber) async {
    try {
      print('MANAGER_AUTH: Checking if manager exists for: $phoneNumber');
      
      final response = await _client.post(
        Uri.parse(ApiConfig.managerPhoneLoginUrl),
        headers: _headers,
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['manager'] != null) {
          _currentManager = Manager.fromJson(data['manager']);
          print('MANAGER_AUTH: Found existing manager: ${_currentManager!.name}');
          return true;
        }
      }
      
      print('MANAGER_AUTH: No existing manager found');
      return false;
    } catch (e) {
      print('MANAGER_AUTH: Error checking manager: $e');
      return false;
    }
  }
  
  /// Register new manager with phone number
  Future<bool> registerWithPhone({
    required String phoneNumber,
    required String name,
  }) async {
    try {
      print('MANAGER_AUTH: Registering new manager: $name');
      
      final response = await _client.post(
        Uri.parse(ApiConfig.managerRegisterUrl),
        headers: _headers,
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'name': name,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['manager'] != null) {
          _currentManager = Manager.fromJson(data['manager']);
          await _saveAuthState(true, 'phone');
          print('MANAGER_AUTH: Manager registered: ${_currentManager!.id}');
          return true;
        }
      }

      print('MANAGER_AUTH: Registration failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('MANAGER_AUTH: Registration error: $e');
      return false;
    }
  }

  /// Call JavaScript verifyPhoneCode function from index.html
  Future<void> _verifyPhoneCodeJS(String smsCode) async {
    try {
      print('MANAGER_AUTH: Calling JS verifyPhoneCode...');
      
      final hasFunction = js_util.hasProperty(html.window, 'verifyPhoneCode');
      if (!hasFunction) {
        throw Exception('verifyPhoneCode function not found. Check index.html setup.');
      }
      
      final promise = js_util.callMethod(html.window, 'verifyPhoneCode', [smsCode]);
      await js_util.promiseToFuture(promise);
      
      print('MANAGER_AUTH: JS verifyPhoneCode successful');
    } catch (e) {
      print('MANAGER_AUTH: JS verifyPhoneCode error: $e');
      rethrow;
    }
  }

  // =====================================================
  // SESSION MANAGEMENT
  // =====================================================

  /// Save authentication state to SharedPreferences
  Future<void> _saveAuthState(bool isAuthenticated, String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manager_logged_in', isAuthenticated);
      await prefs.setString('auth_method', method);

      if (isAuthenticated && _currentManager != null) {
        await prefs.setString('manager_id', _currentManager!.id);
        await prefs.setString('manager_phone', _currentManager!.phoneNumber);
        await prefs.setString('manager_email', _currentManager!.email ?? '');
        print('MANAGER_AUTH: Saved manager data - id: ${_currentManager!.id}');
      } else if (!isAuthenticated) {
        await prefs.remove('manager_id');
        await prefs.remove('manager_phone');
        await prefs.remove('manager_email');
        print('MANAGER_AUTH: Cleared manager data');
      }

      print('MANAGER_AUTH: Saved auth state - logged in: $isAuthenticated, method: $method');
    } catch (e) {
      print('MANAGER_AUTH: Error saving auth state: $e');
    }
  }

  /// Get authentication state from SharedPreferences
  Future<Map<String, dynamic>> getAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'isLoggedIn': prefs.getBool('manager_logged_in') ?? false,
        'authMethod': prefs.getString('auth_method') ?? 'none',
        'managerId': prefs.getString('manager_id'),
        'managerPhone': prefs.getString('manager_phone'),
      };
    } catch (e) {
      print('MANAGER_AUTH: Error getting auth state: $e');
      return {'isLoggedIn': false, 'authMethod': 'none'};
    }
  }

  /// Refresh current manager profile from backend
  Future<bool> refreshManagerProfile() async {
    if (_currentManager == null) {
      final prefs = await SharedPreferences.getInstance();
      final managerId = prefs.getString('manager_id');
      final managerPhone = prefs.getString('manager_phone');

      if (managerId != null && managerId.isNotEmpty) {
        print('MANAGER_AUTH: Attempting to restore manager from ID: $managerId');
        try {
          final response = await _client.get(
            Uri.parse(ApiConfig.managerByIdUrl(managerId)),
            headers: _headers,
          );
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            _currentManager = Manager.fromJson(responseData);
            print('MANAGER_AUTH: Successfully restored manager from ID');
            return true;
          }
        } catch (e) {
          print('MANAGER_AUTH: Error restoring manager by ID: $e');
        }
      } else if (managerPhone != null && managerPhone.isNotEmpty) {
        print('MANAGER_AUTH: Attempting to restore manager from phone: $managerPhone');
        try {
          final response = await _client.get(
            Uri.parse(ApiConfig.managerByPhoneUrl(managerPhone)),
            headers: _headers,
          );
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            _currentManager = Manager.fromJson(responseData);
            print('MANAGER_AUTH: Successfully restored manager from phone');
            return true;
          }
        } catch (e) {
          print('MANAGER_AUTH: Error restoring manager by phone: $e');
        }
      }

      if (_currentManager == null) {
        print('MANAGER_AUTH: Could not restore manager profile');
        return false;
      }
    }

    // Refresh from backend
    try {
      print('MANAGER_AUTH: Refreshing manager profile from backend: ${_currentManager!.id}');

      final response = await _client.get(
        Uri.parse(ApiConfig.managerByIdUrl(_currentManager!.id)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _currentManager = Manager.fromJson(responseData);
        print('MANAGER_AUTH: Manager profile refreshed successfully');
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('Manager not found');
      } else {
        print('MANAGER_AUTH: Failed to refresh manager: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('MANAGER_AUTH: Refresh error: $e');
      return false;
    }
  }

  /// Logout - signs out from Firebase and clears local state
  Future<void> logout() async {
    print('MANAGER_AUTH: Logging out manager');

    try {
      await _auth.signOut();
      _currentManager = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('manager_logged_in');
      await prefs.remove('auth_method');
      await prefs.remove('manager_id');
      await prefs.remove('manager_phone');
      await prefs.remove('manager_email');

      print('MANAGER_AUTH: Logout completed successfully');
    } catch (e) {
      print('MANAGER_AUTH: Error during logout: $e');
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  /// Validate and format phone number
  String? _validateAndFormatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return null;

    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+') && cleaned.length >= 11) {
      return cleaned;
    }

    if (cleaned.startsWith('+') && cleaned.length < 11) {
      return null;
    }

    if (cleaned.length == 10 && !cleaned.startsWith('+')) {
      return null;
    }

    if (cleaned.length >= 11 && !cleaned.startsWith('+')) {
      return '+$cleaned';
    }

    return null;
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
