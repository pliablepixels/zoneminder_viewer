import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:zoneminder_viewer/core/constants/app_constants.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';

/// A utility class for making HTTP requests with proper error handling
class NetworkUtils {
  static final Logger _logger = Logger('NetworkUtils');
  static final Connectivity _connectivity = Connectivity();

  /// The base headers to be sent with every request
  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Makes a GET request to the specified URL
  static Future<dynamic> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    int maxRetries = AppConstants.maxRetryAttempts,
  }) async {
    return _makeRequest(
      () => _getRequest(url, headers: headers, queryParams: queryParams),
      maxRetries: maxRetries,
    );
  }

  /// Makes a POST request to the specified URL
  static Future<dynamic> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int maxRetries = AppConstants.maxRetryAttempts,
  }) async {
    return _makeRequest(
      () => _postRequest(url, headers: headers, body: body),
      maxRetries: maxRetries,
    );
  }

  /// Makes a PUT request to the specified URL
  static Future<dynamic> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int maxRetries = AppConstants.maxRetryAttempts,
  }) async {
    return _makeRequest(
      () => _putRequest(url, headers: headers, body: body),
      maxRetries: maxRetries,
    );
  }

  /// Makes a DELETE request to the specified URL
  static Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int maxRetries = AppConstants.maxRetryAttempts,
  }) async {
    return _makeRequest(
      () => _deleteRequest(url, headers: headers, body: body),
      maxRetries: maxRetries,
    );
  }

  /// Makes a request with retry logic
  static Future<dynamic> _makeRequest<T>(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    // Check network connectivity first
    if (!await _isNetworkAvailable()) {
      throw const NetworkException(message: 'No internet connection');
    }

    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await request();
        return _handleResponse(response);
      } on AppException catch (e) {
        // Re-throw if we've reached max retries or it's not a retryable error
        if (attempt >= maxRetries || !_isRetryableError(e)) {
          rethrow;
        }
        
        _logger.warning(
          'Request failed (attempt $attempt/$maxRetries). Retrying...',
          e,
          StackTrace.current,
        );
        
        // Wait before retrying
        await Future.delayed(retryDelay * (attempt * 1.5).round());
      } catch (e, stackTrace) {
        // Convert to AppException if it's not already one
        if (e is! AppException) {
          throw _convertToAppException(e, stackTrace);
        }
        rethrow;
      }
    }
  }

  /// Handles the HTTP response and converts it to the appropriate type
  static dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final responseBody = response.body;

    _logger.fine('Response [${response.statusCode}]: ${response.request?.url}');
    _logger.finer('Response body: $responseBody');

    // Parse the response body
    dynamic jsonResponse;
    try {
      // Only try to parse if the body is not empty
      if (responseBody.trim().isNotEmpty) {
        jsonResponse = jsonDecode(responseBody);
      }
    } catch (e) {
      _logger.warning('Failed to parse response body as JSON', e);
      // If we can't parse the body, just continue with null
    }

    // Handle different status codes
    if (statusCode >= 200 && statusCode < 300) {
      return jsonResponse ?? responseBody;
    } else if (statusCode == 400) {
      throw ValidationException(
        message: jsonResponse?['message'] ?? 'Invalid request',
        error: jsonResponse,
        code: statusCode.toString(),
      );
    } else if (statusCode == 401) {
      throw AuthException(
        message: jsonResponse?['message'] ?? 'Unauthorized',
        error: jsonResponse,
        code: statusCode.toString(),
      );
    } else if (statusCode == 403) {
      throw PermissionDeniedException(
        message: jsonResponse?['message'] ?? 'Forbidden',
        error: jsonResponse,
        code: statusCode.toString(),
      );
    } else if (statusCode == 404) {
      throw NotFoundException(
        message: jsonResponse?['message'] ?? 'Resource not found',
        error: jsonResponse,
        code: statusCode.toString(),
      );
    } else if (statusCode == 409) {
      throw ConflictException(
        message: jsonResponse?['message'] ?? 'Conflict',
        error: jsonResponse,
        code: statusCode.toString(),
      );
    } else if (statusCode >= 500) {
      throw ServerException(
        message: jsonResponse?['message'] ?? 'Server error',
        error: jsonResponse,
        code: statusCode.toString(),
        statusCode: statusCode,
      );
    } else {
      throw UnexpectedException(
        message: jsonResponse?['message'] ?? 'An unexpected error occurred',
        error: jsonResponse,
        code: statusCode.toString(),
      );
    }
  }

  /// Converts an error to an AppException
  static AppException _convertToAppException(dynamic error, StackTrace stackTrace) {
    if (error is AppException) return error;
    
    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid format: ${error.message}',
        stackTrace: stackTrace,
        error: error,
      );
    }
    
    if (error is TimeoutException) {
      return TimeoutException(
        message: 'Request timed out',
        stackTrace: stackTrace,
        error: error,
      );
    }
    
    return UnexpectedException(
      message: 'An unexpected error occurred: $error',
      stackTrace: stackTrace,
      error: error,
    );
  }

  /// Checks if the device has an active internet connection
  static Future<bool> _isNetworkAvailable() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      _logger.warning('Failed to check network connectivity', e);
      return false;
    }
  }

  /// Checks if an error is retryable
  static bool _isRetryableError(AppException exception) {
    // Don't retry on client errors (4xx) except 408 (Request Timeout) and 429 (Too Many Requests)
    if (exception is ServerException) {
      final statusCode = exception.statusCode ?? 0;
      return statusCode >= 500 || statusCode == 408 || statusCode == 429;
    }
    
    // Retry on network and timeout errors
    return exception is NetworkException || exception is TimeoutException;
  }

  // Helper methods for different HTTP methods
  
  static Future<http.Response> _getRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    _logger.fine('GET $uri');
    
    return http.get(
      uri,
      headers: {..._baseHeaders, ...?headers},
    ).timeout(AppConstants.receiveTimeout);
  }

  static Future<http.Response> _postRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    _logger.fine('POST $uri');
    _logger.finer('Request body: $body');
    
    return http.post(
      uri,
      headers: {..._baseHeaders, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    ).timeout(AppConstants.receiveTimeout);
  }

  static Future<http.Response> _putRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    _logger.fine('PUT $uri');
    _logger.finer('Request body: $body');
    
    return http.put(
      uri,
      headers: {..._baseHeaders, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    ).timeout(AppConstants.receiveTimeout);
  }

  static Future<http.Response> _deleteRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    _logger.fine('DELETE $uri');
    _logger.finer('Request body: $body');
    
    return http.delete(
      uri,
      headers: {..._baseHeaders, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    ).timeout(AppConstants.receiveTimeout);
  }
}
