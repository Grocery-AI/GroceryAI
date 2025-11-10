import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _username;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  String? get token => _token;
  String? get username => _username;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  /// Constructor that initializes auth
  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize auth by checking stored token
  Future<void> _initializeAuth() async {
    try {
      // Try to read stored token
      final storedToken = await storage.read(key: 'auth_token');

      if (storedToken != null && storedToken.isNotEmpty) {
        _token = storedToken;
        _username = getUsernameFromToken(storedToken);
        _isLoggedIn = true;
      } else {
        _token = null;
        _username = null;
        _isLoggedIn = false;
      }
    } catch (e) {
      print('[AuthProvider] Error initializing auth: $e');
      _token = null;
      _username = null;
      _isLoggedIn = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set token after successful login
  Future<void> setToken(String token) async {
    _token = token;
    _username = getUsernameFromToken(token);
    _isLoggedIn = true;

    try {
      await storage.write(key: 'auth_token', value: token);
    } catch (e) {
      print('[AuthProvider] Error saving token: $e');
    }

    notifyListeners();
  }

  /// Clear token on logout
  Future<void> logout() async {
    _token = null;
    _username = null;
    _isLoggedIn = false;

    try {
      await storage.delete(key: 'auth_token');
    } catch (e) {
      print('[AuthProvider] Error deleting token: $e');
    }

    notifyListeners();
  }
}
