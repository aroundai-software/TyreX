
// lib/utils/app_exceptions.dart

/// Base class for all application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

/// Authentication and authorization exceptions
class AuthenticationException extends AppException {
  AuthenticationException(super.message, {super.code, super.originalError});
}

/// Data validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(super.message,
      {this.fieldErrors, super.code, super.originalError});
}

/// Database and storage exceptions
class FileStorageException extends AppException {
  FileStorageException(
      super.message, {
        super.code,
        super.originalError,
      });
}

/// Business logic exceptions
class BusinessLogicException extends AppException {
  BusinessLogicException(super.message, {super.code, super.originalError});
}

/// Not found exceptions
class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code, super.originalError});
}

/// Permission denied exceptions
class PermissionDeniedException extends AppException {
  PermissionDeniedException(super.message, {super.code, super.originalError});
}

/// Helper class to convert common errors to AppExceptions
class ExceptionHandler {
  static AppException handleError(dynamic error) {
    if (error is AppException) {
      return error;
    }

    // Handle common Supabase errors
    if (error.toString().contains('Failed host lookup') ||
        error.toString().contains('SocketException')) {
      return NetworkException(
        'No internet connection. Please check your network.',
        originalError: error,
      );
    }

    if (error.toString().contains('timeout')) {
      return NetworkException(
        'Connection timeout. Please try again.',
        originalError: error,
      );
    }

    if (error.toString().contains('401') || error.toString().contains('Unauthorized')) {
      return AuthenticationException(
        'Authentication failed. Please login again.',
        originalError: error,
      );
    }

    if (error.toString().contains('403') || error.toString().contains('Forbidden')) {
      return PermissionDeniedException(
        'You do not have permission to perform this action.',
        originalError: error,
      );
    }

    if (error.toString().contains('404') || error.toString().contains('Not found')) {
      return NotFoundException(
        'The requested resource was not found.',
        originalError: error,
      );
    }

    return BusinessLogicException(
      'An unexpected error occurred: ${error.toString()}',
      originalError: error,
    );
  }
}