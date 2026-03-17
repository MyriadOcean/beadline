import 'package:get_it/get_it.dart';

import '../../data/file_system_service.dart';
import '../../data/playback_state_storage.dart';
import '../../data/settings_storage.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/search_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/tag_repository.dart';
import '../../services/audio_discovery_service.dart';
import '../../services/configuration_migration_service.dart';
import '../../services/discovery_service.dart';
import '../../services/entry_point_file_service.dart';
import '../../services/file_system_watcher.dart';
import '../../services/import_export_service.dart';
import '../../services/library_location_manager.dart';

import '../../services/notification_service.dart';
import '../../services/online_source_provider.dart';
import '../../services/path_resolver.dart';
import '../../services/permission_service.dart';
import '../../services/platform_media_player.dart';
import '../../services/player_engine.dart';
import '../../services/video_audio_extraction_service.dart';
import '../../viewmodels/library_view_model.dart';
import '../../viewmodels/player_view_model.dart';
import '../../viewmodels/search_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../viewmodels/tag_view_model.dart';

/// Global service locator instance for dependency injection
final GetIt getIt = GetIt.instance;

/// Initialize all dependencies
/// This should be called once at app startup
Future<void> setupServiceLocator() async {
  // Data layer dependencies
  getIt
    ..registerLazySingleton<FileSystemService>(FileSystemService.new)
    ..registerLazySingleton<SettingsStorage>(SettingsStorage.new)
    ..registerLazySingleton<PlaybackStateStorage>(PlaybackStateStorage.new)
    // Repository layer dependencies
    ..registerLazySingleton<TagRepository>(TagRepository.new)
    ..registerLazySingleton<LibraryRepository>(
      LibraryRepository.new,
    )
    // Online source provider registry - needs to be initialized before SearchRepository
    ..registerLazySingleton<OnlineSourceProviderRegistry>(
      OnlineSourceProviderRegistry.new,
    )
    ..registerLazySingleton<SearchRepository>(
      () => SearchRepository(
        getIt<LibraryRepository>(),
        getIt<TagRepository>(),
        getIt<FileSystemService>(),
        onlineProviders: getIt<OnlineSourceProviderRegistry>(),
      ),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(
        getIt<SettingsStorage>(),
        getIt<FileSystemService>(),
      ),
    )
    // Service layer dependencies
    ..registerLazySingleton<PlatformMediaPlayer>(MediaKitPlayer.new)
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<PlayerEngine>(
      () => PlayerEngine.withRealPlayers(
        notificationService: getIt<NotificationService>(),
      ),
      dispose: (engine) => engine.dispose(),
    )
    ..registerLazySingleton<ImportExportService>(
      () => ImportExportService(
        getIt<LibraryRepository>(),
        getIt<FileSystemService>(),
      ),
    )
    ..registerLazySingleton<LibraryLocationManager>(
      () => LibraryLocationManager(getIt<SettingsStorage>()),
    )
    // PathResolver needs to be created with library locations from the manager
    // Registered as a factory so each caller gets a fresh instance with current locations
    ..registerFactory<PathResolver>(
      () {
        // Synchronously return empty resolver - callers that need locations
        // should use the async PathResolver from DiscoveryService
        return PathResolver([]);
      },
    )
    ..registerLazySingleton<EntryPointFileService>(
      () => EntryPointFileService(getIt<PathResolver>()),
    )
    ..registerLazySingleton<DiscoveryService>(
      () => DiscoveryService(
        getIt<LibraryLocationManager>(),
        getIt<EntryPointFileService>(),
        getIt<LibraryRepository>(),
        tagRepository: getIt<TagRepository>(),
      ),
    )
    ..registerLazySingleton<ConfigurationMigrationService>(
      () => ConfigurationMigrationService(
        getIt<LibraryRepository>(),
        getIt<EntryPointFileService>(),
        tagRepository: getIt<TagRepository>(),
      ),
    )
    ..registerLazySingleton<FileSystemWatcher>(
      () => FileSystemWatcher(getIt<LibraryLocationManager>()),
    )
    ..registerLazySingleton<PermissionService>(PermissionService.new)
    ..registerLazySingleton<AudioDiscoveryService>(
      () => AudioDiscoveryService(
        libraryRepository: getIt<LibraryRepository>(),
      ),
    )
    ..registerLazySingleton<VideoAudioExtractionService>(
      VideoAudioExtractionService.new,
    )
    // ViewModel dependencies
    // Note: LibraryViewModel, PlayerViewModel, and TagViewModel are singletons
    // because they manage shared state that must persist across navigation and
    // be accessible from notification callbacks (same instance everywhere).
    // SearchViewModel and SettingsViewModel are factories — they can be recreated
    // without losing important state.
    ..registerLazySingleton<LibraryViewModel>(
      () => LibraryViewModel(
        libraryRepository: getIt<LibraryRepository>(),
        importExportService: getIt<ImportExportService>(),
        migrationService: getIt<ConfigurationMigrationService>(),
        discoveryService: getIt<DiscoveryService>(),
        fileSystemWatcher: getIt<FileSystemWatcher>(),
        entryPointFileService: getIt<EntryPointFileService>(),
        tagRepository: getIt<TagRepository>(),
      ),
    )
    ..registerLazySingleton<PlayerViewModel>(
      () => PlayerViewModel(
        playerEngine: getIt<PlayerEngine>(),
        libraryRepository: getIt<LibraryRepository>(),
        playbackStateStorage: getIt<PlaybackStateStorage>(),
      ),
    )
    ..registerFactory<SearchViewModel>(
      () => SearchViewModel(
        searchRepository: getIt<SearchRepository>(),
        settingsRepository: getIt<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<TagViewModel>(
      () => TagViewModel(
        tagRepository: getIt<TagRepository>(),
        libraryRepository: getIt<LibraryRepository>(),
        settingsRepository: getIt<SettingsRepository>(),
        playbackStateStorage: getIt<PlaybackStateStorage>(),
      ),
    )
    ..registerFactory<SettingsViewModel>(
      () => SettingsViewModel(
        settingsRepository: getIt<SettingsRepository>(),
        migrationService: getIt<ConfigurationMigrationService>(),
        onlineProviderRegistry: getIt<OnlineSourceProviderRegistry>(),
      ),
    );

  // Initialize built-in tags (name, artist, album, time, duration, user)
  await getIt<TagRepository>().initializeBuiltInTags();

  // Ensure default queue exists
  final settingsRepo = getIt<SettingsRepository>();
  final tagRepo = getIt<TagRepository>();
  final activeQueueId = await settingsRepo.getActiveQueueId();
  final activeQueue = await tagRepo.getTag(activeQueueId);
  if (activeQueue == null) {
    // Create default collection
    final defaultQueue = await tagRepo.createCollection(
      'Default',
      isQueue: true,
    );
    await settingsRepo.setActiveQueueId(defaultQueue.id);
  }
}

/// Reset all dependencies (useful for testing)
Future<void> resetServiceLocator() async {
  await getIt.reset();
}
