import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/tag.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/tag_view_model.dart';
import 'app_theme.dart';
import 'widgets/error_display.dart';
import 'widgets/loading_indicator.dart';

/// Tag management view widget
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.5
class TagManagementView extends StatefulWidget {
  const TagManagementView({super.key});

  @override
  State<TagManagementView> createState() => _TagManagementViewState();
}

class _TagManagementViewState extends State<TagManagementView> {
  String? _expandedTagId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TagViewModel>().loadTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.tags.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TagViewModel>().loadTags(),
            tooltip: context.t.common.refresh,
          ),
        ],
      ),
      body: Consumer<TagViewModel>(
        builder: (context, viewModel, child) {
          return LoadingOverlay(
            isLoading: viewModel.isLoading,
            message: context.t.common.loading,
            child: _buildContent(context, viewModel),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTagDialog(context),
        tooltip: context.t.tags.createTag,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TagViewModel viewModel) {
    if (viewModel.error != null && viewModel.getTagPanelTags().isEmpty) {
      return _buildErrorState(context, viewModel);
    }

    return Column(
      children: [
        if (viewModel.error != null)
          ErrorBanner(
            message: viewModel.error!,
            onDismiss: viewModel.clearError,
            onRetry: viewModel.loadTags,
          ),
        Expanded(child: _buildTagList(context, viewModel)),
      ],
    );
  }

  Widget _buildTagList(BuildContext context, TagViewModel viewModel) {
    // Only show user-created, non-group tags (Requirements: 19.1-19.4)
    final tags = viewModel.getTagPanelTags();

    if (tags.isEmpty) {
      return _buildEmptyState(context);
    }

    // Build hierarchy from root tags (no parent)
    final rootTags = tags.where((t) => t.parentId == null).toList();

    return ListView(
      children: _buildTagHierarchy(context, rootTags, viewModel, 0),
    );
  }

  List<Widget> _buildTagHierarchy(
    BuildContext context,
    List<Tag> tags,
    TagViewModel viewModel,
    int depth,
  ) {
    final widgets = <Widget>[];

    for (final tag in tags) {
      widgets.add(_buildTagTile(context, tag, viewModel, depth: depth));

      // Add children if expanded (filter out groups)
      if (_expandedTagId == tag.id) {
        final children = viewModel
            .getChildTags(tag.id)
            .where((t) => !t.isGroup)
            .toList();
        if (children.isNotEmpty) {
          widgets.addAll(
            _buildTagHierarchy(context, children, viewModel, depth + 1),
          );
        }
      }
    }

    return widgets;
  }

  Widget _buildTagTile(
    BuildContext context,
    Tag tag,
    TagViewModel viewModel, {
    int depth = 0,
  }) {
    final theme = Theme.of(context);
    // Filter out groups when checking for visible children
    final hasChildren = viewModel
        .getChildTags(tag.id)
        .where((t) => !t.isGroup)
        .isNotEmpty;
    final isExpanded = _expandedTagId == tag.id;
    final tagColor = _getTagColor(tag.type);

    // Get song unit count for this tag
    final libraryViewModel = context.watch<LibraryViewModel>();
    final songUnitCount = libraryViewModel.songUnits
        .where((s) => s.tagIds.contains(tag.id))
        .length;

    // Build subtitle with collection metadata
    final subtitleParts = <String>[];
    if (tag.isCollection) {
      subtitleParts.add(
        '${tag.itemCount} ${tag.itemCount != 1 ? context.t.tags.items : context.t.tags.item}',
      );
      if (tag.isLocked) {
        subtitleParts.add(context.t.tags.locked);
      }
    }
    subtitleParts.add(
      '$songUnitCount ${songUnitCount != 1 ? context.t.tags.songUnits : context.t.tags.songUnit}',
    );
    final subtitleText = subtitleParts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(
            left: 16.0 + (depth * 24.0),
            right: 8,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasChildren)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _expandedTagId = isExpanded ? null : tag.id;
                    });
                  },
                )
              else
                const SizedBox(width: 48),
              // Show collection icon or tag color dot
              if (tag.isCollection)
                Icon(
                  tag.isLocked ? Icons.folder_off : Icons.folder_outlined,
                  size: 18,
                  color: tagColor,
                  semanticLabel: tag.isLocked
                      ? context.t.tags.lockedCollection
                      : context.t.tags.collection,
                )
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tagColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Flexible(child: Text(tag.name)),
              if (tag.isLocked) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.lock,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: context.t.tags.locked,
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitleText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: tag.type != TagType.builtIn
              ? PopupMenuButton<String>(
                  onSelected: (value) => _handleTagAction(context, tag, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view_songs',
                      child: ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(context.t.tags.viewSongUnits),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'add_alias',
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(context.t.tags.addAlias),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'add_child',
                      child: ListTile(
                        leading: const Icon(Icons.subdirectory_arrow_right),
                        title: Text(context.t.tags.addChildTag),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          context.t.common.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                        dense: true,
                      ),
                    ),
                  ],
                )
              : null,
          onTap: hasChildren
              ? () {
                  setState(() {
                    _expandedTagId = isExpanded ? null : tag.id;
                  });
                }
              : null,
        ),
        // Display aliases as chips below the tag
        if (tag.aliasNames.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: 80.0 + (depth * 24.0),
              right: 16,
              bottom: 8,
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tag.aliasNames.map((alias) {
                return Chip(
                  label: Text(alias, style: theme.textTheme.bodySmall),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: tag.type != TagType.builtIn
                      ? () => _removeAlias(context, tag, alias)
                      : null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _removeAlias(BuildContext context, Tag tag, String alias) {
    context.read<TagViewModel>().removeAlias(tag.id, alias);
  }

  Color _getTagColor(TagType type) {
    switch (type) {
      case TagType.builtIn:
        return AppTheme.builtInTagColor;
      case TagType.user:
        return AppTheme.userTagColor;
      case TagType.automatic:
        return AppTheme.automaticTagColor;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.tags.noTags,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.tags.noTagsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, TagViewModel viewModel) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(context.t.tags.loadError, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            viewModel.error ?? 'Unknown error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              viewModel
                ..clearError()
                ..loadTags();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.t.common.retry),
          ),
        ],
      ),
    );
  }

  void _handleTagAction(BuildContext context, Tag tag, String action) {
    switch (action) {
      case 'view_songs':
        _showTaggedSongUnitsDialog(context, tag);
        break;
      case 'add_alias':
        _showAddAliasDialog(context, tag);
        break;
      case 'add_child':
        _showCreateTagDialog(context, parentId: tag.id);
        break;
      case 'delete':
        _showDeleteTagDialog(context, tag);
        break;
    }
  }

  void _showTaggedSongUnitsDialog(BuildContext context, Tag tag) async {
    // Import LibraryViewModel to get song units
    final libraryViewModel = context.read<LibraryViewModel>();

    // Get all song units with this tag
    final allSongUnits = libraryViewModel.songUnits;
    final taggedSongUnits = allSongUnits
        .where((s) => s.tagIds.contains(tag.id))
        .toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${context.t.tags.viewSongUnits}: "${tag.name}"'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: taggedSongUnits.isEmpty
              ? Center(child: Text(context.t.tags.noTags))
              : ListView.builder(
                  itemCount: taggedSongUnits.length,
                  itemBuilder: (context, index) {
                    final songUnit = taggedSongUnits[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(songUnit.metadata.title),
                      subtitle: Text(songUnit.metadata.artistDisplay),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final updatedTagIds = songUnit.tagIds
                              .where((id) => id != tag.id)
                              .toList();
                          final updatedSongUnit = songUnit.copyWith(
                            tagIds: updatedTagIds,
                          );
                          await libraryViewModel.updateSongUnit(
                            updatedSongUnit,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                            _showTaggedSongUnitsDialog(context, tag);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.t.tags.removeFromSong,
                                ),
                              ),
                            );
                          }
                        },
                        tooltip: context.t.tags.removeFromSong,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (taggedSongUnits.length > 1)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) => AlertDialog(
                    title: Text(context.t.tags.removeAll),
                    content: Text(
                      '${context.t.tags.removeAll} "${tag.name}" ${context.t.common.songs}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(false),
                        child: Text(context.t.common.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(context.t.tags.removeAll),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  for (final songUnit in taggedSongUnits) {
                    final updatedTagIds = songUnit.tagIds
                        .where((id) => id != tag.id)
                        .toList();
                    final updatedSongUnit = songUnit.copyWith(tagIds: updatedTagIds);
                    await libraryViewModel.updateSongUnit(updatedSongUnit);
                  }
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t.tags.removeAll)),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.t.tags.removeAll),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.close),
          ),
        ],
      ),
    );
  }

  void _showCreateTagDialog(BuildContext context, {String? parentId}) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parentId != null ? context.t.tags.createChildTag : context.t.tags.createTag),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.t.tags.tagName,
            hintText: 'alphanumeric_with_underscores',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<TagViewModel>().createTag(
                  controller.text,
                  parentId: parentId,
                );
                Navigator.of(context).pop();
              }
            },
            child: Text(context.t.tags.createTag),
          ),
        ],
      ),
    );
  }

  void _showAddAliasDialog(BuildContext context, Tag tag) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${context.t.tags.addAliasFor} "${tag.name}"'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.t.tags.aliasName,
            hintText: context.t.tags.enterAlias,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<TagViewModel>().addAlias(tag.id, controller.text);
                Navigator.of(context).pop();
              }
            },
            child: Text(context.t.common.add),
          ),
        ],
      ),
    );
  }

  void _showDeleteTagDialog(BuildContext context, Tag tag) {
    final viewModel = context.read<TagViewModel>();
    final hasChildren = viewModel.getChildTags(tag.id).isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${context.t.tags.deleteTagTitle.replaceAll('?', '')} "${tag.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.tags.deleteTagConfirm),
            if (hasChildren) ...[
              const SizedBox(height: 8),
              Text(
                context.t.tags.deleteTagHasChildren,
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            if (tag.aliasNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t.tags.deleteTagAliases,
                style: const TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await viewModel.deleteTag(tag.id);
              if (context.mounted) {
                ErrorSnackBar.showSuccess(
                  context,
                  '${context.t.tags.deletedTag} "${tag.name}".',
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t.common.delete),
          ),
        ],
      ),
    );
  }
}
