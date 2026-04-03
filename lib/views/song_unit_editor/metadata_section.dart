import 'dart:io';

import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../app_theme.dart';

/// Built-in tags (metadata) section: name, artist, album, time, thumbnail.
class MetadataSection extends StatelessWidget {
  const MetadataSection({
    super.key,
    required this.nameController,
    required this.albumController,
    required this.timeController,
    required this.artistValues,
    required this.thumbnailPath,
    required this.availableThumbnails,
    required this.isExtractingThumbnails,
    required this.hasAudioSources,
    required this.onAddArtist,
    required this.onRemoveArtist,
    required this.onPickThumbnail,
    required this.onSelectThumbnail,
    required this.onReloadThumbnails,
    required this.onClearThumbnail,
  });

  final TextEditingController nameController;
  final TextEditingController albumController;
  final TextEditingController timeController;
  final List<String> artistValues;
  final String? thumbnailPath;
  final Map<String, String> availableThumbnails;
  final bool isExtractingThumbnails;
  final bool hasAudioSources;
  final VoidCallback onAddArtist;
  final void Function(int index) onRemoveArtist;
  final VoidCallback onPickThumbnail;
  final VoidCallback onSelectThumbnail;
  final VoidCallback onReloadThumbnails;
  final VoidCallback onClearThumbnail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    color: AppTheme.builtInTagColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.t.songEditor.builtInTagsMetadata,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BuiltInTagField(
              tagName: context.t.songEditor.tagNameName,
              aliasHint: context.t.songEditor.aliasHintTitle,
              label: context.t.songEditor.titleNew,
              controller: nameController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _ArtistTagsField(
              artistValues: artistValues,
              onAdd: onAddArtist,
              onRemove: onRemoveArtist,
            ),
            const SizedBox(height: 12),
            _BuiltInTagField(
              tagName: context.t.songEditor.tagNameAlbum,
              label: context.t.songEditor.accompaniment,
              controller: albumController,
            ),
            const SizedBox(height: 12),
            _BuiltInTagField(
              tagName: context.t.songEditor.tagNameTime,
              label: context.t.songEditor.lyricsLabel,
              controller: timeController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _ThumbnailField(
              thumbnailPath: thumbnailPath,
              availableThumbnails: availableThumbnails,
              isExtractingThumbnails: isExtractingThumbnails,
              hasAudioSources: hasAudioSources,
              onPickThumbnail: onPickThumbnail,
              onSelectThumbnail: onSelectThumbnail,
              onReloadThumbnails: onReloadThumbnails,
              onClearThumbnail: onClearThumbnail,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single built-in tag field with chip label + text input.
class _BuiltInTagField extends StatelessWidget {
  const _BuiltInTagField({
    required this.tagName,
    required this.label,
    required this.controller,
    this.aliasHint,
    this.isRequired = false,
    this.keyboardType,
  });

  final String tagName;
  final String label;
  final TextEditingController controller;
  final String? aliasHint;
  final bool isRequired;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Chip(
                label: Text(tagName),
                backgroundColor:
                    AppTheme.builtInTagColor.withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  color: AppTheme.builtInTagColor,
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              if (aliasHint != null)
                Text(
                  '($aliasHint)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
            validator: isRequired
                ? (v) =>
                    (v == null || v.isEmpty) ? '$label is required' : null
                : null,
          ),
        ),
      ],
    );
  }
}

/// Artist tags field with chips and add button.
class _ArtistTagsField extends StatelessWidget {
  const _ArtistTagsField({
    required this.artistValues,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> artistValues;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Chip(
                label: Text(context.t.songEditor.artist),
                backgroundColor:
                    AppTheme.builtInTagColor.withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  color: AppTheme.builtInTagColor,
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...artistValues.asMap().entries.map(
                    (entry) => InputChip(
                      label: Text(entry.value),
                      onDeleted: () => onRemove(entry.key),
                      backgroundColor:
                          AppTheme.builtInTagColor.withValues(alpha: 0.1),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(context.t.songEditor.addSongs),
                    onPressed: onAdd,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (artistValues.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 92, top: 4),
            child: Text(
              context.t.player.noSongPlaying,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Thumbnail picker / selector field.
class _ThumbnailField extends StatelessWidget {
  const _ThumbnailField({
    required this.thumbnailPath,
    required this.availableThumbnails,
    required this.isExtractingThumbnails,
    required this.hasAudioSources,
    required this.onPickThumbnail,
    required this.onSelectThumbnail,
    required this.onReloadThumbnails,
    required this.onClearThumbnail,
  });

  final String? thumbnailPath;
  final Map<String, String> availableThumbnails;
  final bool isExtractingThumbnails;
  final bool hasAudioSources;
  final VoidCallback onPickThumbnail;
  final VoidCallback onSelectThumbnail;
  final VoidCallback onReloadThumbnails;
  final VoidCallback onClearThumbnail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Chip(
                label: Text(context.t.songEditor.thumbnail),
                backgroundColor:
                    AppTheme.builtInTagColor.withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  color: AppTheme.builtInTagColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnailPath != null) ...[
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(thumbnailPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, size: 18),
                      label: Text(context.t.songEditor.addImage),
                      onPressed: onPickThumbnail,
                    ),
                    if (availableThumbnails.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: Text(
                          context.t.songEditor.selectThumbnails.replaceAll(
                            '{count}',
                            availableThumbnails.length.toString(),
                          ),
                        ),
                        onPressed: onSelectThumbnail,
                      ),
                    if (hasAudioSources)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(context.t.common.extract),
                        onPressed: onReloadThumbnails,
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(context.t.common.remove),
                      onPressed: onClearThumbnail,
                    ),
                  ],
                ),
              ] else ...[
                if (isExtractingThumbnails)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(context.t.common.extractingThumbnails),
                      ],
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(context.t.songEditor.addImage),
                        onPressed: onPickThumbnail,
                      ),
                      if (availableThumbnails.isNotEmpty)
                        FilledButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: Text(
                            context.t.songEditor.selectThumbnails.replaceAll(
                              '{count}',
                              availableThumbnails.length.toString(),
                            ),
                          ),
                          onPressed: onSelectThumbnail,
                        ),
                      if (hasAudioSources)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(context.t.common.extract),
                          onPressed: onReloadThumbnails,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    availableThumbnails.isEmpty
                        ? context.t.songEditor.addImageOrExtract
                        : context.t.songEditor.thumbnailsAvailable.replaceAll('{count}', availableThumbnails.length.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
