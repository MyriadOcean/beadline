import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized error handling for the application
/// Provides user-friendly error messages and recovery strategies
class ErrorHandler {
  /// Convert an exception to a user-friendly error message
  static String getUserFriendlyMessage(Object error) {
    if (error is AppException) {
      return error.userMessage;
    }

    final errorString = error.toString();

    // Database errors
    if (errorString.contains('database') ||
        errorString.contains('sqlite') ||
        errorString.contains('SQLITE')) {
      return 'Database error. Please try again or restart the app.';
    }

    // File system errors
    if (errorString.contains('FileSystemException') ||
        errorString.contains('PathNotFoundException')) {
      return 'File not found or inaccessible. Please check the file path.';
    }

    // Permission errors
    if (errorString.contains('Permission') ||
        errorString.contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    }

    // Network errors
    if (errorString.contains('SocketException') ||
        errorString.contains('Connection') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your connection.';
    }

    // Format errors
    if (errorString.contains('FormatException')) {
      return 'Invalid data format. The file may be corrupted.';
    }

    // Generic fallback
    if (kDebugMode) {
      return errorString;
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Log an error for debugging
  static void logError(Object error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Execute an async operation with error handling
  static Future<T?> runSafe<T>(
    Future<T> Function() operation, {
    void Function(String message)? onError,
    T? defaultValue,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      logError(e, stackTrace);
      onError?.call(getUserFriendlyMessage(e));
      return defaultValue;
    }
  }

  /// Execute a sync operation with error handling
  static T? runSafeSync<T>(
    T Function() operation, {
    void Function(String message)? onError,
    T? defaultValue,
  }) {
    try {
      return operation();
    } catch (e, stackTrace) {
      logError(e, stackTrace);
      onError?.call(getUserFriendlyMessage(e));
      return defaultValue;
    }
  }
}

/// Base exception class for application-specific errors
class AppException implements Exception {
  const AppException({
    required this.message,
    String? userMessage,
    this.originalError,
  }) : userMessage = userMessage ?? message;
  final String message;
  final String userMessage;
  final Object? originalError;

  @override
  String toString() => message;
}

/// Exception for library operations
class LibraryException extends AppException {
  const LibraryException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}

/// Exception for playback operations
class PlaybackException extends AppException {
  const PlaybackException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}

/// Exception for tag operations
class TagException extends AppException {
  const TagException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}

/// Exception for search operations
class SearchException extends AppException {
  const SearchException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}

/// Exception for import/export operations
class ImportExportException extends AppException {
  const ImportExportException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}

/// Exception for settings operations
class SettingsException extends AppException {
  const SettingsException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}

/// Exception for validation errors
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.userMessage,
    super.originalError,
  });
}
