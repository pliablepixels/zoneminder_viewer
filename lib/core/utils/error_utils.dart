import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../errors/app_exceptions.dart';

/// A utility class for handling and displaying errors in a user-friendly way
class ErrorUtils {
  static final Logger _logger = Logger('ErrorUtils');

  /// Shows a snackbar with the error message
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
      ),
    );
  }

  /// Handles an error by logging it and showing a user-friendly message
  static void handleError(
    BuildContext context, {
    required dynamic error,
    StackTrace? stackTrace,
    String? defaultMessage,
    bool showSnackBar = true,
  }) {
    final appException = _convertToAppException(error, stackTrace);
    
    // Log the error
    _logError(appException);
    
    // Show error to user if needed
    if (showSnackBar && context.mounted) {
      showErrorSnackBar(
        context,
        message: appException.message,
      );
    }
  }

  /// Converts any error to an AppException
  static AppException _convertToAppException(
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    if (error is AppException) {
      return error;
    }
    
    final errorString = error.toString().toLowerCase();
    
    // Handle common error patterns
    if (errorString.contains('connection') || 
        errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('host lookup')) {
      return NetworkException(
        message: 'No internet connection. Please check your network settings.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
      );
    }
    
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return TimeoutException(
        message: 'Request timed out. Please try again.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
      );
    }
    
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return AuthException(
        message: 'Authentication failed. Please log in again.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
        code: 'unauthorized',
      );
    }
    
    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return PermissionDeniedException(
        message: 'You do not have permission to perform this action.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
        code: 'forbidden',
      );
    }
    
    if (errorString.contains('404') || errorString.contains('not found')) {
      return NotFoundException(
        message: 'The requested resource was not found.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
        code: 'not_found',
      );
    }
    
    if (errorString.contains('409') || errorString.contains('conflict')) {
      return ConflictException(
        message: 'A conflict occurred while processing your request.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
        code: 'conflict',
      );
    }
    
    if (errorString.contains('500') || 
        errorString.contains('server') || 
        errorString.contains('internal error')) {
      return ServerException(
        message: 'A server error occurred. Please try again later.',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
        code: 'server_error',
      );
    }
    
    // Default to unexpected error
    return UnexpectedException(
      message: defaultMessage ?? 'An unexpected error occurred. Please try again.',
      stackTrace: stackTrace ?? StackTrace.current,
      error: error,
    );
  }

  /// Logs the error with appropriate level
  static void _logError(AppException exception) {
    final message = exception.toString();
    final error = exception.error;
    final stackTrace = exception.stackTrace;
    
    if (exception is NetworkException || 
        exception is TimeoutException ||
        exception is AuthException) {
      _logger.warning(message, error, stackTrace);
    } else if (exception is ServerException ||
              exception is PermissionDeniedException) {
      _logger.severe(message, error, stackTrace);
    } else {
      _logger.severe(message, error, stackTrace);
    }
  }

  /// Shows a dialog with error details (for debugging)
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required dynamic error,
    StackTrace? stackTrace,
    String? actionText,
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) return;

    final appException = _convertToAppException(error, stackTrace);
    
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(appException.message),
              const SizedBox(height: 16),
              if (appException.error != null) ...[
                const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(appException.error.toString()),
                const SizedBox(height: 8),
              ],
              if (appException.stackTrace != null) ...[
                const Text('Stack trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    appException.stackTrace.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionText),
            ),
        ],
      ),
    );
  }
}
