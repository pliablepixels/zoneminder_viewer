import 'package:logging/logging.dart';

/// A utility class for application-wide logging
class LoggerUtil {
  static bool _isInitialized = false;

  /// Initialize the logging system
  static void initialize({Level level = Level.ALL}) {
    if (_isInitialized) return;

    // Configure the logging system
    Logger.root.level = level;

    // Setup the logger to output to the console
    Logger.root.onRecord.listen((record) {
      final time = record.time.toLocal().toString().split(' ')[1];
      final level = record.level.toString().split('.').last.padRight(7);
      final loggerName = record.loggerName.padRight(20);
      final message = '[$time] $level [$loggerName] ${record.message}';
      
      // Print the log message
      print(message);
      
      // Print the error and stack trace if available
      if (record.error != null) {
        print('Error: ${record.error}');
      }
      
      if (record.stackTrace != null) {
        print('Stack trace: ${record.stackTrace}');
      }
    });

    _isInitialized = true;
  }

  /// Get a logger for a specific class
  static Logger getLogger(String name) {
    if (!_isInitialized) {
      initialize();
    }
    return Logger(name);
  }

  /// Get a logger for a specific type
  static Logger getTypeLogger<T>() {
    return getLogger(T.toString());
  }
}

/// Extension to easily get a logger for a class
extension LoggerExtension on Object {
  Logger get logger => LoggerUtil.getLogger(runtimeType.toString());
}
