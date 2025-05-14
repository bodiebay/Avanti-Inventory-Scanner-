// lib/services/sharepoint_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../utils/simulator_mode.dart';
import '../utils/network_utils.dart';
import 'auth_service.dart';

class SharePointService {
  final AuthService _authService;
  final bool isSimulator;

  // Constructor - takes the AuthService instead of raw token
  SharePointService(this._authService) : isSimulator = _authService.isSimulator;

  // Get base headers for SharePoint API requests with current token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json;odata=verbose',
      'Content-Type': 'application/json;odata=verbose',
    };
  }

  // Base URL for SharePoint API
  String get _baseUrl => Config.sharePointSiteUrl;

  // Get the full API URL for the product list
  String get _productListApiUrl =>
      '$_baseUrl/_api/web/lists/getbytitle(\'Product Details\')/items';

  // Get product list from SharePoint with offline support
  Future<List<Map<String, dynamic>>> getProductList() async {
    // Check for network connectivity
    final isOnline = await NetworkUtils.hasNetworkConnection();
    
    if (isSimulator) {
      return SimulatedSharePointApi.getProductList();
    }
    
    if (!isOnline) {
      // Use cached data when offline
      return _getCachedProducts();
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_productListApiUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final items = jsonData['d']['results'] as List;
        final products = items.map((item) => Map<String, dynamic>.from(item)).toList();
        
        // Cache the results for offline use
        await _cacheProducts(products);
        
        return products;
      } else {
        // Try cached data on API error
        final cached = await _getCachedProducts();
        if (cached.isNotEmpty) {
          return cached;
        }
        throw Exception('Failed to load product list: ${response.statusCode}');
      }
    } catch (e) {
      // Try cached data on network error
      final cached = await _getCachedProducts();
      if (cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Error fetching product list: $e');
    }
  }
  
  // Cache products for offline use
  Future<void> _cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(products);
      await prefs.setString('cached_products', jsonString);
      await prefs.setString('last_cached', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error caching products: $e');
    }
  }
  
  // Get cached products
  Future<List<Map<String, dynamic>>> _getCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_products');
      
      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error retrieving cached products: $e');
      return [];
    }
  }
  
  // Update a product in SharePoint with offline support
  Future<bool> updateProduct(String itemId, Map<String, dynamic> data) async {
    if (isSimulator) {
      return SimulatedSharePointApi.updateProduct(itemId, data);
    }
    
    // Check for network connectivity
    final isOnline = await NetworkUtils.hasNetworkConnection();
    
    if (!isOnline) {
      // Store offline changes to be synced later
      await _storeOfflineChange('update', itemId, data);
      return true;
    }
    
    try {
      final headers = await _getHeaders();
      
      // SharePoint requires the __metadata type for updates
      final payload = {
        '__metadata': {
          'type': 'SP.Data.ProductDetailsListItem'
        },
        ...data
      };
      
      // Make the API call to update the item
      final response = await http.post(
        Uri.parse('$_productListApiUrl($itemId)'),
        headers: {
          ...headers,
          'If-Match': '*',
          'X-HTTP-Method': 'MERGE'
        },
        body: json.encode(payload),
      );
      
      // Status 204 means success for MERGE operations
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error updating product: $e');
      
      // Store for later sync if update fails
      await _storeOfflineChange('update', itemId, data);
      return false;
    }
  }
  
  // Store offline changes to sync later
  Future<void> _storeOfflineChange(String operation, String itemId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing offline changes
      List<Map<String, dynamic>> offlineChanges = [];
      final offlineChangesJson = prefs.getString('offline_changes');
      
      if (offlineChangesJson != null) {
        final decoded = json.decode(offlineChangesJson) as List;
        offlineChanges = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      // Add new change
      offlineChanges.add({
        'operation': operation,
        'itemId': itemId,
        'data': data,
        'timestamp': DateTime.now().toIso8601String()
      });
      
      // Save back to storage
      await prefs.setString('offline_changes', json.encode(offlineChanges));
    } catch (e) {
      debugPrint('Error storing offline change: $e');
    }
  }
  
  // Sync offline changes when back online
  Future<bool> syncOfflineChanges() async {
    if (isSimulator) {
      return true;
    }
    
    // Check for network connectivity
    final isOnline = await NetworkUtils.hasNetworkConnection();
    
    if (!isOnline) {
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineChangesJson = prefs.getString('offline_changes');
      
      if (offlineChangesJson == null) {
        return true; // No changes to sync
      }
      
      final decoded = json.decode(offlineChangesJson) as List;
      final offlineChanges = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      
      if (offlineChanges.isEmpty) {
        return true;
      }
      
      // Track successful syncs to remove from storage later
      List<int> syncedIndices = [];
      
      // Process each change
      for (int i = 0; i < offlineChanges.length; i++) {
        final change = offlineChanges[i];
        
        switch (change['operation']) {
          case 'update':
            final success = await updateProduct(
              change['itemId'],
              Map<String, dynamic>.from(change['data'])
            );
            
            if (success) {
              syncedIndices.add(i);
            }
            break;
            
          // Add other operations (create, delete) as needed
        }
      }
      
      // Remove synced changes
      if (syncedIndices.isNotEmpty) {
        // Remove in reverse order to avoid index shifting
        syncedIndices.sort();
        syncedIndices = syncedIndices.reversed.toList();
        
        for (final index in syncedIndices) {
          offlineChanges.removeAt(index);
        }
        
        // Save remaining changes back to storage
        await prefs.setString('offline_changes', json.encode(offlineChanges));
      }
      
      return syncedIndices.isNotEmpty;
    } catch (e) {
      debugPrint('Error syncing offline changes: $e');
      return false;
    }
  }
  
  // Check if there are pending offline changes
  Future<bool> hasPendingOfflineChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineChangesJson = prefs.getString('offline_changes');
      
      if (offlineChangesJson == null) {
        return false;
      }
      
      final decoded = json.decode(offlineChangesJson) as List;
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
