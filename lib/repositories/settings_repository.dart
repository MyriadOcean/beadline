import 'dart:async';

import '../data/file_system_service.dart';
import '../data/settings_storage.dart';
import '../models/app_settings.dart';
import '../models/configuration_mode.dart';
import '../models/online_provider_config.dart';

/// Events emitted by the SettingsRepository
sealed class SettingsEvent {
  const SettingsEvent();
}

/// Event emitted when settings are updated
class SettingsUpdated extends SettingsEvent {
  const SettingsUpdated(this.settings);
  final AppSettings settings;
}

/// Event emitted when library path is changed
class LibraryPathChanged extends SettingsEvent {
  const LibraryPathChanged(this.oldPath, this.newPath);
  final String oldPath;
  final String newPath;
}

/// Event emitted when configuration mode is changed
class ConfigurationModeChanged extends SettingsEvent {
  const ConfigurationModeChanged(this.oldMode, this.newMode);
  final ConfigurationMode oldMode;
  final ConfigurationMode newMode;
}

/// Repository for managing application settings
class SettingsRepository {
  SettingsRepository(this._storage, this._fileSystem);
  final SettingsStorage _storage;
  final FileSystemService _fileSystem;
  final StreamController<SettingsEvent> _eventController =
      StreamController<SettingsEvent>.broadcast();

  AppSettings? _cachedSettings;

  /// Stream of settings events for change notifications
  Stream<SettingsEvent> get events => _eventController.stream;

