/// Encapsulates all desktop-only window management APIs.
///
/// This file imports `desktop_multi_window` and `window_manager` which are
/// desktop-only plugins (Windows/Linux/macOS). All calls are guarded by
/// runtime Platform checks so they never execute on mobile.
///
/// Other files should import this instead of the packages directly.
library;
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Whether the current platform supports desktop window management.
bool get isDesktopWindowPlatform {
  try {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

/// Handle sub-window launch for desktop multi-window (floating lyrics).
/// Returns a widget to run if this is a sub-window, or null if it's the main window.
/// Must only be called on desktop platforms.
Widget? handleSubWindowArgs(List<String> args) {
  if (!isDesktopWindowPlatform) return null;
  if (args.firstOrNull != 'multi_window') return null;

  final windowId = args[1];
  final argument = args[2].isEmpty
      ? <String, dynamic>{}
      : jsonDecode(args[2]) as Map<String, dynamic>;

  final windowType = argument['type'] as String?;

  if (windowType == 'floating_lyrics') {
    return _FloatingLyricsSubWindowApp(
      windowId: windowId,
      argument: argument,
    );
  }
  return null;
}

/// Initialize desktop window manager (size, position, etc.)
Future<void> initDesktopWindow() async {
  if (!isDesktopWindowPlatform) return;

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Toggle fullscreen on desktop platforms.
Future<void> setDesktopFullscreen(bool fullscreen) async {
  if (!isDesktopWindowPlatform) return;
  try {
    await windowManager.setFullScreen(fullscreen);
  } catch (e) {
    debugPrint('Failed to toggle window fullscreen: $e');
  }
}

/// Create a system-level floating lyrics window (desktop only).
/// Returns a [DesktopFloatingLyricsHandle] or null on non-desktop.
/// 
/// NOTE: Currently disabled due to compatibility issues with media_kit playback.
/// Creating a separate window process interferes with audio/video playback.
/// TODO: Investigate alternative approaches (overlay window, platform channels, etc.)
DesktopFloatingLyricsHandle? createFloatingLyricsWindow() {
  if (!isDesktopWindowPlatform) return null;
  // DISABLED: Separate window breaks media playback
  // return DesktopFloatingLyricsHandle();
  return null; // Force fallback to in-app overlay
}

/// Handle for managing a desktop floating lyrics sub-window.
class DesktopFloatingLyricsHandle {
  WindowController? _windowController;
  bool _isShowing = false;
  bool _isCreating = false;
  String _currentText = '';
  double _fontSize = 24;

  bool get isShowing => _isShowing;
  bool get isCreating => _isCreating;

  void show({Offset? initialPosition}) {
    if (_isShowing || _isCreating) {
      debugPrint('FloatingLyrics: Already showing or creating (showing: $_isShowing, creating: $_isCreating)');
      return;
    }
    _isCreating = true;
    debugPrint('FloatingLyrics: Starting to create window...');

    Future(() async {
      try {
        debugPrint('FloatingLyrics: Creating WindowConfiguration...');
        final config = WindowConfiguration(
          arguments: jsonEncode({
            'type': 'floating_lyrics',
            'text': _currentText,
            'fontSize': _fontSize,
          }),
        );

        debugPrint('FloatingLyrics: Creating WindowController...');
        final controller = await WindowController.create(config);
        _windowController = controller;
        debugPrint('FloatingLyrics: WindowController created');

        // Show the window first - this makes it visible
        await controller.show();
        debugPrint('FloatingLyrics: Window shown');
        
        // Mark as showing immediately after show() succeeds
        _isShowing = true;
        _isCreating = false;
        debugPrint('FloatingLyrics: Marked as showing');
        
        // Now try to set frame and title after the window is visible
        // Wait a bit for the window to be fully initialized
        await Future.delayed(const Duration(milliseconds: 200));
        
        try {
          await controller.invokeMethod('setFrame', {
            'x': initialPosition?.dx ?? 100,
            'y': initialPosition?.dy ?? 100,
            'width': 600.0,
            'height': 60.0,
          });
          debugPrint('FloatingLyrics: Frame set');
        } catch (e) {
          debugPrint('FloatingLyrics: Failed to set frame (non-fatal): $e');
        }

        try {
          await controller.invokeMethod('setTitle', '');
          debugPrint('FloatingLyrics: Title set');
        } catch (e) {
          debugPrint('FloatingLyrics: Failed to set title (non-fatal): $e');
        }
        
        // DON'T try to return focus - this was causing playback to stop
        // The floating window should stay in background and not steal focus
        debugPrint('FloatingLyrics: Window created successfully, not forcing focus change');
      } catch (e, stackTrace) {
        debugPrint('FloatingLyrics: Failed to create floating lyrics window: $e');
        debugPrint('FloatingLyrics: Stack trace: $stackTrace');
        _isShowing = false;
        _isCreating = false;
      }
    });
  }

  void hide() {
    if (!_isShowing) {
      debugPrint('FloatingLyrics: hide() called but not showing');
      return;
    }
    debugPrint('FloatingLyrics: Hiding window...');
    _isShowing = false;

    final controller = _windowController;
    _windowController = null;

    if (controller != null) {
      Future(() async {
        try {
          debugPrint('FloatingLyrics: Closing window controller...');
          await controller.invokeMethod('close');
          debugPrint('FloatingLyrics: Window closed');
        } catch (e) {
          debugPrint('FloatingLyrics: Failed to close floating lyrics window: $e');
        }
      });
    }
  }

  void updateLyrics(String text) {
    if (_currentText == text) return;
    _currentText = text;

    if (_isShowing && _windowController != null) {
      Future(() async {
        try {
          await _windowController!.invokeMethod(
            'updateLyrics',
            jsonEncode({'text': text, 'fontSize': _fontSize}),
          );
        } catch (e) {
          debugPrint('FloatingLyrics: Failed to update lyrics: $e');
        }
      });
    } else {
      debugPrint('FloatingLyrics: updateLyrics called but window not ready (showing: $_isShowing, controller: ${_windowController != null})');
    }
  }

  void setFontSize(double size) {
    _fontSize = size;
    if (_isShowing) updateLyrics(_currentText);
  }

  Future<void> dispose() async {
    hide();
  }
}

// ---------------------------------------------------------------------------
// Sub-window app (runs in a separate OS window on desktop)
// ---------------------------------------------------------------------------

class _FloatingLyricsSubWindowApp extends StatelessWidget {
  const _FloatingLyricsSubWindowApp({
    required this.windowId,
    required this.argument,
  });

  final String windowId;
  final Map<String, dynamic> argument;

  @override
  Widget build(BuildContext context) {
    return _FloatingLyricsSubWindow(
      windowId: windowId,
      initialText: argument['text'] as String? ?? '',
      initialFontSize: (argument['fontSize'] as num?)?.toDouble() ?? 24,
    );
  }
}

class _FloatingLyricsSubWindow extends StatefulWidget {
  const _FloatingLyricsSubWindow({
    required this.windowId,
    this.initialText = '',
    this.initialFontSize = 24,
  });

  final String windowId;
  final String initialText;
  final double initialFontSize;

  @override
  State<_FloatingLyricsSubWindow> createState() =>
      _FloatingLyricsSubWindowState();
}

class _FloatingLyricsSubWindowState extends State<_FloatingLyricsSubWindow> {
  String _text = '';
  double _fontSize = 24;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
    _fontSize = widget.initialFontSize;

    // Set up method handler for this window
    WindowController.fromCurrentEngine().then((controller) {
      controller.setWindowMethodHandler((call) async {
        if (call.method == 'updateLyrics' && mounted) {
          try {
            final data =
                jsonDecode(call.arguments as String) as Map<String, dynamic>;
            setState(() {
              _text = data['text'] as String? ?? '';
              _fontSize = (data['fontSize'] as num?)?.toDouble() ?? 24;
            });
          } catch (_) {}
        }
        return null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              // Lyrics text (centered)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  child: _buildText(),
                ),
              ),
              // Control buttons (top right)
              Positioned(
                top: 4,
                right: 4,
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildText() {
    if (_text.isEmpty) {
      return Text(
        '♪',
        style: TextStyle(color: Colors.white38, fontSize: _fontSize),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      _text,
      style: TextStyle(
        color: Colors.white,
        fontSize: _fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 8, color: Colors.cyan),
          Shadow(blurRadius: 16, color: Colors.cyan),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 14),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize - 2).clamp(14.0, 36.0)),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 14),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize + 2).clamp(14.0, 36.0)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              WindowController.fromCurrentEngine().then((controller) {
                controller.invokeMethod('close');
              });
            },
          ),
        ],
      ),
    );
  }
}
