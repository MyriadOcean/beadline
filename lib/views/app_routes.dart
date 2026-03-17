import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../models/configuration_mode.dart';
import '../repositories/settings_repository.dart';
import '../services/audio_discovery_service.dart';
import '../services/configuration_migration_service.dart';
import '../services/discovery_service.dart';
import '../services/file_system_watcher.dart';
import '../services/library_location_manager.dart';
import '../viewmodels/library_view_model.dart';
import 'audio_entries_debug_view.dart';
import 'home_page.dart';
import 'library_locations_settings_page.dart';
import 'library_view.dart';
import 'online_providers_settings_page.dart';
import 'search_view.dart';
import 'settings_view.dart';
import 'song_unit_editor.dart';
import 'tag_management_view.dart';

/// Application route names
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String library = '/library';
  static const String search = '/search';
  static const String tags = '/tags';
  static const String settings = '/settings';
  static const String songUnitEditor = '/song-unit-editor';
  static const String libraryLocations = '/library-locations';
  static const String onlineProviders = '/online-providers';
  static const String audioEntriesDebug = '/audio-entries-debug';
}

/// Application route generator
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case AppRoutes.library:
        return MaterialPageRoute(
          builder: (_) => const LibraryView(),
          settings: settings,
        );
      case AppRoutes.search:
        return MaterialPageRoute(
          builder: (_) => const SearchView(),
          settings: settings,
        );
      case AppRoutes.tags:
        return MaterialPageRoute(
          builder: (_) => const TagManagementView(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsView(),
          settings: settings,
        );
      case AppRoutes.songUnitEditor:
        final songUnitId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => SongUnitEditor(songUnitId: songUnitId),
          settings: settings,
        );
      case AppRoutes.libraryLocations:
        return MaterialPageRoute(
          builder: (_) {
            final settingsRepo = getIt<SettingsRepository>();
            return FutureBuilder(
              future: settingsRepo.loadSettings(),
              builder: (context, snapshot) {
                final configMode = snapshot.data?.configMode;
                return LibraryLocationsSettingsPage(
                  libraryLocationManager: getIt<LibraryLocationManager>(),
                  discoveryService: getIt<DiscoveryService>(),
                  migrationService: getIt<ConfigurationMigrationService>(),
                  globalConfigMode: configMode ?? ConfigurationMode.centralized,
                  onLocationAdded: (location) async {
              // Refresh file watcher to include the new location
              try {
                final fileSystemWatcher = getIt<FileSystemWatcher>();
                await fileSystemWatcher.refreshWatchers();
              } catch (e) {
                // ignore
              }

              // Run audio discovery on the new location if auto-discover is enabled
              try {
                final settingsRepo = getIt<SettingsRepository>();
                final settings = await settingsRepo.loadSettings();
                if (settings.autoDiscoverAudioFiles) {
                  final audioDiscovery = getIt<AudioDiscoveryService>();
                  await audioDiscovery.discoverAudioFiles([location]);
                  // Refresh library view
                  final libraryVM = getIt<LibraryViewModel>();
                  await libraryVM.refreshAudioEntries();
                }
              } catch (e) {
                // ignore
              }

              // Sync library to pick up any new song units
              try {
                final libraryVM = getIt<LibraryViewModel>();
                await libraryVM.syncLibrary();
                await libraryVM.loadAndSync();
              } catch (e) {
                // ignore
              }
            },
                );
              },
            );
          },
          settings: settings,
        );
      case AppRoutes.onlineProviders:
        return MaterialPageRoute(
          builder: (_) => const OnlineProvidersSettingsPage(),
          settings: settings,
        );
      case AppRoutes.audioEntriesDebug:
        return MaterialPageRoute(
          builder: (_) => const AudioEntriesDebugView(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }
}
