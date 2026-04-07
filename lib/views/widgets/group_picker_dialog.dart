import 'package:flutter/material.dart';
import '../../i18n/translations.g.dart';
import '../../models/tag_extensions.dart';

/// Dialog that lists available groups within a collection for the user to pick.
/// Returns the selected group's tag ID, or null if cancelled.
class GroupPickerDialog extends StatelessWidget {
  const GroupPickerDialog({super.key, required this.groups});

  final List<Tag> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.t.playlists.moveToGroup),
      content: SizedBox(
        width: double.maxFinite,
        child: groups.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.t.playlists.noGroupsAvailable,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final songCount = group.metadata?.items.length ?? 0;
                  final isLocked = group.isLocked;

                  return ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(group.name),
                    subtitle: Text(
                      '$songCount ${songCount == 1 ? context.t.playlists.song : context.t.playlists.songs}'
                      '${isLocked ? ' • ${context.t.playlists.locked}' : ''}',
                    ),
                    trailing: isLocked
                        ? Icon(
                            Icons.lock,
                            size: 16,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(group.id),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
      ],
    );
  }
}
