import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/di/service_locator.dart';
import '../data/playback_state_storage.dart';
import '../data/settings_storage.dart';
import '../i18n/translations.g.dart';
import '../models/app_settings.dart';
import '../models/configuration_mode.dart';
import '../repositories/library_repository.dart';
import '../services/audio_discovery_service.dart';
import '../services/library_location_manager.dart';
import '../services/permission_service.dart';
import '../services/player_engine.dart';
import '../services/thumbnail_cache.dart';
import '../src/rust/api/database_api.dart' as rust_db;
import '../viewmodels/library_view_model.dart';
import '../viewmodels/settings_view_model.dart';

/// Settings view widget with comprehensive settings
/// Requirements: 14.1, 14.2, 14.3, 14.4, 14.5
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>()
        ..loadSettings()
        // Set up callback for when auto-discovery is enabled
        ..setAutoDiscoverCallback(() async {
          if (!mounted) return;

          // Trigger a re-scan when auto-discovery is enabled
          await _triggerAutoDiscoveryScan();
        })
        // Set up callback for when auto-discovery is disabled
        ..setAutoDiscoverDisabledCallback(() async {
          if (!mounted) return;

          // Clear all audio entries when auto-discovery is disabled
          await _clearAudioEntries();
        });
    });
  }

  /// Trigger audio discovery scan when auto-discovery is enabled
  Future<void> _triggerAutoDiscoveryScan() async {
    try {
      // Check and request permissions first
      final permissionService = getIt<PermissionService>();
      final hasPermissions = await permissionService.hasStoragePermissions();

      if (!hasPermissions) {
        // Request permissions
        final granted = await permissionService.requestStoragePermissions();

        if (!granted) {
          if (!mounted) return;

          // Show dialog explaining permissions are needed
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.settings.storagePermissionTitle),
              content: Text(context.t.settings.storagePermissionBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.t.common.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.t.settings.openSettings),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await permissionService.openSettings();
          }

          return;
        }
      }

      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _AutoDiscoveryProgressDialog(),
      );

      final audioDiscoveryService = getIt<AudioDiscoveryService>();
      final libraryLocationManager = getIt<LibraryLocationManager>();
      final locations = await libraryLocationManager.getLocations();

      if (locations.isEmpty) {
        if (mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pop(); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t.dialogs.noLibraryLocationsConfigured),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Run discovery with progress callback
      final result = await audioDiscoveryService.discoverAudioFiles(
        locations,
        onProgress: _AutoDiscoveryProgressDialog.updateProgress,
      );

      if (!mounted) return;

      // Close progress dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Refresh library view to show new audio entries
      final libraryViewModel = getIt<LibraryViewModel>();
      await libraryViewModel.refreshAudioEntries();

      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t.settings.foundAudioFiles.replaceAll('{count}', result.discovered.toString())),
              duration: const Duration(seconds: 2),
            ),
          );
        }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.settings.errorScanning.replaceAll('{error}', e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Clear all temporary song units when auto-discovery is disabled
  Future<void> _clearAudioEntries() async {
    try {
      final libraryRepo = getIt<LibraryRepository>();
      await libraryRepo.deleteAllTemporarySongUnits();

      // Refresh library view to remove temporary song units
      final libraryViewModel = getIt<LibraryViewModel>();
      await libraryViewModel.refreshAudioEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.settings.audioEntriesCleared),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.settings.errorClearingAudio.replaceAll('{error}', e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.error != null) {
          return _buildErrorState(context, viewModel);
        }

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildUserSection(context, viewModel),
                const SizedBox(height: 24),
                _buildAppearanceSection(context, viewModel),
                const SizedBox(height: 24),
                _buildPlaybackSection(context, viewModel),
                const SizedBox(height: 24),
                _buildStorageSection(context, viewModel),
                const SizedBox(height: 24),
                _buildDebugSection(context),
                const SizedBox(height: 24),
                _buildAboutSection(context),
              ],
            ),
            if (viewModel.isMigrating)
              _buildMigrationOverlay(context, viewModel),
          ],
        );
      },
    );
  }

  Widget _buildMigrationOverlay(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final progress = viewModel.migrationTotal > 0
        ? viewModel.migrationCurrent / viewModel.migrationTotal
        : null;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  context.t.settings.migratingConfig,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  viewModel.migrationProgress,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    '${viewModel.migrationCurrent} / ${viewModel.migrationTotal}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, SettingsViewModel viewModel) {
    return _buildSection(
      context,
      title: context.t.settings.user,
      icon: Icons.person,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              viewModel.username.isNotEmpty
                  ? viewModel.username[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(context.t.settings.username),
          subtitle: Text(viewModel.username),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showUsernameDialog(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return _buildSection(
      context,
      title: context.t.settings.appearance,
      icon: Icons.palette,
      children: [
        ListTile(
          leading: const Icon(Icons.brightness_6),
          title: Text(context.t.settings.theme),
          subtitle: Text(_getThemeModeLabel(context, viewModel.themeMode)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemeModeDialog(context, viewModel),
        ),
        ListTile(
          leading: const Icon(Icons.color_lens),
          title: Text(context.t.settings.accentColor),
          subtitle: Text(context.t.settings.accentColorHint),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: viewModel.primaryColorSeed != null
                  ? Color(viewModel.primaryColorSeed!)
                  : Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          onTap: () => _showColorPickerDialog(context, viewModel),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(context.t.settings.language),
          subtitle: Text(_getLanguageLabel(context, viewModel.languageCode)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildPlaybackSection(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return _buildSection(
      context,
      title: context.t.settings.playback,
      icon: Icons.play_circle,
      children: [
        ListTile(
          leading: const Icon(Icons.lyrics),
          title: Text(context.t.settings.lyricsMode),
          subtitle: Text(_getLyricsModeLabel(context, viewModel.lyricsMode)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLyricsModeDialog(context, viewModel),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.tv),
          title: Text(context.t.settings.ktvMode),
          subtitle: Text(context.t.settings.ktvModeHint),
          value: viewModel.ktvMode,
          onChanged: (value) => viewModel.setKtvMode(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off),
          title: Text(context.t.settings.hideDisplayPanel),
          subtitle: Text(context.t.settings.hideDisplayPanelHint),
          value: viewModel.hideDisplayPanel,
          onChanged: (value) => viewModel.setHideDisplayPanel(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.image),
          title: Text(context.t.settings.thumbnailBgLibrary),
          subtitle: Text(context.t.settings.thumbnailBgLibraryHint),
          value: viewModel.useThumbnailBackgroundInLibrary,
          onChanged: (value) =>
              viewModel.setUseThumbnailBackgroundInLibrary(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.queue_music),
          title: Text(context.t.settings.thumbnailBgQueue),
          subtitle: Text(context.t.settings.thumbnailBgQueueHint),
          value: viewModel.useThumbnailBackgroundInQueue,
          onChanged: (value) =>
              viewModel.setUseThumbnailBackgroundInQueue(value),
        ),
      ],
    );
  }

  Widget _buildStorageSection(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return _buildSection(
      context,
      title: context.t.settings.storage,
      icon: Icons.folder,
      children: [
        ListTile(
          leading: const Icon(Icons.storage),
          title: Text(context.t.settings.configMode),
          subtitle: Text(_getConfigModeLabel(context, viewModel.configMode)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showConfigModeDialog(context, viewModel),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(context.t.settings.libraryLocations),
          subtitle: Text(context.t.settings.libraryLocationsHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/library-locations'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: Text(context.t.settings.metadataWriteback),
          subtitle: Text(context.t.settings.metadataWritebackHint),
          value: viewModel.metadataWriteBack,
          onChanged: (value) => viewModel.setMetadataWriteBack(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.library_music),
          title: Text(context.t.settings.autoDiscoverAudio),
          subtitle: Text(context.t.settings.autoDiscoverAudioHint),
          value: viewModel.autoDiscoverAudioFiles,
          onChanged: (value) async {
            await viewModel.setAutoDiscoverAudioFiles(value);
          },
        ),
      ],
    );
  }

  Widget _buildDebugSection(BuildContext context) {
    return _buildSection(
      context,
      title: context.t.settings.debug,
      icon: Icons.bug_report,
      children: [
        ListTile(
          leading: const Icon(Icons.library_music),
          title: Text(context.t.settings.audioEntriesDebug),
          subtitle: Text(context.t.settings.audioEntriesDebugHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/audio-entries-debug'),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(context.t.settings.rescanAudio),
          subtitle: Text(context.t.settings.rescanAudioHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _rescanAudioFiles(context),
        ),
      ],
    );
  }

  Future<void> _rescanAudioFiles(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.settings.rescanTitle),
        content: Text(
          '${context.t.settings.rescanBody}\n\n${context.t.settings.rescanNote}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t.settings.rescan),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Show progress dialog using a custom widget
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _RescanProgressDialog(),
      );

      // Clear all temporary song units
      final libraryRepo = getIt<LibraryRepository>();
      await libraryRepo.deleteAllTemporarySongUnits();

      // Trigger re-discovery with progress callback
      final audioDiscoveryService = getIt<AudioDiscoveryService>();
      final libraryLocationManager = getIt<LibraryLocationManager>();
      final locations = await libraryLocationManager.getLocations();

      await audioDiscoveryService.discoverAudioFiles(
        locations,
        onProgress: _RescanProgressDialog.updateProgress,
      );

      debugPrint('AudioDiscovery: Discovery completed, closing dialog...');

      if (context.mounted) {
        debugPrint('AudioDiscovery: Context is mounted, popping dialog');
        // Use Navigator.of(context, rootNavigator: true) to ensure we pop the dialog
        Navigator.of(context, rootNavigator: true).pop();

        debugPrint(
          'AudioDiscovery: Dialog closed, starting background refresh',
        );

        // Refresh library in background (don't await)
        final libraryViewModel = getIt<LibraryViewModel>();
        libraryViewModel
            .refreshAudioEntries()
            .then((_) {
              debugPrint('AudioDiscovery: Background refresh completed');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t.settings.audioRescanSuccess),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            })
            .catchError((e) {
              debugPrint('AudioDiscovery: Background refresh error: $e');
            });
      } else {
        debugPrint('AudioDiscovery: Context is NOT mounted!');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.settings.errorRescanning.replaceAll('{error}', e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      context,
      title: context.t.settings.about,
      icon: Icons.info,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '0.0.0';
            return ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(context.t.app.name),
              subtitle: Text('${context.t.settings.version} $version'),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(context.t.settings.license),
          subtitle: Text(context.t.settings.licenseValue),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/MyriadOcean/beadline'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        Consumer<SettingsViewModel>(
          builder: (context, viewModel, _) => ListTile(
            leading: Icon(
              Icons.restore,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              context.t.settings.resetFactory,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(context.t.settings.resetFactoryHint),
            onTap: () => _showResetConfirmationDialog(context, viewModel),
          ),
        ),
      ],
    );
  }

  void _showResetConfirmationDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    final errorColor = Theme.of(context).colorScheme.error;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: errorColor, size: 48),
        title: Text(context.t.settings.resetFactoryTitle),
        content: Text(
          '${context.t.settings.resetFactoryBody}\n\n${context.t.settings.resetFactoryItems}\n\n${context.t.settings.resetFactoryNote}\n${context.t.settings.resetFactoryRestart}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _performFullFactoryReset(context, viewModel);
            },
            child: Text(context.t.settings.resetEverything),
          ),
        ],
      ),
    );
  }

  /// Perform a full factory reset: wipe DB, settings, playback state, then
  /// force-restart the application.  Previous attempts to tear down and
  /// re-initialise the service graph in-process kept hitting "database not
  /// initialised" races, so we now simply do the destructive cleanup and exit.
  /// The next launch starts completely fresh.
  Future<void> _performFullFactoryReset(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    try {
      // 0. Stop all playback first
      try {
        final playerEngine = getIt<PlayerEngine>();
        await playerEngine.stop();
      } catch (_) {}

      // 1. Clear playback state
      try {
        final playbackStorage = getIt<PlaybackStateStorage>();
        await playbackStorage.clearPlaybackState();
      } catch (_) {}

      // 2. Delete the settings file
      try {
        final settingsStorage = getIt<SettingsStorage>();
        await settingsStorage.deleteSettings();
      } catch (_) {}

      // 3. Clear thumbnail cache
      try {
        await ThumbnailCache.instance.purgeOrphans({});
      } catch (_) {}

      // 4. Close the Rust database so the file handle is released
      try {
        await rust_db.closeDatabase();
      } catch (_) {}

      // 5. Delete the database file
      try {
        final directory = await getApplicationDocumentsDirectory();
        final dbFile = File(p.join(directory.path, 'beadline_tags.db'));
        if (dbFile.existsSync()) await dbFile.delete();
      } catch (_) {}

      // 6. Exit the application - next launch will start completely fresh.
      //    This avoids all the "database not initialised" races that occur
      //    when trying to tear down and re-build the service graph in-process.
      exit(0);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t.dialogs.resetFailed.replaceAll('{error}', e.toString()))));
      }
    }
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, SettingsViewModel viewModel) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(context.t.common.error, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            viewModel.error ?? 'Unknown error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              viewModel
                ..clearError()
                ..loadSettings();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.t.common.retry),
          ),
        ],
      ),
    );
  }

  void _showUsernameDialog(BuildContext context, SettingsViewModel viewModel) {
    final controller = TextEditingController(text: viewModel.username);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.settings.username),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.t.settings.username,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                viewModel.setUsername(controller.text);
              }
              Navigator.of(context).pop();
            },
            child: Text(context.t.common.save),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.settings.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(context, viewModel, 'system', context.t.settings.themeSystem, Icons.brightness_auto),
            _buildThemeOption(context, viewModel, 'light', context.t.settings.themeLight, Icons.light_mode),
            _buildThemeOption(context, viewModel, 'dark', context.t.settings.themeDark, Icons.dark_mode),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    SettingsViewModel viewModel,
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = viewModel.themeMode == value;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check) : null,
      selected: isSelected,
      onTap: () {
        viewModel.setThemeMode(value);
        Navigator.of(context).pop();
      },
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    final colors = [
      Colors.blue, Colors.indigo, Colors.purple, Colors.pink, Colors.red,
      Colors.orange, Colors.amber, Colors.green, Colors.teal, Colors.cyan,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.settings.accentColor),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Default option
            InkWell(
              onTap: () {
                viewModel.setPrimaryColorSeed(null);
                Navigator.of(context).pop();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                  shape: BoxShape.circle,
                  border: viewModel.primaryColorSeed == null
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
                child: viewModel.primaryColorSeed == null
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            ),
            ...colors.map((color) {
              final colorValue = color.value;
              final isSelected = viewModel.primaryColorSeed == colorValue;
              return InkWell(
                onTap: () {
                  viewModel.setPrimaryColorSeed(colorValue);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final current = viewModel.languageCode;
          final languages = [
            (null, ctx.t.settings.languageSystemDefault, ''),
            ('en', 'English', ''),
            ('zh-Hans', '简体中文', ''),
            ('zh-Hant', '繁體中文', ''),
          ];
          return AlertDialog(
            title: Text(ctx.t.settings.language),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: languages.map((lang) {
                final isSelected = current == lang.$1;
                return ListTile(
                  title: Text(lang.$2),
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  selected: isSelected,
                  onTap: () async {
                    await viewModel.setLanguageCode(lang.$1);
                    if (lang.$1 != null) {
                      await LocaleSettings.setLocaleRaw(lang.$1!);
                    } else {
                      await LocaleSettings.useDeviceLocale();
                    }
                    setDialogState(() {});
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  void _showLyricsModeDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.settings.lyricsMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LyricsMode.values.map((mode) {
            final isDisabled = viewModel.ktvMode && mode == LyricsMode.floating;
            final isSelected = viewModel.lyricsMode == mode;
            return ListTile(
              leading: Icon(_getLyricsModeIcon(mode)),
              title: Text(_getLyricsModeLabel(context, mode)),
              subtitle: isDisabled ? const Text('Disabled in KTV mode') : null,
              trailing: isSelected ? const Icon(Icons.check) : null,
              selected: isSelected,
              enabled: !isDisabled,
              onTap: isDisabled
                  ? null
                  : () {
                      viewModel.setLyricsMode(mode);
                      Navigator.of(context).pop();
                    },
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getLyricsModeIcon(LyricsMode mode) {
    switch (mode) {
      case LyricsMode.off:
        return Icons.lyrics_outlined;
      case LyricsMode.screen:
        return Icons.tv;
      case LyricsMode.floating:
        return Icons.picture_in_picture;
      case LyricsMode.rolling:
        return Icons.view_list;
    }
  }

  String _getLyricsModeLabel(BuildContext context, LyricsMode mode) {
    switch (mode) {
      case LyricsMode.off:
        return context.t.player.lyricsMode.off;
      case LyricsMode.screen:
        return context.t.player.lyricsMode.screen;
      case LyricsMode.floating:
        return context.t.player.lyricsMode.floating;
      case LyricsMode.rolling:
        return context.t.player.lyricsMode.rolling;
    }
  }

  String _getThemeModeLabel(BuildContext context, String mode) {
    switch (mode) {
      case 'light':
        return context.t.settings.themeLight;
      case 'dark':
        return context.t.settings.themeDark;
      default:
        return context.t.settings.themeSystem;
    }
  }

  String _getLanguageLabel(BuildContext context, String? code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'zh-Hans':
        return '简体中文';
      case 'zh-Hant':
        return '繁體中文';
      default:
        return context.t.settings.languageSystemDefault;
    }
  }

  String _getConfigModeLabel(BuildContext context, ConfigurationMode mode) {
    switch (mode) {
      case ConfigurationMode.centralized:
        return context.t.settings.configModeCentralized;
      case ConfigurationMode.inPlace:
        return context.t.settings.configModeInPlace;
    }
  }

  void _showConfigModeDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use Consumer to get fresh viewModel state in the dialog
        return Consumer<SettingsViewModel>(
          builder: (_, vm, _) => AlertDialog(
            title: Text(context.t.settings.configMode),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.configModeChange.description),
                const SizedBox(height: 16),
                ...ConfigurationMode.values.map((mode) {
                  final isSelected = vm.configMode == mode;
                  return ListTile(
                    leading: Icon(
                      mode == ConfigurationMode.centralized
                          ? Icons.folder_special
                          : Icons.folder_open,
                    ),
                    title: Text(_getConfigModeLabel(context, mode)),
                    subtitle: Text(
                      mode == ConfigurationMode.centralized
                          ? context.t.settings.configModeCentralized
                          : context.t.settings.configModeInPlace,
                    ),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    selected: isSelected,
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      if (!isSelected) {
                        await _confirmConfigModeChange(context, vm, mode);
                      }
                    },
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.t.common.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmConfigModeChange(
    BuildContext context,
    SettingsViewModel viewModel,
    ConfigurationMode newMode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.dialogs.confirmModeChange),
        content: Text(
          newMode == ConfigurationMode.inPlace
              ? context.t.configModeChange.inPlaceDescription
              : context.t.configModeChange.centralizedDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t.dialogs.changeMode),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.changeConfigurationModeWithMigration(
        newMode,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Configuration mode changed to ${_getConfigModeLabel(context, newMode)}'
                  : 'Failed to change configuration mode: ${viewModel.error ?? "Unknown error"}',
            ),
            backgroundColor: success
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Progress dialog for auto-discovery scanning
class _AutoDiscoveryProgressDialog extends StatefulWidget {
  static _AutoDiscoveryProgressDialogState? _currentState;

  static void updateProgress(int current, int total, String message) {
    _currentState?.updateProgress(current, total, message);
  }

  @override
  State<_AutoDiscoveryProgressDialog> createState() =>
      _AutoDiscoveryProgressDialogState();
}

class _AutoDiscoveryProgressDialogState
    extends State<_AutoDiscoveryProgressDialog> {
  String _message = 'Scanning for audio files...';
  int _current = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _AutoDiscoveryProgressDialog._currentState = this;
  }

  @override
  void dispose() {
    _AutoDiscoveryProgressDialog._currentState = null;
    super.dispose();
  }

  void updateProgress(int current, int total, String message) {
    if (mounted) {
      setState(() {
        _current = current;
        _total = total;
        _message = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t.dialogs.progressDialogs.discovering),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_message),
          if (_total > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _total > 0 ? _current / _total : null,
            ),
            const SizedBox(height: 8),
            Text(
              '$_current / $_total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress dialog for audio re-scanning
class _RescanProgressDialog extends StatefulWidget {
  static _RescanProgressDialogState? _currentState;

  static void updateProgress(int current, int total, String message) {
    _currentState?.updateProgress(current, total, message);
  }

  @override
  State<_RescanProgressDialog> createState() => _RescanProgressDialogState();
}

class _RescanProgressDialogState extends State<_RescanProgressDialog> {
  String _message = 'Preparing to scan...';
  int _current = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _RescanProgressDialog._currentState = this;
  }

  @override
  void dispose() {
    _RescanProgressDialog._currentState = null;
    super.dispose();
  }

  void updateProgress(int current, int total, String message) {
    if (mounted) {
      setState(() {
        _current = current;
        _total = total;
        _message = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t.dialogs.progressDialogs.rescanning),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_message),
          if (_total > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _total > 0 ? _current / _total : null,
            ),
            const SizedBox(height: 8),
            Text(
              '$_current / $_total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
