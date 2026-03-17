import 'dart:io';

import 'package:beadline/services/player_engine.dart' show PlayerEngine;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../i18n/translations.g.dart';
import '../models/app_settings.dart';
import '../models/source.dart';
import '../models/source_origin.dart';
import '../services/lrc_parser.dart';
import '../viewmodels/player_view_model.dart';
import 'lyrics_widgets.dart' show RollingLyricsWidget, ScreenLyricsWidget;

/// Display screen widget for video/image rendering.
///
/// Uses the shared media_kit [Player] owned by [PlayerEngine]
/// (exposed via [PlayerViewModel.videoNativePlayer]) so that
/// volume / mute routing from PlayerEngine affects rendered video.
class DisplayScreen extends StatefulWidget {
  const DisplayScreen({
    super.key,
    required this.viewModel,
    this.lyrics,
    this.lyricsMode = LyricsMode.off,
    this.displayMode = DisplayMode.enabled,
    this.ktvMode = false,
    this.isFullscreen = false,
    this.onToggleFullscreen,
  });

  final PlayerViewModel viewModel;
  final ParsedLyrics? lyrics;
  final LyricsMode lyricsMode;
  final DisplayMode displayMode;
  final bool ktvMode;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
    _ensureVideoController();
  }

  @override
  void didUpdateWidget(DisplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_onViewModelChanged);
      widget.viewModel.addListener(_onViewModelChanged);
    }

    _ensureVideoController();
  }

  void _onViewModelChanged() {
    _ensureVideoController();
    if (mounted) setState(() {});
  }

  /// Ensure the video controller exists.
  /// Uses the shared Player from PlayerEngine.
  void _ensureVideoController() {
    final nativePlayer = widget.viewModel.videoNativePlayer;
    if (nativePlayer == null) return;
    if (_videoController != null) return;

    _videoController = VideoController(nativePlayer);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSource = widget.viewModel.activeDisplaySource;
    final songUnit = widget.viewModel.currentSongUnit;

    return Card(
      margin: widget.isFullscreen ? EdgeInsets.zero : const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onDoubleTap: widget.onToggleFullscreen,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildDisplayContent(context, activeSource),

              if (songUnit != null && !widget.isFullscreen)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildSourceSelector(context),
                ),

              _buildLyricsOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayContent(BuildContext context, Source? source) {
    if (widget.displayMode == DisplayMode.disabled) {
      return _buildCleanBackground(context);
    }

    if (source == null) {
      return _buildPlaceholder(context);
    }

    if (source is DisplaySource) {
      if (widget.displayMode == DisplayMode.imageOnly &&
          source.displayType == DisplayType.video) {
        return _buildCleanBackground(context);
      }

      switch (source.displayType) {
        case DisplayType.video:
          return _buildVideoPlayer(context, source);

        case DisplayType.image:
          return _buildImageDisplay(context, source);
      }
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_video,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.display.noSource,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanBackground(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(BuildContext context, DisplaySource source) {
    if (_videoController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              context.t.display.loading.replaceAll(
                '{name}',
                _getSourceName(source),
              ),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * 9.0 / 16.0,
        // Use [Video] widget to display video output.
        child: Video(controller: _videoController!, controls: NoVideoControls),
      ),
    );
  }

  Widget _buildImageDisplay(BuildContext context, DisplaySource source) {
    final origin = source.origin;

    Widget imageWidget;

    switch (origin) {
      case LocalFileOrigin(path: final path):
        final file = File(path);

        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildImageError(context, source),
          );
        } else {
          imageWidget = _buildImageError(context, source);
        }

      case UrlOrigin(url: final url):
        imageWidget = Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;

            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          },
          errorBuilder: (_, _, _) => _buildImageError(context, source),
        );

      case ApiOrigin():
        imageWidget = _buildImageError(context, source);
    }

    return Center(child: imageWidget);
  }

  Widget _buildImageError(BuildContext context, DisplaySource source) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            context.t.display.failedToLoad.replaceAll(
              '{name}',
              _getSourceName(source),
            ),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector(BuildContext context) {
    final displaySources = widget.viewModel.getDisplaySources();

    if (displaySources.length <= 1) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<Source>(
      icon: const Icon(Icons.switch_video, color: Colors.white70),
      onSelected: (source) {
        if (source is DisplaySource) {
          widget.viewModel.switchDisplaySource(source);
        }
      },
      itemBuilder: (context) {
        return displaySources.map((source) {
          final isActive =
              source.id == widget.viewModel.activeDisplaySource?.id;

          return PopupMenuItem(
            value: source,
            child: ListTile(
              leading: Icon(
                source is DisplaySource &&
                        source.displayType == DisplayType.video
                    ? Icons.videocam
                    : Icons.image,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(_getSourceName(source)),
              trailing: isActive ? const Icon(Icons.check) : null,
              dense: true,
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildLyricsOverlay(BuildContext context) {
    final effectiveMode = widget.ktvMode
        ? LyricsMode.screen
        : widget.lyricsMode;

    if (effectiveMode == LyricsMode.off ||
        effectiveMode == LyricsMode.floating) {
      return const SizedBox.shrink();
    }

    final lyrics = widget.lyrics ?? widget.viewModel.currentLyrics;

    if (lyrics == null || lyrics.isEmpty) {
      return const SizedBox.shrink();
    }

    final audioPosition = widget.viewModel.position;

    final activeHoverSource = widget.viewModel.activeHoverSource;

    final lyricsOffset = (activeHoverSource is HoverSource)
        ? activeHoverSource.offset
        : Duration.zero;

    final lyricsPosition = audioPosition - lyricsOffset;

    if (effectiveMode == LyricsMode.rolling) {
      return Positioned.fill(
        child: IgnorePointer(
          child: RollingLyricsWidget(lyrics: lyrics, position: lyricsPosition),
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: ScreenLyricsWidget(
          lyrics: lyrics,
          position: lyricsPosition,
          ktvStyle: widget.ktvMode,
        ),
      ),
    );
  }

  String _getSourceName(Source source) {
    final origin = source.origin;

    switch (origin) {
      case LocalFileOrigin(path: final path):
        return path.split('/').last;

      case UrlOrigin(url: final url):
        return Uri.parse(url).pathSegments.lastOrNull ?? 'URL';

      case ApiOrigin(provider: final provider):
        return provider;
    }
  }
}
