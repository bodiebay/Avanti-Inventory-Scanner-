// lib/utils/simulator_mode.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Mobile Scanner stub for simulator
class MobileScannerStub {
  static final List<String> _testBarcodes = [
    'MMFK3LL',    // Mac Mini M2
    'SPP6TVD91W5', // Sample inventory serial
    'MD223LL/A',   // Sample Apple product code
    '12345678',    // Generic numeric code
    'WF-A1-2023',  // From our mock product data
    'SD-200-2023', // From our mock product data
    'GP-C-2436',   // From our mock product data
  ];

  static Future<String> scanBarcode() async {
    // Simulate delay of actual scanning
    await Future.delayed(Duration(seconds: 1));

    // Return a random test barcode
    final random = Random();
    return _testBarcodes[random.nextInt(_testBarcodes.length)];
  }
}

// Secure Storage stub for simulator - enhanced version
class FlutterSecureStorageStub implements FlutterSecureStorage {
  // In-memory storage map to simulate secure storage
  static final Map<String, String> _storage = {};

  // Constructor that matches the real FlutterSecureStorage constructor
  FlutterSecureStorageStub({
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
    LinuxOptions? linuxOptions,
    WindowsOptions? windowsOptions,
    WebOptions? webOptions,
    MacOsOptions? macOsOptions,
  });

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? winOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? winOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? winOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? winOptions,
  }) async {
    return Map<String, String>.from(_storage);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? winOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? winOptions,
  }) async {
    return _storage.containsKey(key);
  }
}

/// Mock for SharePoint API responses in simulator mode
class SimulatedSharePointApi {
  /// Returns a simulated list of products
  static Future<List<Map<String, dynamic>>> getProductList() async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 800));
    
    // Return mock product data
    return [
      {
        'ID': '1001',
        'Title': 'Window Frame A1',
        'ProductCode': 'WF-A1-2023',
        'Category': 'Frames',
        'Description': 'Standard window frame, white finish',
        'Price': 129.99,
        'StockQuantity': 45,
      },
      {
        'ID': '1002',
        'Title': 'Sliding Door SD-200',
        'ProductCode': 'SD-200-2023',
        'Category': 'Doors',
        'Description': 'Double-pane sliding door with aluminum frame',
        'Price': 349.99,
        'StockQuantity': 18,
      },
      {
        'ID': '1003',
        'Title': 'Glass Panel Clear 24x36',
        'ProductCode': 'GP-C-2436',
        'Category': 'Glass',
        'Description': 'Clear tempered glass panel, 24x36 inches',
        'Price': 89.99,
        'StockQuantity': 62,
      },
      {
        'ID': '1004',
        'Title': 'Window Crank Handle',
        'ProductCode': 'WCH-101',
        'Category': 'Hardware',
        'Description': 'Replacement window crank handle, brushed nickel',
        'Price': 24.99,
        'StockQuantity': 113,
      },
      {
        'ID': '1005',
        'Title': 'Weather Stripping Kit',
        'ProductCode': 'WSK-400',
        'Category': 'Accessories',
        'Description': 'Complete weather stripping kit for standard door',
        'Price': 19.99,
        'StockQuantity': 87,
      },
    ];
  }
  
  /// Simulates a product lookup by barcode/product code
  static Future<Map<String, dynamic>?> getProductByCode(String productCode) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 600));
    
    final products = await getProductList();
    try {
      return products.firstWhere(
        (product) => product['ProductCode'] == productCode,
      );
    } catch (e) {
      // Return null if no matching product found
      return null;
    }
  }
  
  /// Simulates updating inventory count for a product
  static Future<bool> updateInventoryCount(String productCode, int newCount) async {
    // Simulate network delay and processing
    await Future.delayed(Duration(milliseconds: 1000));
    
    // Always return success in simulator
    return true;
  }
}
