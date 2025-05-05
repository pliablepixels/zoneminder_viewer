import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class ZoneMinderService extends ChangeNotifier {
  static final Logger _logger = Logger('ZoneMinderService');
  static const String _baseUrlKey = 'zoneminder_base_url';
  static const String _accessTokenKey = 'zoneminder_access_token';
  static const String _refreshTokenKey = 'zoneminder_refresh_token';

  String _baseUrl = 'https://demo.zoneminder.com';
  String _apiUrl = '';
  String? _accessToken;
  String? _refreshToken;
  bool _isInitialized = false;

  /// Ensures the service is initialized before making any API calls
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  Future<void> _initialize() async {
    _logger.info('Initializing ZoneMinderService...');
    try {
      final prefs = await SharedPreferences.getInstance();
      _logger.info('Loaded SharedPreferences');
      
      _baseUrl = prefs.getString(_baseUrlKey) ?? _baseUrl;
      _logger.info('Base URL from prefs: ${prefs.getString(_baseUrlKey) ?? 'using default'}');
      
      final apiUrl = '$_baseUrl/api';
      _logger.info('Constructed API URL before sanitization: $apiUrl');
      
      _apiUrl = _sanitizeUrl(apiUrl);
      _accessToken = prefs.getString(_accessTokenKey);
      _refreshToken = prefs.getString(_refreshTokenKey);
      
      _isInitialized = true;
      
      _logger.info('Initialized ZoneMinderService with:');
      _logger.info('- Base URL: $_baseUrl');
      _logger.info('- API URL: $_apiUrl');
      _logger.info('- Has access token: ${_accessToken != null}');
      _logger.info('- Has refresh token: ${_refreshToken != null}');
    } catch (e) {
      _logger.severe('Error initializing ZoneMinderService: $e');
      rethrow;
    }
  }

  String _sanitizeUrl(String url) {
    _logger.fine('Sanitizing URL: $url');
    
    // Handle empty or null URL
    if (url.isEmpty) {
      _logger.warning('Empty URL provided, using default');
      return 'https://demo.zoneminder.com/api';
    }

    // Ensure URL has a scheme
    if (!url.startsWith('http')) {
      url = 'https://$url';
      _logger.fine('Added scheme: $url');
    }
    
    try {
      // Parse the URL to ensure it's valid
      final uri = Uri.parse(url);
      
      // Rebuild the URL with proper formatting
      final sanitized = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path.replaceAll(RegExp(r'/{2,}'), '/'),
        query: uri.query,
      ).toString();
      
      _logger.fine('Sanitized URL: $sanitized');
      return sanitized;
    } catch (e) {
      _logger.severe('Error parsing URL: $e');
      // Return a default URL if parsing fails
      return 'https://demo.zoneminder.com/api';
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getValidToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    // Make the initial request
    var response = await requestFn();
    
    // If unauthorized, try to refresh the token and retry once
    if (response.statusCode == 401) {
      _logger.info('Token expired, attempting to refresh...');
      
      // Try to refresh the token
      final refreshed = await _refreshTokenIfAvailable();
      
      if (refreshed) {
        _logger.info('Token refreshed, retrying request...');
        // Retry the request with the new token
        return await requestFn();
      } else {
        _logger.warning('Failed to refresh token, user needs to log in again');
        // If we can't refresh, log out the user
        await logout();
      }
    }
    
    return response;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    _logger.info('Attempting login for user: $username');
    
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/host/login.json'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'user': username,
          'pass': password,
        }),
      );
      
      _logger.fine('Received response with status code: ${response.statusCode}');
      _logger.fine('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // ZoneMinder API returns version info on success
        if (data.containsKey('version')) {
          _logger.info('Successfully connected to ZoneMinder version: ${data['version']}');
          
          // ZoneMinder uses the 'token' field in the response
          final token = data['token'] as String? ?? 'noauth';
          _logger.info('Using token: $token');
          
          _accessToken = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_accessTokenKey, token);
          notifyListeners();
          
          return data;
        } else {
          _logger.severe('Unexpected response format: $data');
          throw Exception('Unexpected response format from ZoneMinder API');
        }
      } else {
        _logger.severe('Login failed: ${response.statusCode} - ${response.body}');
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Login error: $e');
      rethrow;
    }
  }

  /// Logs out the current user by clearing authentication tokens
  Future<void> logout() async {
    _logger.info('Logging out...');
    _accessToken = null;
    _refreshToken = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    
    notifyListeners();
    _logger.info('Successfully logged out');
  }

  Future<List<Map<String, dynamic>>> getMonitors() async {
    await ensureInitialized();
    _logger.info('Fetching monitors');
    try {
      final headers = await _getHeaders();
      
      // Construct the full URL
      final fullUrl = '$_apiUrl/monitors.json';
      _logger.fine('Constructed full URL: $fullUrl');
      
      // Parse the URL to ensure it's valid
      final url = Uri.parse(fullUrl);
      _logger.fine('Parsed URL: $url');
      _logger.fine('URL components - scheme: ${url.scheme}, host: ${url.host}, path: ${url.path}');
      
      if (url.host.isEmpty) {
        throw Exception('No host specified in URL. API URL: $_apiUrl');
      }
      
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
    return '$_baseUrl/cgi-bin/nph-zms?mode=single&monitor=$monitorId&scale=100&maxfps=5&buffer=1000&rand=$connKey&auth=$token';
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    _apiUrl = _sanitizeUrl('$_baseUrl/api');
    _logger.info('Base URL updated to: $_baseUrl');
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  String get baseUrl => _baseUrl;

  String? get accessToken => _accessToken;

  String get apiUrl => _apiUrl;

  // Get the current access token, refreshing it if necessary
  Future<String?> getValidToken() async {
    if (_accessToken == null) return null;
    
    // Check if token is still valid
    if (await isTokenValid()) {
      return _accessToken;
    }
    
    // Try to refresh the token
    try {
      await _refreshTokenIfAvailable();
      return _accessToken;
    } catch (e) {
      _logger.warning('Failed to refresh token: $e');
      return null;
    }
  }

  /// Checks if the current token is valid by making a test API call
  Future<bool> isTokenValid() async {
    if (_accessToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/host/getVersion.json'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['version'] != null;
      }
      return false;
    } catch (e) {
      _logger.warning('Token validation failed: $e');
      return false;
    }
  }

  // Attempt to refresh the access token if a refresh token is available
  Future<bool> _refreshTokenIfAvailable() async {
    if (_refreshToken == null) return false;
    
    try {
      _logger.info('Attempting to refresh token...');
      
      final response = await http.post(
        Uri.parse('$_apiUrl/token/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_refreshToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          _accessToken = data['token'] as String;
          _refreshToken = data['refreshToken'] as String?;
          _logger.info('Tokens updated');
          notifyListeners();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_accessTokenKey, _accessToken!);
          if (_refreshToken != null) {
            await prefs.setString(_refreshTokenKey, _refreshToken!);
          }
          return true;
        }
      }
      
      _logger.warning('Failed to refresh token: ${response.statusCode}');
      return false;
    } catch (e) {
      _logger.severe('Error refreshing token: $e');
      return false;
    }
  }

  bool get isAuthenticated => _accessToken != null;

  /// Generates a URL for an event thumbnail
  /// 
  /// The format is: base_url/index.php?eid=<event_id>&fid=snapshot&view=image&width=200&height=125
  String getEventThumbnailUrl(int eventId, {int width = 200, int height = 125}) {
    final params = {
      'eid': eventId.toString(),
      'fid': 'snapshot',
      'view': 'image',
      'width': width.toString(),
      'height': height.toString(),
    };
    
    // Add token if authenticated
    if (_accessToken != null && _accessToken != 'noauth') {
      params['token'] = _accessToken!;
    }
    
    final query = Uri(queryParameters: params).query;
    return '$_baseUrl/index.php?$query';
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
      String url = '$_apiUrl/events';
      
      // Add monitor filter if specified
      if (monitorIds != null && monitorIds.isNotEmpty) {
        url += '/index';
        for (final id in monitorIds) {
          url += '/MonitorId:$id';
        }
      }
      url += '.json';
      
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
      
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final headers = await _getHeaders();
      
      _logger.fine('Using headers: $headers');
      _logger.fine('Final URI: $uri');
      
      final response = await _makeAuthenticatedRequest(
        () => http.get(uri, headers: headers),
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
      final headers = await _getHeaders();
      
      // Construct the full URL
      final fullUrl = '$_apiUrl/monitors/$monitorId.json';
      _logger.fine('Constructed monitor URL: $fullUrl');
      
      // Parse the URL to ensure it's valid
      final url = Uri.parse(fullUrl);
      _logger.fine('Parsed URL: $url');
      
      if (url.host.isEmpty) {
        throw Exception('No host specified in URL. API URL: $_apiUrl');
      }
      
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
          _logger.warning('Unexpected response format for monitor $monitorId: $data');
        }
      } else {
        _logger.warning('Failed to fetch monitor $monitorId: ${response.statusCode} - ${response.body}');
      }
      return 'Monitor $monitorId';
    } catch (e) {
      _logger.warning('Failed to get monitor name: $e');
      return 'Monitor $monitorId';
    }
  }
}
