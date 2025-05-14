import 'dart:async';

// Simple storage stub for simulator mode
class FlutterSecureStorageStub {
  // In-memory storage
  static final Map<String, String> _storage = {};
  
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }
  
  Future<String?> read({required String key}) async {
    return _storage[key];
  }
  
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }
  
  Future<void> deleteAll() async {
    _storage.clear();
  }
}
