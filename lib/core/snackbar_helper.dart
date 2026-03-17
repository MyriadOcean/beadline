import 'package:flutter/material.dart';

/// Helper class for showing minimal, non-intrusive notifications
/// Most success/info messages should be removed - only show critical errors
class SnackBarHelper {
  SnackBarHelper._();

  /// Show a critical error message only (2 seconds, top-right corner)
  /// Use sparingly - only for errors that require user attention
  static void showError(BuildContext context, String message) {
    // Remove any existing SnackBars first
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: Colors.red.shade700,
        margin: const EdgeInsets.only(
          bottom: 80, // Above player controls
          right: 20,
          left: 20,
        ),
      ),
    );
  }
}
