import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'core/di/service_locator.dart';
import 'core/keyboard_shortcuts.dart';
import 'data/settings_storage.dart';
import 'i18n/translations.g.dart';
import 'repositories/library_repository.dart';
import 'repositories/settings_repository.dart';
import 'services/audio_discovery_service.dart';
import 'services/desktop_window_manager.dart' as desktop;
import 'services/file_system_watcher.dart';
import 'services/library_location_manager.dart';
import 'services/notification_service.dart';
import 'services/online_source_provider.dart';
import 'services/permission_service.dart';
import 'services/player_engine.dart';
import 'services/thumbnail_cache.dart';
import 'src/rust/api/database_api.dart' as rust_db;
import 'src/rust/frb_generated.dart';
import 'viewmodels/library_view_model.dart';
import 'viewmodels/player_view_model.dart';
import 'viewmodels/search_view_model.dart';
import 'viewmodels/settings_view_model.dart';
import 'viewmodels/tag_view_model.dart';
import 'views/app_routes.dart';
import 'views/app_theme.dart';
import 'views/configuration_mode_selector.dart';
import 'views/language_selector.dart';
import 'views/library_location_setup_dialog.dart';

void main(List<String> args) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  MediaKit.ensureInitialized();

  // Initialize slang i18n — use device locale, fall back to English.
  // Must be async so deferred locale libraries are loaded before any widget
  // tries to read translations.
  await LocaleSettings.useDeviceLocale();

  // Apply saved language preference early so localized strings (e.g. default
  // queue name) are correct before setupServiceLocator runs.
  try {
    final savedSettings = await SettingsStorage().loadSettings();
    final savedLang = savedSettings.languageCode;
    if (savedLang != null && savedLang.isNotEmpty) {
      await LocaleSettings.setLocaleRaw(savedLang);
    }
  } catch (_) {
    // Silently fall back to device locale on any error
  }

  // Check if this is a desktop sub-window (floating lyrics)
  final subWindowWidget = desktop.handleSubWindowArgs(args);
  if (subWindowWidget != null) {
    runApp(subWindowWidget);
    return;
  }

  // Initialize window manager for desktop platforms (size, position, etc.)
  await desktop.initDesktopWindow();


  // Initialize Flutter Rust Bridge
  await RustLib.init();

  // Initialize Rust tag system database
  // Uses the same documents directory as the Dart database, separate file
  try {
    final directory = await getApplicationDocumentsDirectory();
    final rustDbPath = p.join(directory.path, 'beadline_tags.db');
    await rust_db.initDatabase(dbPath: rustDbPath);
    debugPrint('Rust tag database initialized at: $rustDbPath');
  } catch (e) {
    debugPrint('Failed to initialize Rust tag database: $e');
  }

  // Initialize thumbnail cache
  await ThumbnailCache.instance.initialize();

  // Initialize dependency injection
  await setupServiceLocator();

  // Register thumbnail hashes provider for scheduled purge
  ThumbnailCache.instance.registerHashesProvider(() async {
    final libraryRepository = getIt<LibraryRepository>();
    final allUnits = await libraryRepository.getAllSongUnits();
    return allUnits
        .map((u) => u.metadata.thumbnailSourceId)
        .whereType<String>()
        .where((id) => id.length == 64)
        .toSet();
  });

  // Initialize audio_service (media session, notifications, MPRIS)
  // Must happen after setupServiceLocator so NotificationService is registered
  final notificationService = getIt<NotificationService>();
  await notificationService.initialize();

  // Wire up notification/media-button callbacks (all platforms)
  {
    final playerEngine = getIt<PlayerEngine>();
    final tagViewModel = getIt<TagViewModel>();
    final playerViewModel = getIt<PlayerViewModel>();

    // Wire up TagViewModel to PlayerViewModel for notification buttons
    tagViewModel.setPlayerViewModel(playerViewModel);

    // Debouncing for notification buttons to prevent rapid clicks
    DateTime? lastPreviousClick;
    DateTime? lastNextClick;
    const debounceDuration = Duration(milliseconds: 500);

    notificationService
      ..onPlayPause = () async {
        if (playerEngine.currentState.isPlaying) {
          await playerEngine.pause();
        } else {
          await playerEngine.resume();
        }
      }
      ..onPlay = () async {
        await playerEngine.resume();
      }
      ..onPause = () async {
        await playerEngine.pause();
      }
      ..onStop = () async {
        await playerEngine.stop();
      }
      ..onSeek = (int positionMs) async {
        final position = Duration(milliseconds: positionMs);
        try {
          await playerEngine
              .seekTo(position)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  debugPrint('NotificationService: Seek timeout');
                },
              );
        } catch (e) {
          debugPrint('NotificationService: Seek error: $e');
        }
      }
      ..onPrevious = () async {
        final now = DateTime.now();
        if (lastPreviousClick != null &&
            now.difference(lastPreviousClick!) < debounceDuration) {
          return;
        }
        lastPreviousClick = now;
        try {
          await tagViewModel.playAndMoveToPrevious();
        } catch (e) {
          debugPrint('NotificationService: Failed to handle previous: $e');
        }
      }
      ..onNext = () async {
        final now = DateTime.now();
        if (lastNextClick != null &&
            now.difference(lastNextClick!) < debounceDuration) {
          return;
        }
        lastNextClick = now;
        try {
          await tagViewModel.playAndMoveToNext();
        } catch (e) {
          debugPrint('NotificationService: Failed to handle next: $e');
        }
      };
  }

  // Request notification permission for Android 13+
  if (Platform.isAndroid) {
    try {
      final permissionService = getIt<PermissionService>();
      final notificationGranted = await permissionService
          .requestNotificationPermission();
      debugPrint('Main: Notification permission granted: $notificationGranted');
    } catch (e) {
      debugPrint('Main: Failed to request notification permission: $e');
    }
  }

  // Load online provider configurations from settings
  await _initializeOnlineProviders();

  runApp(TranslationProvider(child: const RestartWidget(child: BeadlineApp())));
}

