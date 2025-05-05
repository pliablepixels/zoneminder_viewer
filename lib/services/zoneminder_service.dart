import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

class ZoneMinderService {
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
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
      _logger.fine('Adding authorization header with token');
    }
    _logger.fine('Request headers: $headers');
    return headers;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    _logger.info('Attempting login with username: $username');
    _logger.fine('API URL: $_apiUrl');
    
    try {
      _logger.fine('Making login request...');
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
          
          return data;
        } else {
          _logger.severe('Unexpected response format: $data');
          throw Exception('Unexpected response format from ZoneMinder API');
        }
      } else {
        _logger.severe('Login failed: ${response.statusCode} - ${response.body}');
        throw Exception('Login failed: ${response.statusCode}');
      }
      throw Exception('Login failed: ${response.statusCode}');
    } catch (e) {
      _logger.severe('Login error: $e');
      rethrow;
    }
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

  String getStreamUrl(int monitorId) {
    if (monitorId <= 0) {
      throw ArgumentError('Invalid monitor ID: $monitorId');
    }
    final random = Random();
    final connKey = random.nextInt(1000000);
    final token = _accessToken ?? 'noauth';
    return '$_baseUrl/cgi-bin/nph-zms?mode=single&monitor=$monitorId&scale=100&maxfps=5&buffer=1000&rand=$connKey&auth=$token';
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = _sanitizeUrl(url);
    _apiUrl = _sanitizeUrl('$_baseUrl/api');
    _logger.info('Base URL updated to: $_baseUrl');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  String get baseUrl => _baseUrl;

  String? get accessToken => _accessToken;

  String get apiUrl => _apiUrl;

  /// Checks if the current token is valid by making a test API call
  Future<bool> isTokenValid() async {
    if (_accessToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/host/getVersion.json'),
        headers: await _getHeaders(),
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

  bool get isAuthenticated => _accessToken != null;
}
