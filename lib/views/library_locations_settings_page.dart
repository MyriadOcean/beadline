import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/configuration_mode.dart';
import '../models/library_location.dart';
import '../services/configuration_migration_service.dart';
import '../services/discovery_service.dart';
import '../services/library_location_manager.dart';
import '../viewmodels/library_view_model.dart';

/// Settings page for managing library locations
/// Library locations are directories where Song Unit data and source files are stored.
/// Discovery is automatically triggered when a new location is added.
/// Requirements: 1.1, 1.3, 1.5, 6.2
class LibraryLocationsSettingsPage extends StatefulWidget {
  const LibraryLocationsSettingsPage({
    super.key,
    required this.libraryLocationManager,
    this.discoveryService,
    this.migrationService,
    this.globalConfigMode = ConfigurationMode.centralized,
    this.onLocationAdded,
  });
  final LibraryLocationManager libraryLocationManager;
  final DiscoveryService? discoveryService;
  final ConfigurationMigrationService? migrationService;
  final ConfigurationMode globalConfigMode;

  /// Called after a new location is added (for triggering audio discovery, etc.)
  final void Function(LibraryLocation location)? onLocationAdded;

  @override
  State<LibraryLocationsSettingsPage> createState() =>
      _LibraryLocationsSettingsPageState();
}

