// lib/services/auth_service.dart
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:inventory_scanner_new/utils/config.dart';
import 'package:inventory_scanner_new/utils/simulator_mode.dart';

class AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  // Use simulator storage when in simulator mode
  final _secureStorage = AppConfig.isSimulator 
      ? FlutterSecureStorageStub() 
      : const FlutterSecureStorage();
  
  static const String clientId = '3c82ea21-fb37-4e3d-bbe2-bd4dc7237185';
  static const String redirectUrl = 'msauth://com.aaronwalker.inventoryscanner/auth';
  static const String issuer = 'https://login.microsoftonline.com/873ebc3c-13b9-43e6-865c-1e26b0185b40';
  
  // Scopes for v1.0 endpoint
  static const List<String> scopes = [
    'User.Read',
    'openid',
    'profile',
    'offline_access'
  ];

  // Get user name from token
  Future<String?> getUserName() async {
    if (AppConfig.isSimulator) {
      return "Simulator User";
    }
    
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return null;
      }
      
      final tokenParts = token.split('.');
      if (tokenParts.length > 1) {
        final payload = tokenParts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final tokenData = jsonDecode(decoded);
        
        // Try different claims for the username
        return tokenData['name'] ?? 
               tokenData['upn'] ?? 
               tokenData['email'] ?? 
               tokenData['preferred_username'] ??
               "Unknown User";
      }
      return null;
    } catch (e) {
      print('AuthService: Error getting user name: $e');
      return null;
    }
  }

  // Check if a valid, non-expired token exists
  Future<bool> get isAuthenticated async {
    if (AppConfig.isSimulator) {
      // In simulator mode, check if we have a simulator token
      final token = await _secureStorage.read(key: 'access_token');
      return token != null && token.isNotEmpty;
    }
    
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        print('AuthService: isAuthenticated check: false (no token)');
        return false;
      }
      final tokenParts = token.split('.');
      if (tokenParts.length > 1) {
        final payload = tokenParts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final tokenData = jsonDecode(decoded);
        final expiry = tokenData['exp'] as int?;
        if (expiry != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
          final isValid = DateTime.now().isBefore(expiryDate);
          print('AuthService: isAuthenticated check: $isValid (expiry: $expiryDate)');
          return isValid;
        }
      }
      print('AuthService: isAuthenticated check: false (invalid token format)');
      return false;
    } catch (e) {
      print('AuthService: Error checking authentication: $e');
      return false;
    }
  }

  // Perform Azure AD login and store tokens
  Future<String?> signIn() async {
    if (AppConfig.isSimulator) {
      // Simulate login delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Create a fake token for simulator mode
      final simulatorToken = 'sim_token_${DateTime.now().millisecondsSinceEpoch}';
      await _secureStorage.write(
        key: 'access_token',
        value: simulatorToken,
      );
      await _secureStorage.write(
        key: 'refresh_token',
        value: 'sim_refresh_token',
      );
      
      print('AuthService (Simulator): Signed in successfully');
      return simulatorToken;
    }
    
    try {
      print('AuthService: Starting sign-in process');
      print('AuthService: Attempting Azure AD login with clientID: $clientId');
      print('AuthService: Redirect URI: $redirectUrl');
      print('AuthService: Issuer: $issuer');
      print('AuthService: Scopes being requested: $scopes');
      
      final config = AuthorizationServiceConfiguration(
        authorizationEndpoint: '$issuer/oauth2/authorize',
        tokenEndpoint: '$issuer/oauth2/token',
      );
      
      final authRequest = AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        issuer: issuer,
        scopes: scopes,
        additionalParameters: {
          'resource': 'https://avantiwindowcom-my.sharepoint.com'
        },
      );
      
      print('AuthService: Making authorization request...');
      final result = await _appAuth.authorizeAndExchangeCode(authRequest);
      
      print('AuthService: Authentication result details: $result');
      if (result != null && result.accessToken != null) {
        print('AuthService: Token received, saving credentials');
        await _secureStorage.write(
          key: 'access_token',
          value: result.accessToken,
        );
        await _secureStorage.write(
          key: 'refresh_token',
          value: result.refreshToken ?? '',
        );
        print('AuthService: Credentials saved successfully');
        
        if (result.accessToken != null) {
          final tokenParts = result.accessToken!.split('.');
          if (tokenParts.length > 1) {
            final payload = tokenParts[1];
            final normalized = base64Url.normalize(payload);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final tokenData = jsonDecode(decoded);
            print('AuthService: Token audience: ${tokenData['aud']}');
            print('AuthService: Token scopes: ${tokenData['scp']}');
            print('AuthService: Token issued to: ${tokenData['email'] ?? tokenData['upn']}');
            print('AuthService: Token roles: ${tokenData['roles']}');
            print('AuthService: Token tenant ID: ${tokenData['tid']}');
          }
        }
        
        return result.accessToken;
      }
      
      print('AuthService: Authentication result was null or no access token');
      return null;
    } catch (e) {
      print('AuthService: Error during sign-in: $e');
      if (e is PlatformException) {
        print('AuthService: PlatformException details: code=${e.code}, message=${e.message}, details=${e.details}');
      }
      return null;
    }
  }

  // Retrieve access token, refreshing if expired
  Future<String?> getAccessToken() async {
    if (AppConfig.isSimulator) {
      // In simulator mode, just return the stored token
      return await _secureStorage.read(key: 'access_token');
    }
    
    try {
      String? accessToken = await _secureStorage.read(key: 'access_token');
      if (accessToken == null || accessToken.isEmpty) {
        print('AuthService: No access token found');
        return null;
      }

      final tokenParts = accessToken.split('.');
      if (tokenParts.length > 1) {
        final payload = tokenParts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final tokenData = jsonDecode(decoded);
        final expiry = tokenData['exp'] as int?;
        if (expiry != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
          if (DateTime.now().isAfter(expiryDate)) {
            print('AuthService: Access token expired, attempting refresh');
            accessToken = await _refreshToken();
          }
        }
      }

      return accessToken;
    } catch (e) {
      print('AuthService: Error retrieving access token: $e');
      return null;
    }
  }

  // Refresh access token using refresh token
  Future<String?> _refreshToken() async {
    if (AppConfig.isSimulator) {
      // In simulator mode, just create a new token
      final simulatorToken = 'sim_refreshed_token_${DateTime.now().millisecondsSinceEpoch}';
      await _secureStorage.write(
        key: 'access_token',
        value: simulatorToken,
      );
      return simulatorToken;
    }
    
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        print('AuthService: No refresh token available');
        return null;
      }

      final config = AuthorizationServiceConfiguration(
        authorizationEndpoint: '$issuer/oauth2/authorize',
        tokenEndpoint: '$issuer/oauth2/token',
      );

      final result = await _appAuth.token(TokenRequest(
        clientId,
        redirectUrl,
        issuer: issuer,
        refreshToken: refreshToken,
        scopes: scopes,
        additionalParameters: {
          'resource': 'https://avantiwindowcom-my.sharepoint.com'
        },
      ));

      if (result != null && result.accessToken != null) {
        print('AuthService: Token refreshed successfully');
        await _secureStorage.write(
          key: 'access_token',
          value: result.accessToken,
        );
        await _secureStorage.write(
          key: 'refresh_token',
          value: result.refreshToken ?? refreshToken,
        );
        return result.accessToken;
      }

      print('AuthService: Token refresh failed');
      return null;
    } catch (e) {
      print('AuthService: Error refreshing token: $e');
      if (e is PlatformException) {
        print('AuthService: PlatformException details: code=${e.code}, message=${e.message}, details=${e.details}');
      }
      return null;
    }
  }

  // Clear all stored tokens
  Future<void> signOut() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.deleteAll();
      print('AuthService: Signed out successfully');
    } catch (e) {
      print('AuthService: Error during sign-out: $e');
      return;
    }
  }
}
