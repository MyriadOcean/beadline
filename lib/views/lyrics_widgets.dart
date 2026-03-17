import 'package:flutter/material.dart';
import '../services/lrc_parser.dart';

/// Screen lyrics widget for KTV-style display
/// Shows two lines alternating left/right based on line index
/// Odd lines on left (higher), even lines on right (lower)
/// Requirements: 13.2
class ScreenLyricsWidget extends StatelessWidget {
  const ScreenLyricsWidget({
    super.key,
    required this.lyrics,
    required this.position,
    this.ktvStyle = true,
    this.currentLineStyle,
    this.nextLineStyle,
  });

  /// Parsed lyrics data
  final ParsedLyrics? lyrics;

  /// Current playback position
  final Duration position;

  /// Whether to show KTV-style highlighting
  final bool ktvStyle;

  /// Text style for current line
  final TextStyle? currentLineStyle;

  /// Text style for next line
  final TextStyle? nextLineStyle;

  /// Threshold for showing countdown indicator (in seconds)
  static const int _countdownThreshold = 10;

  @override
  Widget build(BuildContext context) {
    if (lyrics == null || lyrics!.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentIndex = lyrics!.getLineIndexAt(position);
    final currentLine = lyrics!.getLineAt(position);
    final nextLine = lyrics!.getNextLine(position);

    // Determine which line goes left (higher) and which goes right (lower)
    // Based on current line index: odd index = left, even index = right
    // This creates alternating pattern: L1(left), L2(right), L3(left), L4(right)...
    final currentIsLeft = currentIndex.isOdd;

    final leftText = currentIsLeft
        ? (currentLine?.text ?? '')
        : (nextLine?.text ?? '');
    final rightText = currentIsLeft
        ? (nextLine?.text ?? '')
        : (currentLine?.text ?? '');
    final leftIsCurrent = currentIsLeft;

    // Calculate time until next line for countdown indicator (KTV mode only)
    // Show dots for last 5 seconds when interval > 10 seconds
    Widget? countdownWidget;
    if (ktvStyle && nextLine != null) {
      final adjustedPosition =
          position + Duration(milliseconds: lyrics!.metadata.offset);
      final timeUntilNext = nextLine.timestamp - adjustedPosition;
      final totalInterval =
          nextLine.timestamp - (currentLine?.timestamp ?? Duration.zero);
      // Only show if total interval > 10 seconds and we're in the last 5 seconds
      if (totalInterval.inSeconds > _countdownThreshold &&
          timeUntilNext.inSeconds <= 5 &&
          timeUntilNext.inSeconds > 0) {
        countdownWidget = _CountdownIndicator(
          secondsRemaining: timeUntilNext.inSeconds,
        );
      }
    }

    // Determine if next line position is left or right
    final nextLineIsLeft = !currentIsLeft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left line (higher position) with countdown if next line is on left
          _buildKtvLineWithCountdown(
            context,
            leftText,
            isCurrentLine: leftIsCurrent,
            alignment: Alignment.centerLeft,
            countdownWidget: nextLineIsLeft ? countdownWidget : null,
          ),
          const SizedBox(height: 4),
          // Right line (lower position) with countdown if next line is on right
          _buildKtvLineWithCountdown(
            context,
            rightText,
            isCurrentLine: !leftIsCurrent,
            alignment: Alignment.centerRight,
            countdownWidget: !nextLineIsLeft ? countdownWidget : null,
          ),
        ],
      ),
    );
  }

  Widget _buildKtvLineWithCountdown(
    BuildContext context,
    String text, {
    required bool isCurrentLine,
    required Alignment alignment,
    Widget? countdownWidget,
  }) {
    final isLeft = alignment == Alignment.centerLeft;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        // Countdown dots above the next line
        if (countdownWidget != null && !isCurrentLine) ...[
          Padding(
            padding: EdgeInsets.only(
              left: isLeft ? 0 : 48,
              right: isLeft ? 48 : 0,
            ),
            child: countdownWidget,
          ),
          const SizedBox(height: 4),
        ],
        _buildKtvLine(
          context,
          text,
          isCurrentLine: isCurrentLine,
          alignment: alignment,
        ),
      ],
    );
  }

  Widget _buildKtvLine(
    BuildContext context,
    String text, {
    required bool isCurrentLine,
    required Alignment alignment,
  }) {
    if (text.isEmpty) {
      return const SizedBox(height: 36);
    }

    final isLeft = alignment == Alignment.centerLeft;
    final screenHeight = MediaQuery.of(context).size.height;

    // Scale font size based on screen height
    // Base size: 28px for ~480px height, scale proportionally
    final baseFontSize = (screenHeight / 480) * 28;
    final fontSize = baseFontSize.clamp(24.0, 96.0);

    // Fixed text style - no dynamic size change to avoid eye strain
    final textStyle = isCurrentLine
        ? TextStyle(
            color: Colors.yellow,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(blurRadius: 8, color: Colors.orange),
              Shadow(blurRadius: 16, offset: Offset(2, 2)),
            ],
          )
        : TextStyle(
            color: Colors.white70,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(
                blurRadius: 4,
                color: Colors.black54,
                offset: Offset(1, 1),
              ),
            ],
          );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: EdgeInsets.only(left: isLeft ? 0 : 48, right: isLeft ? 48 : 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(
            text,
            style: textStyle,
            textAlign: isLeft ? TextAlign.left : TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Countdown indicator widget for long intervals between lyrics (KTV mode)
/// Shows 3 dots above the next lyric line
/// - Displayed for last 5 seconds when interval > 10 seconds
/// - Color changes start at 3 seconds: dot 1 at 3s, dot 2 at 2s, dot 3 at 1s
/// - All dots colored at 1 second, then disappear
class _CountdownIndicator extends StatelessWidget {
  const _CountdownIndicator({required this.secondsRemaining});

  final int secondsRemaining;

  static const int _dotCount = 3;

  @override
  Widget build(BuildContext context) {
    // Dots change color from left to right as time decreases
    // 5s, 4s: no dots colored (all white)
    // 3s: first dot colored
    // 2s: first two dots colored
    // 1s: all three dots colored
    // 0s: indicator disappears (handled by parent)
    final coloredDots = secondsRemaining <= 3 ? (4 - secondsRemaining) : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _dotCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < coloredDots ? Colors.yellow : Colors.white54,
                boxShadow: i < coloredDots
                    ? [
                        BoxShadow(
                          color: Colors.yellow.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Rolling lyrics widget for scrolling display
/// Shows lyrics scrolling from top to bottom with current line highlighted
/// Displays full screen with smooth scrolling animation
/// Requirements: 13.4
class RollingLyricsWidget extends StatefulWidget {
  const RollingLyricsWidget({
    super.key,
    required this.lyrics,
    required this.position,
    this.linesAbove = 4,
    this.linesBelow = 4,
    this.currentLineStyle,
    this.otherLineStyle,
    this.lineHeight = 48,
  });

  /// Parsed lyrics data
  final ParsedLyrics? lyrics;

  /// Current playback position
  final Duration position;

  /// Number of lines to show above current line
  final int linesAbove;

  /// Number of lines to show below current line
  final int linesBelow;

  /// Text style for current line
  final TextStyle? currentLineStyle;

  /// Text style for other lines
  final TextStyle? otherLineStyle;

  /// Height of each line
  final double lineHeight;

  @override
  State<RollingLyricsWidget> createState() => _RollingLyricsWidgetState();
}

class _RollingLyricsWidgetState extends State<RollingLyricsWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RollingLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToCurrentLine();
  }

  void _scrollToCurrentLine() {
    if (widget.lyrics == null || widget.lyrics!.isEmpty) {
      return;
    }

    final currentIndex = widget.lyrics!.getLineIndexAt(widget.position);
    if (currentIndex != _lastIndex && currentIndex >= 0) {
      _lastIndex = currentIndex;
      final targetOffset = currentIndex * widget.lineHeight;

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics == null || widget.lyrics!.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentIndex = widget.lyrics!.getLineIndexAt(widget.position);
    final screenHeight = MediaQuery.of(context).size.height;

    // Scale font size based on screen height
    // Base size: 20px for ~480px height, scale proportionally
    final baseFontSize = (screenHeight / 480) * 28;
    final fontSize = baseFontSize.clamp(18.0, 288.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.15, 0.85, 1.0],
        ),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.15, 0.85, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: widget.lyrics!.lines.length,
          itemExtent: widget.lineHeight,
          padding: EdgeInsets.symmetric(
            vertical: widget.linesAbove * widget.lineHeight,
          ),
          itemBuilder: (context, index) {
            final line = widget.lyrics!.lines[index];
            final isCurrent = index == currentIndex;
            final distance = (index - currentIndex).abs();

            // Calculate opacity based on distance from current line
            final opacity = isCurrent
                ? 1.0
                : (1.0 - (distance * 0.15)).clamp(0.3, 0.7);

            // Scale font size based on screen height
            final textStyle = TextStyle(
              color: isCurrent
                  ? Colors.cyan
                  : Colors.white.withValues(alpha: opacity),
              fontSize: fontSize,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              shadows: isCurrent
                  ? const [Shadow(blurRadius: 12, color: Colors.cyan)]
                  : null,
            );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  line.text,
                  style: textStyle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lyrics display container that switches between modes
/// Requirements: 13.1, 13.2, 13.4
class LyricsDisplay extends StatelessWidget {
  const LyricsDisplay({
    super.key,
    required this.lyrics,
    required this.position,
    required this.mode,
    this.ktvMode = false,
  });

  /// Parsed lyrics data
  final ParsedLyrics? lyrics;

  /// Current playback position
  final Duration position;

  /// Lyrics display mode
  final LyricsDisplayMode mode;

  /// Whether KTV mode is enabled (forces screen mode)
  final bool ktvMode;

  @override
  Widget build(BuildContext context) {
    // In KTV mode, always use screen mode
    final effectiveMode = ktvMode ? LyricsDisplayMode.screen : mode;

    switch (effectiveMode) {
      case LyricsDisplayMode.off:
        return const SizedBox.shrink();
      case LyricsDisplayMode.screen:
        return ScreenLyricsWidget(
          lyrics: lyrics,
          position: position,
          ktvStyle: ktvMode,
        );
      case LyricsDisplayMode.rolling:
        return RollingLyricsWidget(lyrics: lyrics, position: position);
      case LyricsDisplayMode.floating:
        // Floating mode is handled separately by FloatingLyricsWindow
        // This widget doesn't render anything for floating mode
        return const SizedBox.shrink();
    }
  }
}

/// Lyrics display mode enum
enum LyricsDisplayMode {
  /// No lyrics displayed
  off,

  /// Lyrics on main screen (KTV style)
  screen,

  /// Floating window overlay
  floating,

  /// Rolling/scrolling lyrics
  rolling,
}
