// This file provides stubs for plugins that don't work in simulator

// For mobile_scanner
class MobileScanner {
  static bool get isSimulator => true;
  
  // Any constructor parameters or methods you use in your code
  MobileScanner({
    required dynamic controller,
    required dynamic onDetect,
    dynamic fit,
    dynamic formats,
    dynamic onStart,
    dynamic onError,
    dynamic overlay,
  }) {}
}

// For flutter_secure_storage
class FlutterSecureStorage {
  // In-memory storage just for simulator
  static final Map<String, String> _storage = {};
  
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
    print('SimulatorMode: Saved $key');
  }
  
  Future<String?> read({required String key}) async {
    return _storage[key];
  }
  
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }
  
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(_storage);
  }
}

// For connectivity_plus
class Connectivity {
  Future<ConnectivityResult> checkConnectivity() async {
    return ConnectivityResult.wifi; // Always pretend to be connected
  }
  
  Stream<ConnectivityResult> get onConnectivityChanged {
    return Stream.value(ConnectivityResult.wifi);
  }
}

enum ConnectivityResult {
  wifi,
  mobile,
  none,
}
