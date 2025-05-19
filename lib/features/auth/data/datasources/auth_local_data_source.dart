import 'package:logging/logging.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';
import 'package:zoneminder_viewer/core/utils/storage_utils.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_credentials.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/auth_response.dart';
import 'package:zoneminder_viewer/features/auth/domain/entities/user.dart';

/// Abstract class defining the local data source for authentication
abstract class AuthLocalDataSource {
  /// Saves the authentication response (tokens, user info, etc.)
  /// Returns [bool] indicating success or failure
  Future<bool> saveAuthResponse(AuthResponse response);

  /// Gets the saved authentication response
  /// Returns [AuthResponse] if found, null otherwise
  Future<AuthResponse?> getAuthResponse();

  /// Clears the saved authentication response
  /// Returns [bool] indicating success or failure
  Future<bool> clearAuthResponse();

  /// Saves the authentication credentials
  /// Returns [bool] indicating success or failure
  Future<bool> saveCredentials(AuthCredentials credentials);

  /// Gets the saved authentication credentials
  /// Returns [AuthCredentials] if found, null otherwise
  Future<AuthCredentials?> getCredentials();

  /// Clears the saved authentication credentials
  /// Returns [bool] indicating success or failure
  Future<bool> clearCredentials();
}

/// Implementation of [AuthLocalDataSource]
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _authResponseKey = 'auth_response';
  static const String _authCredentialsKey = 'auth_credentials';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';
  static const String _baseUrlKey = 'base_url';
  static const String _usernameKey = 'username';

  final StorageUtils _storage;
  final Logger _logger;

  /// Creates a new instance of [AuthLocalDataSourceImpl]
  AuthLocalDataSourceImpl({
    required StorageUtils storage,
    required Logger logger,
  })  : _storage = storage,
        _logger = logger;

  @override
  Future<bool> saveAuthResponse(AuthResponse response) async {
    try {
      // Save the access token in secure storage
      await _storage.writeSecurely(
        key: _accessTokenKey,
        value: response.token,
      );

      // Save the refresh token in secure storage if available
      if (response.refreshToken != null) {
        await _storage.writeSecurely(
          key: _refreshTokenKey,
          value: response.refreshToken!,
        );
      }

      // Save the user data in shared preferences
      await _storage.write(
        key: _userKey,
        value: response.user.toJson(),
      );

      // Save the base URL in shared preferences
      await _storage.write(
        key: _baseUrlKey,
        value: _storage.baseUrl,
      );

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to save auth response', e, stackTrace);
      return false;
    }
  }

  @override
  Future<AuthResponse?> getAuthResponse() async {
    try {
      // Get the access token from secure storage
      final accessToken = await _storage.readSecurely<String>(_accessTokenKey);
      if (accessToken == null) return null;

      // Get the refresh token from secure storage
      final refreshToken = await _storage.readSecurely<String>(_refreshTokenKey);

      // Get the user data from shared preferences
      final userData = _storage.read<Map<String, dynamic>>(_userKey);
      if (userData == null) return null;

      // Parse the user data
      final user = User.fromJson(userData);

      return AuthResponse(
        token: accessToken,
        refreshToken: refreshToken,
        expiresIn: 3600, // Default expiration time (1 hour)
        tokenType: 'Bearer',
        user: user,
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to get auth response', e, stackTrace);
      return null;
    }
  }

  @override
  Future<bool> clearAuthResponse() async {
    try {
      // Clear the access token from secure storage
      await _storage.deleteSecurely(_accessTokenKey);

      // Clear the refresh token from secure storage
      await _storage.deleteSecurely(_refreshTokenKey);

      // Clear the user data from shared preferences
      await _storage.delete(_userKey);

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to clear auth response', e, stackTrace);
      return false;
    }
  }

  @override
  Future<bool> saveCredentials(AuthCredentials credentials) async {
    try {
      // Save the credentials in secure storage
      final saved = await _storage.writeSecurely<String>(
        key: _authCredentialsKey,
        value: credentials.toJson(),
      );

      // Also save the base URL in shared preferences
      if (saved) {
        await _storage.write(
          key: _baseUrlKey,
          value: credentials.baseUrl,
        );
      }

      return saved;
    } catch (e, stackTrace) {
      _logger.severe('Failed to save credentials', e, stackTrace);
      return false;
    }
  }

  @override
  Future<AuthCredentials?> getCredentials() async {
    try {
      // Get the credentials from secure storage
      final credentialsJson = 
          await _storage.readSecurely<String>(_authCredentialsKey);

      if (credentialsJson != null) {
        try {
          final credentialsData = jsonDecode(credentialsJson) as Map<String, dynamic>;
          return AuthCredentials.fromJson(credentialsData);
        } catch (e) {
          _logger.warning('Failed to parse stored credentials', e);
          // Continue to fallback method
        }
      }

      // Fallback to getting the base URL and username from shared preferences
      final baseUrl = _storage.read<String>(_baseUrlKey);
      final username = _storage.read<String>(_usernameKey);

      if (baseUrl != null && username != null) {
        return AuthCredentials(
          baseUrl: baseUrl,
          username: username,
          password: '', // Password is not stored
          rememberMe: true,
        );
      }
      return null;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get credentials', e, stackTrace);
      return null;
    }
  }

  @override
  Future<bool> clearCredentials() async {
    try {
      // Clear the credentials from secure storage
      await _storage.deleteSecurely(_authCredentialsKey);

      // Clear the base URL and username from shared preferences
      await _storage.delete(_baseUrlKey);
      await _storage.delete(_usernameKey);

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to clear credentials', e, stackTrace);
      return false;
    }
  }
}