/// Widget that allows restarting the entire app by rebuilding the widget tree.
/// Call RestartWidget.restartApp(context) to trigger a full restart.
class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});
  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// Initialize online source providers from saved settings
Future<void> _initializeOnlineProviders() async {
  try {
    final settingsRepo = getIt<SettingsRepository>();
    final providerRegistry = getIt<OnlineSourceProviderRegistry>();

    final providers = await settingsRepo.getOnlineProviders();

    // Update registry with saved configurations
    for (final config in providers) {
      providerRegistry.updateProvider(config);
    }
  } catch (e) {
    // Silently fail - providers will use defaults
    debugPrint('Failed to initialize online providers: $e');
  }
}

/// Main application widget
/// Sets up MaterialApp with theme, routing, and Provider for dependency injection
/// Requirements: 12.1, 12.5
class BeadlineApp extends StatefulWidget {
  const BeadlineApp({super.key});

  @override
  State<BeadlineApp> createState() => _BeadlineAppState();
}

class _BeadlineAppState extends State<BeadlineApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Re-claim audio focus when returning to foreground
      try {
        getIt<NotificationService>().requestAudioFocus();
      } catch (e) {
        debugPrint('Failed to request audio focus on resume: $e');
      }
    }

    // Save playback state when app goes to background or is paused
    // NOTE: Don't save on 'inactive' state because creating floating windows
    // triggers inactive state, but the app is still active
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint('App lifecycle changed to $state, saving playback state');
      try {
        getIt<PlayerViewModel>().savePlaybackStateNow();
      } catch (e) {
        debugPrint('Failed to save playback state on lifecycle change: $e');
      }
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('App lifecycle changed to $state (ignoring - may be floating window)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Singleton ViewModels - use .value to avoid Provider disposing them
        ChangeNotifierProvider<PlayerViewModel>.value(
          value: getIt<PlayerViewModel>(),
        ),
        ChangeNotifierProvider<LibraryViewModel>.value(
          value: getIt<LibraryViewModel>(),
        ),
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => getIt<SearchViewModel>(),
        ),
        ChangeNotifierProvider<TagViewModel>.value(
          value: getIt<TagViewModel>(),
        ),
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: getIt<SettingsViewModel>(),
        ),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settingsViewModel, child) {
          // Apply saved language preference whenever settings change
          final langCode = settingsViewModel.languageCode;
          
          // Schedule locale change for next frame to avoid sync issues
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (langCode != null && langCode.isNotEmpty) {
              await LocaleSettings.setLocaleRaw(langCode);
            } else {
              await LocaleSettings.useDeviceLocale();
            }
          });

          return MaterialApp(
            title: 'Beadline',
            debugShowCheckedModeBanner: false,
            // i18n delegates
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: AppLocaleUtils.supportedLocales,
            // Theme configuration
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: AppTheme.getThemeMode(settingsViewModel.themeMode),
            // Show first-launch configuration or main app
            home: _AppInitializer(settingsViewModel: settingsViewModel),
          );
        },
      ),
    );
  }
}

