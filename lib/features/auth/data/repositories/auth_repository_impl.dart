import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';
import 'package:zoneminder_viewer/core/services/api_client.dart';
import 'package:zoneminder_viewer/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:zoneminder_viewer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_credentials.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_response.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/user.dart';
import 'package:zoneminder_viewer/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of [AuthRepository]
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final ApiClient _apiClient;
  final Logger _logger;

  /// Creates a new instance of [AuthRepositoryImpl]
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required ApiClient apiClient,
    required Logger logger,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _apiClient = apiClient,
        _logger = logger;

  @override
  Future<Either<AppException, AuthResponse>> login({
    required String baseUrl,
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      // Update the base URL of the API client
      _apiClient.options.baseUrl = baseUrl;

      // Call the remote data source to perform login
      final response = await _remoteDataSource.login(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );

      // Save the authentication response
      await _localDataSource.saveAuthResponse(response);

      // Save credentials if rememberMe is true
      if (rememberMe) {
        final credentials = AuthCredentials(
          baseUrl: baseUrl,
          username: username,
          password: password,
          rememberMe: true,
        );
        await _localDataSource.saveCredentials(credentials);
      } else {
        // Clear any saved credentials if rememberMe is false
        await _localDataSource.clearCredentials();
      }

      // Set the authorization header for subsequent requests
      _apiClient.setAuthToken(response.token);

      return Right(response);
    } on AppException catch (e) {
      _logger.severe('Login failed', e.error, e.stackTrace);
      return Left(e);
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during login', e, stackTrace);
      return Left(
        AppException(
          message: 'An unexpected error occurred during login',
          error: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<AppException, bool>> logout() async {
    try {
      // Call the remote data source to perform logout
      final result = await _remoteDataSource.logout();

      // Clear the local authentication data
      await _localDataSource.clearAuthResponse();
      await _localDataSource.clearCredentials();

      // Clear the authorization header
      _apiClient.clearAuthToken();

      return Right(result);
    } on AppException catch (e) {
      _logger.severe('Logout failed', e.error, e.stackTrace);
      return Left(e);
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during logout', e, stackTrace);
      return Left(
        AppException(
          message: 'An unexpected error occurred during logout',
          error: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<AppException, AuthResponse>> refreshToken({
    required String refreshToken,
  }) async {
    try {
      // Call the remote data source to refresh the token
      final response = await _remoteDataSource.refreshToken(
        refreshToken: refreshToken,
      );

      // Save the new authentication response
      await _localDataSource.saveAuthResponse(response);

      // Update the authorization header
      _apiClient.setAuthToken(response.token);

      return Right(response);
    } on AppException catch (e) {
      _logger.severe('Token refresh failed', e.error, e.stackTrace);
      return Left(e);
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during token refresh', e, stackTrace);
      return Left(
        AppException(
          message: 'An unexpected error occurred during token refresh',
          error: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final response = await _localDataSource.getAuthResponse();
      return response?.user;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get current user', e, stackTrace);
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      // Check if we have a valid auth response
      final authResponse = await _localDataSource.getAuthResponse();
      if (authResponse == null) return false;

      // Validate the session with the server
      final isValid = await _remoteDataSource.validateSession();
      
      // If the session is not valid, try to refresh the token
      if (!isValid && authResponse.refreshToken != null) {
        final result = await refreshToken(
          refreshToken: authResponse.refreshToken!,
        );
        return result.fold((_) => false, (_) => true);
      }

      return isValid;
    } catch (e, stackTrace) {
      _logger.severe('Failed to check authentication status', e, stackTrace);
      return false;
    }
  }

  @override
  Future<Either<AppException, bool>> saveCredentials({
    required AuthCredentials credentials,
  }) async {
    try {
      final result = await _localDataSource.saveCredentials(credentials);
      return Right(result);
    } catch (e, stackTrace) {
      _logger.severe('Failed to save credentials', e, stackTrace);
      return Left(
        AppException(
          message: 'Failed to save credentials',
          error: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<AuthCredentials?> getSavedCredentials() async {
    try {
      return await _localDataSource.getCredentials();
    } catch (e, stackTrace) {
      _logger.severe('Failed to get saved credentials', e, stackTrace);
      return null;
    }
  }

  @override
  Future<Either<AppException, bool>> clearCredentials() async {
    try {
      final result = await _localDataSource.clearCredentials();
      return Right(result);
    } catch (e, stackTrace) {
      _logger.severe('Failed to clear credentials', e, stackTrace);
      return Left(
        AppException(
          message: 'Failed to clear credentials',
          error: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Either<AppException, bool>> validateSession() async {
    try {
      final isValid = await _remoteDataSource.validateSession();
      return Right(isValid);
    } on AppException catch (e) {
      _logger.severe('Session validation failed', e.error, e.stackTrace);
      return Left(e);
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during session validation', e, stackTrace);
      return Left(
        AppException(
          message: 'An unexpected error occurred during session validation',
          error: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
