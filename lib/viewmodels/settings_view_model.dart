import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/configuration_mode.dart';
import '../models/online_provider_config.dart';
import '../repositories/settings_repository.dart';
import '../services/configuration_migration_service.dart';
import '../services/online_source_provider.dart';

/// ViewModel for application settings
/// Handles settings loading, updating, and persistence
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsRepository settingsRepository,
    ConfigurationMigrationService? migrationService,
    OnlineSourceProviderRegistry? onlineProviderRegistry,
  }) : _settingsRepository = settingsRepository,
       _migrationService = migrationService,
       _onlineProviderRegistry = onlineProviderRegistry {
    _setupListeners();
    // Load settings on startup
    _loadInitialSettings();
  }
  final SettingsRepository _settingsRepository;
  final ConfigurationMigrationService? _migrationService;
  final OnlineSourceProviderRegistry? _onlineProviderRegistry;

  AppSettings _settings = AppSettings.defaults();
  bool _isLoading = true; // Start as loading until initial settings are read
  bool _isMigrating = false;
  String? _error;
  String _migrationProgress = '';
  int _migrationCurrent = 0;
  int _migrationTotal = 0;
  StreamSubscription<SettingsEvent>? _eventSubscription;

  /// Load settings on startup
  Future<void> _loadInitialSettings() async {
    _isLoading = true;
    // Don't notifyListeners here — we're still in the constructor.
    // The first build will see isLoading=true and show a spinner.
    try {
      _settings = await _settingsRepository.loadSettings();
    } catch (e) {
      // Use defaults on error
      _settings = AppSettings.defaults();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Current settings
  AppSettings get settings => _settings;

  /// Library path
  String get libraryPath => _settings.libraryPath;

  /// Whether metadata write-back is enabled
  bool get metadataWriteBack => _settings.metadataWriteBack;

  /// Whether auto-discover audio files is enabled
  bool get autoDiscoverAudioFiles => _settings.autoDiscoverAudioFiles;

  /// Current lyrics mode
  LyricsMode get lyricsMode => _settings.lyricsMode;

  /// Current display mode
  DisplayMode get displayMode => _settings.displayMode;

  /// Whether KTV mode is enabled
  bool get ktvMode => _settings.ktvMode;

  /// Whether to hide the display panel
  bool get hideDisplayPanel => _settings.hideDisplayPanel;

  /// Whether to use thumbnail as background in library
  bool get useThumbnailBackgroundInLibrary =>
      _settings.useThumbnailBackgroundInLibrary;

  /// Whether to use thumbnail as background in queue
  bool get useThumbnailBackgroundInQueue =>
      _settings.useThumbnailBackgroundInQueue;

  /// Current theme mode
  String get themeMode => _settings.themeMode;

  /// Current language code
  String? get languageCode => _settings.languageCode;

  /// Current username
  String get username => _settings.username;

  /// Primary color seed
  int? get primaryColorSeed => _settings.primaryColorSeed;

  /// Configuration mode
  ConfigurationMode get configMode => _settings.configMode;

  /// Whether the initial configuration has been completed
  bool get isConfigured => _settings.isConfigured;

  /// Whether settings are loading
  bool get isLoading => _isLoading;

  /// Whether migration is in progress
  bool get isMigrating => _isMigrating;

  /// Migration progress message
  String get migrationProgress => _migrationProgress;

  /// Current migration item
  int get migrationCurrent => _migrationCurrent;

  /// Total migration items
  int get migrationTotal => _migrationTotal;

  /// Error message if any
  String? get error => _error;

  void _setupListeners() {
    _eventSubscription = _settingsRepository.events.listen(
      _onSettingsEvent,
      onError: _onSettingsError,
    );
  }

  void _onSettingsEvent(SettingsEvent event) {
    switch (event) {
      case SettingsUpdated(settings: final settings):
        _settings = settings;
        notifyListeners();
      case LibraryPathChanged():
        // Already handled by SettingsUpdated
        break;
      case ConfigurationModeChanged():
        // Already handled by SettingsUpdated
        break;
    }
  }

  void _onSettingsError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  /// Load settings from storage
  Future<void> loadSettings() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _settings = await _settingsRepository.loadSettings();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the library path with data migration
  Future<void> updateLibraryPath(String newPath) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _settingsRepository.updateLibraryPath(newPath);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set metadata write-back setting
  Future<void> setMetadataWriteBack(bool enabled) async {
    try {
      _error = null;
      await _settingsRepository.setMetadataWriteBack(enabled);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set auto-discover audio files setting
  Future<void> setAutoDiscoverAudioFiles(bool enabled) async {
    try {
      _error = null;
      final currentSettings = await _settingsRepository.loadSettings();
      final newSettings = currentSettings.copyWith(
        autoDiscoverAudioFiles: enabled,
      );
      await _settingsRepository.saveSettings(newSettings);

      // Trigger discovery immediately if enabled, or clear if disabled
      if (enabled) {
        await _onAutoDiscoverEnabled?.call();
      } else {
        await _onAutoDiscoverDisabled?.call();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Callback for when auto-discover is enabled (returns Future for async operations)
  Future<void> Function()? _onAutoDiscoverEnabled;

  /// Callback for when auto-discover is disabled (returns Future for async operations)
  Future<void> Function()? _onAutoDiscoverDisabled;

  /// Set callback for when auto-discover is enabled
  void setAutoDiscoverCallback(Future<void> Function() callback) {
    _onAutoDiscoverEnabled = callback;
  }

  /// Set callback for when auto-discover is disabled
  void setAutoDiscoverDisabledCallback(Future<void> Function() callback) {
    _onAutoDiscoverDisabled = callback;
  }

  /// Set lyrics mode
  /// Note: In KTV mode, only screen mode is allowed (floating and rolling are disabled)
  Future<void> setLyricsMode(LyricsMode mode) async {
    try {
      _error = null;

      // If KTV mode is enabled, only allow screen mode
      if (_settings.ktvMode &&
          (mode == LyricsMode.floating || mode == LyricsMode.rolling)) {
        _error = 'Only screen lyrics mode is allowed in KTV mode';
        notifyListeners();
        return;
      }

      await _settingsRepository.setLyricsMode(mode);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set display mode
  Future<void> setDisplayMode(DisplayMode mode) async {
    try {
      _error = null;
      await _settingsRepository.setDisplayMode(mode);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set KTV mode
  /// When enabled, forces lyrics mode to screen
  Future<void> setKtvMode(bool enabled) async {
    try {
      _error = null;
      await _settingsRepository.setKtvMode(enabled);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set hide display panel
  Future<void> setHideDisplayPanel(bool enabled) async {
    try {
      _error = null;
      await _settingsRepository.setHideDisplayPanel(enabled);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set use thumbnail background in library
  Future<void> setUseThumbnailBackgroundInLibrary(bool enabled) async {
    try {
      _error = null;
      final currentSettings = await _settingsRepository.loadSettings();
      final newSettings = currentSettings.copyWith(
        useThumbnailBackgroundInLibrary: enabled,
      );
      await _settingsRepository.saveSettings(newSettings);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set use thumbnail background in queue
  Future<void> setUseThumbnailBackgroundInQueue(bool enabled) async {
    try {
      _error = null;
      final currentSettings = await _settingsRepository.loadSettings();
      final newSettings = currentSettings.copyWith(
        useThumbnailBackgroundInQueue: enabled,
      );
      await _settingsRepository.saveSettings(newSettings);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(String mode) async {
    try {
      _error = null;
      await _settingsRepository.setThemeMode(mode);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set language code
  Future<void> setLanguageCode(String? code) async {
    try {
      _error = null;
      await _settingsRepository.setLanguageCode(code);
      _settings = _settings.copyWith(languageCode: code);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set username
  Future<void> setUsername(String username) async {
    try {
      _error = null;
      await _settingsRepository.setUsername(username);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set primary color seed
  Future<void> setPrimaryColorSeed(int? colorSeed) async {
    try {
      _error = null;
      await _settingsRepository.setPrimaryColorSeed(colorSeed);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Complete initial configuration with the selected mode
  /// This is called after the user completes the first-launch setup
  Future<void> completeInitialConfiguration(ConfigurationMode mode) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      final currentSettings = await _settingsRepository.loadSettings();
      final newSettings = currentSettings.copyWith(
        configMode: mode,
        isConfigured: true,
      );
      await _settingsRepository.saveSettings(newSettings);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set configuration mode
  Future<void> setConfigMode(ConfigurationMode mode) async {
    try {
      _error = null;
      final currentSettings = await _settingsRepository.loadSettings();
      final newSettings = currentSettings.copyWith(configMode: mode);
      await _settingsRepository.saveSettings(newSettings);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Change configuration mode with migration
  /// This handles migrating entry point files when switching between modes
  /// Requirements: 3.5
  ///
  /// Parameters:
  /// - [newMode]: The new configuration mode to switch to
  ///
  /// Returns true if the mode change was successful, false otherwise.
  Future<bool> changeConfigurationModeWithMigration(
    ConfigurationMode newMode,
  ) async {
    if (_migrationService == null) {
      // No migration service available, just update the setting
      return _changeConfigModeWithoutMigration(newMode);
    }

    try {
      _error = null;
      _isMigrating = true;
      _migrationProgress = 'Starting migration...';
      _migrationCurrent = 0;
      _migrationTotal = 0;
      notifyListeners();

      // Clear cache to ensure we get fresh settings
      _settingsRepository.clearCache();
      final currentSettings = await _settingsRepository.loadSettings();
      final oldMode = currentSettings.configMode;

      if (oldMode == newMode) {
        _isMigrating = false;
        notifyListeners();
        return true;
      }

      // Perform the migration with progress updates
      final success = await _migrationService.migrateEntryPoints(
        fromMode: oldMode,
        toMode: newMode,
        libraryLocations: currentSettings.libraryLocations,
        onProgress: (current, total, message) {
          _migrationCurrent = current;
          _migrationTotal = total;
          _migrationProgress = message;
          notifyListeners();
        },
      );

      if (!success) {
        _error = 'Migration failed';
        _isMigrating = false;
        notifyListeners();
        return false;
      }

      // Update the configuration mode in settings
      final newSettings = currentSettings.copyWith(configMode: newMode);
      await _settingsRepository.saveSettings(newSettings);

      // Explicitly update local state to ensure UI reflects the change
      _settings = newSettings;
      _isMigrating = false;
      _migrationProgress = '';
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isMigrating = false;
      notifyListeners();
      return false;
    }
  }

  /// Change config mode without migration (fallback when no migration service)
  Future<bool> _changeConfigModeWithoutMigration(
    ConfigurationMode newMode,
  ) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      final currentSettings = await _settingsRepository.loadSettings();
      final newSettings = currentSettings.copyWith(configMode: newMode);
      await _settingsRepository.saveSettings(newSettings);
      _settings = newSettings;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get configured online providers
  Future<List<OnlineProviderConfig>> getOnlineProviders() async {
    try {
      return await _settingsRepository.getOnlineProviders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Save online provider configuration
  Future<void> saveOnlineProvider(OnlineProviderConfig provider) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _settingsRepository.saveOnlineProvider(provider);
      _settings = await _settingsRepository.loadSettings();

      // Update the registry with the new provider configuration
      _onlineProviderRegistry?.updateProvider(provider);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove online provider configuration
  Future<void> removeOnlineProvider(String providerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _settingsRepository.removeOnlineProvider(providerId);
      _settings = await _settingsRepository.loadSettings();

      // Remove provider from registry by updating with a disabled config
      _onlineProviderRegistry?.updateProvider(
        OnlineProviderConfig(
          providerId: providerId,
          displayName: '',
          baseUrl: '',
          enabled: false,
        ),
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle online provider enabled status
  Future<void> setOnlineProviderEnabled(String providerId, bool enabled) async {
    try {
      await _settingsRepository.setOnlineProviderEnabled(providerId, enabled);
      _settings = await _settingsRepository.loadSettings();

      // Get the updated provider config and update registry
      final providers = await _settingsRepository.getOnlineProviders();
      final provider = providers.firstWhere(
        (p) => p.providerId == providerId,
        orElse: () => OnlineProviderConfig(
          providerId: providerId,
          displayName: '',
          baseUrl: '',
          enabled: false,
        ),
      );
      _onlineProviderRegistry?.updateProvider(provider);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Test connection to an online provider
  Future<bool> testOnlineProviderConnection(OnlineProviderConfig config) async {
    try {
      // Create a temporary provider instance to test
      final registry = OnlineSourceProviderRegistry(configs: [config]);
      final provider = registry.getProvider(config.providerId);

      if (provider == null) return false;

      return await provider.testConnection();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reset all settings to factory defaults
  /// This clears all user preferences and returns to default state
  Future<void> resetToFactory() async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      await _settingsRepository.resetToFactory();
      _settings = AppSettings.defaults();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
