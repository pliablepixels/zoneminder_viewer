import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';
import 'package:zoneminder_viewer/core/services/api_client.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_credentials.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_response.dart';

/// Abstract class defining the remote data source for authentication
abstract class AuthRemoteDataSource {
  /// Logs in a user with the provided credentials
  /// Returns [AuthResponse] on success
  /// Throws [AppException] on failure
  Future<AuthResponse> login({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Refreshes the authentication token
  /// Returns [AuthResponse] on success
  /// Throws [AppException] on failure
  Future<AuthResponse> refreshToken({
    required String refreshToken,
  });

  /// Logs out the current user
  /// Returns [true] on success
  /// Throws [AppException] on failure
  Future<bool> logout();

  /// Validates the current session
  /// Returns [true] if the session is valid
  /// Throws [AppException] on failure
  Future<bool> validateSession();
}

/// Implementation of [AuthRemoteDataSource]
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;
  final Logger _logger;

  /// Creates a new instance of [AuthRemoteDataSourceImpl]
  AuthRemoteDataSourceImpl({
    required ApiClient apiClient,
    required Logger logger,
  })  : _apiClient = apiClient,
        _logger = logger;

  @override
  Future<AuthResponse> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    try {
      // Update the base URL of the API client
      _apiClient.options.baseUrl = baseUrl;

      // Make the login request
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      // Parse the response
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      _logger.severe('Login failed', e.error, e.stackTrace);
      throw AppException(
        message: e.response?.data?['message']?.toString() ?? 'Login failed',
        error: e.error,
        stackTrace: e.stackTrace,
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during login', e, stackTrace);
      throw AppException(
        message: 'An unexpected error occurred during login',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<AuthResponse> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/auth/refresh-token',
        data: {
          'refresh_token': refreshToken,
        },
      );

      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      _logger.severe('Token refresh failed', e.error, e.stackTrace);
      throw AppException(
        message: 'Failed to refresh token',
        error: e.error,
        stackTrace: e.stackTrace,
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during token refresh', e, stackTrace);
      throw AppException(
        message: 'An unexpected error occurred during token refresh',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await _apiClient.post<void>('/api/auth/logout');
      return true;
    } on DioException catch (e) {
      _logger.severe('Logout failed', e.error, e.stackTrace);
      throw AppException(
        message: 'Logout failed',
        error: e.error,
        stackTrace: e.stackTrace,
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during logout', e, stackTrace);
      throw AppException(
        message: 'An unexpected error occurred during logout',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> validateSession() async {
    try {
      await _apiClient.get<void>('/api/auth/validate');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return false;
      }
      _logger.severe('Session validation failed', e.error, e.stackTrace);
      throw AppException(
        message: 'Failed to validate session',
        error: e.error,
        stackTrace: e.stackTrace,
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      _logger.severe(
        'Unexpected error during session validation',
        e,
        stackTrace,
      );
      throw AppException(
        message: 'An unexpected error occurred during session validation',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
