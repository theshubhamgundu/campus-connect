import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user.dart';
import '../services/logger_service.dart';

class AuthProvider with ChangeNotifier {
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';
  static const String _hasLoggedInKey = 'has_logged_in';
  
  final NetworkInfo _networkInfo = NetworkInfo();
  
  bool _isLoading = false;
  String? _error;
  User? _currentUser;
  bool _isLoggedIn = false;
  String? _authToken;
  List<User> _nearbyUsers = [];
  List<User> _searchResults = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isLoggedIn;
  String? get authToken => _authToken;
  List<User> get nearbyUsers => List.unmodifiable(_nearbyUsers);
  List<User> get searchResults => List.unmodifiable(_searchResults);
  bool get isFaculty => _currentUser?.isFaculty ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Load saved user from shared preferences
  Future<void> _loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);
      final hasLoggedIn = prefs.getBool(_hasLoggedInKey) ?? false;
      
      if (userJson != null && token != null && hasLoggedIn) {
        final userMap = jsonDecode(userJson);
        _currentUser = User.fromJson(userMap);
        _authToken = token;
        _isLoggedIn = true;
        debugPrint('✓ Auto-loaded user: ${_currentUser?.userId}');
        notifyListeners();
      }
    } catch (e) {
      Log.error('Error loading saved user', e);
      _isLoggedIn = false;
      _currentUser = null;
      _authToken = null;
    }
  }

  // Save auth state to shared preferences
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
        await prefs.setBool(_hasLoggedInKey, true);
        debugPrint('✓ Saved user: ${_currentUser?.userId}');
      }
      if (_authToken != null) {
        await prefs.setString(_tokenKey, _authToken!);
      }
    } catch (e) {
      Log.error('Error saving auth state', e);
    }
  }

  // Check if user can auto-login
  Future<bool> canAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);
      return userJson != null && token != null;
    } catch (e) {
      Log.error('Error checking auto-login status', e);
      return false;
    }
  }

  // Clear all auth data (for logout)
  Future<void> clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_hasLoggedInKey);
      _currentUser = null;
      _authToken = null;
      _isLoggedIn = false;
      debugPrint('✓ Auth data cleared (logged out)');
      notifyListeners();
    } catch (e) {
      Log.error('Error clearing auth data', e);
    }
  }

  // Initialize the auth provider
  Future<void> initialize() async {
    if (_isLoading) return;
    
    try {
      _setLoading(true);
      await _loadSavedUser();
      
      if (_isLoggedIn && _currentUser != null) {
        // Check network connectivity before connecting
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity != ConnectivityResult.none) {
          // Do not auto-init network connection here. ConnectionService will be
          // started from the Home screen so UI navigation is immediate.
        }
      }
    } catch (e, stackTrace) {
      _error = 'Initialization failed';
      Log.error('AuthProvider.initialize', e, stackTrace);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up new user
  Future<bool> signUp({
    required String userId,
    required String name,
    String? email,
    String? password,
    required UserRole role,
    String? department,
  }) async {
    if (_isLoading) return false;
    
    try {
      _setLoading(true);
      _error = null;
      
      // Validate input
      if (userId.isEmpty) throw const FormatException('User ID is required');
      if (name.isEmpty) throw const FormatException('Name is required');
      
      // Check if user already exists
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('$_userKey$userId')) {
        throw Exception('User with this ID already exists');
      }
      
      // Create and save new user
      _currentUser = User(
        userId: userId.toUpperCase(),
        name: name.trim(),
        email: email?.trim(),
        role: role,
        department: department?.trim(),
        isOnline: true,
        lastSeen: DateTime.now(),
      );
      
      _isLoggedIn = true;
      _authToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
      await _saveAuthState();
      if (_currentUser != null) {
        debugPrint('✓ User signed up: ${_currentUser!.userId}');
      }
      
      // Do not start ConnectionService here; HomeScreen will start it.
      
      return true;
      
    } on FormatException catch (e) {
      _error = e.message;
      return false;
    } catch (e, stackTrace) {
      _error = 'Sign up failed. Please try again.';
      Log.error('AuthProvider.signUp', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Sign in with user ID (offline-first)
  Future<bool> signIn({
    required String userId,
    String? email,
    String? password,
  }) async {
    if (_isLoading) return false;
    
    try {
      _setLoading(true);
      _error = null;
      
      // Validate input
      if (userId.isEmpty) {
        throw const FormatException('User ID cannot be empty');
      }
      
      // Try to load user from local storage
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('$_userKey$userId');
      
      if (userJson == null) {
        throw Exception('User not found. Please sign up first.');
      }
      
      // Parse user data
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      _currentUser = User.fromJson(userMap);
      _isLoggedIn = true;
      _authToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
      
      // Save auth state and connect to WebSocket
      await _saveAuthState();
      debugPrint('✓ User signed in: ${_currentUser?.userId}');
      // Do not start ConnectionService here; the Home screen will handle network initialization.
      
      return true;
      
    } on FormatException catch (e) {
      _error = e.message;
      return false;
    } catch (e, stackTrace) {
      _error = 'Sign in failed. Please try again.';
      Log.error('AuthProvider.signIn', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Discover nearby users on the local network
  Future<void> discoverNearbyUsers() async {
    if (_isLoading) return;
    
    try {
      _setLoading(true);
      _error = null;
      
      // Check network connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw Exception('No network connection available');
      }
      
      // Get local IP address
      final ip = await _networkInfo.getWifiIP();
      if (ip == null) {
        throw Exception('Not connected to Wi-Fi');
      }
      
      // In a real app, this would scan the local network for other users
      // For now, we'll simulate finding some users with proper error handling
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      // Only update if we're still mounted
      if (!_isLoading) return;
      
      _nearbyUsers = [
        User(
          userId: 'STU1001',
          name: 'John Doe',
          role: UserRole.student,
          department: 'Computer Science',
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
        User(
          userId: 'FAC2001',
          name: 'Dr. Smith',
          role: UserRole.faculty,
          department: 'Computer Science',
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
      ];
      
    } on SocketException catch (e) {
      _error = 'Network error: ${e.message}';
      rethrow;
    } on TimeoutException {
      _error = 'Connection timed out';
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Failed to discover nearby users';
      Log.error('AuthProvider.discoverNearbyUsers', e, stackTrace);
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      // Clear user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      await prefs.setBool('isLoggedIn', false);
      
      _currentUser = null;
      _isLoggedIn = false;
      
      notifyListeners();
    } catch (e) {
      Log.error('Error signing out', e);
      rethrow;
    }
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
  
  // Start user discovery process
  Future<void> _startDiscovery() async {
    if (!_isLoggedIn || _currentUser == null) return;
    
    try {
      await discoverNearbyUsers();
      // In a real app, you might want to set up a periodic discovery
      // Timer.periodic(const Duration(minutes: 5), (_) => discoverNearbyUsers());
    } catch (e) {
      // Silently handle discovery errors
      debugPrint('Discovery error: $e');
    }
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
