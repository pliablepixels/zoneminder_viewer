import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:zoneminder_viewer/utils/jwt_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class ZoneMinderService extends ChangeNotifier {
  static final Logger _logger = Logger('ZoneMinderService');
  static const String _baseUrlKey = 'base_url';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _accessTokenExpiryKey = 'access_token_expiry';
  static const String _refreshTokenExpiryKey = 'refresh_token_expiry';

  String _baseUrl = '';
  String _apiUrl = '';
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiry;
  DateTime? _refreshTokenExpiry;
  bool _isInitialized = false;

  // Store credentials for re-login
  String? _username;
  String? _password;

  static const String _usernameKey = 'zm_username';
  static const String _passwordKey = 'zm_password';

  /// Ensures the service is initialized before making any API calls
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) {
      _logger.fine('ZoneMinderService already initialized');
      return;
    }
    
    _logger.info('Initializing ZoneMinderService...');
    try {
      final prefs = await SharedPreferences.getInstance();
      _logger.info('Loaded SharedPreferences');
      
      // Load tokens
      _accessToken = prefs.getString(_accessTokenKey);
      _refreshToken = prefs.getString(_refreshTokenKey);
      
      _logger.info('Loaded tokens from storage - ' 
          'Access Token: ${_accessToken != null ? 'present' : 'not present'}, '
          'Refresh Token: ${_refreshToken != null ? 'present' : 'not present'}');
      
      // Load token expiry times
      final accessExpiry = prefs.getInt(_accessTokenExpiryKey);
      final refreshExpiry = prefs.getInt(_refreshTokenExpiryKey);
      
      if (accessExpiry != null) {
        _accessTokenExpiry = DateTime.fromMillisecondsSinceEpoch(accessExpiry);
      }
      if (refreshExpiry != null) {
        _refreshTokenExpiry = DateTime.fromMillisecondsSinceEpoch(refreshExpiry);
      }
      
      // Load base URL
      final savedBaseUrl = prefs.getString(_baseUrlKey);
      if (savedBaseUrl != null && savedBaseUrl.isNotEmpty) {
        _baseUrl = savedBaseUrl;
      }
      
      _logger.info('Using base URL: $_baseUrl');
      
      // Construct and sanitize API URL
      final apiUrl = _baseUrl.endsWith('/api') ? _baseUrl : '$_baseUrl/api';
      _logger.info('Constructed API URL before sanitization: $apiUrl');
      
      _apiUrl = _sanitizeUrl(apiUrl);
      _isInitialized = true;
      
      _logger.info('Initialized ZoneMinderService with:');
      _logger.info('- Base URL: $_baseUrl');
      _logger.info('- API URL: $_apiUrl');
      _logger.info('- Has access token: ${_accessToken != null}');
      _logger.info('- Has refresh token: ${_refreshToken != null}');
      
      if (_accessTokenExpiry != null) {
        _logger.info('- Access token expires at: $_accessTokenExpiry');
      }
      if (_refreshTokenExpiry != null) {
        _logger.info('- Refresh token expires at: $_refreshTokenExpiry');
      }
    } catch (e) {
      _isInitialized = false;
      _logger.severe('Error initializing ZoneMinderService: $e');
      rethrow;
    }
  }

  String _sanitizeUrl(String url) {
    _logger.fine('Sanitizing URL: $url');
    
    // Handle empty or null URL
    if (url.isEmpty) {
      _logger.info('Empty URL provided, using default');
      url = '';
    }
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
      _logger.info('Added https:// to URL: $url');
    }
    
    try {
      final uri = Uri.parse(url);
      
      url = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path.replaceAll(RegExp(r'/{2,}'), '/'),
        query: uri.query,
      ).toString();
      
      url = url.replaceAll(RegExp(r'/+$'), '');
      _logger.fine('Sanitized URL: $url');
      
      return url;
    } catch (e) {
      _logger.severe('Error sanitizing URL: $e');
      return '';
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    _logger.fine('Getting headers for API request');
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      // Get a valid token
      final token = await getValidToken();
      
      if (token != null && token != 'noauth') {
        _logger.fine('Adding Bearer token to headers');
        headers['Authorization'] = 'Bearer $token';
      } else {
        _logger.fine('No valid token available, skipping Authorization header');
      }
      
      return headers;
    } catch (e) {
      _logger.severe('Error getting headers: $e');
      // Return headers without auth if there was an error
      return headers;
    }
  }
  
  /// Clears all stored tokens and credentials
  Future<void> _clearTokens() async {
    _logger.info('Clearing all stored tokens and credentials');
    
    try {
      // Clear in-memory tokens
      _accessToken = null;
      _refreshToken = null;
      _accessTokenExpiry = null;
      _refreshTokenExpiry = null;
      
      // Clear tokens from persistent storage
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_accessTokenKey),
        prefs.remove(_refreshTokenKey),
        prefs.remove(_accessTokenExpiryKey),
        prefs.remove(_refreshTokenExpiryKey),
      ]);
      
      _logger.fine('Successfully cleared all tokens from storage');
      
      // Note: We don't clear the username and password here
      // as they might be needed for automatic re-login
      
      // Notify listeners that the authentication state has changed
      notifyListeners();
      _logger.fine('Notified listeners of token clearance');
    } catch (e) {
      _logger.severe('Error clearing tokens: $e');
      rethrow;
    }
  }

  // Helper method to add auth token to URLs
  Future<String> _addAuthToUrl(String url) async {
    if (url.isEmpty) {
      _logger.warning('Empty URL provided to _addAuthToUrl');
      return url;
    }
    
    final token = await getValidToken();
    if (token == null || token == 'noauth') {
      _logger.fine('No valid token available, returning URL as-is');
      return url;
    }
    
    try {
      _logger.fine('Adding auth token to URL: $url');
      
      // Parse the URL
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      
      // Only add the auth parameter if it's not already in the URL
      if (!params.containsKey('token') && !params.containsKey('auth')) {
        params['token'] = token;
        _logger.fine('Added token parameter to URL');
      } else {
        _logger.fine('URL already contains auth parameters, not adding new ones');
      }
      
      // Rebuild the URL with the updated parameters
      final newUri = uri.replace(queryParameters: params);
      final result = newUri.toString();
      
      _logger.fine('Final URL with auth: $result');
      return result;
    } catch (e) {
      _logger.severe('Error adding auth to URL: $e');
      // Return the original URL if there was an error
      return url;
    }
  }

  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() requestFn, {
    bool retryOnAuthFailure = true,
  }) async {
    try {
      await ensureInitialized();
      
      // Get a fresh token for this request
      final token = await getValidToken();
      _logger.fine('Using token for request: ${token != null ? 'present' : 'not available'}');
      
      // Make the request
      _logger.fine('Making authenticated request...');
      http.Response response;
      
      try {
        response = await requestFn().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _logger.severe('Request timed out after 30 seconds');
            throw TimeoutException('Request timed out', const Duration(seconds: 30));
          },
        );
        _logger.fine('Request completed with status: ${response.statusCode}');
      } catch (e) {
        _logger.severe('Request failed: $e');
        rethrow;
      }
      
      // If we got a 401, try to refresh the token and retry once
      if (response.statusCode == 401 && retryOnAuthFailure) {
        _logger.warning('Received 401, attempting to refresh token...');
        
        try {
          // Try to refresh the token
          final refreshSuccess = await _refreshTokenIfAvailable();
          
          if (refreshSuccess) {
            _logger.info('Token refreshed, retrying request...');
            // Retry the request with the new token
            return _makeAuthenticatedRequest(requestFn, retryOnAuthFailure: false);
          } else {
            _logger.warning('Failed to refresh token, giving up');
            // Clear tokens to force login on next attempt
            await _clearTokens();
            
            // Check if we should provide more specific error information
            if (response.body.isNotEmpty) {
              try {
                final errorData = jsonDecode(response.body);
                if (errorData is Map<String, dynamic>) {
                  final errorMsg = errorData['message']?.toString() ?? 'Authentication failed';
                  throw Exception(errorMsg);
                }
              } catch (e) {
                _logger.fine('Could not parse error response: $e');
              }
            }
            
            throw Exception('Authentication failed. Please log in again.');
          }
        } catch (e) {
          _logger.severe('Error during token refresh: $e');
          await _clearTokens();
          rethrow;
        }
      }
      
      // Handle other error status codes
      if (response.statusCode >= 400) {
        String errorMessage = 'Request failed with status: ${response.statusCode}';
        
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic>) {
              errorMessage = errorData['message']?.toString() ?? errorMessage;
            }
          }
        } catch (e) {
          _logger.fine('Could not parse error response: $e');
        }
        
        _logger.severe('$errorMessage - Status: ${response.statusCode}');
        throw Exception(errorMessage);
      }
      
      return response;
    } catch (e) {
      _logger.severe('Error in authenticated request: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    // Save credentials in memory for possible re-login
    _username = username;
    _password = password;

    _logger.info('Attempting login for user: $username');
    
    // Input validation
    if (username.isEmpty) {
      _logger.warning('Login failed: Username cannot be empty');
      throw Exception('Username is required');
    }
    
    if (password.isEmpty) {
      _logger.warning('Login failed: Password cannot be empty');
      throw Exception('Password is required');
    }
    
    try {
      await ensureInitialized();
      
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      };
      
      // Ensure the URL is properly constructed
      final loginUrl = '${_apiUrl.endsWith('/') ? _apiUrl.substring(0, _apiUrl.length - 1) : _apiUrl}/host/login.json';
      final url = Uri.parse(loginUrl);
      
      // URL encode the username and password to handle special characters
      final encodedUser = Uri.encodeComponent(username);
      final encodedPass = Uri.encodeComponent(password);
      final body = 'user=$encodedUser&pass=$encodedPass';
      
      _logger.fine('POST $url');
      _logger.fine('Headers: $headers');
      
      final stopwatch = Stopwatch()..start();
      http.Response response;
      
      try {
        // First try with the regular request
        try {
          response = await http.post(
            url,
            headers: headers,
            body: body,
            encoding: Encoding.getByName('utf-8'),
          ).timeout(const Duration(seconds: 30));
        } catch (e) {
          _logger.warning('First attempt failed, trying with CORS workaround: $e');
          
          // For security, do NOT send tokens through a CORS proxy. Only use proxy for public requests (never for login).
          throw Exception('Network error: CORS issue detected. Please use a native app or configure your server for CORS.');
        }
      } catch (e) {
        _logger.severe('Network error during login: $e');
        throw Exception('Network error: ${e.toString()}');
      }
      
      _logger.fine('Request completed in ${stopwatch.elapsedMilliseconds}ms');
      
      _logger.fine('Received response with status code: ${response.statusCode}');
      _logger.fine('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          
          if (data.containsKey('version')) {
            _logger.info('Successfully connected to ZoneMinder version: ${data['version']}');
            
            // Store both access and refresh tokens
            _accessToken = data['access_token']?.toString();
            _refreshToken = data['refresh_token']?.toString();
            
            if (_accessToken == null || _accessToken!.isEmpty) {
              _logger.info('No access token received, using noauth mode');
              _accessToken = 'noauth';
            }
            
            // Parse token expiration times (in seconds since epoch)
            final now = DateTime.now();
            final accessTokenExpiresIn = (data['access_token_expires_in'] as num?)?.toInt() ?? 3600; // Default 1 hour
            final refreshTokenExpiresIn = (data['refresh_token_expires_in'] as num?)?.toInt() ?? 2592000; // Default 30 days
            
            _accessTokenExpiry = now.add(Duration(seconds: accessTokenExpiresIn));
            _refreshTokenExpiry = now.add(Duration(seconds: refreshTokenExpiresIn));
            
            _logger.info('Using access token: ${_accessToken != null ? 'present' : 'not present'} (expires: $_accessTokenExpiry)');
            _logger.info('Using refresh token: ${_refreshToken != null ? 'present' : 'not present'} (expires: $_refreshTokenExpiry)');
            
            // Save tokens, expiry times, and credentials to preferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_accessTokenKey, _accessToken!);
            await prefs.setInt(_accessTokenExpiryKey, _accessTokenExpiry!.millisecondsSinceEpoch);
            
            // Do NOT store username and password for future token refreshes (security best practice)
            // User will be prompted to re-enter credentials if refresh fails.
            
            if (_refreshToken != null && _refreshToken!.isNotEmpty) {
              await prefs.setString(_refreshTokenKey, _refreshToken!);
              await prefs.setInt(_refreshTokenExpiryKey, _refreshTokenExpiry!.millisecondsSinceEpoch);
            }
            
            _logger.info('Login successful for user: $username');
            notifyListeners();
            return data;
          } else {
            _logger.severe('Unexpected response format: $data');
            throw Exception('Unexpected response format from ZoneMinder API');
          }
        } catch (e) {
          _logger.severe('Error parsing login response: $e');
          throw Exception('Invalid response from server');
        }
      } else {
        String errorMessage = 'Login failed: ${response.statusCode}';
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message']?.toString() ?? errorMessage;
          }
        } catch (e) {
          _logger.fine('Could not parse error response: $e');
        }
        
        _logger.severe('$errorMessage - Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      _logger.severe('Login error: $e');
      rethrow;
    }
  }


  Future<List<Map<String, dynamic>>> getMonitors() async {
    await ensureInitialized();
    _logger.info('Fetching monitors');
    try {
      // Construct the full URL with auth token
      final fullUrl = await _addAuthToUrl('$_apiUrl/monitors.json');
      _logger.fine('Constructed full URL: $fullUrl');
      
      // Parse the URL to ensure it's valid
      final url = Uri.parse(fullUrl);
      _logger.fine('Parsed URL: $url');
      _logger.fine('URL components - scheme: ${url.scheme}, host: ${url.host}, path: ${url.path}');
      
      if (url.host.isEmpty) {
        throw Exception('No host specified in URL. API URL: $_apiUrl');
      }
      
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(url, headers: headers),
      );
      
      _logger.fine('Received response with status code: ${response.statusCode}');
      _logger.fine('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('monitors')) {
          final monitors = data['monitors'] as List<dynamic>;
          _logger.info('Retrieved ${monitors.length} monitors');
          return monitors.cast<Map<String, dynamic>>();
        } else {
          _logger.severe('Unexpected response format: $data');
          throw Exception('Unexpected response format from ZoneMinder API');
        }
      } else {
        _logger.severe('Failed to fetch monitors: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch monitors: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching monitors: $e');
      rethrow;
    }
  }

  Future<String> getStreamUrl(int monitorId) async {
    if (monitorId <= 0) {
      throw ArgumentError('Invalid monitor ID: $monitorId');
    }
    final random = Random();
    final connKey = random.nextInt(1000000);
    final token = await getValidToken() ?? 'noauth';
    
    // Build the base URL with parameters
    final params = <String, String>{
      'mode': 'single',
      'monitor': monitorId.toString(),
      'scale': '100',
      'maxfps': '5',
      'buffer': '1000',
      'rand': connKey.toString(),
    };
    
    // Only add token if it's not 'noauth'
    if (token != 'noauth') {
      params['token'] = token;
    }
    
    final url = Uri.parse('$_baseUrl/cgi-bin/nph-zms').replace(
      queryParameters: params,
    );
    
    return url.toString();
  }

  Future<void> setBaseUrl(String url) async {
    if (_baseUrl == url) {
      _logger.info('Base URL is already set to: $url');
      return;
    }
    
    _logger.info('Updating base URL from $_baseUrl to $url');
    
    // Clear existing tokens and state
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiry = null;
    _refreshTokenExpiry = null;
    
    // Update URLs
    _baseUrl = url;
    _apiUrl = _sanitizeUrl('$_baseUrl/api');
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_accessTokenExpiryKey);
    await prefs.remove(_refreshTokenExpiryKey);
    
    _logger.info('Base URL updated to: $_baseUrl, tokens cleared');
    
    // Notify listeners and force reinitialization
    _isInitialized = false;
    notifyListeners();
    
    // Reinitialize the service with the new URL
    await ensureInitialized();
  }

  String get baseUrl => _baseUrl;

  String? get accessToken => _accessToken;

  String get apiUrl => _apiUrl;

  /// Logs out the current user by clearing authentication tokens
  Future<void> logout() async {
    _logger.info('Logging out');
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiry = null;
    _refreshTokenExpiry = null;
    _username = null;
    _password = null;
    // Clear tokens, expiry times, and credentials from preferences
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_accessTokenExpiryKey),
      prefs.remove(_refreshTokenExpiryKey),
      prefs.remove(_usernameKey),
      prefs.remove(_passwordKey),
    ]);
    notifyListeners();
  }

  /// Returns true if the user is authenticated (has a valid access token)
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  /// Returns a valid access token, refreshing if needed
  Future<String?> getValidToken() async {
    if (_accessToken == null) return null;
    if (!JwtUtils.isExpired(_accessToken!)) {
      return _accessToken;
    }
    final refreshed = await _refreshTokenIfAvailable();
    if (refreshed) return _accessToken;
    await logout();
    return null;
  }

  /// Attempts to refresh the access token (stub, since username/password are not stored)
  Future<bool> _refreshTokenIfAvailable() async {
    // Try to re-login using saved credentials
    final prefs = await SharedPreferences.getInstance();
    _username ??= prefs.getString(_usernameKey);
    _password ??= prefs.getString(_passwordKey);

    if (_username != null && _password != null) {
      try {
        _logger.info('Attempting to re-login with stored credentials...');
        await login(_username!, _password!);
        _logger.info('Re-login successful');
        return true;
      } catch (e) {
        _logger.warning('Re-login failed: $e');
      }
    } else {
      _logger.warning('No credentials stored for refresh; user must re-authenticate.');
    }
    await logout();
    return false;
  }

    // Stub for getMonitorsMap (implement as needed)


  // --- All methods below are now correctly inside ZoneMinderService ---

  Future<String> getEventThumbnailUrl(int eventId, {int width = 200, int height = 125}) async {
    final params = <String, String>{
      'eid': eventId.toString(),
      'fid': 'snapshot',
      'view': 'image',
      'width': width.toString(),
      'height': height.toString(),
    };
    
    // Get current token
    final token = await getValidToken();
    
    // Add auth token if authenticated
    if (token != null && token != 'noauth') {
      params['auth'] = token;
    }
    
    final uri = Uri.parse('$_baseUrl/index.php').replace(
      queryParameters: params,
    );
    
    return uri.toString();
  }

  /// Generates a URL for playing back an event
  /// 
  /// The format is: $_baseUrl/cgi-bin/nph-zms?mode=jpeg&frame=1&scale=10&rate=100
  /// &maxfps=10&replay=none&source=event&event=<eventId>&connkey=<random>&rand=<random>
  Future<String> getEventPlaybackUrl(int eventId) async {
    final random = Random();
    final connkey = random.nextInt(1000000).toString();
    final rand = random.nextInt(1000000).toString();
    
    final params = <String, String>{
      'mode': 'jpeg',
      'frame': '1',
      'scale': '10',
      'rate': '100',
      'maxfps': '10',
      'replay': 'none',
      'source': 'event',
      'event': eventId.toString(),
      'connkey': connkey,
      'rand': rand,
    };
    
    // Get current token
    final token = await getValidToken();
    
    // Add auth token if authenticated
    if (token != null && token != 'noauth') {
      params['auth'] = token;
    }
    
    final uri = Uri.parse('$_baseUrl/cgi-bin/nph-zms').replace(
      queryParameters: params,
    );
    
    final url = uri.toString();
    _logger.info('Generated event playback URL for event $eventId: $url');
    _logger.fine('Connection parameters - connkey: $connkey, rand: $rand');
    
    return url;
  }

  /// Formats a DateTime to the format expected by ZoneMinder API (YYYY-MM-DD HH:MM:SS)
  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year-$month-${day}T$hour:$minute:$second';
  }

  /// Fetches events from ZoneMinder with support for pagination and filtering
  Future<Map<String, dynamic>> getEvents({
    int page = 1,
    int limit = 20,
    List<int>? monitorIds,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    await ensureInitialized();
    _logger.info('Fetching events (page: $page, limit: $limit)');
    
    try {
      // Build the base URL
      String baseUrl = '$_apiUrl/events';
      
      // Add monitor filter if specified
      if (monitorIds != null && monitorIds.isNotEmpty) {
        baseUrl += '/index';
        for (final id in monitorIds) {
          baseUrl += '/MonitorId:$id';
        }
      }
      baseUrl += '.json';
      
      // Add query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      // Add time range filters if specified
      if (startTime != null) {
        queryParams['from'] = _formatDateTime(startTime);
      }
      if (endTime != null) {
        queryParams['to'] = _formatDateTime(endTime);
      }
      
      // Create URI and add auth token
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final urlWithAuth = await _addAuthToUrl(uri.toString());
      final finalUri = Uri.parse(urlWithAuth);
      
      _logger.fine('Final URI: $finalUri');
      
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(finalUri, headers: headers),
      );

      _logger.fine('Received response with status code: ${response.statusCode}');
      _logger.fine('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // The API returns events in a 'events' field and pagination info in 'pagination'
        if (data.containsKey('events') && data['events'] is List) {
          final events = data['events'] as List<dynamic>;
          final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
          
          _logger.info('Retrieved ${events.length} events (page $page of ${pagination['pageCount'] ?? '?'})');
          
          return {
            'events': events.cast<Map<String, dynamic>>(),
            'pagination': pagination,
            'currentPage': page,
            'totalEvents': pagination['count'] ?? events.length,
            'totalPages': pagination['pageCount'] ?? 1,
          };
        } else {
          _logger.severe('Unexpected response format: $data');
          throw Exception('Unexpected response format from ZoneMinder API');
        }
      } else {
        _logger.severe('Failed to fetch events: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch events: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error fetching events: $e');
      rethrow;
    }
  }

  /// Fetches a map of monitor IDs to monitor details
  Future<Map<int, Map<String, dynamic>>> getMonitorsMap() async {
    final monitors = await getMonitors();
    final map = <int, Map<String, dynamic>>{};
    
    for (final monitor in monitors) {
      if (monitor['Monitor'] is Map<String, dynamic>) {
        final monitorData = monitor['Monitor'] as Map<String, dynamic>;
        final id = monitorData['Id'] as int?;
        if (id != null) {
          map[id] = monitorData;
        }
      }
    }
    
    return map;
  }

  /// Gets the monitor name by ID
  Future<String> getMonitorName(int monitorId) async {
    await ensureInitialized();
    try {
      _logger.fine('Getting name for monitor ID: $monitorId');
      
      // Construct the full URL with auth token
      final fullUrl = await _addAuthToUrl('$_apiUrl/monitors/$monitorId.json');
      _logger.fine('Constructed monitor URL: $fullUrl');
      
      // Parse the URL to ensure it's valid
      final url = Uri.parse(fullUrl);
      _logger.fine('Parsed URL: $url');
      
      if (url.host.isEmpty) {
        throw Exception('No host specified in URL. API URL: $_apiUrl');
      }
      
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(url, headers: headers),
      );

      _logger.fine('Received response with status code: ${response.statusCode}');
      _logger.fine('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('monitor')) {
          final monitor = data['monitor'] as Map<String, dynamic>;
          final name = monitor['Name'] as String? ?? 'Monitor $monitorId';
          _logger.fine('Retrieved monitor name: $name');
          return name;
        } else {
          _logger.info('Unexpected response format for monitor $monitorId: $data');
        }
      } else {
        _logger.info('Failed to fetch monitor $monitorId: ${response.statusCode} - ${response.body}');
      }
      return 'Monitor $monitorId';
    } catch (e) {
      _logger.info('Failed to get monitor name: $e');
      return 'Monitor $monitorId';
    }
  }
}
