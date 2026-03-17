import 'package:flutter/material.dart';

/// Color palette for search chips. Adjacent chips cycle through these colors
/// so no two neighbors share the same color.
/// Requirements: 10.2
const List<Color> chipPalette = [
  Color(0xFF42A5F5), // blue
  Color(0xFF66BB6A), // green
  Color(0xFFAB47BC), // purple
  Color(0xFFEF5350), // red
  Color(0xFFFFA726), // orange
  Color(0xFF26C6DA), // cyan
];

/// Returns the chip background color for a given chip index,
/// cycling through [chipPalette] so adjacent chips differ.
Color chipColorForIndex(int index) {
  return chipPalette[index % chipPalette.length];
}

/// Visual icon/label data for each chip type.
/// Requirements: 10.3
IconData chipTypeIcon(String chipType) {
  switch (chipType) {
    case 'named_tag':
      return Icons.label;
    case 'nameless_tag':
      return Icons.tag;
    case 'bare_keyword':
      return Icons.text_fields;
    case 'range':
      return Icons.linear_scale;
    case 'negation':
      return Icons.remove_circle_outline;
    case 'or_operator':
      return Icons.compare_arrows;
    default:
      return Icons.help_outline;
  }
}

/// A single search chip representing a parsed query condition.
///
/// Renders with a colored background (determined by [colorIndex]),
/// an icon for the chip type, the chip text, and a delete button.
///
/// Requirements: 10.1, 10.2, 10.3
class SearchChip extends StatelessWidget {
  const SearchChip({
    super.key,
    required this.chipType,
    required this.text,
    required this.colorIndex,
    this.onDeleted,
    this.onTap,
  });

  /// One of: "named_tag", "nameless_tag", "bare_keyword", "range", "negation", "or_operator"
  final String chipType;

  /// Display text for this chip (e.g. "artist:luotianyi")
  final String text;

  /// Index used to pick a color from [chipPalette]
  final int colorIndex;

  /// Called when the user taps the delete button on this chip.
  final VoidCallback? onDeleted;

  /// Called when the user taps the chip body (for editing).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // OR operator chips are rendered as a simple text label, not a full chip
    if (chipType == 'or_operator') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'OR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
          ),
        ),
      );
    }

    final bgColor = chipColorForIndex(colorIndex);
    final fgColor =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InputChip(
        avatar: Icon(chipTypeIcon(chipType), size: 16, color: fgColor),
        label: Text(text, style: TextStyle(color: fgColor, fontSize: 13)),
        backgroundColor: bgColor.withAlpha(200),
        deleteIconColor: fgColor.withAlpha(180),
        onDeleted: onDeleted,
        onPressed: onTap,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
