import 'dart:async';
import 'dart:math';

import 'package:beadline/models/app_settings.dart';
import 'package:beadline/models/configuration_mode.dart';
import 'package:beadline/models/online_provider_config.dart';
import 'package:beadline/repositories/settings_repository.dart';
import 'package:beadline/viewmodels/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory settings storage for testing
class InMemorySettingsStorage {
  AppSettings _settings = AppSettings.defaults();

  AppSettings get settings => _settings;

  void save(AppSettings settings) {
    _settings = settings;
  }

  void clear() {
    _settings = AppSettings.defaults();
  }
}

/// Mock SettingsRepository for testing
class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository(this._storage);
  final InMemorySettingsStorage _storage;
  final StreamController<SettingsEvent> _eventController =
      StreamController<SettingsEvent>.broadcast();

  AppSettings? _cachedSettings;
  String _activeQueueId = 'default';

  @override
  Stream<SettingsEvent> get events => _eventController.stream;

  @override
  Future<String> getActiveQueueId() async => _activeQueueId;

  @override
  Future<void> setActiveQueueId(String queueId) async {
    _activeQueueId = queueId;
  }

  @override
  Future<List<OnlineProviderConfig>> getOnlineProviders() async => [];

  @override
  Future<void> saveOnlineProvider(OnlineProviderConfig provider) async {}

  @override
  Future<void> removeOnlineProvider(String providerId) async {}

  @override
  Future<void> setOnlineProviderEnabled(
    String providerId,
    bool enabled,
  ) async {}

  @override
  Future<AppSettings> loadSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }
    _cachedSettings = _storage.settings;
    return _cachedSettings!;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _storage.save(settings);
    _cachedSettings = settings;
    _eventController.add(SettingsUpdated(settings));
  }

  @override
  Future<void> updateSetting<T>({
    required T value,
    required AppSettings Function(AppSettings, T) updater,
  }) async {
    final currentSettings = await loadSettings();
    final newSettings = updater(currentSettings, value);
    await saveSettings(newSettings);
  }

  @override
  Future<void> updateLibraryPath(String newPath) async {
    final currentSettings = await loadSettings();
    final oldPath = currentSettings.libraryPath;

    if (oldPath == newPath) return;

    final newSettings = currentSettings.copyWith(libraryPath: newPath);
    await saveSettings(newSettings);
    _eventController.add(LibraryPathChanged(oldPath, newPath));
  }

  @override
  Future<void> setMetadataWriteBack(bool enabled) async {
    await updateSetting(
      value: enabled,
      updater: (settings, value) => settings.copyWith(metadataWriteBack: value),
    );
  }

  @override
  Future<void> setDisplayMode(DisplayMode mode) async {
    await updateSetting(
      value: mode,
      updater: (settings, value) => settings.copyWith(displayMode: value),
    );
  }

  @override
  Future<void> setLyricsMode(LyricsMode mode) async {
    await updateSetting(
      value: mode,
      updater: (settings, value) => settings.copyWith(lyricsMode: value),
    );
  }

  @override
  Future<void> setKtvMode(bool enabled) async {
    final currentSettings = await loadSettings();
    var newSettings = currentSettings.copyWith(ktvMode: enabled);

    // If KTV mode is enabled, force lyrics mode to screen
    if (enabled && newSettings.lyricsMode != LyricsMode.screen) {
      newSettings = newSettings.copyWith(lyricsMode: LyricsMode.screen);
    }

    await saveSettings(newSettings);
  }

  @override
  Future<void> setHideDisplayPanel(bool enabled) async {
    await updateSetting(
      value: enabled,
      updater: (settings, value) => settings.copyWith(hideDisplayPanel: value),
    );
  }

  @override
  Future<void> setThemeMode(String mode) async {
    await updateSetting(
      value: mode,
      updater: (settings, value) => settings.copyWith(themeMode: value),
    );
  }

  @override
  Future<void> setLanguageCode(String? code) async {
    await updateSetting(
      value: code,
      updater: (settings, value) => settings.copyWith(languageCode: value),
    );
  }

  @override
  Future<void> setUsername(String username) async {
    await updateSetting(
      value: username,
      updater: (settings, value) => settings.copyWith(username: value),
    );
  }

  @override
  Future<void> setPrimaryColorSeed(int? colorSeed) async {
    await updateSetting(
      value: colorSeed,
      updater: (settings, value) => settings.copyWith(primaryColorSeed: value),
    );
  }

  @override
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
      return true;
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

  @override
  void clearCache() {
    _cachedSettings = null;
  }

  @override
  Future<void> resetToFactory() async {
    final defaultSettings = AppSettings.defaults();
    _storage.save(defaultSettings);
    _cachedSettings = defaultSettings;
    _eventController.add(SettingsUpdated(defaultSettings));
  }

  @override
  void dispose() {
    _eventController.close();
  }
}

