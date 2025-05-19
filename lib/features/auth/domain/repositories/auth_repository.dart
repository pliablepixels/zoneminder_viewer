import 'package:dartz/dartz.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_credentials.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_response.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/user.dart';

/// Abstract class defining the authentication repository contract
abstract class AuthRepository {
  /// Logs in a user with the provided credentials
  /// Returns [AuthResponse] on success or [AppException] on failure
  Future<Either<AppException, AuthResponse>> login({
    required String baseUrl,
    required String username,
    required String password,
    bool rememberMe = false,
  });

  /// Logs out the current user
  /// Returns [bool] indicating success or failure
  Future<Either<AppException, bool>> logout();

  /// Refreshes the authentication token
  /// Returns [AuthResponse] on success or [AppException] on failure
  Future<Either<AppException, AuthResponse>> refreshToken({
    required String refreshToken,
  });

  /// Gets the current authenticated user
  /// Returns [User] if authenticated, null otherwise
  Future<User?> getCurrentUser();

  /// Checks if the user is authenticated
  /// Returns [bool] indicating authentication status
  Future<bool> isAuthenticated();

  /// Saves the authentication credentials
  /// Returns [bool] indicating success or failure
  Future<Either<AppException, bool>> saveCredentials({
    required AuthCredentials credentials,
  });

  /// Gets the saved authentication credentials
  /// Returns [AuthCredentials] if found, null otherwise
  Future<AuthCredentials?> getSavedCredentials();

  /// Clears the saved authentication credentials
  /// Returns [bool] indicating success or failure
  Future<Either<AppException, bool>> clearCredentials();

  /// Validates the current session
  /// Returns [bool] indicating if the session is valid
  Future<Either<AppException, bool>> validateSession();
}
