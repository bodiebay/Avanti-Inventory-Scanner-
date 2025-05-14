import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:dio/dio.dart';
import 'package:retry/retry.dart';
// import 'package:connectivity_plus/connectivity_plus.dart'; // REMOVED
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math';

class InventoryService {
  final String _baseUrl = 'https://avantiwindowcom.sharepoint.com/sites/CompanyHomepage/_api/web/lists';
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Accept': 'application/json;odata=verbose'},
  ));

  // Validate token for SharePoint scopes
  bool _validateTokenForSharePoint(String token) {
    try {
      print('InventoryService: Token prefix: ${token.substring(0, min(20, token.length))}...');
      final parts = token.split('.');
      if (parts.length > 1) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> tokenData = jsonDecode(decoded);
        
        final String scopes = tokenData['scp'] ?? '';
        if (!scopes.contains('Sites.') && 
            !scopes.contains('FullControl.All') && 
            !scopes.contains('Sites.FullControl.All')) {
          print('InventoryService: Token lacks required SharePoint scopes: $scopes');
          return false;
        }
        
        print('InventoryService: Token validated successfully with scopes: $scopes');
        return true;
      }
    } catch (e) {
      print('InventoryService: Error validating token: $e');
    }
    return false;
  }

  // Check network connectivity - MODIFIED to remove connectivity_plus dependency
  Future<bool> _checkConnectivity() async {
    // Removed connectivity_plus dependency - always assuming connected
    print('InventoryService: Connectivity check bypassed (always returning true)');
    return true;
  }

  // Normalize barcode to remove prefixes/suffixes
  String _normalizeBarcode(String barcode) {
    String upper = barcode.toUpperCase();
    
    RegExp regex = RegExp(r'[0-9]*[A-Z]*([A-Z0-9]{7})[/A-Z]*');
    var match = regex.firstMatch(upper);
    
    if (match != null && match.groupCount >= 1) {
      print('InventoryService: Barcode normalized using regex: $barcode -> ${match.group(1)}');
      return match.group(1)!;
    }
    
    if (upper.contains('P')) {
      int pIndex = upper.indexOf('P');
      if (pIndex >= 0 && pIndex < 3) {
        upper = upper.substring(pIndex + 1);
        print('InventoryService: Barcode normalized by removing prefix before P: $barcode -> $upper');
      }
    }
    
    if (upper.contains('/')) {
      upper = upper.substring(0, upper.indexOf('/'));
      print('InventoryService: Barcode normalized by removing suffix after /: $barcode -> $upper');
    }
    
    return upper;
  }

  // Verify SharePoint list connection
  Future<bool> verifySharePointConnection(String token) async {
    try {
      final uri = Uri.parse("$_baseUrl/getbytitle('Product%20Details')");
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json;odata=verbose',
      };
      
      print('InventoryService: Testing SharePoint connection: $uri');
      final response = await http.get(uri, headers: headers);
      print('InventoryService: List connection test: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('InventoryService: List found! Response snippet: ${response.body.substring(0, min(200, response.body.length))}...');
      } else {
        print('InventoryService: List not found: ${response.body.substring(0, min(200, response.body.length))}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('InventoryService: Connection verification error: $e');
      return false;
    }
  }

  // Query SharePoint for inventory item
  Future<String> getInventoryItem(String token, String barcode) async {
    print('InventoryService: Querying SharePoint for barcode: $barcode');
    
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available. Please check your network and try again.');
    }
    
    if (!_validateTokenForSharePoint(token)) {
      throw Exception('Invalid token: Missing required SharePoint scopes. Please re-authenticate.');
    }
    
    List<Future<String>> connectionMethods = [
      _tryDirectConnection(token, barcode),
      _tryWithDioAndRetry(token, barcode),
      _tryWithCustomProxy(token, barcode),
      _tryWithAlternateUrl(token, barcode),
    ];
    
    String? successMethod;
    for (var i = 0; i < connectionMethods.length; i++) {
      try {
        final result = await connectionMethods[i];
        successMethod = ['direct', 'dio', 'proxy', 'alternate'][i];
        print('InventoryService: Successfully connected using $successMethod method');
        return result;
      } catch (e) {
        print('InventoryService: Connection method failed: $e');
      }
    }
    
    throw Exception('Unable to connect to SharePoint. Please check your network settings or contact IT support.');
  }
  
  // Direct HTTP connection
  Future<String> _tryDirectConnection(String token, String barcode) async {
    print('InventoryService: Trying direct connection...');
    
    try {
      String normalizedBarcode = _normalizeBarcode(barcode);
      final uri = Uri.parse("$_baseUrl/getbytitle('Product%20Details')/items?\$select=Title,HardwareDescription&\$filter=Title eq '$normalizedBarcode'");
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json;odata=verbose',
      };
      
      print('InventoryService: Sending direct request to: $uri');
      final response = await http.get(uri, headers: headers);
      return _processResponse(response, barcode);
    } catch (e) {
      print('InventoryService: Direct connection error: $e');
      throw e;
    }
  }
  
  // Dio with retry mechanism
  Future<String> _tryWithDioAndRetry(String token, String barcode) async {
    print('InventoryService: Trying connection with Dio and retry...');
    
    _dio.options.headers['Authorization'] = 'Bearer $token';
    
    String normalizedBarcode = _normalizeBarcode(barcode);
    final uri = "$_baseUrl/getbytitle('Product%20Details')/items?\$select=Title,HardwareDescription&\$filter=Title eq '$normalizedBarcode'";
    
    try {
      print('InventoryService: Sending Dio request to: $uri');
      final response = await retry(
        () => _dio.get(uri).timeout(const Duration(seconds: 10)),
        retryIf: (e) => e is DioException &&
                       (e.type == DioExceptionType.connectionTimeout ||
                        e.type == DioExceptionType.receiveTimeout ||
                        e.error is SocketException),
        maxAttempts: 3,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['d']['results'] as List<dynamic>;
        
        if (results.isNotEmpty) {
          final item = results[0];
          return 'Item: ${item['Title'] ?? 'Unknown'}, Description: ${item['HardwareDescription'] ?? 'No description available'}';
        }
        
        return 'Item not found in SharePoint list';
      } else {
        throw Exception('Failed to load inventory data: ${response.statusCode}');
      }
    } catch (e) {
      print('InventoryService: Dio connection error: $e');
      throw e;
    }
  }
  
  // Custom proxy connection
  Future<String> _tryWithCustomProxy(String token, String barcode) async {
    print('InventoryService: Trying connection through proxy...');
    
    try {
      final client = HttpClient();
      
      final systemProxies = await HttpClient.findProxyFromEnvironment(
        Uri.parse('https://avantiwindowcom.sharepoint.com/sites/CompanyHomepage'),
      );
      print('InventoryService: System proxies detected: $systemProxies');
      
      client.findProxy = (uri) => systemProxies;
      
      String normalizedBarcode = _normalizeBarcode(barcode);
      final uri = Uri.parse("$_baseUrl/getbytitle('Product%20Details')/items?\$select=Title,HardwareDescription&\$filter=Title eq '$normalizedBarcode'");
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json;odata=verbose',
      };
      
      print('InventoryService: Sending proxy request to: $uri');
      final httpClient = http_io.IOClient(client);
      final response = await httpClient.get(uri, headers: headers);
      return _processResponse(response, barcode);
    } catch (e) {
      print('InventoryService: Proxy connection error: $e');
      throw e;
    }
  }
  
  // Alternate SharePoint URL connection
  Future<String> _tryWithAlternateUrl(String token, String barcode) async {
    print('InventoryService: Trying alternate SharePoint URL...');
    
    try {
      final alternateBaseUrl = 'https://avantiwindowcom.sharepoint.com/sites/CompanyHomepage/_api/web/lists';
      String normalizedBarcode = _normalizeBarcode(barcode);
      final uri = Uri.parse("$alternateBaseUrl/getbytitle('Product%20Details')/items?\$select=Title,HardwareDescription&\$filter=Title eq '$normalizedBarcode'");
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json;odata=verbose',
      };
      
      print('InventoryService: Sending alternate URL request to: $uri');
      final response = await http.get(uri, headers: headers);
      return _processResponse(response, barcode);
    } catch (e) {
      print('InventoryService: Alternate URL error: $e');
      throw e;
    }
  }
  
  // Process SharePoint API response
  String _processResponse(http.Response response, String barcode) {
    print('InventoryService: Response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('InventoryService: Error response body: ${response.body.substring(0, min(200, response.body.length))}');
    }
    
    if (response.statusCode == 200) {
      print('InventoryService: Full Response Body: ${response.body}');
      final data = json.decode(response.body);
      final results = data['d']['results'] as List<dynamic>;
      
      if (results.isNotEmpty) {
        final item = results[0];
        final title = item['Title'] ?? 'Unknown';
        final description = item['HardwareDescription'] ?? 'No description available';
        
        print('InventoryService: Found item: $title');
        print('InventoryService: Description: $description');
        
        return 'Item: $title, Description: $description';
      }
      
      print('InventoryService: No item found for barcode: $barcode');
      return 'Item not found in SharePoint list';
    } else {
      throw Exception('Failed to load inventory data: ${response.statusCode}');
    }
  }

  // Update inventory item quantity (if implemented)
  Future<bool> updateInventoryItem(String token, String barcode, int newQuantity) async {
    print('InventoryService: Updating inventory item for barcode: $barcode');
    
    if (!await _checkConnectivity() || !_validateTokenForSharePoint(token)) {
      return false;
    }
    
    try {
      String normalizedBarcode = _normalizeBarcode(barcode);
      final uri = Uri.parse("$_baseUrl/getbytitle('Product%20Details')/items?\$select=Title,HardwareDescription&\$filter=Title eq '$normalizedBarcode'");
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json;odata=verbose',
        'Content-Type': 'application/json;odata=verbose',
        'X-HTTP-Method': 'MERGE',
        'IF-MATCH': '*'
      };
      
      print('InventoryService: Sending update request to: $uri');
      final getResponse = await http.get(
        uri, 
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json;odata=verbose'}
      );
      
      if (getResponse.statusCode == 200) {
        final data = json.decode(getResponse.body);
        final results = data['d']['results'] as List<dynamic>;
        
        if (results.isNotEmpty) {
          final item = results[0];
          final itemId = item['Id'];
          
          final updateUri = Uri.parse("$_baseUrl/getbytitle('Product%20Details')/items($itemId)");
          final updateData = json.encode({
            '__metadata': {'type': 'SP.Data.ProductDetailsListItem'},
            'Quantity': newQuantity
          });
          
          final updateResponse = await http.post(
            updateUri,
            headers: headers,
            body: updateData
          );
          
          if (updateResponse.statusCode >= 200 && updateResponse.statusCode < 300) {
            print('InventoryService: Successfully updated item quantity for barcode: $barcode');
            return true;
          } else {
            print('InventoryService: Failed to update item: ${updateResponse.statusCode} - ${updateResponse.body}');
            return false;
          }
        }
      }
      
      print('InventoryService: Item not found for update: $barcode');
      return false;
    } catch (e) {
      print('InventoryService: Error updating inventory item: $e');
      return false;
    }
  }
}
