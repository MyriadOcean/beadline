import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/translations.g.dart';
import '../../models/tag.dart';
import '../../viewmodels/tag_view_model.dart';
import '../app_theme.dart';

/// User tags selection section.
class UserTagsSection extends StatelessWidget {
  const UserTagsSection({
    super.key,
    required this.selectedUserTagIds,
    required this.onToggleTag,
  });

  final Set<String> selectedUserTagIds;
  final void Function(String tagId, bool selected) onToggleTag;

  /// Get display name for tag (full path for child tags).
  String _getTagDisplayName(Tag tag, TagViewModel tagViewModel) {
    if (tag.parentId == null) return tag.name;

    final pathParts = <String>[tag.name];
    Tag? current = tag;

    while (current?.parentId != null) {
      try {
        current = tagViewModel.allTags.firstWhere(
          (t) => t.id == current!.parentId,
        );
        pathParts.insert(0, current.name);
      } catch (e) {
        break;
      }
    }

    return pathParts.join('/');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.userTagColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.t.songEditor.userTags,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<TagViewModel>(
              builder: (context, tagViewModel, child) {
                if (tagViewModel.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userTags = tagViewModel.allTags
                    .where((t) => t.type == TagType.user && !t.isCollection)
                    .toList();

                if (userTags.isEmpty) {
                  return Text(
                    context.t.songEditor.noUserTags,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: userTags.map((tag) {
                    final isSelected = selectedUserTagIds.contains(tag.id);
                    final displayName =
                        _getTagDisplayName(tag, tagViewModel);
                    return FilterChip(
                      label: Text(displayName),
                      selected: isSelected,
                      onSelected: (selected) => onToggleTag(tag.id, selected),
                      avatar: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.userTagColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
