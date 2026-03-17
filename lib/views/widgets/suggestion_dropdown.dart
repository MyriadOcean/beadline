import 'package:flutter/material.dart';

import '../../models/dart_suggestion.dart';

/// An overlay dropdown that shows auto-complete suggestions below the search bar.
///
/// Displays up to 10 suggestions. History items show a clock icon.
/// On selection, calls [onSuggestionSelected] with the chosen suggestion.
///
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
class SuggestionDropdown extends StatelessWidget {
  const SuggestionDropdown({
    super.key,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.onDismiss,
  });

  final List<DartSuggestion> suggestions;
  final ValueChanged<DartSuggestion> onSuggestionSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            final isHistory = suggestion.suggestionType == 'history';
            return ListTile(
              dense: true,
              leading: isHistory
                  ? Icon(
                      Icons.history,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
              title: Text(
                suggestion.displayText,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSuggestionSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}
