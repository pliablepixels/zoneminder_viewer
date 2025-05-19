import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:zoneminder_viewer/core/errors/app_exceptions.dart';

/// A utility class for handling secure and non-secure storage
class StorageUtils {
  final Logger _logger;
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  String _baseUrl = '';

  /// The base URL for API requests
  String get baseUrl => _baseUrl;
  set baseUrl(String value) => _baseUrl = value;

  /// Creates a new instance of [StorageUtils]
  StorageUtils({
    required SharedPreferences prefs,
    Logger? logger,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _logger = logger ?? Logger('StorageUtils'),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Creates a new instance of [StorageUtils] with default dependencies
  static Future<StorageUtils> createInstance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StorageUtils(
        prefs: prefs,
        logger: Logger('StorageUtils'),
      );
    } catch (e, stackTrace) {
      Logger('StorageUtils').severe(
        'Failed to initialize storage utilities',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  // Secure Storage Methods (for sensitive data like tokens)

  /// Securely writes a value to storage
  Future<bool> writeSecurely<T>({
    required String key,
    required T value,
  }) async {
    try {
      if (value is String) {
        await _secureStorage.write(key: key, value: value);
      } else if (value is Map<String, dynamic> || value is List) {
        final json = jsonEncode(value);
        await _secureStorage.write(key: key, value: json);
      } else if (value is bool || value is int || value is double) {
        await _secureStorage.write(key: key, value: value.toString());
      } else {
        throw ArgumentError('Unsupported type: ${value.runtimeType}');
      }
      return true;
    } catch (e, stackTrace) {
      _handleStorageError('writeSecurely', e, stackTrace);
      return false;
    }
  }

  /// Reads a securely stored value
  Future<T?> readSecurely<T>(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;

      if (T == String) {
        return value as T;
      } else if (T == int) {
        return int.tryParse(value) as T?;
      } else if (T == double) {
        return double.tryParse(value) as T?;
      } else if (T == bool) {
        return (value.toLowerCase() == 'true') as T;
      } else if (T == Map<String, dynamic> || T == List) {
        try {
          return jsonDecode(value) as T;
        } catch (e) {
          _logger.warning('Failed to decode JSON for key: $key');
          return null;
        }
      } else {
        throw ArgumentError('Unsupported type: $T');
      }
    } catch (e, stackTrace) {
      _handleStorageError('readSecurely', e, stackTrace);
      return null;
    }
  }

  /// Deletes a securely stored value
  Future<bool> deleteSecurely(String key) async {
    try {
      await _secureStorage.delete(key: key);
      return true;
    } catch (e, stackTrace) {
      _handleStorageError('deleteSecurely', e, stackTrace);
      return false;
    }
  }

  /// Checks if a key exists in secure storage
  Future<bool> containsKeySecurely(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e, stackTrace) {
      _handleStorageError('containsKeySecurely', e, stackTrace);
      return false;
    }
  }

  // SharedPreferences Methods (for non-sensitive data)

  /// Writes a value to shared preferences
  Future<bool> write<T>({
    required String key,
    required T value,
  }) async {
    try {
      if (value is String) {
        return _prefs.setString(key, value);
      } else if (value is int) {
        return _prefs.setInt(key, value);
      } else if (value is double) {
        return _prefs.setDouble(key, value);
      } else if (value is bool) {
        return _prefs.setBool(key, value);
      } else if (value is List<String>) {
        return _prefs.setStringList(key, value);
      } else if (value is Map<String, dynamic> || value is List) {
        final json = jsonEncode(value);
        return _prefs.setString(key, json);
      } else {
        throw ArgumentError('Unsupported type: ${value.runtimeType}');
      }
    } catch (e, stackTrace) {
      _handleStorageError('write', e, stackTrace);
      return false;
    }
  }

  /// Reads a value from shared preferences
  T? read<T>(String key, {T? defaultValue}) {
    try {
      if (T == String) {
        return _prefs.getString(key) as T? ?? defaultValue;
      } else if (T == int) {
        return _prefs.getInt(key) as T? ?? defaultValue;
      } else if (T == double) {
        return _prefs.getDouble(key) as T? ?? defaultValue;
      } else if (T == bool) {
        return _prefs.getBool(key) as T? ?? defaultValue;
      } else if (T == List<String>) {
        return _prefs.getStringList(key) as T? ?? defaultValue;
      } else if (T == Map<String, dynamic> || T == List) {
        final json = _prefs.getString(key);
        if (json == null) return defaultValue;
        try {
          return jsonDecode(json) as T? ?? defaultValue;
        } catch (e) {
          _logger.warning('Failed to decode JSON for key: $key');
          return defaultValue;
        }
      } else {
        throw ArgumentError('Unsupported type: $T');
      }
    } catch (e, stackTrace) {
      _handleStorageError('read', e, stackTrace);
      return defaultValue;
    }
  }

  /// Deletes a value from shared preferences
  Future<bool> delete(String key) async {
    try {
      return await _prefs.remove(key);
    } catch (e, stackTrace) {
      _handleStorageError('delete', e, stackTrace);
      return false;
    }
  }

  /// Checks if a key exists in shared preferences
  bool containsKey(String key) {
    try {
      return _prefs.containsKey(key);
    } catch (e, stackTrace) {
      _handleStorageError('containsKey', e, stackTrace);
      return false;
    }
  }

  /// Saves an integer value to shared preferences
  /// This is a convenience method that uses the generic [write] method
  Future<bool> saveInt(String key, int value) async {
    return await write(key: key, value: value);
  }

  /// Retrieves an integer value from shared preferences
  /// This is a convenience method that uses the generic [read] method
  int getInt(String key, {int defaultValue = 0}) {
    final value = read<int>(key, defaultValue: defaultValue);
    if (value == null) return defaultValue;
    return value;
  }

  /// Saves a double value to shared preferences
  /// This is a convenience method that uses the generic [write] method
  Future<bool> saveDouble(String key, double value) async {
    return await write(key: key, value: value);
  }

  /// Retrieves a double value from shared preferences
  /// This is a convenience method that uses the generic [read] method
  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = read<double>(key, defaultValue: defaultValue);
    if (value == null) return defaultValue;
    return value;
  }
  
