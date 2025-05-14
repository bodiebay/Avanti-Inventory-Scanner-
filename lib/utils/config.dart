// lib/utils/config.dart
class AppConfig {
  // Set to true when testing in iOS Simulator, false for real devices
  static const bool isSimulator = true;  // Toggle this as needed

  // Azure AD configuration
  static const String clientId = '3c82ea21-fb37-4e3d-bbe2-bd4dc7237185';
  static const String tenant = '873ebc3c-13b9-43e6-865c-1e26b0185b40';
  static const String redirectUrl = 'msauth://com.aaronwalker.inventoryscanner/auth';
  
  // Azure AD scopes
  static const List<String> scopes = [
    'User.Read',
    'openid',
    'profile',
    'offline_access'
  ];

  // SharePoint configuration
  static const String sharePointSite = 'https://avantiwindowcom-my.sharepoint.com';
  static const String inventoryListName = 'InventoryItems';
}
