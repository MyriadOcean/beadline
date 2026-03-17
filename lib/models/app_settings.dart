import 'package:json_annotation/json_annotation.dart';

import 'configuration_mode.dart';
import 'library_location.dart';
import 'online_provider_config.dart';

part 'app_settings.g.dart';

/// Application settings
@JsonSerializable(explicitToJson: true)
class AppSettings {
  const AppSettings({
    required this.libraryPath,
    this.metadataWriteBack = false,
    this.lyricsMode = LyricsMode.off,
    this.displayMode = DisplayMode.enabled,
    this.ktvMode = false,
    this.hideDisplayPanel = false,
    this.themeMode = 'system',
    this.languageCode,
    this.username = 'User',
    this.primaryColorSeed,
    this.configMode = ConfigurationMode.centralized,
    this.libraryLocations = const [],
    this.isConfigured = false,
    this.useThumbnailBackgroundInQueue = false,
    this.useThumbnailBackgroundInLibrary = false,
    this.onlineProviders = const [],
    this.autoDiscoverAudioFiles = false,
    this.activeQueueId,
    this.nameAutoSearch = true,
  });

  /// Create default settings
  factory AppSettings.defaults() {
    return const AppSettings(libraryPath: '');
  }

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  /// Path to the Song Unit library
  final String libraryPath;

  /// Whether to write metadata back to source files
  final bool metadataWriteBack;

  /// Lyrics display mode
  final LyricsMode lyricsMode;

  /// Display mode for video/image sources
  final DisplayMode displayMode;

  /// Whether KTV mode is enabled
  final bool ktvMode;

  /// Whether to hide the display panel completely
  final bool hideDisplayPanel;

  /// Theme mode (light, dark, system)
  final String themeMode;

  /// Selected language code
  final String? languageCode;

  /// Username for song requests and user tags
  final String username;

  /// Primary color seed for theme
  final int? primaryColorSeed;

  /// Configuration storage mode (centralized or in-place)
  final ConfigurationMode configMode;

  /// List of configured library locations
  final List<LibraryLocation> libraryLocations;

  /// Whether the initial configuration has been completed
  /// This is set to true after the user completes the first-launch setup
  final bool isConfigured;

  /// Whether to use thumbnail as background in queue
  final bool useThumbnailBackgroundInQueue;

  /// Whether to use thumbnail as background in library
  final bool useThumbnailBackgroundInLibrary;

  /// Configured online source providers
  final List<OnlineProviderConfig> onlineProviders;

  /// Whether to automatically discover and add audio files from library locations
  /// When enabled, audio files without song units will be added as audio-only entries
  final bool autoDiscoverAudioFiles;

  /// Active queue ID (collection tag ID that is currently being played)
  final String? activeQueueId;

  /// Whether bare keywords also match the `name` built-in tag (default: true)
  /// Requirement 5.4
  final bool nameAutoSearch;

  // Sentinel for nullable fields that need to be explicitly set to null
  static const _unset = Object();

  /// Create a copy with updated fields.
  /// For nullable fields (languageCode, primaryColorSeed, activeQueueId),
  /// pass the sentinel [_unset] to keep the current value, or pass null to
  /// explicitly clear the field.
  AppSettings copyWith({
    String? libraryPath,
    bool? metadataWriteBack,
    LyricsMode? lyricsMode,
    DisplayMode? displayMode,
    bool? ktvMode,
    bool? hideDisplayPanel,
    String? themeMode,
    Object? languageCode = _unset,
    String? username,
    Object? primaryColorSeed = _unset,
    ConfigurationMode? configMode,
    List<LibraryLocation>? libraryLocations,
    bool? isConfigured,
    bool? useThumbnailBackgroundInQueue,
    bool? useThumbnailBackgroundInLibrary,
    List<OnlineProviderConfig>? onlineProviders,
    bool? autoDiscoverAudioFiles,
    Object? activeQueueId = _unset,
    bool? nameAutoSearch,
  }) {
    return AppSettings(
      libraryPath: libraryPath ?? this.libraryPath,
      metadataWriteBack: metadataWriteBack ?? this.metadataWriteBack,
      lyricsMode: lyricsMode ?? this.lyricsMode,
      displayMode: displayMode ?? this.displayMode,
      ktvMode: ktvMode ?? this.ktvMode,
      hideDisplayPanel: hideDisplayPanel ?? this.hideDisplayPanel,
      themeMode: themeMode ?? this.themeMode,
      languageCode: identical(languageCode, _unset)
          ? this.languageCode
          : languageCode as String?,
      username: username ?? this.username,
      primaryColorSeed: identical(primaryColorSeed, _unset)
          ? this.primaryColorSeed
          : primaryColorSeed as int?,
      configMode: configMode ?? this.configMode,
      libraryLocations: libraryLocations ?? this.libraryLocations,
      isConfigured: isConfigured ?? this.isConfigured,
      useThumbnailBackgroundInQueue:
          useThumbnailBackgroundInQueue ?? this.useThumbnailBackgroundInQueue,
      useThumbnailBackgroundInLibrary:
          useThumbnailBackgroundInLibrary ??
          this.useThumbnailBackgroundInLibrary,
      onlineProviders: onlineProviders ?? this.onlineProviders,
      autoDiscoverAudioFiles:
          autoDiscoverAudioFiles ?? this.autoDiscoverAudioFiles,
      activeQueueId: identical(activeQueueId, _unset)
          ? this.activeQueueId
          : activeQueueId as String?,
      nameAutoSearch: nameAutoSearch ?? this.nameAutoSearch,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppSettings &&
        other.libraryPath == libraryPath &&
        other.metadataWriteBack == metadataWriteBack &&
        other.lyricsMode == lyricsMode &&
        other.displayMode == displayMode &&
        other.ktvMode == ktvMode &&
        other.hideDisplayPanel == hideDisplayPanel &&
        other.themeMode == themeMode &&
        other.languageCode == languageCode &&
        other.username == username &&
        other.primaryColorSeed == primaryColorSeed &&
        other.configMode == configMode &&
        _listEquals(other.libraryLocations, libraryLocations) &&
        other.isConfigured == isConfigured;
  }

  @override
  int get hashCode {
    return Object.hash(
      libraryPath,
      metadataWriteBack,
      lyricsMode,
      displayMode,
      ktvMode,
      hideDisplayPanel,
      themeMode,
      languageCode,
      username,
      primaryColorSeed,
      configMode,
      Object.hashAll(libraryLocations),
      isConfigured,
    );
  }

  bool _listEquals(List<LibraryLocation> a, List<LibraryLocation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Lyrics display mode
enum LyricsMode {
  /// No lyrics displayed
  off,

  /// Lyrics displayed on main screen
  screen,

  /// Lyrics displayed in floating window
  floating,

  /// Lyrics displayed in rolling style
  rolling;

  /// Convert to JSON
  String toJson() => name;

  /// Create from JSON
  static LyricsMode fromJson(String json) {
    return LyricsMode.values.firstWhere(
      (mode) => mode.name == json,
      orElse: () => LyricsMode.off,
    );
  }
}

/// Display mode for video/image sources
enum DisplayMode {
  /// Display video and image sources normally
  enabled,

  /// Only display image sources (convert video to image/placeholder)
  imageOnly,

  /// Disable all display sources (lyrics-only mode)
  disabled,

  /// Hide the display panel completely
  hidden;

  /// Convert to JSON
  String toJson() => name;

  /// Create from JSON
  static DisplayMode fromJson(String json) {
    return DisplayMode.values.firstWhere(
      (mode) => mode.name == json,
      orElse: () => DisplayMode.enabled,
    );
  }
}
