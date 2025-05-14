// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import '../config.dart';
import '../utils/simulator_mode.dart';
import '../utils/network_utils.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userProfileKey = 'user_profile';

  late final FlutterSecureStorage _secureStorage;
  final bool isSimulator;

  // Constructor
  AuthService() : isSimulator = _isRunningOnSimulator() {
    // Use real or simulated secure storage based on environment
    _secureStorage = isSimulator
        ? FlutterSecureStorageStub()
        : const FlutterSecureStorage();
  }

  // Get token - from secure storage or generate a simulated one
  Future<String> getToken() async {
    // Check network connectivity
    final isOnline = await NetworkUtils.hasNetworkConnection();
    
    // Try to get cached token
    final cachedToken = await _secureStorage.read(key: _tokenKey);
    if (cachedToken != null) {
      // If we're offline, return cached token without checking expiration
      if (!isOnline) return cachedToken;
      
      // Check if token is expired and refresh if needed
      if (await _isTokenExpired(cachedToken)) {
        try {
          return await _refreshToken();
        } catch (e) {
          // If refresh fails and we have a cached token, use it
          return cachedToken;
        }
      }
      return cachedToken;
    }

    // No token found, login required
    if (isSimulator) {
      // Return a fake token in simulator mode
      const simulatedToken = 'simulated-jwt-token-for-development-only';
      await _secureStorage.write(key: _tokenKey, value: simulatedToken);
      return simulatedToken;
    } else if (!isOnline) {
      throw Exception('No cached credentials available and device is offline');
    } else {
      // Real environment needs to login
      throw Exception('Not authenticated. Please call login() first.');
    }
  }

  // Login with Azure AD
  Future<bool> login(BuildContext context) async {
    if (isSimulator) {
      // Store simulated tokens and profile
      const simulatedToken = 'simulated-jwt-token-for-development-only';
      const simulatedRefreshToken = 'simulated-refresh-token';
      final simulatedProfile = json.encode({
        'name': 'Test User',
        'email': 'test@example.com',
        'id': 'user123'
      });
      
      await _secureStorage.write(key: _tokenKey, value: simulatedToken);
      await _secureStorage.write(key: _refreshTokenKey, value: simulatedRefreshToken);
      await _secureStorage.write(key: _userProfileKey, value: simulatedProfile);
      
      return true;
    }
    
    // Check connectivity before attempting login
    final isOnline = await NetworkUtils.hasNetworkConnection();
    if (!isOnline) {
      return false;
    }
    
    // For real authentication, use Azure AD OAuth flow
    try {
      // Build the authorization URL
      final authUrl = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize', {
        'client_id': Config.azureClientId,
        'response_type': 'code',
        'redirect_uri': Config.redirectUri,
        'scope': 'user.read offline_access',
      });
      
      // Launch the browser for auth
      final result = await FlutterWebAuth.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: Config.urlScheme,
      );
      
      // Extract authorization code from callback URL
      final code = Uri.parse(result).queryParameters['code'];
      
      if (code != null) {
        // Exchange code for tokens
        return await _getTokensFromCode(code);
      }
      
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Exchange authorization code for tokens
  Future<bool> _getTokensFromCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': Config.azureClientId,
          'scope': 'user.read offline_access',
          'code': code,
          'redirect_uri': Config.redirectUri,
          'grant_type': 'authorization_code',
          'client_secret': Config.azureClientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Store tokens
        await _secureStorage.write(key: _tokenKey, value: data['access_token']);
        await _secureStorage.write(key: _refreshTokenKey, value: data['refresh_token']);
        
        // Get and store user profile
        await _fetchAndStoreUserProfile(data['access_token']);
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }

  // Fetch user profile
  Future<void> _fetchAndStoreUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await _secureStorage.write(key: _userProfileKey, value: response.body);
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  // Check if token is expired
  Future<bool> _isTokenExpired(String token) async {
    try {
      // Token is in format header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      // Decode the payload
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final data = json.decode(decoded);
      
      // Check expiration
      if (data['exp'] != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(data['exp'] * 1000);
        final now = DateTime.now();
        
        // Return true if token expires in less than 5 minutes
        return now.isAfter(expiry.subtract(const Duration(minutes: 5)));
      }
      
      return true;
    } catch (e) {
      // If any error occurs during parsing, consider token expired
      return true;
    }
  }

  // Refresh the token
  Future<String> _refreshToken() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://login.microsoftonline.com/common/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': Config.azureClientId,
          'scope': 'user.read offline_access',
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
          'client_secret': Config.azureClientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final newToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];
        
        // Update stored tokens
        await _secureStorage.write(key: _tokenKey, value: newToken);
        await _secureStorage.write(key: _refreshTokenKey, value: newRefreshToken);
        
        return newToken;
      } else {
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Token refresh error: $e');
    }
  }

  // Logout user
  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userProfileKey);
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final profileJson = await _secureStorage.read(key: _userProfileKey);
    if (profileJson != null) {
      return json.decode(profileJson);
    }
    return null;
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token == null) return false;
      
      // If in simulator mode, always consider logged in with token
      if (isSimulator) return true;
      
      // Check network connectivity
      final isOnline = await NetworkUtils.hasNetworkConnection();
      if (!isOnline) {
        // When offline, consider logged in if we have a token
        return token.isNotEmpty;
      }
      
      // Check if token is expired
      if (await _isTokenExpired(token)) {
        try {
          // Try to refresh the token
          await _refreshToken();
          return true;
        } catch (e) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Check if running in simulator mode
  static bool _isRunningOnSimulator() {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      // iOS simulator detection
      if (Platform.isIOS) {
        return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') || 
               Platform.environment.containsKey('SIMULATOR_HOST_HOME');
      }
      
      // Android emulator detection
      if (Platform.isAndroid) {
        return Platform.environment.containsKey('ANDROID_EMULATOR') ||
               Platform.environment.containsKey('ANDROID_SDK_ROOT');
      }
    }
    
    // For web or desktop, consider it a "simulator" mode for testing
    return kIsWeb || !(Platform.isIOS || Platform.isAndroid);
  }
}