/// Widget that handles app initialization and first-launch configuration
/// Requirements: 3.1, 3.4
class _AppInitializer extends StatefulWidget {
  const _AppInitializer({required this.settingsViewModel});
  final SettingsViewModel settingsViewModel;

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  bool _showingLibrarySetup = false;
  bool _languageSelected = false;
  bool _libraryReady = false;

  @override
  void initState() {
    super.initState();
    debugPrint('main.dart: _AppInitializerState.initState() called');

    // Always initialize library monitoring on app launch
    // This is independent of configuration state - if library locations exist, watch them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLibraryMonitoring();
      // Note: Playback state restoration is now handled in HomePage.initState()
    });

    // Set up callback for when auto-discover is enabled
    widget.settingsViewModel.setAutoDiscoverCallback(() async {
      await _runAudioDiscovery();
    });

    // Set up callback for when auto-discover is disabled
    widget.settingsViewModel.setAutoDiscoverDisabledCallback(() async {
      await _clearAudioEntries();
    });
  }

  /// Initialize library monitoring (auto-scan and file watching)
  Future<void> _initializeLibraryMonitoring() async {
    debugPrint('main.dart: _initializeLibraryMonitoring() called');
    try {
      final libraryViewModel = getIt<LibraryViewModel>();
      final fileSystemWatcher = getIt<FileSystemWatcher>();
      final libraryLocationManager = getIt<LibraryLocationManager>();
      final audioDiscoveryService = getIt<AudioDiscoveryService>();
      final settingsRepository = getIt<SettingsRepository>();

      // On Android, ensure MANAGE_EXTERNAL_STORAGE is granted before scanning.
      // Without it, non-media files (beadline-*.json) can't be read.
      if (Platform.isAndroid) {
        final permissionService = getIt<PermissionService>();
        final hasFullAccess = await permissionService.hasManageExternalStorage();
        if (!hasFullAccess) {
          debugPrint(
            'main.dart: MANAGE_EXTERNAL_STORAGE not granted, requesting...',
          );
          await permissionService.requestManageExternalStorage();
        }
      }

      // Always set up the file watcher listener first, even if we don't start watching yet
      debugPrint('main.dart: Setting up file watcher listener');
      fileSystemWatcher.events.listen((event) async {
        debugPrint('main.dart.FileChange: ${event.type} - ${event.path}');

        final extension = p.extension(event.path).toLowerCase();
        final fileName = p.basename(event.path);

        // Check file type
        const audioExtensions = [
          '.mp3',
          '.flac',
          '.wav',
          '.aac',
          '.ogg',
          '.m4a',
        ];
        final isAudioFile = audioExtensions.contains(extension);
        final isEntryPointFile =
            extension == '.json' &&
            (fileName.startsWith('beadline-') ||
                fileName.startsWith('.beadline-'));

        debugPrint(
          'main.dart: isAudioFile=$isAudioFile, isEntryPointFile=$isEntryPointFile, libraryLocationId=${event.libraryLocationId}',
        );

        // Handle audio file events if auto-discovery is enabled
        final currentSettings = await settingsRepository.loadSettings();
        debugPrint(
          'main.dart: autoDiscoverAudioFiles=${currentSettings.autoDiscoverAudioFiles}',
        );

        if (currentSettings.autoDiscoverAudioFiles &&
            isAudioFile &&
            event.libraryLocationId != null) {
          if (event.type == FileChangeType.created ||
              event.type == FileChangeType.modified) {
            final file = File(event.path);
            if (file.existsSync()) {
              debugPrint(
                'AudioFile: New/modified audio file detected: ${event.path}',
              );
              // Extract thumbnails for file watcher events
              final added = await audioDiscoveryService.processAudioFile(
                event.path,
                event.libraryLocationId!,
              );

              if (added) {
                debugPrint('AudioFile: Added audio entry, refreshing library');
                // Refresh library view to show the new audio entry
                await libraryViewModel.refreshAudioEntries();
              } else {
                debugPrint(
                  'AudioFile: File not added (may be in song unit or already exists)',
                );
              }
            }
          } else if (event.type == FileChangeType.deleted) {
            debugPrint('AudioFile: Audio file deleted: ${event.path}');
            await audioDiscoveryService.removeAudioFile(event.path);
            // Refresh library view to remove the deleted audio entry
            await libraryViewModel.refreshAudioEntries();
          }
        } else if (currentSettings.autoDiscoverAudioFiles && isAudioFile) {
          debugPrint(
            'main.dart: Audio file detected but libraryLocationId is null!',
          );
        }

        // Trigger a sync for entry point files only
        if (isEntryPointFile) {
          debugPrint(
            'EntryPointFile: Syncing library for entry point file change',
          );
          await libraryViewModel.syncLibrary();
        }
      });

      // Get library locations
      final locations = await libraryLocationManager.getLocations();

      if (locations.isEmpty) {
        // No library locations configured yet - listener is set up but watcher not started
        debugPrint(
          'main.dart: No library locations configured, watcher listener ready but not started',
        );
        if (mounted) {
          FlutterNativeSplash.remove();
          setState(() {
            _libraryReady = true;
          });
        }
        return;
      }

      // Get current settings to check if auto-discovery is enabled
      final settings = await settingsRepository.loadSettings();

      // Validate existing temporary song units - remove entries for files that no longer exist
      if (settings.autoDiscoverAudioFiles) {
        debugPrint('main.dart: Validating existing temporary song units');
        final libraryRepository = getIt<LibraryRepository>();
        final tempUnits = await libraryRepository.getTemporarySongUnits();
        var removedCount = 0;

        for (final unit in tempUnits) {
          final filePath = unit.originalFilePath;
          if (filePath != null) {
            final file = File(filePath);
            if (!file.existsSync()) {
              debugPrint(
                'main.dart: Removing temporary song unit for deleted file: $filePath',
              );
              await libraryRepository.deleteSongUnit(unit.id);
              removedCount++;
            }
          }
        }

        if (removedCount > 0) {
          debugPrint(
            'main.dart: Removed $removedCount temporary song units for deleted files',
          );
          // Refresh library view to reflect changes
          await libraryViewModel.refreshAudioEntries();
        }
      }

      // Start file system watcher for real-time monitoring
      debugPrint('main.dart: Starting file system watcher');
      await fileSystemWatcher.startWatching();

      // Perform initial scan FIRST so entry point files are imported
      // before audio discovery runs. This ensures audio files referenced
      // by beadline-*.json entry points are not created as temporary entries.
      await libraryViewModel.loadAndSync();

      // Library is ready — dismiss splash screen
      if (mounted) {
        FlutterNativeSplash.remove();
        setState(() {
          _libraryReady = true;
        });
      }

      // Run audio discovery AFTER sync so _isFileReferencedBySongUnit()
      // can see the imported song units and skip their source files.
      if (settings.autoDiscoverAudioFiles) {
        debugPrint('main.dart: Running initial audio discovery');
        await _runAudioDiscovery();

        // Clean up any temporary entries that were created for files
        // already referenced by imported song units. This handles edge
        // cases where path comparison in _isFileReferencedBySongUnit
        // didn't match (e.g. different path normalization).
        await libraryViewModel.cleanupTemporaryEntries();
      }
    } catch (e) {
      debugPrint('Failed to initialize library monitoring: $e');
      // Even on error, dismiss splash so the app isn't stuck
      if (mounted) {
        FlutterNativeSplash.remove();
        setState(() {
          _libraryReady = true;
        });
      }
    }
  }

  /// Run audio discovery on all library locations
  Future<void> _runAudioDiscovery() async {
    try {
      final audioDiscoveryService = getIt<AudioDiscoveryService>();
      final settingsRepository = getIt<SettingsRepository>();
      final libraryViewModel = getIt<LibraryViewModel>();

      final settings = await settingsRepository.loadSettings();

      if (settings.libraryLocations.isNotEmpty) {
        debugPrint(
          'Running audio discovery on ${settings.libraryLocations.length} locations...',
        );
        final result = await audioDiscoveryService.discoverAudioFiles(
          settings.libraryLocations,
        );
        debugPrint(
          'Audio discovery complete: ${result.discovered} discovered, ${result.skipped} skipped, ${result.errors} errors',
        );

        // Refresh library view to show newly discovered audio entries
        await libraryViewModel.loadAndSync();
      }
    } catch (e) {
      debugPrint('Failed to run audio discovery: $e');
    }
  }

  /// Clear all temporary song units when auto-discover is disabled
  Future<void> _clearAudioEntries() async {
    try {
      final libraryRepository = getIt<LibraryRepository>();
      final libraryViewModel = getIt<LibraryViewModel>();

      debugPrint('Clearing all temporary song units...');
      await libraryRepository.deleteAllTemporarySongUnits();

      // Refresh library view to remove temporary song units from display
      await libraryViewModel.loadAndSync();

      debugPrint('Temporary song units cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear temporary song units: $e');
    }
  }

  /// Show library location setup dialog
  Future<void> _showLibraryLocationSetup() async {
    if (_showingLibrarySetup) return;

    setState(() {
      _showingLibrarySetup = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Clear LibraryLocationManager's cache so it reads fresh settings from storage.
    // This prevents it from overwriting isConfigured=true with stale cached settings.
    final libraryLocationManager = getIt<LibraryLocationManager>()
      ..clearCache();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LibraryLocationSetupDialog(
        libraryLocationManager: libraryLocationManager,
        permissionService: getIt<PermissionService>(),
        onComplete: () async {
          // Start file watcher if not running, or refresh if already running
          final fileSystemWatcher = getIt<FileSystemWatcher>();
          await fileSystemWatcher.startWatching();
          await fileSystemWatcher.refreshWatchers();
          debugPrint(
            'main.dart: File watcher started/refreshed after library location setup',
          );
        },
      ),
    );

    if (mounted) {
      setState(() {
        _showingLibrarySetup = false;
      });
    }

    // If user added locations, trigger initial scan and start monitoring
    if (result == true) {
      // LibraryLocationManager writes directly to SettingsStorage, bypassing SettingsRepository events.
      // Clear the repository cache so loadSettings() fetches fresh data from storage.
      getIt<SettingsRepository>().clearCache();
      await widget.settingsViewModel.loadSettings();

      // Start file system watcher if not already running
      // (on first launch, _initializeLibraryMonitoring returned early with no locations)
      final fileSystemWatcher = getIt<FileSystemWatcher>();
      await fileSystemWatcher.startWatching();

      // Force a full sync - loadAndSync() skips sync after the first call,
      // so we call syncLibrary() directly to scan the newly added locations.
      final libraryViewModel = getIt<LibraryViewModel>();
      await libraryViewModel.syncLibrary();
      await libraryViewModel.loadAndSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while settings are loading
    if (widget.settingsViewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show language selector first if not configured and language not yet selected
    if (!widget.settingsViewModel.isConfigured && !_languageSelected) {
      return LanguageSelector(
        onLanguageSelected: (languageCode) async {
          // Apply locale immediately so t.queue.title is correct
          await LocaleSettings.setLocaleRaw(languageCode);
          // Save language preference
          await widget.settingsViewModel.setLanguageCode(languageCode);
          // Now create the default queue with the correct locale
          await ensureDefaultQueue();
          // Reload viewmodels so they pick up the newly created queue
          await getIt<TagViewModel>().reloadActiveQueue();
          // Mark language as selected to show configuration mode selector
          setState(() {
            _languageSelected = true;
          });
        },
      );
    }

    // Show configuration mode selector after language is selected
    if (!widget.settingsViewModel.isConfigured) {
      return ConfigurationModeSelector(
        onModeSelected: (mode) async {
          await widget.settingsViewModel.completeInitialConfiguration(mode);

          // Both modes should show library location setup
          // Use post-frame callback to show dialog after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLibraryLocationSetup();
          });
        },
        onSetupLibraryLocations: _showLibraryLocationSetup,
      );
    }

    // Keep showing a blank scaffold while native splash is still visible
    if (!_libraryReady) {
      return const Scaffold();
    }

    // Show main app with keyboard shortcuts
    return const _AppShortcutsWrapper(
      child: Navigator(
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRoutes.home,
      ),
    );
  }
}

/// Wrapper widget that provides global keyboard shortcuts
class _AppShortcutsWrapper extends StatelessWidget {
  const _AppShortcutsWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcutsWrapper(
      onPlayPause: () {
        context.read<PlayerViewModel>().togglePlayPause();
      },
      onNext: () async {
        final tagViewModel = context.read<TagViewModel>();
        final playerViewModel = context.read<PlayerViewModel>();
        if (tagViewModel.hasNext) {
          await tagViewModel.next();
          final songUnit = tagViewModel.currentSongUnit;
          if (songUnit != null) {
            await playerViewModel.play(songUnit);
          }
        }
      },
      onPrevious: () async {
        final tagViewModel = context.read<TagViewModel>();
        final playerViewModel = context.read<PlayerViewModel>();
        if (tagViewModel.hasPrevious) {
          await tagViewModel.previous();
          final songUnit = tagViewModel.currentSongUnit;
          if (songUnit != null) {
            await playerViewModel.play(songUnit);
          }
        }
      },
      onSearch: () {
        Navigator.of(context).pushNamed(AppRoutes.search);
      },
      child: child,
    );
  }
}
