import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';

class AuthProvider with ChangeNotifier {
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _user;
  String? _accessToken;
  String? _refreshToken;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  static const String _baseUrl = 'YOUR_API_BASE_URL';

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _error = null;
      notifyListeners();

      // final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      // if (googleUser == null) {
      //   throw Exception('Google sign in was cancelled');
      // }

      // final GoogleSignInAuthentication googleAuth = 
      //     await googleUser.authentication;

      // Call your authentication endpoint
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': 'dummy_token',
          'idToken': 'dummy_id_token',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data);
        return true;
      } else {
        throw Exception('Failed to sign in with Google');
      }
    } catch (e) {
      _error = e.toString();
      Log.error('Google sign in error', e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkAuthStatus() async {
    try {
      _setLoading(true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) return false;

      // Verify token with backend
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      Log.error('Auth check error', e);
      await signOut();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) {
        await signOut();
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      Log.error('Token refresh error', e);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      // await _googleSignIn.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user');

      _user = null;
      _accessToken = null;
      _refreshToken = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
      Log.error('Sign out error', e);
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
    _user = data['user'];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', _accessToken!);
    await prefs.setString('refresh_token', _refreshToken!);
    await prefs.setString('user', jsonEncode(_user));
    
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    // _googleSignIn.signOut();
    super.dispose();
  }
}
