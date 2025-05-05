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

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _baseUrl;
    _apiUrl = _sanitizeUrl('$_baseUrl/api');
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _logger.info('Initialized ZoneMinderService with base URL: $_baseUrl');
    _logger.info('API URL: $_apiUrl');
    _logger.info('Has access token: ${_accessToken != null}');
  }

  String _sanitizeUrl(String url) {
    _logger.fine('Sanitizing URL: $url');
    if (!url.startsWith('http')) {
      url = 'https://$url';
      _logger.fine('Added scheme: $url');
    }
    
    final parts = url.split('://');
    if (parts.length != 2) {
      _logger.fine('URL already has proper format: $url');
      return url;
    }
    
    final scheme = parts[0];
    String rest = parts[1].replaceAll(RegExp(r'/{2,}'), '/');
    _logger.fine('Sanitized rest of URL: $rest');
    
    final sanitized = '$scheme://$rest';
    _logger.fine('Final sanitized URL: $sanitized');
    return sanitized;
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
    _logger.info('Fetching monitors');
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}/api/monitors.json'),
        headers: await _getHeaders(),
      );
      
      _logger.fine('Received response with status code: ${response.statusCode}');
      _logger.fine('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('monitors')) {
          final monitors = data['monitors'] as List<dynamic>;
          _logger.info('Retrieved ${monitors.length} monitors');
          return monitors.map((m) => m as Map<String, dynamic>).toList();
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

  /// Fetches recent events from ZoneMinder
  Future<List<Map<String, dynamic>>> getEvents({
    int limit = 50,
    DateTime? from,
    DateTime? to,
    List<int>? monitorIds,
  }) async {
    _logger.info('Fetching events with limit: $limit');
    
    try {
      // Build query parameters
      final params = <String, String>{
        'limit': limit.toString(),
        'sort': 'StartTime',
        'direction': 'desc',
      };

      if (from != null) {
        params['from'] = from.toUtc().toIso8601String();
      }
      if (to != null) {
        params['to'] = to.toUtc().toIso8601String();
      }
      if (monitorIds != null && monitorIds.isNotEmpty) {
        params['monitor_ids'] = monitorIds.join(',');
      }

      final uri = Uri.parse('$_apiUrl/events.json').replace(
        queryParameters: params,
      );

      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('events')) {
          final events = data['events'] as List<dynamic>;
          _logger.info('Retrieved ${events.length} events');
          return events.cast<Map<String, dynamic>>();
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
    try {
      final headers = await _getHeaders();
      final response = await _makeAuthenticatedRequest(
        () => http.get(
          Uri.parse('$_apiUrl/monitors/$monitorId.json'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('monitor')) {
          final monitor = data['monitor'] as Map<String, dynamic>;
          return monitor['Name'] as String? ?? 'Monitor $monitorId';
        }
      }
      return 'Monitor $monitorId';
    } catch (e) {
      _logger.warning('Failed to get monitor name: $e');
      return 'Monitor $monitorId';
    }
  }
}
