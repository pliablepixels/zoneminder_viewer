/// App-level constants used throughout the application
class AppConstants {
  // App info
  static const String appName = 'ZoneMinder Viewer';
  static const String appVersion = '1.0.0';
  
  // API constants
  static const String defaultZmUrl = 'https://demo.zoneminder.com';
  static const String defaultUsername = 'x';
  static const String defaultPassword = 'x';
  
  // Storage keys
  static const String storageBaseUrlKey = 'base_url';
  static const String storageAccessTokenKey = 'access_token';
  static const String storageRefreshTokenKey = 'refresh_token';
  static const String storageAccessTokenExpiryKey = 'access_token_expiry';
  static const String storageRefreshTokenExpiryKey = 'refresh_token_expiry';
  static const String storageUsernameKey = 'zm_username';
  static const String storagePasswordKey = 'zm_password';
  
  // Network
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // UI
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration defaultDebounceTime = Duration(milliseconds: 500);
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxRetryAttempts = 3;
  
  // Prevent instantiation
  const AppConstants._();
}
