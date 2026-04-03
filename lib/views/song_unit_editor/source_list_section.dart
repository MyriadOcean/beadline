import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../models/source.dart';
import 'source_with_validation.dart';

/// Callback signatures for source operations
typedef SourceReorderCallback = void Function(
  List<SourceWithValidation> sources,
  SourceType type,
  int oldIndex,
  int newIndex,
);
typedef SourceRemoveCallback = Future<void> Function(
  List<SourceWithValidation> sources,
  SourceType type,
  int index,
);
typedef SourceAddCallback = void Function(SourceType type);
typedef SourceEditNameCallback = void Function(
  List<SourceWithValidation> sources,
  SourceType type,
  int index,
);
typedef SourceOffsetCallback = void Function(
  List<SourceWithValidation> sources,
  SourceType type,
  int index,
);

/// The entire "Sources" card containing all four source type lists.
class SourcesSection extends StatelessWidget {
  const SourcesSection({
    super.key,
    required this.displaySources,
    required this.audioSources,
    required this.accompanimentSources,
    required this.hoverSources,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    required this.onEditName,
    required this.onEditOffset,
    required this.getSourceName,
    required this.getLinkedVideoName,
  });

  final List<SourceWithValidation> displaySources;
  final List<SourceWithValidation> audioSources;
  final List<SourceWithValidation> accompanimentSources;
  final List<SourceWithValidation> hoverSources;
  final SourceAddCallback onAdd;
  final SourceRemoveCallback onRemove;
  final SourceReorderCallback onReorder;
  final SourceEditNameCallback onEditName;
  final SourceOffsetCallback onEditOffset;
  final String Function(Source) getSourceName;
  final String? Function(Source) getLinkedVideoName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.songEditor.sources,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _SourceListView(
              label: context.t.songEditor.display,
              sources: displaySources,
              type: SourceType.display,
              icon: Icons.tv,
              onAdd: onAdd,
              onRemove: onRemove,
              onReorder: onReorder,
              onEditName: onEditName,
              onEditOffset: onEditOffset,
              getSourceName: getSourceName,
              getLinkedVideoName: getLinkedVideoName,
            ),
            const Divider(),
            _SourceListView(
              label: context.t.songEditor.audio,
              sources: audioSources,
              type: SourceType.audio,
              icon: Icons.audiotrack,
              onAdd: onAdd,
              onRemove: onRemove,
              onReorder: onReorder,
              onEditName: onEditName,
              onEditOffset: onEditOffset,
              getSourceName: getSourceName,
              getLinkedVideoName: getLinkedVideoName,
            ),
            const Divider(),
            _SourceListView(
              label: context.t.songEditor.accompaniment,
              sources: accompanimentSources,
              type: SourceType.accompaniment,
              icon: Icons.music_note,
              onAdd: onAdd,
              onRemove: onRemove,
              onReorder: onReorder,
              onEditName: onEditName,
              onEditOffset: onEditOffset,
              getSourceName: getSourceName,
              getLinkedVideoName: getLinkedVideoName,
            ),
            const Divider(),
            _SourceListView(
              label: context.t.songEditor.lyricsLabel,
              sources: hoverSources,
              type: SourceType.hover,
              icon: Icons.subtitles,
              onAdd: onAdd,
              onRemove: onRemove,
              onReorder: onReorder,
              onEditName: onEditName,
              onEditOffset: onEditOffset,
              getSourceName: getSourceName,
              getLinkedVideoName: getLinkedVideoName,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single source type list (e.g. Display, Audio, etc.)
class _SourceListView extends StatelessWidget {
  const _SourceListView({
    required this.label,
    required this.sources,
    required this.type,
    required this.icon,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    required this.onEditName,
    required this.onEditOffset,
    required this.getSourceName,
    required this.getLinkedVideoName,
  });

  final String label;
  final List<SourceWithValidation> sources;
  final SourceType type;
  final IconData icon;
  final SourceAddCallback onAdd;
  final SourceRemoveCallback onRemove;
  final SourceReorderCallback onReorder;
  final SourceEditNameCallback onEditName;
  final SourceOffsetCallback onEditOffset;
  final String Function(Source) getSourceName;
  final String? Function(Source) getLinkedVideoName;

  Duration _getSourceOffset(Source source) {
    if (source is DisplaySource) return source.offset;
    if (source is AudioSource) return source.offset;
    if (source is AccompanimentSource) return source.offset;
    if (source is HoverSource) return source.offset;
    return Duration.zero;
  }

  String _formatOffsetMs(Duration offset) {
    final ms = offset.inMilliseconds;
    if (ms >= 0) return '+${ms}ms';
    return '${ms}ms';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onAdd(type),
              tooltip: context.t.songEditor.addSource,
            ),
          ],
        ),
        if (sources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${context.t.common.no} $label',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: sources.length,
            onReorder: (oldIndex, newIndex) =>
                onReorder(sources, type, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = sources[index];
              final offset = _getSourceOffset(item.source);
              final linkedVideoName = getLinkedVideoName(item.source);

              return ReorderableDragStartListener(
                key: ValueKey(item.source.id),
                index: index,
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.source.displayName ??
                                    getSourceName(item.source),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (item.source.displayName != null)
                                Text(
                                  getSourceName(item.source),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (linkedVideoName != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.videocam,
                                      size: 14,
                                      color:
                                          Theme.of(context).colorScheme.tertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        context.t.songEditor.linkedVideoFrom.replaceAll('{name}', linkedVideoName),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .tertiary,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              if (item.error != null)
                                Text(
                                  item.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              if (offset != Duration.zero)
                                Text(
                                  context.t.songEditor.offsetDisplay.replaceAll('{value}', _formatOffsetMs(offset)),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    iconSize: 20,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        onEditName(sources, type, index),
                                    tooltip: context.t.songEditor.editDisplayName,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.timer),
                                    iconSize: 20,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        onEditOffset(sources, type, index),
                                    tooltip: context.t.songEditor.setOffset,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    iconSize: 20,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        onRemove(sources, type, index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
