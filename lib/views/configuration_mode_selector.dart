import 'package:flutter/material.dart';
import '../i18n/translations.g.dart';

import '../models/configuration_mode.dart';

/// Widget for selecting configuration storage mode on first launch.
/// Displays options for centralized vs in-place storage with explanations.
/// Requirements: 3.1
class ConfigurationModeSelector extends StatefulWidget {
  const ConfigurationModeSelector({
    super.key,
    required this.onModeSelected,
    this.onSetupLibraryLocations,
  });

  /// Callback when a configuration mode is selected
  final void Function(ConfigurationMode mode) onModeSelected;

  /// Optional callback to trigger library location setup after in-place mode selection
  final VoidCallback? onSetupLibraryLocations;

  @override
  State<ConfigurationModeSelector> createState() =>
      _ConfigurationModeSelectorState();
}

class _ConfigurationModeSelectorState extends State<ConfigurationModeSelector> {
  ConfigurationMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ScrollConfiguration(
          // Hide scrollbar for cleaner look
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 32),
                      _buildModeOption(
                        theme,
                        mode: ConfigurationMode.centralized,
                        title: context.t.configMode.centralizedTitle,
                        icon: Icons.folder_special,
                        description: context.t.configMode.centralizedDesc,
                        benefits: context.t.configMode.centralizedPros.split('\n'),
                        considerations: context.t.configMode.centralizedCons.split('\n'),
                      ),
                      const SizedBox(height: 16),
                      _buildModeOption(
                        theme,
                        mode: ConfigurationMode.inPlace,
                        title: context.t.configMode.inPlaceTitle,
                        icon: Icons.folder_open,
                        description: context.t.configMode.inPlaceDesc,
                        benefits: context.t.configMode.inPlacePros.split('\n'),
                        considerations: context.t.configMode.inPlaceCons.split('\n'),
                      ),
                      const SizedBox(height: 32),
                      _buildContinueButton(theme),
                      const SizedBox(height: 16),
                      Text(
                        context.t.configMode.changeNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.music_note, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          context.t.configMode.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.t.configMode.subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildModeOption(
    ThemeData theme, {
    required ConfigurationMode mode,
    required String title,
    required IconData icon,
    required String description,
    required List<String> benefits,
    required List<String> considerations,
  }) {
    final isSelected = _selectedMode == mode;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Radio<ConfigurationMode>(
                    value: mode,
                    groupValue: _selectedMode,
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildBulletList(
                theme,
                items: benefits,
                icon: Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              _buildBulletList(
                theme,
                items: considerations,
                icon: Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletList(
    ThemeData theme, {
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    return FilledButton(
      onPressed: _selectedMode != null
          ? () {
              widget.onModeSelected(_selectedMode!);
              // Both modes should trigger library location setup
              widget.onSetupLibraryLocations?.call();
            }
          : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(context.t.common.continueText),
    );
  }
}