class _LibraryLocationsSettingsPageState
    extends State<LibraryLocationsSettingsPage> {
  List<LibraryLocation> _locations = [];
  bool _isLoading = true;
  String? _error;

  // Discovery state
  bool _isDiscovering = false;
  bool _isMigrating = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final locations = await widget.libraryLocationManager
          .refreshAccessibility();
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addLocation() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Library Location',
    );

    if (result == null) return;

    // Show name dialog
    final name = await _showNameDialog(result);
    if (name == null) return;

    setState(() => _isLoading = true);

    try {
      final location = await widget.libraryLocationManager.addLocation(
        result,
        name: name,
      );
      await _loadLocations();

      // Automatically run discovery on the new location
      if (widget.discoveryService != null && mounted) {
        _runDiscoveryOnLocation(location);
      }

      // Notify caller so they can trigger audio discovery, file watcher refresh, etc.
      widget.onLocationAdded?.call(location);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t.libraryLocations.locationAdded)));
      }
    } on LibraryLocationException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Run discovery on a specific location (called after adding a new location)
  Future<void> _runDiscoveryOnLocation(LibraryLocation location) async {
    if (widget.discoveryService == null) return;

    setState(() {
      _isDiscovering = true;
    });

    try {
      final results = await widget.discoveryService!.collectResults(
        widget.discoveryService!.scanLocation(location),
      );

      // Auto-import all new entry points
      final imported = await widget.discoveryService!.importAllNew(results);

      setState(() {
        _isDiscovering = false;
      });

      if (mounted && imported.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.libraryLocations.discoveredImported.replaceAll('{count}', imported.length.toString()),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  /// Toggle a location's config mode between in-place and centralized
  Future<void> _toggleLocationConfigMode(LibraryLocation location) async {
    if (widget.migrationService == null) return;

    final effectiveMode =
        location.configMode ?? widget.globalConfigMode;
    final newMode = effectiveMode == ConfigurationMode.inPlace
        ? ConfigurationMode.centralized
        : ConfigurationMode.inPlace;

    final modeLabel = newMode == ConfigurationMode.inPlace
        ? 'In-Place'
        : 'Centralized';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newMode == ConfigurationMode.inPlace
            ? context.t.libraryLocations.switchToInPlace
            : context.t.libraryLocations.switchToCentralized),
        content: Text(
          newMode == ConfigurationMode.inPlace
              ? context.t.libraryLocations.migrateToInPlaceBody.replaceAll('{path}', location.name)
              : context.t.libraryLocations.migrateToCentralizedBody.replaceAll('{path}', location.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t.common.migrate),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isMigrating = true);

    try {
      final success = await widget.migrationService!.migrateLocationEntryPoints(
        location: location,
        toMode: newMode,
        allLocations: _locations,
      );

      // Update the location's config mode
      await widget.libraryLocationManager.updateLocationConfigMode(
        location.id,
        newMode,
      );
      await _loadLocations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (newMode == ConfigurationMode.inPlace
                      ? context.t.libraryLocations.switchedToInPlace
                      : context.t.libraryLocations.switchedToCentralized)
                  : context.t.libraryLocations.migrationFailed,
            ),
            backgroundColor: success ? null : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t.libraryLocations.migrationError}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  Future<String?> _showNameDialog(String path) async {
    final controller = TextEditingController(
      text: path.split('/').where((p) => p.isNotEmpty).lastOrNull ?? 'Library',
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.libraryLocations.nameLocation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              path,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.t.libraryLocations.nameLabel,
                hintText: context.t.libraryLocations.enterLocationName,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.t.common.add),
          ),
        ],
      ),
    );
  }

  Future<void> _removeLocation(LibraryLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.libraryLocations.removeLocation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.t.libraryLocations.removeLocationConfirm} "${location.name}"?'),
            const SizedBox(height: 8),
            Text(
              context.t.libraryLocations.removeLocationNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.t.common.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Remove all song units and temporary entries from this location
      try {
        final libraryViewModel = context.read<LibraryViewModel>();
        debugPrint('LibraryLocationsSettingsPage: Removing entries for location ${location.id}');
        await libraryViewModel.removeLocationEntries(location.id);
        debugPrint('LibraryLocationsSettingsPage: Entries removed');
      } catch (e) {
        debugPrint('Failed to remove location entries: $e');
      }

      await widget.libraryLocationManager.removeLocation(location.id);
      await _loadLocations();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.t.libraryLocations.removed} "${location.name}"')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t.libraryLocations.failedToRemove}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _setDefault(LibraryLocation location) async {
    if (location.isDefault) return;

    setState(() => _isLoading = true);

    try {
      await widget.libraryLocationManager.setDefaultLocation(location.id);
      await _loadLocations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${location.name}" ${context.t.libraryLocations.isNowDefault}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t.libraryLocations.failedToSetDefault}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editName(LibraryLocation location) async {
    final controller = TextEditingController(text: location.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.libraryLocations.renameLocation),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: context.t.libraryLocations.nameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.t.common.save),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == location.name) return;

    setState(() => _isLoading = true);

    try {
      await widget.libraryLocationManager.updateLocationName(
        location.id,
        newName,
      );
      await _loadLocations();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.libraryLocations.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
            tooltip: context.t.common.refresh,
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(Icons.add),
        label: Text(context.t.locationSetup.addLocation),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    if (_locations.isEmpty) {
      return _buildEmptyState(context);
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _locations.length,
          itemBuilder: (context, index) {
            return _buildLocationTile(context, _locations[index]);
          },
        ),
        if (_isDiscovering || _isMigrating)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _isMigrating
                            ? context.t.settings.migratingEntryPoints
                            : context.t.settings.scanningForSongUnits,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(context.t.dialogs.libraryLocationsError.errorLoading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadLocations,
            icon: const Icon(Icons.refresh),
            label: Text(context.t.dialogs.libraryLocationsError.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.dialogs.noLocationsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.dialogs.addLocationToStoreMusic,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(BuildContext context, LibraryLocation location) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: _buildLocationIcon(context, location),
            title: Row(
              children: [
                Expanded(
                  child: Text(location.name, overflow: TextOverflow.ellipsis),
                ),
                if (location.isDefault)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Default',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  location.rootPath,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildAccessibilityStatus(context, location),
                    const SizedBox(width: 12),
                    _buildConfigModeChip(context, location),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, location),
              itemBuilder: (context) {
                final effectiveMode =
                    location.configMode ?? widget.globalConfigMode;
                final isInPlace =
                    effectiveMode == ConfigurationMode.inPlace;

                return [
                  PopupMenuItem(
                    value: 'toggle_mode',
                    child: ListTile(
                      leading: Icon(
                        isInPlace ? Icons.cloud_upload : Icons.save_alt,
                      ),
                      title: Text(
                        isInPlace
                            ? context.t.libraryLocations.switchToCentralized
                            : context.t.libraryLocations.switchToInPlace,
                      ),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: const Icon(Icons.edit),
                      title: Text(context.t.common.rename),
                      dense: true,
                    ),
                  ),
                  if (!location.isDefault)
                    PopupMenuItem(
                      value: 'set_default',
                      child: ListTile(
                        leading: const Icon(Icons.star),
                        title: Text(context.t.libraryLocations.setAsDefault),
                        dense: true,
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: Text(
                        context.t.common.remove,
                        style: const TextStyle(color: Colors.red),
                      ),
                      dense: true,
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationIcon(BuildContext context, LibraryLocation location) {
    final theme = Theme.of(context);

    if (!location.isAccessible) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.folder_off,
          color: theme.colorScheme.onErrorContainer,
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: location.isDefault
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        location.isDefault ? Icons.folder_special : Icons.folder,
        color: location.isDefault
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildAccessibilityStatus(
    BuildContext context,
    LibraryLocation location,
  ) {
    final theme = Theme.of(context);

    if (location.isAccessible) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            context.t.libraryLocations.accessible,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning, size: 14, color: theme.colorScheme.error),
        const SizedBox(width: 4),
        Text(
          context.t.libraryLocations.inaccessible,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigModeChip(BuildContext context, LibraryLocation location) {
    final theme = Theme.of(context);
    final effectiveMode = location.configMode ?? widget.globalConfigMode;
    final isInPlace = effectiveMode == ConfigurationMode.inPlace;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isInPlace ? Icons.save_alt : Icons.cloud,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          isInPlace ? context.t.libraryLocations.inPlace : context.t.libraryLocations.centralized,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action, LibraryLocation location) {
    switch (action) {
      case 'rename':
        _editName(location);
      case 'set_default':
        _setDefault(location);
      case 'remove':
        _removeLocation(location);
      case 'toggle_mode':
        _toggleLocationConfigMode(location);
    }
  }
}