/// Test generators for settings tests
class SettingsTestGenerators {
  static final Random _random = Random();

  static String randomString({int minLength = 3, int maxLength = 15}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  static String randomPath() {
    return '/path/to/${randomString()}/${randomString()}';
  }

  static LyricsMode randomLyricsMode() {
    return LyricsMode.values[_random.nextInt(LyricsMode.values.length)];
  }

  static LyricsMode randomNonFloatingLyricsMode() {
    final modes = [LyricsMode.off, LyricsMode.screen, LyricsMode.rolling];
    return modes[_random.nextInt(modes.length)];
  }
}

void main() {
  group('SettingsViewModel Property Tests', () {
    late InMemorySettingsStorage storage;
    late MockSettingsRepository settingsRepository;
    late SettingsViewModel viewModel;

    setUp(() async {
      storage = InMemorySettingsStorage();
      settingsRepository = MockSettingsRepository(storage);
      viewModel = SettingsViewModel(settingsRepository: settingsRepository);
      await viewModel.loadSettings();
    });

    tearDown(() {
      viewModel.dispose();
      settingsRepository.dispose();
      storage.clear();
    });

    // Feature: song-unit-core, Property 43: Metadata write-back correctness
    // **Validates: Requirements 14.4**
    // Note: This property tests that when write-back is enabled, the setting is correctly persisted.
    // The actual file modification is handled by a separate service, not the ViewModel.
    test(
      'Property 43: For any Song Unit with write-back enabled, changes to Built-in Tag values SHALL be reflected in the source file metadata (setting persistence)',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Enable metadata write-back
          await viewModel.setMetadataWriteBack(true);

          // Verify the setting is persisted
          final settings = await settingsRepository.loadSettings();
          expect(
            settings.metadataWriteBack,
            isTrue,
            reason: 'Metadata write-back should be enabled',
          );
          expect(
            viewModel.metadataWriteBack,
            isTrue,
            reason: 'ViewModel should reflect enabled write-back',
          );

          // Disable metadata write-back
          await viewModel.setMetadataWriteBack(false);

          // Verify the setting is persisted
          final updatedSettings = await settingsRepository.loadSettings();
          expect(
            updatedSettings.metadataWriteBack,
            isFalse,
            reason: 'Metadata write-back should be disabled',
          );
          expect(
            viewModel.metadataWriteBack,
            isFalse,
            reason: 'ViewModel should reflect disabled write-back',
          );
        }
      },
    );

    // Feature: song-unit-core, Property 44: Metadata write-back disabled invariant
    // **Validates: Requirements 14.5**
    test(
      'Property 44: For any Song Unit with write-back disabled, source file metadata SHALL remain unchanged regardless of tag modifications (setting invariant)',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Ensure write-back is disabled
          await viewModel.setMetadataWriteBack(false);

          // Verify the setting persists as disabled
          expect(
            viewModel.metadataWriteBack,
            isFalse,
            reason: 'Write-back should be disabled',
          );

          // Make other settings changes
          await viewModel.setThemeMode(Random().nextBool() ? 'light' : 'dark');
          await viewModel.setLanguageCode(
            SettingsTestGenerators.randomString(),
          );

          // Verify write-back is still disabled
          expect(
            viewModel.metadataWriteBack,
            isFalse,
            reason: 'Write-back should remain disabled after other changes',
          );

          final settings = await settingsRepository.loadSettings();
          expect(
            settings.metadataWriteBack,
            isFalse,
            reason: 'Persisted write-back should remain disabled',
          );
        }
      },
    );

    // Feature: song-unit-core, Property 45: KTV mode lyrics constraint
    // **Validates: Requirements 13.5**
    test(
      'Property 45: For any system state in KTV mode, the lyrics mode SHALL be forced to "screen" and "floating" SHALL be disabled',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Set a random initial lyrics mode
          final initialMode = SettingsTestGenerators.randomLyricsMode();
          await viewModel.setLyricsMode(initialMode);

          // Enable KTV mode
          await viewModel.setKtvMode(true);

          // Verify lyrics mode is forced to screen
          expect(
            viewModel.lyricsMode,
            equals(LyricsMode.screen),
            reason: 'Lyrics mode should be forced to screen in KTV mode',
          );
          expect(
            viewModel.ktvMode,
            isTrue,
            reason: 'KTV mode should be enabled',
          );

          // Try to set floating mode while in KTV mode
          await viewModel.setLyricsMode(LyricsMode.floating);

          // Verify floating mode is rejected
          expect(
            viewModel.lyricsMode,
            isNot(equals(LyricsMode.floating)),
            reason: 'Floating mode should be disabled in KTV mode',
          );

          // Verify error was set
          expect(
            viewModel.error,
            isNotNull,
            reason:
                'Error should be set when trying to enable floating in KTV mode',
          );

          viewModel.clearError();

          // Disable KTV mode
          await viewModel.setKtvMode(false);

          // Now floating mode should be allowed
          await viewModel.setLyricsMode(LyricsMode.floating);
          expect(
            viewModel.lyricsMode,
            equals(LyricsMode.floating),
            reason: 'Floating mode should be allowed when KTV mode is disabled',
          );
        }
      },
    );

    test(
      'Property 45 (KTV mode preserves screen): Enabling KTV when already on screen',
      () async {
        // Set lyrics mode to screen
        await viewModel.setLyricsMode(LyricsMode.screen);
        expect(viewModel.lyricsMode, equals(LyricsMode.screen));

        // Enable KTV mode
        await viewModel.setKtvMode(true);

        // Verify still on screen
        expect(viewModel.lyricsMode, equals(LyricsMode.screen));
        expect(viewModel.ktvMode, isTrue);
      },
    );

    test(
      'Property 45 (KTV mode from floating): Enabling KTV when on floating switches to screen',
      () async {
        // Set lyrics mode to floating
        await viewModel.setLyricsMode(LyricsMode.floating);
        expect(viewModel.lyricsMode, equals(LyricsMode.floating));

        // Enable KTV mode
        await viewModel.setKtvMode(true);

        // Verify switched to screen
        expect(viewModel.lyricsMode, equals(LyricsMode.screen));
        expect(viewModel.ktvMode, isTrue);
      },
    );

    // Feature: song-unit-core, Property 46: Lyrics off state
    // **Validates: Requirements 13.1**
    test(
      'Property 46: For any system state with lyrics mode set to "off", no lyrics SHALL be displayed in any output (setting correctness)',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          // Set lyrics mode to off
          await viewModel.setLyricsMode(LyricsMode.off);

          // Verify the setting is persisted
          expect(
            viewModel.lyricsMode,
            equals(LyricsMode.off),
            reason: 'Lyrics mode should be off',
          );

          final settings = await settingsRepository.loadSettings();
          expect(
            settings.lyricsMode,
            equals(LyricsMode.off),
            reason: 'Persisted lyrics mode should be off',
          );

          // Make other settings changes
          await viewModel.setThemeMode(Random().nextBool() ? 'light' : 'dark');

          // Verify lyrics mode is still off
          expect(
            viewModel.lyricsMode,
            equals(LyricsMode.off),
            reason: 'Lyrics mode should remain off after other changes',
          );
        }
      },
    );

    test(
      'Property 46 (lyrics off persistence): Lyrics off survives reload',
      () async {
        // Set lyrics mode to off
        await viewModel.setLyricsMode(LyricsMode.off);
        expect(viewModel.lyricsMode, equals(LyricsMode.off));

        // Clear cache and reload
        settingsRepository.clearCache();
        await viewModel.loadSettings();

        // Verify still off
        expect(viewModel.lyricsMode, equals(LyricsMode.off));
      },
    );

    test(
      'Property 46 (lyrics off vs KTV): KTV mode overrides off to screen',
      () async {
        // Set lyrics mode to off
        await viewModel.setLyricsMode(LyricsMode.off);
        expect(viewModel.lyricsMode, equals(LyricsMode.off));

        // Enable KTV mode
        await viewModel.setKtvMode(true);

        // Verify switched to screen (KTV forces screen)
        expect(viewModel.lyricsMode, equals(LyricsMode.screen));

        // Disable KTV mode
        await viewModel.setKtvMode(false);

        // Set back to off
        await viewModel.setLyricsMode(LyricsMode.off);
        expect(viewModel.lyricsMode, equals(LyricsMode.off));
      },
    );

    // Additional tests for settings persistence
    test(
      'Settings persistence: All settings are immediately retrievable',
      () async {
        const iterations = 50;

        for (var i = 0; i < iterations; i++) {
          // Set random values
          final path = SettingsTestGenerators.randomPath();
          final writeBack = Random().nextBool();
          final lyricsMode =
              SettingsTestGenerators.randomNonFloatingLyricsMode();
          final theme = Random().nextBool() ? 'light' : 'dark';

          await viewModel.updateLibraryPath(path);
          await viewModel.setMetadataWriteBack(writeBack);
          await viewModel.setLyricsMode(lyricsMode);
          await viewModel.setThemeMode(theme);

          // Verify all settings are immediately retrievable
          expect(viewModel.libraryPath, equals(path));
          expect(viewModel.metadataWriteBack, equals(writeBack));
          expect(viewModel.lyricsMode, equals(lyricsMode));
          expect(viewModel.themeMode, equals(theme));

          // Verify persisted settings match
          final settings = await settingsRepository.loadSettings();
          expect(settings.libraryPath, equals(path));
          expect(settings.metadataWriteBack, equals(writeBack));
          expect(settings.lyricsMode, equals(lyricsMode));
          expect(settings.themeMode, equals(theme));
        }
      },
    );
  });
}
