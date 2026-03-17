import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../viewmodels/tag_view_model.dart';

/// Show dialog to rename a queue group
Future<void> showRenameGroupDialog(
  BuildContext context,
  TagViewModel tagViewModel,
  QueueDisplayItem item,
) async {
  final controller = TextEditingController(text: item.groupName);

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.dialogs.home.renameGroup),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: context.t.playlists.groupName,
          hintText: context.t.queue.enterNewName,
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        TextButton(
          onPressed: () {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              Navigator.of(context).pop(newName);
            }
          },
          child: Text(context.t.common.save),
        ),
      ],
    ),
  );

  if (result != null && item.groupId != null) {
    try {
      await tagViewModel.renameTag(item.groupId!, result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.common.failedToRename.replaceAll('{error}', e.toString()),
            ),
          ),
        );
      }
    }
  }
}

/// Show dialog to create a nested group inside a parent group
Future<void> showCreateNestedGroupDialog(
  BuildContext context,
  TagViewModel tagViewModel,
  String parentGroupId,
) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.dialogs.home.createNestedGroup),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: context.t.playlists.groupName,
          hintText: context.t.playlists.enterGroupName,
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        TextButton(
          onPressed: () {
            final groupName = controller.text.trim();
            if (groupName.isNotEmpty) {
              Navigator.of(context).pop(groupName);
            }
          },
          child: Text(context.t.dialogs.home.create),
        ),
      ],
    ),
  );

  if (result != null) {
    await tagViewModel.createNestedGroup(parentGroupId, result);
  }
}

/// Show dialog to remove a group (with options to keep or remove songs)
Future<void> showRemoveGroupDialog(
  BuildContext context,
  TagViewModel tagViewModel,
  QueueDisplayItem item,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.dialogs.home.removeGroup),
      content: Text(
        context.t.dialogs.home.removeGroupQuestion
            .replaceAll('{groupName}', item.groupName ?? ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('ungroup'),
          child: Text(context.t.dialogs.home.ungroupKeepSongs),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('remove_all'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.t.dialogs.home.removeAll),
        ),
      ],
    ),
  );

  if (result != null && item.groupId != null) {
    if (result == 'ungroup') {
      await tagViewModel.dissolveGroup(tagViewModel.activeQueueId, item.groupId!);
    } else if (result == 'remove_all') {
      await tagViewModel.removeGroupFromQueue(
        tagViewModel.activeQueueId,
        item.groupId!,
      );
    }
  }
}
