// lib/config.dart
class Config {
  // Azure AD Configuration
  static const String azureClientId = 'YOUR_AZURE_CLIENT_ID';
  static const String azureClientSecret = 'YOUR_AZURE_CLIENT_SECRET';
  static const String redirectUri = 'com.yourcompany.inventory_scanner_new://auth';
  static const String urlScheme = 'com.yourcompany.inventory_scanner_new';

  // SharePoint Configuration
  static const String sharePointSiteUrl = 'https://yourtenant.sharepoint.com/sites/inventory';

  // Feature Flags
  static const bool enableOfflineMode = true;
  
  // API Endpoints
  static const String productListEndpoint = '/sites/inventory/_api/web/lists/getByTitle(\'Products\')/items';
}
