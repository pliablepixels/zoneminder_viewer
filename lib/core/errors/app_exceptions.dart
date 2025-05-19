import 'package:equatable/equatable.dart';

/// Base class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final dynamic error;
  final String? code;

  const AppException({
    required this.message,
    this.stackTrace,
    this.error,
    this.code,
  });

  @override
  String toString() => '[$runtimeType] $message${code != null ? ' (Code: $code)' : ''}';
}

/// Thrown when there's a network connectivity issue
class NetworkException extends AppException {
  const NetworkException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when there's an authentication or authorization issue
class AuthException extends AppException {
  const AuthException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when there's a server-side error
class ServerException extends AppException {
  const ServerException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
    this.statusCode,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );

  final int? statusCode;
}

/// Thrown when there's a timeout
class TimeoutException extends AppException {
  const TimeoutException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when there's a validation error
class ValidationException extends AppException {
  const ValidationException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
    this.errors = const {},
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );

  final Map<String, List<String>> errors;
}

/// Thrown when a requested resource is not found
class NotFoundException extends AppException {
  const NotFoundException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when there's a conflict with the current state of the target resource
class ConflictException extends AppException {
  const ConflictException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when the user doesn't have permission to access a resource
class PermissionDeniedException extends AppException {
  const PermissionDeniedException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when a feature is not implemented
class NotImplementedException extends AppException {
  const NotImplementedException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when there's a problem with the local storage
class StorageException extends AppException {
  const StorageException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Thrown when a platform-specific operation fails
class PlatformException extends AppException {
  const PlatformException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// A generic exception for unexpected errors
class UnexpectedException extends AppException {
  const UnexpectedException({
    required String message,
    StackTrace? stackTrace,
    dynamic error,
    String? code,
  }) : super(
          message: message,
          stackTrace: stackTrace,
          error: error,
          code: code,
        );
}

/// Extension to convert any error to an [AppException]
extension ErrorToAppException on Object {
  AppException toAppException([StackTrace? stackTrace]) {
    if (this is AppException) return this as AppException;
    
    final error = this;
    final errorString = error.toString();
    
    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid format: ${error.message}',
        stackTrace: stackTrace ?? StackTrace.current,
        error: error,
      );
    }
    
    // Handle other common error types here
    
    return UnexpectedException(
      message: 'An unexpected error occurred: $errorString',
      stackTrace: stackTrace ?? StackTrace.current,
      error: error,
    );
  }
}
