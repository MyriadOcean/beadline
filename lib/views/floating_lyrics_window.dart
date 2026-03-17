import 'dart:io';

import 'package:flutter/material.dart';
import '../i18n/translations.g.dart';
import '../services/desktop_window_manager.dart' as desktop;
import '../services/lrc_parser.dart';

/// Check if running on desktop platform
bool get isDesktopPlatform {
  try {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

/// Floating lyrics window widget (in-app fallback for mobile)
class FloatingLyricsWindow extends StatefulWidget {
  const FloatingLyricsWindow({
    super.key,
    required this.lyrics,
    required this.position,
    this.isVisible = true,
    this.onClose,
    this.initialPosition = const Offset(100, 100),
  });

  final ParsedLyrics? lyrics;
  final Duration position;
  final bool isVisible;
  final VoidCallback? onClose;
  final Offset initialPosition;

  @override
  State<FloatingLyricsWindow> createState() => _FloatingLyricsWindowState();
}

class _FloatingLyricsWindowState extends State<FloatingLyricsWindow> {
  late Offset _position;
  double _fontSize = 20;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    final currentLine = widget.lyrics?.getLineAt(widget.position);
    final nextLine = widget.lyrics?.getNextLine(widget.position);
    final text = currentLine?.text ?? '';
    final nextText = nextLine?.text ?? '';

    // Calculate window size based on text length
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? '♪' : text,
        style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.bold),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final contentWidth = textPainter.width + 120;
    final windowWidth = contentWidth.clamp(
      400.0,
      (screenSize.width - 32).clamp(400.0, 1000.0),
    );
    final windowHeight = nextText.isNotEmpty ? 100.0 : 70.0;

    final clampedX = _position.dx.clamp(
      0.0,
      (screenSize.width - windowWidth).clamp(0.0, double.infinity),
    );
    final clampedY = _position.dy.clamp(
      0.0,
      (screenSize.height - windowHeight).clamp(0.0, double.infinity),
    );

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: Container(
            width: windowWidth,
            height: windowHeight,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.cyan.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Lyrics content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 60, 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLyricsText(text, isCurrentLine: true),
                        if (nextText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildLyricsText(nextText, isCurrentLine: false),
                        ],
                      ],
                    ),
                  ),
                ),
                // Control buttons (top right)
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildControls(),
                ),
                // Drag handle (top left)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsText(String text, {required bool isCurrentLine}) {
    if (widget.lyrics == null || widget.lyrics!.isEmpty) {
      return Text(
        t.lyrics.noLyrics,
        style: TextStyle(
          color: Colors.white38,
          fontSize: _fontSize * 0.8,
        ),
        textAlign: TextAlign.center,
      );
    }
    if (text.isEmpty) {
      return Text(
        '♪',
        style: TextStyle(
          color: Colors.white38,
          fontSize: _fontSize,
        ),
        textAlign: TextAlign.center,
      );
    }
    
    if (isCurrentLine) {
      // Current line: bright with glow effect
      return Text(
        text,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      // Next line: dimmed
      return Text(
        text,
        style: TextStyle(
          color: Colors.white54,
          fontSize: _fontSize * 0.85,
          fontWeight: FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 18),
            color: _fontSize > 16 ? Colors.white70 : Colors.white30,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _fontSize > 16
                ? () => setState(
                    () => _fontSize = (_fontSize - 2).clamp(16.0, 40.0),
                  )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 18),
            color: _fontSize < 40 ? Colors.white70 : Colors.white30,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _fontSize < 40
                ? () => setState(
                    () => _fontSize = (_fontSize + 2).clamp(16.0, 40.0),
                  )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white70,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}

/// Manager for system-level floating lyrics window on desktop
/// Creates a separate OS window that floats over all applications
class SystemFloatingLyricsManager {
  desktop.DesktopFloatingLyricsHandle? _handle;
  bool _isShowing = false;

  bool get isShowing => _isShowing;
  static bool get isSupported => desktop.isDesktopWindowPlatform;

  /// Show the floating lyrics window
  void show({Offset? initialPosition}) {
    if (_isShowing) {
      debugPrint('SystemFloatingLyricsManager: Already showing');
      return;
    }
    debugPrint('SystemFloatingLyricsManager: Creating handle and showing...');
    _handle ??= desktop.createFloatingLyricsWindow();
    if (_handle == null) {
      debugPrint('SystemFloatingLyricsManager: Failed to create handle');
      return;
    }
    
    _handle!.show(initialPosition: initialPosition);
    // The handle's show() is async, but we mark as showing immediately
    // so we don't try to show multiple times
    _isShowing = true;
    debugPrint('SystemFloatingLyricsManager: Marked as showing');
  }

  /// Hide the floating lyrics window
  void hide() {
    if (!_isShowing) {
      debugPrint('SystemFloatingLyricsManager: hide() called but not showing');
      return;
    }
    debugPrint('SystemFloatingLyricsManager: Hiding...');
    _isShowing = false;
    _handle?.hide();
  }

  /// Update the lyrics text
  void updateLyrics(String text) {
    debugPrint('SystemFloatingLyricsManager: updateLyrics called with: "$text" (showing: $_isShowing)');
    _handle?.updateLyrics(text);
  }

  void setFontSize(double size) {
    _handle?.setFontSize(size);
  }

  Future<void> dispose() async {
    debugPrint('SystemFloatingLyricsManager: Disposing...');
    await _handle?.dispose();
  }
}

/// Overlay manager for in-app floating lyrics (mobile fallback)
class FloatingLyricsOverlay {
  OverlayEntry? _overlayEntry;

  bool get isShowing => _overlayEntry != null;

  void show({
    required BuildContext context,
    required ParsedLyrics? lyrics,
    required Duration position,
    VoidCallback? onClose,
    Offset? initialPosition,
  }) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingLyricsWindow(
        lyrics: lyrics,
        position: position,
        onClose: () {
          hide();
          onClose?.call();
        },
        initialPosition: initialPosition ?? const Offset(100, 100),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void dispose() => hide();
}
