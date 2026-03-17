import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts configuration for the application
/// Requirements: 12.5
class KeyboardShortcuts {
  /// Play/Pause shortcut (Space)
  static const playPause = SingleActivator(LogicalKeyboardKey.space);

  /// Next track shortcut (Right Arrow)
  static const nextTrack = SingleActivator(LogicalKeyboardKey.arrowRight);

  /// Previous track shortcut (Left Arrow)
  static const previousTrack = SingleActivator(LogicalKeyboardKey.arrowLeft);

  /// Search shortcut (Ctrl+F / Cmd+F)
  static final search = SingleActivator(
    LogicalKeyboardKey.keyF,
    control: !_isMacOS,
    meta: _isMacOS,
  );

  /// Volume up shortcut (Up Arrow)
  static const volumeUp = SingleActivator(LogicalKeyboardKey.arrowUp);

  /// Volume down shortcut (Down Arrow)
  static const volumeDown = SingleActivator(LogicalKeyboardKey.arrowDown);

  /// Mute shortcut (M)
  static const mute = SingleActivator(LogicalKeyboardKey.keyM);

  /// Toggle fullscreen (F)
  static const fullscreen = SingleActivator(LogicalKeyboardKey.keyF);

  /// Escape to close dialogs/panels
  static const escape = SingleActivator(LogicalKeyboardKey.escape);

  /// Check if running on macOS
  static bool get _isMacOS {
    // This is a simplified check - in production, use Platform.isMacOS
    return false;
  }
}

/// Widget that provides keyboard shortcuts for the application
class KeyboardShortcutsWrapper extends StatelessWidget {
  const KeyboardShortcutsWrapper({
    super.key,
    required this.child,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onSearch,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onMute,
    this.onFullscreen,
    this.onEscape,
  });
  final Widget child;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onSearch;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onMute;
  final VoidCallback? onFullscreen;
  final VoidCallback? onEscape;

  /// Returns true when the primary focus is on a text input widget.
  static bool _isTextInputFocused(BuildContext context) {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) return false;
    // EditableText is the inner widget used by TextField / TextFormField.
    final editableText =
        focusNode.context?.findAncestorWidgetOfExactType<EditableText>();
    return editableText != null;
  }

  /// Wraps [callback] so it only fires when no text field is focused.
  static VoidCallback _guardedCallback(
    BuildContext context,
    VoidCallback callback,
  ) {
    return () {
      if (!_isTextInputFocused(context)) {
        callback();
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (onPlayPause != null)
          KeyboardShortcuts.playPause:
              _guardedCallback(context, onPlayPause!),
        if (onNext != null)
          KeyboardShortcuts.nextTrack: _guardedCallback(context, onNext!),
        if (onPrevious != null)
          KeyboardShortcuts.previousTrack:
              _guardedCallback(context, onPrevious!),
        if (onSearch != null)
          KeyboardShortcuts.search: _guardedCallback(context, onSearch!),
        if (onVolumeUp != null)
          KeyboardShortcuts.volumeUp: _guardedCallback(context, onVolumeUp!),
        if (onVolumeDown != null)
          KeyboardShortcuts.volumeDown:
              _guardedCallback(context, onVolumeDown!),
        if (onMute != null)
          KeyboardShortcuts.mute: _guardedCallback(context, onMute!),
        if (onFullscreen != null)
          KeyboardShortcuts.fullscreen:
              _guardedCallback(context, onFullscreen!),
        if (onEscape != null)
          KeyboardShortcuts.escape: _guardedCallback(context, onEscape!),
      },
      child: child,
    );
  }
}

/// Intent for play/pause action
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

/// Intent for next track action
class NextTrackIntent extends Intent {
  const NextTrackIntent();
}

/// Intent for previous track action
class PreviousTrackIntent extends Intent {
  const PreviousTrackIntent();
}

/// Intent for search action
class SearchIntent extends Intent {
  const SearchIntent();
}

/// Shortcuts widget with intents for more complex scenarios
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child, required this.actions});
  final Widget child;
  final Map<Type, Action<Intent>> actions;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        KeyboardShortcuts.playPause: const PlayPauseIntent(),
        KeyboardShortcuts.nextTrack: const NextTrackIntent(),
        KeyboardShortcuts.previousTrack: const PreviousTrackIntent(),
        KeyboardShortcuts.search: const SearchIntent(),
      },
      child: Actions(
        actions: actions,
        child: child,
      ),
    );
  }
}
