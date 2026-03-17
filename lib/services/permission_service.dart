import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling platform-specific permissions
class PermissionService {
  /// Request storage permissions for mobile platforms
  ///
  /// Returns true if permissions are granted or not needed (desktop platforms)
  Future<bool> requestStoragePermissions() async {
    // Desktop platforms don't need storage permissions
    if (!_isMobilePlatform()) {
      return true;
    }

    try {
      // For Android 13+ (API 33+), we need different permissions
      if (Platform.isAndroid) {
        // Check Android version
        final androidInfo = await _getAndroidVersion();

        if (androidInfo >= 33) {
          // Android 13+ uses scoped storage
          // Request photos, videos, and audio permissions
          final statuses = await [
            Permission.photos,
            Permission.videos,
            Permission.audio,
          ].request();

          final mediaGranted = statuses.values.every(
            (status) => status.isGranted || status.isLimited,
          );

          // Also request MANAGE_EXTERNAL_STORAGE for reading config files
          // (beadline-*.json) alongside media files
          final manageGranted = await requestManageExternalStorage();

          return mediaGranted && manageGranted;
        } else {
          // Android 12 and below
          final status = await Permission.storage.request();
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        // iOS uses photo library permission
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      }

      return false;
    } catch (e) {
      debugPrint('PermissionService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission on Android.
  ///
  /// This is needed to read non-media files (beadline-*.json entry points)
  /// in user-selected library locations. On Android 11+, media-only
  /// permissions don't cover JSON files.
  ///
  /// Returns true if granted, already granted, or not applicable.
  Future<bool> requestManageExternalStorage() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        debugPrint('PermissionService: MANAGE_EXTERNAL_STORAGE already granted');
        return true;
      }

      debugPrint('PermissionService: Requesting MANAGE_EXTERNAL_STORAGE');
      final result = await Permission.manageExternalStorage.request();
      debugPrint('PermissionService: MANAGE_EXTERNAL_STORAGE result: $result');
      return result.isGranted;
    } catch (e) {
      debugPrint(
        'PermissionService: Error requesting MANAGE_EXTERNAL_STORAGE: $e',
      );
      return false;
    }
  }

  /// Check if the app has full file access (MANAGE_EXTERNAL_STORAGE)
  Future<bool> hasManageExternalStorage() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Check if storage permissions are granted
  Future<bool> hasStoragePermissions() async {
    if (!_isMobilePlatform()) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();

        if (androidInfo >= 33) {
          // Check if any of the media permissions are granted
          final photos = await Permission.photos.status;
          final videos = await Permission.videos.status;
          final audio = await Permission.audio.status;

          return photos.isGranted ||
              photos.isLimited ||
              videos.isGranted ||
              videos.isLimited ||
              audio.isGranted ||
              audio.isLimited;
        } else {
          final status = await Permission.storage.status;
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.status;
        return status.isGranted || status.isLimited;
      }

      return false;
    } catch (e) {
      debugPrint('PermissionService: Error checking permissions: $e');
      return false;
    }
  }

  /// Open app settings to allow user to grant permissions manually
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Check if running on a mobile platform
  bool _isMobilePlatform() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Get Android SDK version
  /// Returns 0 if not Android or unable to determine
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      // This is a simplified version - in production you'd use device_info_plus
      // For now, assume Android 13+ to be safe
      return 33;
    } catch (e) {
      return 0;
    }
  }

  /// Show permission rationale dialog
  /// Returns true if user wants to proceed with permission request
  Future<bool> shouldShowPermissionRationale() async {
    if (!_isMobilePlatform()) {
      return false;
    }

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        return status.isPermanentlyDenied;
      } else if (Platform.isIOS) {
        final status = await Permission.photos.status;
        return status.isPermanentlyDenied;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS handles this automatically
    }

    try {
      final androidInfo = await _getAndroidVersion();

      if (androidInfo >= 33) {
        // Android 13+ requires explicit notification permission
        final status = await Permission.notification.request();
        debugPrint(
          'PermissionService: Notification permission status: $status',
        );
        return status.isGranted;
      }

      // Android 12 and below don't need explicit permission
      return true;
    } catch (e) {
      debugPrint(
        'PermissionService: Error requesting notification permission: $e',
      );
      return false;
    }
  }
}
