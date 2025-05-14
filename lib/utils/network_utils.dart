// lib/utils/network_utils.dart
import 'package:http/http.dart' as http;

/// A simple utility class for network-related functions
class NetworkUtils {
  /// Checks if the device has an active internet connection
  /// Returns true if connected, false otherwise
  static Future<bool> hasNetworkConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
  
  /// Determines if the app should use online or offline mode
  /// Based on both network connectivity and user preference
  static Future<bool> shouldUseOfflineMode(bool userPreferredOfflineMode) async {
    // If user explicitly wants offline mode, respect that
    if (userPreferredOfflineMode) {
      return true;
    }
    
    // Otherwise check for network connectivity
    final hasConnection = await hasNetworkConnection();
    return !hasConnection; // Use offline mode if no connection
  }
}
