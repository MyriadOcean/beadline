import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

/// Storage for application settings
/// Uses platform-appropriate storage locations
class SettingsStorage {
  static const String _settingsFileName = 'settings.json';

  /// Get the settings file path
  Future<String> _getSettingsFilePath() async {
    final directory = await _getSettingsDirectory();
    return path.join(directory.path, _settingsFileName);
  }

  /// Get the platform-appropriate settings directory
  Future<Directory> _getSettingsDirectory() async {
    Directory directory;

    if (Platform.isLinux) {
      // Linux: ~/.config/beadline/
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw Exception('HOME environment variable not set');
      }
      directory = Directory(path.join(home, '.config', 'beadline'));
    } else if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/beadline/
      final appSupport = await getApplicationSupportDirectory();
      directory = Directory(path.join(appSupport.path, 'beadline'));
    } else if (Platform.isWindows) {
      // Windows: %APPDATA%\beadline\
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw Exception('APPDATA environment variable not set');
      }
      directory = Directory(path.join(appData, 'beadline'));
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Android/iOS: App-specific storage
      directory = await getApplicationSupportDirectory();
    } else {
      // Fallback to application support directory
      directory = await getApplicationSupportDirectory();
    }

    // Create directory if it doesn't exist
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  /// Load settings from storage
  Future<AppSettings> loadSettings() async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);

      if (!file.existsSync()) {
        // Return default settings if file doesn't exist
        return AppSettings.defaults();
      }

      final jsonString = await file.readAsString();
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return AppSettings.fromJson(jsonMap);
    } catch (e) {
      // Return default settings on error
      return AppSettings.defaults();
    }
  }

  /// Save settings to storage
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final filePath = await _getSettingsFilePath();
      final file = File(filePath);

      // Ensure directory exists
      await file.parent.create(recursive: true);

      // Convert settings to JSON and write to file
      final jsonMap = settings.toJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      await file.writeAsString(jsonString);
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }

  /// Check if settings file exists
  Future<bool> settingsExist() async {
    final filePath = await _getSettingsFilePath();
    final file = File(filePath);
    return file.existsSync();
  }

  /// Delete settings file
  Future<void> deleteSettings() async {
    final filePath = await _getSettingsFilePath();
    final file = File(filePath);

    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Get the settings directory path
  Future<String> getSettingsDirectoryPath() async {
    final directory = await _getSettingsDirectory();
    return directory.path;
  }

  /// Backup settings to a specific location
  Future<void> backupSettings(String backupPath) async {
    final filePath = await _getSettingsFilePath();
    final file = File(filePath);

    if (file.existsSync()) {
      await file.copy(backupPath);
    }
  }

  /// Restore settings from a backup
  Future<void> restoreSettings(String backupPath) async {
    final backupFile = File(backupPath);

    if (!backupFile.existsSync()) {
      throw Exception('Backup file does not exist: $backupPath');
    }

    // Validate the backup file by trying to parse it
    final jsonString = await backupFile.readAsString();
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final settings = AppSettings.fromJson(jsonMap);

    // If validation succeeds, save the settings
    await saveSettings(settings);
  }

  /// Migrate settings from old location (if needed)
  Future<void> migrateSettings(String oldPath) async {
    final oldFile = File(oldPath);

    if (!oldFile.existsSync()) {
      return; // Nothing to migrate
    }

    try {
      // Read old settings
      final jsonString = await oldFile.readAsString();
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final settings = AppSettings.fromJson(jsonMap);

      // Save to new location
      await saveSettings(settings);

      // Delete old file
      await oldFile.delete();
    } catch (e) {
      // If migration fails, leave old file in place
      throw Exception('Failed to migrate settings: $e');
    }
  }
}