  /// Saves a boolean value to shared preferences
  /// This is a convenience method that uses the generic [write] method
  Future<bool> saveBool(String key, bool value) async {
    return await write(key: key, value: value);
  }

  /// Retrieves a boolean value from shared preferences
  /// This is a convenience method that uses the generic [read] method
  bool getBool(String key, {bool defaultValue = false}) {
    final value = read<bool>(key, defaultValue: defaultValue);
    if (value == null) return defaultValue;
    return value;
  }

  /// Saves a list of strings to shared preferences
  /// This is a convenience method that uses the generic [write] method
  Future<bool> saveStringList(String key, List<String> value) async {
    return await write(key: key, value: value);
  }

  /// Retrieves a list of strings from shared preferences
  /// This is a convenience method that uses the generic [read] method
  List<String> getStringList(String key, {List<String> defaultValue = const []}) {
    final value = read<List<String>>(key, defaultValue: defaultValue);
    if (value == null) return defaultValue;
    return value;
  }

  /// Saves an object (as JSON) to shared preferences
  /// This is a convenience method that uses the generic [write] method
  Future<bool> saveObject(String key, Map<String, dynamic> value) async {
    return await write(key: key, value: value);
  }

  /// Retrieves an object (from JSON) from shared preferences
  Map<String, dynamic>? getObject(String key) {
    return read<Map<String, dynamic>>(key);
  }

  /// Clears all data from shared preferences
  Future<bool> clear() async {
    try {
      return await _prefs.clear();
    } catch (e, stackTrace) {
      _handleStorageError('clear', e, stackTrace);
      return false;
    }
  }

  /// Clears all secure storage
  Future<bool> clearSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
      return true;
    } catch (e, stackTrace) {
      _handleStorageError('clearSecureStorage', e, stackTrace);
      return false;
    }
  }

  /// Clears all data (both secure and non-secure)
  Future<bool> clearAll() async {
    try {
      await clear();
      await clearSecureStorage();
      return true;
    } catch (e, stackTrace) {
      _handleStorageError('clearAll', e, stackTrace);
      return false;
    }
  }

  void _handleStorageError(
    String method,
    dynamic error,
    StackTrace stackTrace,
  ) {
    _logger.severe(
      'Storage error in $method: ${error.toString()}',
      error,
      stackTrace,
    );
    throw StorageException(
      message: 'Storage operation failed: $method',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
