/// API-related constants and endpoints
class ApiConstants {
  // API paths
  static const String apiPrefix = '/api';
  static const String authPath = '/host/login.json';
  static const String monitorsPath = '/monitors.json';
  static const String eventsPath = '/events.json';
  static const String eventDetailPath = '/events';
  
  // Query parameters
  static const String monitorIdParam = 'monitor_id';
  static const String fromParam = 'from';
  static const String toParam = 'to';
  static const String pageParam = 'page';
  static const String limitParam = 'limit';
  static const String sortParam = 'sort';
  
  // Headers
  static const String authHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String acceptHeader = 'Accept';
  static const String jsonContentType = 'application/json';
  
  // Response fields
  static const String accessTokenField = 'access_token';
  static const String refreshTokenField = 'refresh_token';
  static const String expiresInField = 'expires_in';
  
  // Prevent instantiation
  const ApiConstants._();
}
