import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../i18n/translations.g.dart';

import '../services/library_location_manager.dart';
import '../services/permission_service.dart';

/// Dialog for setting up library locations after configuration mode selection
class LibraryLocationSetupDialog extends StatefulWidget {
  const LibraryLocationSetupDialog({
    super.key,
    required this.libraryLocationManager,
    required this.permissionService,
    this.onComplete,
  });

  final LibraryLocationManager libraryLocationManager;
  final PermissionService permissionService;
  final VoidCallback? onComplete;

  @override
  State<LibraryLocationSetupDialog> createState() =>
      _LibraryLocationSetupDialogState();
}

class _LibraryLocationSetupDialogState
    extends State<LibraryLocationSetupDialog> {
  final List<String> _selectedPaths = [];
  bool _isLoading = false;
  String? _error;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermissions = await widget.permissionService
        .hasStoragePermissions();
    setState(() {
      _permissionsGranted = hasPermissions;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final granted = await widget.permissionService.requestStoragePermissions();

    setState(() {
      _isLoading = false;
      _permissionsGranted = granted;
      if (!granted) {
        _error = context.t.settings.storagePermissionBody;
      }
    });
  }

  Future<void> _addLocation() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Library Location',
      );

      if (result != null && !_selectedPaths.contains(result)) {
        setState(() {
          _selectedPaths.add(result);
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to select directory: $e';
      });
    }
  }

  void _removeLocation(String path) {
    setState(() {
      _selectedPaths.remove(path);
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedPaths.isEmpty) {
      setState(() {
        _error = 'Please add at least one library location.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Add all selected locations
      for (var i = 0; i < _selectedPaths.length; i++) {
        final path = _selectedPaths[i];
        final name = _getLocationName(path);
        final location = await widget.libraryLocationManager.addLocation(
          path,
          name: name,
        );

        // Set first location as default
        if (i == 0) {
          await widget.libraryLocationManager.setDefaultLocation(location.id);
        }
      }

      if (mounted) {
        widget.onComplete?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to save library locations: $e';
      });
    }
  }

  String _getLocationName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.last.isEmpty ? parts[parts.length - 2] : parts.last;
  }

  void _skip() {
    widget.onComplete?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.t.locationSetup.title),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add folders where your music files are stored. Beadline will automatically scan these locations and monitor for changes.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Permission status
            if (!_permissionsGranted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Storage permissions required',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _requestPermissions,
                      child: Text(context.t.common.grant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Selected locations list
            if (_selectedPaths.isNotEmpty) ...[
              Text('${context.t.locationSetup.selectedLocations}:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _selectedPaths.length,
                  itemBuilder: (context, index) {
                    final path = _selectedPaths[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.folder,
                        color: index == 0 ? theme.colorScheme.primary : null,
                      ),
                      title: Text(
                        _getLocationName(path),
                        style: index == 0
                            ? TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeLocation(path),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Add location button
            OutlinedButton.icon(
              onPressed: _isLoading || !_permissionsGranted
                  ? null
                  : _addLocation,
              icon: const Icon(Icons.add),
              label: Text(context.t.locationSetup.addLocation),
            ),

            if (_selectedPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'The first location will be used as the default for new song units.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _skip,
          child: Text(context.t.common.skip),
        ),
        FilledButton(
          onPressed: _isLoading || _selectedPaths.isEmpty
              ? null
              : _saveAndContinue,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.t.common.continueText),
        ),
      ],
    );
  }
}