  /// Load settings from storage
  /// Returns cached settings if available
  Future<AppSettings> loadSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    _cachedSettings = await _storage.loadSettings();
    return _cachedSettings!;
  }

  /// Save settings to storage
  /// Persists immediately and emits a SettingsUpdated event
  Future<void> saveSettings(AppSettings settings) async {
    await _storage.saveSettings(settings);
    _cachedSettings = settings;
    _eventController.add(SettingsUpdated(settings));
  }

  /// Update a single setting
  Future<void> updateSetting<T>({
    required T value,
    required AppSettings Function(AppSettings, T) updater,
  }) async {
    final currentSettings = await loadSettings();
    final newSettings = updater(currentSettings, value);
    await saveSettings(newSettings);
  }

  /// Update the library path with data migration
  /// Copies all data to the new location and clears the old location
  Future<void> updateLibraryPath(String newPath) async {
    final currentSettings = await loadSettings();
    final oldPath = currentSettings.libraryPath;

    if (oldPath == newPath) {
      return; // No change needed
    }

    // If old path is not empty, migrate data
    if (oldPath.isNotEmpty) {
      await _migrateLibraryData(oldPath, newPath);
    }

    // Update settings with new path
    final newSettings = currentSettings.copyWith(libraryPath: newPath);
    await saveSettings(newSettings);

    _eventController.add(LibraryPathChanged(oldPath, newPath));
  }

  /// Migrate library data from old path to new path
  Future<void> _migrateLibraryData(String oldPath, String newPath) async {
    // Check if old path exists
    if (!await _fileSystem.directoryExists(oldPath)) {
      return; // Nothing to migrate
    }

    // Create new directory if it doesn't exist
    await _fileSystem.createDirectory(newPath);

    // Copy all data from old path to new path
    await _fileSystem.copyDirectory(oldPath, newPath);

    // Delete old directory
    await _fileSystem.deleteDirectory(oldPath, recursive: true);
  }

  /// Set metadata write-back setting
  Future<void> setMetadataWriteBack(bool enabled) async {
    await updateSetting(
      value: enabled,
      updater: (settings, value) => settings.copyWith(metadataWriteBack: value),
    );
  }

  /// Set lyrics mode
  Future<void> setLyricsMode(LyricsMode mode) async {
    await updateSetting(
      value: mode,
      updater: (settings, value) => settings.copyWith(lyricsMode: value),
    );
  }

  /// Set display mode
  Future<void> setDisplayMode(DisplayMode mode) async {
    await updateSetting(
      value: mode,
      updater: (settings, value) => settings.copyWith(displayMode: value),
    );
  }

  /// Set KTV mode
  /// When KTV mode is enabled, lyrics mode is forced to screen
  Future<void> setKtvMode(bool enabled) async {
    final currentSettings = await loadSettings();
    var newSettings = currentSettings.copyWith(ktvMode: enabled);

    // If KTV mode is enabled, force lyrics mode to screen
    if (enabled && newSettings.lyricsMode != LyricsMode.screen) {
      newSettings = newSettings.copyWith(lyricsMode: LyricsMode.screen);
    }

    await saveSettings(newSettings);
  }

  /// Set hide display panel
  Future<void> setHideDisplayPanel(bool enabled) async {
    await updateSetting(
      value: enabled,
      updater: (settings, value) => settings.copyWith(hideDisplayPanel: value),
    );
  }

  /// Set theme mode
  Future<void> setThemeMode(String mode) async {
    await updateSetting(
      value: mode,
      updater: (settings, value) => settings.copyWith(themeMode: value),
    );
  }

  /// Set language code (null = use device locale / system default)
  Future<void> setLanguageCode(String? code) async {
    final current = await loadSettings();
    // Use copyWith with explicit null to clear languageCode when code is null
    final updated = current.copyWith(languageCode: code);
    await saveSettings(updated);
  }

  /// Set username
  Future<void> setUsername(String username) async {
    await updateSetting(
      value: username,
      updater: (settings, value) => settings.copyWith(username: value),
    );
  }

  /// Set primary color seed
  Future<void> setPrimaryColorSeed(int? colorSeed) async {
    await updateSetting(
      value: colorSeed,
      updater: (settings, value) => settings.copyWith(primaryColorSeed: value),
    );
  }

  /// Change configuration mode with migration
  /// When switching modes, this method handles migrating entry point files
  /// Requirements: 3.5
  ///
  /// Parameters:
  /// - [newMode]: The new configuration mode to switch to
  /// - [migrateEntryPoints]: Callback function to perform the actual migration
  ///   This is provided by the caller (typically SettingsViewModel) which has
  ///   access to the necessary services (LibraryRepository, EntryPointFileService, etc.)
  ///
  /// The migration callback receives:
  /// - [oldMode]: The previous configuration mode
  /// - [newMode]: The new configuration mode
  /// - [libraryLocations]: The list of configured library locations
  ///
  /// Returns true if migration was successful, false otherwise.
  Future<bool> changeConfigurationMode(
    ConfigurationMode newMode, {
    Future<bool> Function(
      ConfigurationMode oldMode,
      ConfigurationMode newMode,
      List<dynamic> libraryLocations,
    )?
    migrateEntryPoints,
  }) async {
    final currentSettings = await loadSettings();
    final oldMode = currentSettings.configMode;

    if (oldMode == newMode) {
      return true; // No change needed
    }

    // Perform migration if callback is provided
    if (migrateEntryPoints != null) {
      final success = await migrateEntryPoints(
        oldMode,
        newMode,
        currentSettings.libraryLocations,
      );
      if (!success) {
        return false;
      }
    }

    // Update settings with new mode
    final newSettings = currentSettings.copyWith(configMode: newMode);
    await saveSettings(newSettings);

    _eventController.add(ConfigurationModeChanged(oldMode, newMode));
    return true;
  }

  /// Clear cached settings (useful for testing)
  void clearCache() {
    _cachedSettings = null;
  }

  /// Reset all settings to factory defaults
  /// This clears all user preferences and returns to default state
  Future<void> resetToFactory() async {
    final defaultSettings = AppSettings.defaults();
    await _storage.saveSettings(defaultSettings);
    _cachedSettings = defaultSettings;
    _eventController.add(SettingsUpdated(defaultSettings));
  }

  /// Get configured online providers
  Future<List<OnlineProviderConfig>> getOnlineProviders() async {
    final settings = await loadSettings();
    return settings.onlineProviders;
  }

  /// Add or update an online provider configuration
  Future<void> saveOnlineProvider(OnlineProviderConfig provider) async {
    final settings = await loadSettings();
    final providers = List<OnlineProviderConfig>.from(settings.onlineProviders)
      // Remove existing provider with same ID
      ..removeWhere((p) => p.providerId == provider.providerId)
      // Add new/updated provider
      ..add(provider);

    final newSettings = settings.copyWith(onlineProviders: providers);
    await saveSettings(newSettings);
  }

  /// Remove an online provider configuration
  Future<void> removeOnlineProvider(String providerId) async {
    final settings = await loadSettings();
    final providers = settings.onlineProviders
        .where((p) => p.providerId != providerId)
        .toList();

    final newSettings = settings.copyWith(onlineProviders: providers);
    await saveSettings(newSettings);
  }

  /// Update online provider enabled status
  Future<void> setOnlineProviderEnabled(String providerId, bool enabled) async {
    final settings = await loadSettings();
    final providers = settings.onlineProviders.map((p) {
      if (p.providerId == providerId) {
        return p.copyWith(enabled: enabled);
      }
      return p;
    }).toList();

    final newSettings = settings.copyWith(onlineProviders: providers);
    await saveSettings(newSettings);
  }

  /// Get the active queue ID
  /// Returns 'default' if not set
  Future<String> getActiveQueueId() async {
    final settings = await loadSettings();
    return settings.activeQueueId ?? 'default';
  }

  /// Set the active queue ID
  Future<void> setActiveQueueId(String queueId) async {
    await updateSetting(
      value: queueId,
      updater: (settings, value) => settings.copyWith(activeQueueId: value),
    );
  }

  /// Dispose of resources
  void dispose() {
    _eventController.close();
  }
}
