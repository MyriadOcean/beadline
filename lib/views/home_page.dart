import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:provider/provider.dart';

import '../i18n/translations.g.dart';
import '../models/app_settings.dart';
import '../models/source.dart';
import '../services/desktop_window_manager.dart' as desktop;

import '../viewmodels/library_view_model.dart';
import '../viewmodels/player_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'display_screen.dart';
import 'floating_lyrics_window.dart';
import 'library_view.dart';
import 'player_control_panel.dart';
import 'playlists_management_page.dart';
import 'settings_view.dart';
import 'tag_management_view.dart';
import 'widgets/error_display.dart';
import 'widgets/queue_view.dart';

/// Navigation destination for the side panel
enum NavDestination { home, library, playlists, tags, settings }


/// Main home page with side navigation, main content area, and bottom control panel
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  NavDestination _currentDestination = NavDestination.home;

  // Navigation history for back button (tracks tab switches)
  final List<NavDestination> _navigationHistory = [NavDestination.home];

  // Queue view key for scroll-to-current
  final GlobalKey<QueueViewState> _queueViewKey = GlobalKey();

  // Fullscreen state
  bool _isFullscreen = false;
  bool _showFullscreenControls = false;
  Timer? _controlsHideTimer;

  // Playback position update timer
  Timer? _playbackPositionTimer;


  /// Public method to show queue (called from queue button)
  void showQueue() {
    _navigateTo(NavDestination.home);
  }

  /// Navigate to a destination, tracking history for back button
  void _navigateTo(NavDestination destination) {
    if (destination == _currentDestination) return;
    setState(() {
      _navigationHistory.add(destination);
      _currentDestination = destination;
    });
  }

  /// Go back to previous tab in history. Returns true if navigated back.
  bool _navigateBack() {
    if (_navigationHistory.length > 1) {
      setState(() {
        _navigationHistory.removeLast();
        _currentDestination = _navigationHistory.last;
      });
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // Set up auto-advance callback and restore state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAutoAdvance();
      _setupPlaybackPositionUpdater();
      _restorePlaybackState();
    });
  }

  /// Restore playback state when HomePage is ready
  Future<void> _restorePlaybackState() async {
    debugPrint('HomePage: Restoring playback state');
    try {
      final playerVM = context.read<PlayerViewModel>();
      final tagVM = context.read<TagViewModel>();

      // Restore playback mode first
      await tagVM.restorePlaybackMode();
      debugPrint('HomePage: Playback mode restored: ${tagVM.playbackMode}');

      // Restore playback state (song and position)
      final restoredSongId = await playerVM.restorePlaybackState();

      if (restoredSongId != null) {
        debugPrint(
          'HomePage: Playback state restored for song: $restoredSongId',
        );
        // Force a rebuild
        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint('HomePage: No playback state to restore');
      }
    } catch (e, stackTrace) {
      debugPrint('HomePage: Failed to restore playback state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _playbackPositionTimer?.cancel();
    super.dispose();
  }

  void _setupAutoAdvance() {
    final playerVM = context.read<PlayerViewModel>();
    final tagVM = context.read<TagViewModel>();

    playerVM.onPlaybackCompleted = () {
      _handlePlaybackCompleted(playerVM, tagVM);
    };
  }

  void _setupPlaybackPositionUpdater() {
    // Update playback position every 5 seconds
    _playbackPositionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final playerVM = context.read<PlayerViewModel>();
      final tagVM = context.read<TagViewModel>();

      // Only update if there's a current song
      if (playerVM.currentSongUnit != null) {
        tagVM.updatePlaybackPosition(playerVM.position, playerVM.isPlaying);
      }
    });
  }

  void _handlePlaybackCompleted(
    PlayerViewModel playerVM,
    TagViewModel tagVM,
  ) async {
    // Handle remove after play
    if (tagVM.removeAfterPlay && tagVM.currentIndex >= 0) {
      unawaited(tagVM.removeFromQueue(tagVM.currentIndex));
    }

    // Advance to next song based on playback mode
    final nextSong = await tagVM.advanceToNext();
    if (nextSong != null) {
      unawaited(playerVM.play(nextSong));
    } else {
      // No more songs, stop playback
      unawaited(playerVM.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // If fullscreen, show only display screen with overlay controls
    if (_isFullscreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          // Exit fullscreen instead of exiting app
          toggleFullscreen();
        },
        child: KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              toggleFullscreen();
            }
          },
          child: Scaffold(
            body: GestureDetector(
              onTap: _toggleFullscreenControls,
              child: Stack(
                children: [
                  _buildDisplaySection(context),
                  // Top control bar (exit fullscreen)
                  if (_showFullscreenControls)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildFullscreenTopBar(context),
                    ),
                  // Bottom control panel
                  if (_showFullscreenControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomControlPanel(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mobile layout with bottom navigation - handle back button properly
    if (isMobile) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          // Try going back in tab history first
          if (_navigateBack()) return;

          // At root tab, minimize app (keeps service alive for background playback)
          unawaited(SystemNavigator.pop());
        },
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Error banner if any
                    _buildErrorBanner(context),
                    // Main content
                    Expanded(child: _buildMainContent(context)),
                    // Bottom control panel
                    _buildBottomControlPanel(context),
                  ],
                ),
                // Floating lyrics overlay
                _buildFloatingLyrics(context),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigation(context),
        ),
      );
    }

    // Desktop/tablet layout with side navigation
    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile platforms, handle back button even in tablet layout
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          // Try going back in tab history first
          if (_navigateBack()) return;

          // At root tab, minimize app
          unawaited(SystemNavigator.pop());
        },
        child: Scaffold(
          body: Stack(
            children: [_buildBody(context), _buildFloatingLyrics(context)],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildBody(context),
          // Floating lyrics overlay (appears over all content)
          _buildFloatingLyrics(context),
        ],
      ),
    );
  }

  void _toggleFullscreenControls() {
    setState(() {
      _showFullscreenControls = !_showFullscreenControls;
    });

    // Auto-hide controls after 3 seconds
    if (_showFullscreenControls) {
      _controlsHideTimer?.cancel();
      _controlsHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isFullscreen) {
          setState(() {
            _showFullscreenControls = false;
          });
        }
      });
    }
  }

  Widget _buildFullscreenTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
            onPressed: toggleFullscreen,
            tooltip: context.t.player.exitFullscreen,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFloatingLyrics(BuildContext context) {
    return Consumer2<PlayerViewModel, SettingsViewModel>(
      builder: (context, playerVM, settingsVM, child) {
        final lyrics = playerVM.currentLyrics;

        // Only show floating lyrics when:
        // 1. Lyrics mode is floating
        // 2. KTV mode is NOT enabled (floating disabled in KTV mode)
        // 3. There are valid lyrics to display (not null and not empty)
        final hasValidLyrics = lyrics != null && lyrics.isNotEmpty;
        final shouldShow =
            settingsVM.lyricsMode == LyricsMode.floating &&
            !settingsVM.ktvMode &&
            hasValidLyrics;

        // Use in-app overlay for all platforms (desktop_multi_window breaks playback)
        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        // Apply lyrics offset for floating lyrics
        final activeHoverSource = playerVM.activeHoverSource;
        final lyricsOffset = (activeHoverSource is HoverSource)
            ? activeHoverSource.offset
            : Duration.zero;
        final lyricsPosition = playerVM.position - lyricsOffset;

        return FloatingLyricsWindow(
          lyrics: lyrics,
          position: lyricsPosition,
          onClose: () => settingsVM.setLyricsMode(LyricsMode.off),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        // Error banner if any
        _buildErrorBanner(context),
        // Main content with side navigation
        Expanded(
          child: Row(
            children: [
              // Side navigation panel
              _buildSideNavigation(context),
              // Main content area
              Expanded(child: _buildMainContent(context)),
            ],
          ),
        ),
        // Bottom control panel
        _buildBottomControlPanel(context),
      ],
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentDestination.index,
      onDestinationSelected: (index) {
        _navigateTo(NavDestination.values[index]);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: context.t.nav.home,
        ),
        NavigationDestination(
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(Icons.library_music),
          label: context.t.nav.library,
        ),
        NavigationDestination(
          icon: const Icon(Icons.playlist_play_outlined),
          selectedIcon: const Icon(Icons.playlist_play),
          label: context.t.nav.playlists,
        ),
        NavigationDestination(
          icon: const Icon(Icons.label_outlined),
          selectedIcon: const Icon(Icons.label),
          label: context.t.nav.tags,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: context.t.nav.settings,
        ),
      ],
    );
  }

  Widget _buildSideNavigation(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 800;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On mobile, use compact navigation rail without labels
    if (isMobile) {
      return NavigationRail(
        minWidth: 56,
        selectedIndex: _currentDestination.index,
        onDestinationSelected: (index) {
          _navigateTo(NavDestination.values[index]);
        },
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Icon(
            Icons.music_note,
            size: 28,
            color: theme.colorScheme.primary,
          ),
        ),
        labelType: NavigationRailLabelType.none,
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: Text(context.t.nav.home),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.library_music_outlined),
            selectedIcon: const Icon(Icons.library_music),
            label: Text(context.t.nav.library),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.playlist_play_outlined),
            selectedIcon: const Icon(Icons.playlist_play),
            label: Text(context.t.nav.playlists),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.label_outlined),
            selectedIcon: const Icon(Icons.label),
            label: Text(context.t.nav.tags),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: Text(context.t.nav.settings),
          ),
        ],
      );
    }

    return NavigationRail(
      extended: isWide,
      minExtendedWidth: 180,
      selectedIndex: _currentDestination.index,
      onDestinationSelected: (index) {
        _navigateTo(NavDestination.values[index]);
      },
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(Icons.music_note, size: 32, color: theme.colorScheme.primary),
            if (isWide) ...[
              const SizedBox(height: 4),
              Text(
                context.t.app.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: Text(context.t.nav.home),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(Icons.library_music),
          label: Text(context.t.nav.library),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.playlist_play_outlined),
          selectedIcon: const Icon(Icons.playlist_play),
          label: Text(context.t.nav.playlists),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.label_outlined),
          selectedIcon: const Icon(Icons.label),
          label: Text(context.t.nav.tags),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(context.t.nav.settings),
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    // Use IndexedStack to keep all panels alive (especially home with video player)
    // This prevents video from reloading when switching between panels
    return IndexedStack(
      index: _currentDestination.index,
      children: [
        _buildHomeContent(context), // NavDestination.home
        const LibraryView(), // NavDestination.library
        const PlaylistsManagementPage(), // NavDestination.playlists
        const TagManagementView(), // NavDestination.tags
        const SettingsView(), // NavDestination.settings
      ],
    );
  }

  /// Home content: Display screen and playlist side by side
  Widget _buildHomeContent(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Consumer<SettingsViewModel>(
      builder: (context, settingsVM, child) {
        final hideDisplay =
            settingsVM.hideDisplayPanel ||
            settingsVM.displayMode == DisplayMode.hidden;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Mobile layout: Single column, no tabs
            if (isMobile) {
              if (hideDisplay) {
                return _buildPlaylistSection(context);
              }

              return Column(
                children: [
                  // Display section (compact)
                  SizedBox(
                    height: constraints.maxHeight * 0.4,
                    child: _buildDisplaySection(context),
                  ),
                  const Divider(height: 1),
                  // Playlist section
                  Expanded(child: _buildPlaylistSection(context)),
                ],
              );
            }

            // Tablet layout: Tabbed Display/Playlist
            if (constraints.maxWidth < 800) {
              if (hideDisplay) {
                return _buildPlaylistSection(context);
              }

              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.tv), text: 'Display'),
                        Tab(icon: Icon(Icons.queue_music), text: 'Playlist'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildDisplaySection(context),
                          _buildPlaylistSection(context),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Desktop layout: Display and Playlist side by side
            if (hideDisplay) {
              return _buildPlaylistSection(context);
            }

            return Row(
              children: [
                Expanded(flex: 2, child: _buildDisplaySection(context)),
                const VerticalDivider(width: 1),
                SizedBox(width: 320, child: _buildPlaylistSection(context)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    return Consumer2<PlayerViewModel, SettingsViewModel>(
      builder: (context, playerViewModel, settingsViewModel, child) {
        return DisplayScreen(
          viewModel: playerViewModel,
          lyrics: playerViewModel.currentLyrics,
          lyricsMode: settingsViewModel.lyricsMode,
          displayMode: settingsViewModel.displayMode,
          ktvMode: settingsViewModel.ktvMode,
          isFullscreen: _isFullscreen,
          onToggleFullscreen: toggleFullscreen,
        );
      },
    );
  }

  void toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _showFullscreenControls = false;
      _controlsHideTimer?.cancel();
    });

    // Toggle window fullscreen on desktop platforms
    await desktop.setDesktopFullscreen(_isFullscreen);
  }

  Widget _buildPlaylistSection(BuildContext context) {
    return Consumer3<PlayerViewModel, TagViewModel, SettingsViewModel>(
      builder: (context, playerVM, tagVM, settingsVM, child) {
        return QueueView(
          key: _queueViewKey,
          tagViewModel: tagVM,
          playerViewModel: playerVM,
          settingsViewModel: settingsVM,
        );
      },
    );
  }

  Widget _buildBottomControlPanel(BuildContext context) {
    return Consumer<PlayerViewModel>(
      builder: (context, playerViewModel, child) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: PlayerControlPanel(
            viewModel: playerViewModel,
            isHorizontal: true,
            onSongInfoTap: () {
              // Navigate to home (queue) tab and scroll to current song
              _navigateTo(NavDestination.home);
              // Delay slightly to let the queue view build if switching tabs
              Future.delayed(const Duration(milliseconds: 100), () {
                _queueViewKey.currentState?.scrollToCurrentSong();
              });
            },
          ),
        );
      },
    );
  }


  Widget _buildErrorBanner(BuildContext context) {
    return Consumer3<PlayerViewModel, LibraryViewModel, TagViewModel>(
      builder: (context, playerVM, libraryVM, tagVM, child) {
        final errors = <String>[];
        if (playerVM.error != null) errors.add(playerVM.error!);
        if (libraryVM.error != null) errors.add(libraryVM.error!);
        if (tagVM.error != null) errors.add(tagVM.error!);

        if (errors.isEmpty) return const SizedBox.shrink();

        return ErrorBanner(
          message: errors.first,
          onDismiss: () {
            playerVM.clearError();
            libraryVM.clearError();
            tagVM.clearError();
          },
        );
      },
    );
  }
}
