// lib/services/product_service.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'auth_service.dart';
import 'sharepoint_service.dart';
import 'barcode_scanner_service.dart';

class ProductService {
  final AuthService _authService;
  late SharePointService _sharePointService;
  late BarcodeScannerService _barcodeScannerService;
  bool _initialized = false;

  // Constructor with dependency injection
  ProductService(this._authService) {
    _initialize();
  }

  // Initialize services based on simulator detection
  Future<void> _initialize() async {
    if (_initialized) return;

    final isSimulator = SharePointService.isRunningOnSimulator();
    
    // Get token for SharePoint API (will be dummy token in simulator)
    final token = await _authService.getToken();
    
    // Initialize services with proper simulator flags
    _sharePointService = SharePointService(
      token: token,
      isSimulator: isSimulator,
    );
    
    _barcodeScannerService = BarcodeScannerService(
      isSimulator: isSimulator,
    );
    
    _initialized = true;
  }

  // Ensure initialization before any operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _initialize();
    }
  }

  // Get all products
  Future<List<Map<String, dynamic>>> getProducts() async {
    await _ensureInitialized();
    return _sharePointService.getProductList();
  }

  // Get a product by scanning its barcode
  Future<Map<String, dynamic>?> scanProductBarcode() async {
    await _ensureInitialized();
    
    // Scan barcode
    final barcode = await _barcodeScannerService.scanBarcode();
    
    if (barcode != null && barcode.isNotEmpty) {
      // Look up product information using the scanned barcode
      return _sharePointService.getProductByCode(barcode);
    }
    
    return null;
  }

  // Get product by its code (without scanning)
  Future<Map<String, dynamic>?> getProductByCode(String code) async {
    await _ensureInitialized();
    return _sharePointService.getProductByCode(code);
  }

  // Update inventory count for a product
  Future<bool> updateInventoryCount(String productId, int newCount) async {
    await _ensureInitialized();
    return _sharePointService.updateInventoryCount(productId, newCount);
  }
  
  // Check if running in simulator mode
  bool get isSimulatorMode => SharePointService.isRunningOnSimulator();
}
