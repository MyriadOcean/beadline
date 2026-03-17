import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/app_settings.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_origin.dart';
import '../services/platform_media_player.dart';
import '../services/player_engine.dart';
import '../viewmodels/player_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'home_page.dart';
import 'widgets/cached_thumbnail.dart';

/// Player control panel widget
/// Requirements: 12.2, 13.1
class PlayerControlPanel extends StatelessWidget {
  const PlayerControlPanel({
    super.key,
    required this.viewModel,
    this.isHorizontal = false,
  });
  final PlayerViewModel viewModel;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return _buildHorizontalLayout(context);
    }
    return _buildVerticalLayout(context);
  }

  /// Horizontal layout for bottom bar
  Widget _buildHorizontalLayout(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return _buildMobileLayout(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Song info (left)
          Expanded(flex: 2, child: _buildCompactSongInfo(context)),
          // Main controls (center)
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMainControls(context),
                _buildCompactProgressBar(context),
              ],
            ),
          ),
          // Secondary controls (right)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildSourceSelectionButton(context),
                _buildDisplayModeButton(context),
                _buildAudioModeButton(context),
                _buildPlaybackModeButton(context),
                _buildLyricsModeButton(context),
                _buildFullscreenButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile-optimized layout
  Widget _buildMobileLayout(BuildContext context) {
    final tagViewModel = context.read<TagViewModel>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar at top
          _buildCompactProgressBar(context),
          const SizedBox(height: 4),
          // Controls row
          Row(
            children: [
              // Previous button
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: tagViewModel.hasPrevious
                    ? () async {
                        await tagViewModel.previous();
                        final songUnit = tagViewModel.currentSongUnit;
                        if (songUnit != null) {
                          await viewModel.play(songUnit);
                        }
                      }
                    : null,
                iconSize: 28,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              // Play/Pause button
              IconButton(
                icon: Icon(
                  viewModel.status == PlaybackStatus.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: () => viewModel.togglePlayPause(
                  songUnit: tagViewModel.currentSongUnit,
                ),
                iconSize: 48,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              ),
              // Next button
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: tagViewModel.hasNext
                    ? () async {
                        await tagViewModel.next();
                        final songUnit = tagViewModel.currentSongUnit;
                        if (songUnit != null) {
                          await viewModel.play(songUnit);
                        }
                      }
                    : null,
                iconSize: 28,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 8),
              // Song info
              Expanded(child: _buildMobileSongInfo(context)),
              // More options button
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                iconSize: 20,
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleMobileMenuAction(context, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'source',
                    child: ListTile(
                      leading: const Icon(Icons.source),
                      title: Text(context.t.player.source),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'display',
                    child: ListTile(
                      leading: const Icon(Icons.tv),
                      title: Text(context.t.player.display),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'audio',
                    child: ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(context.t.player.audio),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playback',
                    child: ListTile(
                      leading: const Icon(Icons.repeat),
                      title: Text(context.t.player.playback),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'lyrics',
                    child: ListTile(
                      leading: const Icon(Icons.lyrics),
                      title: Text(context.t.player.lyrics),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSongInfo(BuildContext context) {
    final songUnit = viewModel.currentSongUnit;
    final theme = Theme.of(context);

    if (songUnit == null) {
      return Text(
        context.t.library.noSong,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          songUnit.metadata.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          songUnit.metadata.artistDisplay,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _handleMobileMenuAction(BuildContext context, String action) {
    final songUnit = viewModel.currentSongUnit;
    final settingsVM = context.read<SettingsViewModel>();

    switch (action) {
      case 'source':
        if (songUnit != null) {
          _showSourceSelectionDialog(context, songUnit);
        }
        break;
      case 'display':
        _showDisplayModeMenu(context, settingsVM);
        break;
      case 'audio':
        _showAudioModeMenu(context);
        break;
      case 'playback':
        _showPlaybackModeMenu(context);
        break;
      case 'lyrics':
        _showLyricsModeMenu(context, settingsVM);
        break;
    }
  }

  void _showDisplayModeMenu(
    BuildContext context,
    SettingsViewModel settingsVM,
  ) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t.player.displayMode.label),
        children: DisplayMode.values.map((mode) {
          return RadioListTile<DisplayMode>(
            title: Text(_getDisplayModeLabel(context, mode)),
            value: mode,
            groupValue: settingsVM.displayMode,
            onChanged: (value) {
              if (value != null) {
                settingsVM.setDisplayMode(value);
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showAudioModeMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t.player.audioMode.label),
        children: [
          ListTile(
            title: Text(context.t.player.audioMode.original),
            onTap: () {
              viewModel.switchToOriginal();
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(context.t.player.audioMode.accompaniment),
            onTap: () {
              viewModel.switchToAccompaniment();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showPlaybackModeMenu(BuildContext context) {
    final tagVM = context.read<TagViewModel>();
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t.player.playbackMode.label),
        children: PlaybackMode.values.map((mode) {
          return RadioListTile<PlaybackMode>(
            title: Text(_getPlaybackModeLabel(context, mode)),
            value: mode,
            groupValue: tagVM.playbackMode,
            onChanged: (value) {
              if (value != null) {
                tagVM.setPlaybackMode(value);
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showLyricsModeMenu(BuildContext context, SettingsViewModel settingsVM) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t.player.lyricsMode.label),
        children: LyricsMode.values.map((mode) {
          // Skip floating mode in KTV mode
          if (settingsVM.ktvMode && mode == LyricsMode.floating) {
            return const SizedBox.shrink();
          }
          return RadioListTile<LyricsMode>(
            title: Text(_getLyricsModeLabel(context, mode)),
            value: mode,
            groupValue: settingsVM.lyricsMode,
            onChanged: (value) {
              if (value != null) {
                settingsVM.setLyricsMode(value);
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  String _getDisplayModeLabel(BuildContext context, DisplayMode mode) {
    switch (mode) {
      case DisplayMode.enabled:
        return context.t.player.displayMode.enabled;
      case DisplayMode.imageOnly:
        return context.t.player.displayMode.imageOnly;
      case DisplayMode.disabled:
        return context.t.player.displayMode.disabled;
      case DisplayMode.hidden:
        return context.t.player.displayMode.hidden;
    }
  }

  String _getPlaybackModeLabel(BuildContext context, PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return context.t.player.playbackMode.sequential;
      case PlaybackMode.repeatOne:
        return context.t.player.playbackMode.repeatOne;
      case PlaybackMode.repeatAll:
        return context.t.player.playbackMode.repeatAll;
      case PlaybackMode.random:
        return context.t.player.playbackMode.random;
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

  /// Vertical layout for side panel
  Widget _buildVerticalLayout(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSongInfo(context),
            const SizedBox(height: 16),
            _buildProgressBar(context),
            const SizedBox(height: 16),
            _buildMainControls(context),
            const SizedBox(height: 8),
            _buildSecondaryControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSongInfo(BuildContext context) {
    final songUnit = viewModel.currentSongUnit;
    final theme = Theme.of(context);
    final error = viewModel.error;
    final hasError = viewModel.status == PlaybackStatus.error;

    if (songUnit == null) {
      return Text(
        context.t.player.noSongPlaying,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Row(
      children: [
        // Album art/thumbnail using cached thumbnail
        CachedThumbnail(
          metadata: songUnit.metadata,
          width: 48,
          height: 48,
          borderRadius: BorderRadius.circular(4),
          placeholderIcon: hasError ? Icons.error_outline : Icons.music_note,
          placeholderColor: hasError
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onPrimaryContainer,
          placeholderBackgroundColor: hasError
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                songUnit.metadata.title,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasError && error != null)
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  songUnit.metadata.artistDisplay,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSongInfo(BuildContext context) {
    final songUnit = viewModel.currentSongUnit;
    final theme = Theme.of(context);

    if (songUnit == null) {
      return Text(
        context.t.player.noSongPlaying,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        Text(
          songUnit.metadata.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          songUnit.metadata.artistDisplay,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactProgressBar(BuildContext context) {
    final position = viewModel.position;
    final duration = viewModel.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Row(
      children: [
        Text(
          _formatDuration(position),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                viewModel.seekTo(newPosition);
              },
            ),
          ),
        ),
        Text(
          _formatDuration(duration),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final position = viewModel.position;
    final duration = viewModel.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              viewModel.seekTo(newPosition);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position)),
              Text(_formatDuration(duration)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls(BuildContext context) {
    final isPlaying = viewModel.isPlaying;
    final isLoading = viewModel.isLoading;
    final tagViewModel = context.read<TagViewModel>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: isHorizontal ? 28 : 32,
          onPressed: tagViewModel.hasPrevious
              ? () async {
                  await tagViewModel.previous();
                  final songUnit = tagViewModel.currentSongUnit;
                  if (songUnit != null) {
                    await viewModel.play(songUnit);
                  }
                }
              : null,
          tooltip: context.t.common.back,
        ),
        SizedBox(width: isHorizontal ? 8 : 16),
        IconButton.filled(
          icon: isLoading
              ? SizedBox(
                  width: isHorizontal ? 20 : 24,
                  height: isHorizontal ? 20 : 24,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: isHorizontal ? 36 : 48,
          onPressed: isLoading
              ? null
              : () => viewModel.togglePlayPause(
                  songUnit: tagViewModel.currentSongUnit,
                ),
          tooltip: isPlaying ? context.t.player.pause : context.t.player.play,
        ),
        SizedBox(width: isHorizontal ? 8 : 16),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: isHorizontal ? 28 : 32,
          onPressed: tagViewModel.hasNext
              ? () async {
                  await tagViewModel.next();
                  final songUnit = tagViewModel.currentSongUnit;
                  if (songUnit != null) {
                    await viewModel.play(songUnit);
                  }
                }
              : null,
          tooltip: context.t.player.next,
        ),
      ],
    );
  }

  Widget _buildSecondaryControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSourceSelectionButton(context),
        _buildDisplayModeButton(context),
        _buildAudioModeButton(context),
        _buildPlaybackModeButton(context),
        _buildLyricsModeButton(context),
        _buildFullscreenButton(context),
      ],
    );
  }

  /// Build source selection button for switching between multiple sources
  Widget _buildSourceSelectionButton(BuildContext context) {
    final songUnit = viewModel.currentSongUnit;
    if (songUnit == null) {
      return const SizedBox.shrink();
    }

    // Check if there are multiple sources of any type
    final hasMultipleAudio = songUnit.sources.audioSources.length > 1;
    final hasMultipleAccompaniment =
        songUnit.sources.accompanimentSources.length > 1;
    final hasMultipleLyrics = songUnit.sources.hoverSources.length > 1;
    final hasMultipleDisplay = songUnit.sources.displaySources.length > 1;

    final hasMultipleSources =
        hasMultipleAudio ||
        hasMultipleAccompaniment ||
        hasMultipleLyrics ||
        hasMultipleDisplay;

    if (!hasMultipleSources) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.tune),
      onPressed: () => _showSourceSelectionDialog(context, songUnit),
      tooltip: context.t.player.selectSources,
    );
  }

  /// Build display mode button for controlling display behavior
  Widget _buildDisplayModeButton(BuildContext context) {
    final settingsViewModel = context.watch<SettingsViewModel>();
    final currentMode = settingsViewModel.displayMode;

    return PopupMenuButton<DisplayMode>(
      icon: Icon(_getDisplayModeIcon(currentMode)),
      tooltip: '${context.t.player.displayMode.label}: ${_getDisplayModeName(context, currentMode)}',
      onSelected: (mode) {
        settingsViewModel.setDisplayMode(mode);
        viewModel.setDisplayMode(mode);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: DisplayMode.enabled,
          child: ListTile(
            leading: const Icon(Icons.tv),
            title: Text(context.t.player.displayMode.enabled),
            trailing: currentMode == DisplayMode.enabled
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: DisplayMode.imageOnly,
          child: ListTile(
            leading: const Icon(Icons.image),
            title: Text(context.t.player.displayMode.imageOnly),
            trailing: currentMode == DisplayMode.imageOnly
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: DisplayMode.disabled,
          child: ListTile(
            leading: const Icon(Icons.lyrics),
            title: Text(context.t.player.displayMode.disabled),
            trailing: currentMode == DisplayMode.disabled
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: DisplayMode.hidden,
          child: ListTile(
            leading: const Icon(Icons.visibility_off),
            title: Text(context.t.player.displayMode.hidden),
            trailing: currentMode == DisplayMode.hidden
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
      ],
    );
  }

  IconData _getDisplayModeIcon(DisplayMode mode) {
    switch (mode) {
      case DisplayMode.enabled:
        return Icons.tv;
      case DisplayMode.imageOnly:
        return Icons.image;
      case DisplayMode.disabled:
        return Icons.lyrics;
      case DisplayMode.hidden:
        return Icons.visibility_off;
    }
  }

  String _getDisplayModeName(BuildContext context, DisplayMode mode) {
    switch (mode) {
      case DisplayMode.enabled:
        return context.t.player.displayMode.enabled;
      case DisplayMode.imageOnly:
        return context.t.player.displayMode.imageOnly;
      case DisplayMode.disabled:
        return context.t.player.displayMode.disabled;
      case DisplayMode.hidden:
        return context.t.player.displayMode.hidden;
    }
  }

  /// Show dialog for selecting active sources
  void _showSourceSelectionDialog(BuildContext context, dynamic songUnit) {
    showDialog(
      context: context,
      builder: (dialogContext) => _SourceSelectionDialog(
        songUnit: songUnit,
        playerViewModel: viewModel,
      ),
    );
  }

  Widget _buildAudioModeButton(BuildContext context) {
    final audioMode = viewModel.audioMode;
    final isOriginal = audioMode == AudioMode.original;

    if (isHorizontal) {
      return IconButton(
        icon: Icon(isOriginal ? Icons.music_note : Icons.mic),
        onPressed: viewModel.toggleAudioMode,
        tooltip: isOriginal ? context.t.player.audioMode.original : context.t.player.audioMode.accompaniment,
        color: isOriginal
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary,
      );
    }

    return TextButton.icon(
      icon: Icon(isOriginal ? Icons.music_note : Icons.mic),
      label: Text(isOriginal ? context.t.player.audioMode.original : context.t.player.audioMode.accompaniment),
      onPressed: viewModel.toggleAudioMode,
      style: TextButton.styleFrom(
        foregroundColor: isOriginal
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildPlaybackModeButton(BuildContext context) {
    final tagViewModel = context.watch<TagViewModel>();
    final currentMode = tagViewModel.playbackMode;

    return PopupMenuButton<PlaybackMode>(
      icon: Icon(_getPlaybackModeIcon(currentMode)),
      tooltip: '${context.t.player.playbackMode.label}: ${_getPlaybackModeName(context, currentMode)}',
      onSelected: tagViewModel.setPlaybackMode,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: PlaybackMode.sequential,
          child: ListTile(
            leading: const Icon(Icons.arrow_forward),
            title: Text(context.t.player.playbackMode.sequential),
            trailing: currentMode == PlaybackMode.sequential
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: PlaybackMode.repeatAll,
          enabled: !tagViewModel.removeAfterPlay,
          child: ListTile(
            leading: Icon(
              Icons.repeat,
              color: tagViewModel.removeAfterPlay ? Colors.grey : null,
            ),
            title: Text(
              context.t.player.playbackMode.repeatAll,
              style: tagViewModel.removeAfterPlay
                  ? const TextStyle(color: Colors.grey)
                  : null,
            ),
            trailing: currentMode == PlaybackMode.repeatAll
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: PlaybackMode.repeatOne,
          enabled: !tagViewModel.removeAfterPlay,
          child: ListTile(
            leading: Icon(
              Icons.repeat_one,
              color: tagViewModel.removeAfterPlay ? Colors.grey : null,
            ),
            title: Text(
              context.t.player.playbackMode.repeatOne,
              style: tagViewModel.removeAfterPlay
                  ? const TextStyle(color: Colors.grey)
                  : null,
            ),
            trailing: currentMode == PlaybackMode.repeatOne
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: PlaybackMode.random,
          child: ListTile(
            leading: const Icon(Icons.shuffle),
            title: Text(context.t.player.playbackMode.random),
            trailing: currentMode == PlaybackMode.random
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
      ],
    );
  }

  IconData _getPlaybackModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return Icons.arrow_forward;
      case PlaybackMode.repeatAll:
        return Icons.repeat;
      case PlaybackMode.repeatOne:
        return Icons.repeat_one;
      case PlaybackMode.random:
        return Icons.shuffle;
    }
  }

  String _getPlaybackModeName(BuildContext context, PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return context.t.player.playbackMode.sequential;
      case PlaybackMode.repeatAll:
        return context.t.player.playbackMode.repeatAll;
      case PlaybackMode.repeatOne:
        return context.t.player.playbackMode.repeatOne;
      case PlaybackMode.random:
        return context.t.player.playbackMode.random;
    }
  }

  Widget _buildLyricsModeButton(BuildContext context) {
    final settingsViewModel = context.watch<SettingsViewModel>();
    final currentMode = settingsViewModel.lyricsMode;
    final isKtvMode = settingsViewModel.ktvMode;

    return PopupMenuButton<LyricsMode>(
      icon: Icon(
        _getLyricsModeIcon(currentMode),
        color: currentMode != LyricsMode.off
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      tooltip: '${context.t.player.lyricsMode.label}: ${currentMode.name}',
      onSelected: settingsViewModel.setLyricsMode,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: LyricsMode.off,
          child: ListTile(
            leading: const Icon(Icons.lyrics_outlined),
            title: Text(context.t.player.lyricsMode.off),
            trailing: currentMode == LyricsMode.off
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: LyricsMode.screen,
          child: ListTile(
            leading: const Icon(Icons.tv),
            title: Text(context.t.player.lyricsMode.screen),
            trailing: currentMode == LyricsMode.screen
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: LyricsMode.floating,
          enabled: !isKtvMode,
          child: ListTile(
            leading: Icon(
              Icons.picture_in_picture,
              color: isKtvMode ? Colors.grey : null,
            ),
            title: Text(
              context.t.player.lyricsMode.floating,
              style: isKtvMode ? const TextStyle(color: Colors.grey) : null,
            ),
            trailing: currentMode == LyricsMode.floating
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: LyricsMode.rolling,
          enabled: !isKtvMode,
          child: ListTile(
            leading: Icon(
              Icons.view_list,
              color: isKtvMode ? Colors.grey : null,
            ),
            title: Text(
              context.t.player.lyricsMode.rolling,
              style: isKtvMode ? const TextStyle(color: Colors.grey) : null,
            ),
            trailing: currentMode == LyricsMode.rolling
                ? const Icon(Icons.check)
                : null,
            dense: true,
          ),
        ),
      ],
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

  Widget _buildFullscreenButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.fullscreen),
      onPressed: () {
        final homePageState = context.findAncestorStateOfType<HomePageState>();
        homePageState?.toggleFullscreen();
      },
      tooltip: context.t.player.fullscreen,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Playback mode enum
enum PlaybackMode { sequential, repeatAll, repeatOne, random }

/// Dialog for selecting active sources when multiple are available
class _SourceSelectionDialog extends StatefulWidget {
  const _SourceSelectionDialog({
    required this.songUnit,
    required this.playerViewModel,
  });
  final SongUnit songUnit;
  final PlayerViewModel playerViewModel;

  @override
  State<_SourceSelectionDialog> createState() => _SourceSelectionDialogState();
}

class _SourceSelectionDialogState extends State<_SourceSelectionDialog> {
  late String? _selectedAudioId;
  late String? _selectedAccompanimentId;
  late String? _selectedLyricsId;
  late String? _selectedDisplayId;

  @override
  void initState() {
    super.initState();
    final prefs = widget.songUnit.preferences;
    _selectedAudioId =
        prefs.preferredAudioSourceId ??
        widget.songUnit.sources.audioSources.firstOrNull?.id;
    _selectedAccompanimentId =
        prefs.preferredAccompanimentSourceId ??
        widget.songUnit.sources.accompanimentSources.firstOrNull?.id;
    _selectedLyricsId =
        prefs.preferredHoverSourceId ??
        widget.songUnit.sources.hoverSources.firstOrNull?.id;
    _selectedDisplayId =
        prefs.preferredDisplaySourceId ??
        widget.songUnit.sources.displaySources.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = widget.songUnit.sources;

    return AlertDialog(
      title: Text(context.t.player.selectSources),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Audio sources
              if (sources.audioSources.length > 1) ...[
                Text(context.t.player.audio, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...sources.audioSources.map(
                  (source) => _buildSourceTile(
                    source: source,
                    isSelected: _selectedAudioId == source.id,
                    onTap: () => setState(() => _selectedAudioId = source.id),
                    icon: Icons.audiotrack,
                  ),
                ),
                const Divider(),
              ],

              // Accompaniment sources
              if (sources.accompanimentSources.length > 1) ...[
                Text(context.t.player.audioMode.accompaniment, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...sources.accompanimentSources.map(
                  (source) => _buildSourceTile(
                    source: source,
                    isSelected: _selectedAccompanimentId == source.id,
                    onTap: () =>
                        setState(() => _selectedAccompanimentId = source.id),
                    icon: Icons.mic,
                    showOffset: true,
                  ),
                ),
                const Divider(),
              ],

              // Lyrics sources
              if (sources.hoverSources.length > 1) ...[
                Text(context.t.player.lyrics, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...sources.hoverSources.map(
                  (source) => _buildSourceTile(
                    source: source,
                    isSelected: _selectedLyricsId == source.id,
                    onTap: () => setState(() => _selectedLyricsId = source.id),
                    icon: Icons.lyrics,
                    showOffset: true,
                  ),
                ),
                const Divider(),
              ],

              // Display sources
              if (sources.displaySources.length > 1) ...[
                Text(context.t.player.display, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...sources.displaySources.map(
                  (source) => _buildSourceTile(
                    source: source,
                    isSelected: _selectedDisplayId == source.id,
                    onTap: () => setState(() => _selectedDisplayId = source.id),
                    icon: source.displayType == DisplayType.video
                        ? Icons.videocam
                        : Icons.image,
                    showOffset: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        FilledButton(onPressed: _applySelection, child: Text(context.t.common.apply)),
      ],
    );
  }

  Widget _buildSourceTile({
    required Source source,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    bool showOffset = false,
  }) {
    final theme = Theme.of(context);
    final origin = source.origin;
    var originPath = '';

    // Get source name from origin
    if (origin is LocalFileOrigin) {
      originPath = origin.path.split('/').last.split('\\').last;
    } else if (origin is UrlOrigin) {
      originPath = origin.url;
    } else if (origin is ApiOrigin) {
      originPath = '${origin.provider}: ${origin.resourceId}';
    }

    // Use display name if available, otherwise use origin path
    final displayName = source.displayName ?? originPath;

    // Add offset info if applicable
    Duration? offset;
    if (showOffset) {
      if (source is DisplaySource) {
        offset = source.offset;
      } else if (source is AccompanimentSource) {
        offset = source.offset;
      } else if (source is HoverSource) {
        offset = source.offset;
      }
    }

    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : null),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (source.displayName != null)
            Text(
              originPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (offset != null && offset != Duration.zero)
            Text(
              'Offset: ${_formatOffset(offset)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
        ],
      ),
      trailing: isSelected ? const Icon(Icons.check) : null,
      selected: isSelected,
      onTap: onTap,
      dense: true,
    );
  }

  String _formatOffset(Duration offset) {
    final ms = offset.inMilliseconds;
    if (ms >= 0) {
      return '+${ms}ms';
    } else {
      return '${ms}ms';
    }
  }

  void _applySelection() {
    // Update the song unit preferences and notify the player
    widget.playerViewModel.updateSourceSelection(
      audioSourceId: _selectedAudioId,
      accompanimentSourceId: _selectedAccompanimentId,
      hoverSourceId: _selectedLyricsId,
      displaySourceId: _selectedDisplayId,
    );
    Navigator.of(context).pop();
  }
}
