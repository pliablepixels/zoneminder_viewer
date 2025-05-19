import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:zoneminder_viewer/core/constants/app_constants.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';
import 'package:zoneminder_viewer/core/utils/logger_util.dart';

/// A wrapper around Dio HTTP client with interceptors and error handling
class ApiClient {
  final Logger _logger = Logger('ApiClient');
  final Dio _dio;
  final String baseUrl;
  final Map<String, String>? defaultHeaders;
  final bool enableLogging;

  /// Creates a new ApiClient instance
  ApiClient({
    required this.baseUrl,
    this.defaultHeaders,
    this.enableLogging = true,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) : _dio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout ?? AppConstants.connectTimeout,
      receiveTimeout: receiveTimeout ?? AppConstants.receiveTimeout,
      sendTimeout: sendTimeout ?? AppConstants.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?defaultHeaders,
      },
      validateStatus: (status) => status! < 500, // Consider all status codes < 500 as success
    );

    // Add logging interceptor if enabled
    if (enableLogging) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
    }

    // Add error interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          _logger.severe(
            'API Error: ${error.message}',
            error.error,
            error.stackTrace,
          );
          
          // Handle network errors
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            return handler.reject(
              _handleError(
                error,
                'Connection timeout. Please check your internet connection and try again.',
              ),
            );
          }
          
          // Handle no internet connection
          if (error.type == DioExceptionType.connectionError) {
            final connectivityResult = await Connectivity().checkConnectivity();
            if (connectivityResult == ConnectivityResult.none) {
              return handler.reject(
                _handleError(
                  error,
                  'No internet connection. Please check your network settings.',
                ),
              );
            }
          }
          
          // Handle response errors
          if (error.response != null) {
            final statusCode = error.response!.statusCode!;
            String message = 'An error occurred';
            
            try {
              final data = error.response!.data;
              if (data is Map<String, dynamic>) {
                message = data['message'] ?? data['error'] ?? message;
              } else if (data is String) {
                message = data;
              }
            } catch (e) {
              _logger.warning('Failed to parse error response', e);
            }
            
            // Map status codes to specific exceptions
            if (statusCode >= 400 && statusCode < 500) {
              if (statusCode == 401) {
                return handler.reject(
                  _handleError(
                    error,
                    'Authentication failed. Please log in again.',
                    code: 'unauthorized',
                  ),
                );
              } else if (statusCode == 403) {
                return handler.reject(
                  _handleError(
                    error,
                    'You do not have permission to perform this action.',
                    code: 'forbidden',
                  ),
                );
              } else if (statusCode == 404) {
                return handler.reject(
                  _handleError(
                    error,
                    'The requested resource was not found.',
                    code: 'not_found',
                  ),
                );
              } else if (statusCode == 422) {
                return handler.reject(
                  _handleError(
                    error,
                    'Validation failed. Please check your input.',
                    code: 'validation_failed',
                  ),
                );
              } else {
                return handler.reject(
                  _handleError(
                    error,
                    'Client error: $message',
                    code: 'client_error',
                  ),
                );
              }
            } else if (statusCode >= 500) {
              return handler.reject(
                _handleError(
                  error,
                  'Server error. Please try again later.',
                  code: 'server_error',
                ),
              );
            }
          }
          
          // Default error handling
          return handler.reject(
            _handleError(
              error,
              'An unexpected error occurred. Please try again.',
            ),
          );
        },
      ),
    );
  }

  /// Handles errors and converts them to AppException
  DioException _handleError(
    DioException error, 
    String message, {
    String? code,
  }) {
    return error.copyWith(
      error: AppException(
        message: message,
        error: error.error,
        stackTrace: error.stackTrace,
        code: code,
      ),
    );
  }

  /// Performs a GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      _logger.severe('GET request failed: ${e.message}', e.error, e.stackTrace);
      rethrow;
    }
  }

  /// Performs a POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      _logger.severe('POST request failed: ${e.message}', e.error, e.stackTrace);
      rethrow;
    }
  }

  /// Performs a PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      _logger.severe('PUT request failed: ${e.message}', e.error, e.stackTrace);
      rethrow;
    }
  }

  /// Performs a PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      _logger.severe('PATCH request failed: ${e.message}', e.error, e.stackTrace);
      rethrow;
    }
  }

  /// Performs a DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _logger.severe('DELETE request failed: ${e.message}', e.error, e.stackTrace);
      rethrow;
    }
  }

  /// Downloads a file
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        data: data,
        options: options,
      );
    } on DioException catch (e) {
      _logger.severe('Download failed: ${e.message}', e.error, e.stackTrace);
      rethrow;
    }
  }

  /// Sets the authentication token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clears the authentication token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Adds a request interceptor
  void addRequestInterceptor(
    FutureOr<dynamic> Function(RequestOptions, RequestInterceptorHandler) onRequest,
  ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          return await onRequest(options, handler);
        } catch (e, stackTrace) {
          _logger.severe('Request interceptor error', e, stackTrace);
          return handler.reject(
            DioException(
              requestOptions: options,
              error: e,
              stackTrace: stackTrace,
            ),
          );
        }
      },
    ));
  }

  /// Adds a response interceptor
  void addResponseInterceptor(
    FutureOr<dynamic> Function(Response, ResponseInterceptorHandler) onResponse,
  ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) async {
        try {
          return await onResponse(response, handler);
        } catch (e, stackTrace) {
          _logger.severe('Response interceptor error', e, stackTrace);
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              error: e,
              stackTrace: stackTrace,
              response: response,
            ),
          );
        }
      },
    ));
  }

  /// Adds an error interceptor
  void addErrorInterceptor(
    FutureOr<dynamic> Function(DioException, ErrorInterceptorHandler) onError,
  ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        try {
          return await onError(error, handler);
        } catch (e, stackTrace) {
          _logger.severe('Error interceptor error', e, stackTrace);
          return handler.next(error);
        }
      },
    ));
  }

  /// Cancels all pending requests
  void cancelRequests({CancelToken? cancelToken}) {
    if (cancelToken != null) {
      cancelToken.cancel();
    } else {
      _dio.close(force: true);
    }
  }
}
