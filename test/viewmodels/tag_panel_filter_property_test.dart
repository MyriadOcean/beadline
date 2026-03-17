/// Task 19.2: Property test for tag panel filter
///
/// Properties tested:
/// - Property 38: Tag Panel Filter Shows Only User Non-Group Tags
///
/// **Validates: Requirements 19.1, 19.2, 19.3, 19.4**
library;

import 'dart:math';

import 'package:beadline/models/playlist_metadata.dart';
import 'package:beadline/models/tag.dart';
import 'package:beadline/viewmodels/tag_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'shuffle_locks_property_test.dart';

// ============================================================================
// Test generators for tag panel filter tests
// ============================================================================

class TagPanelFilterGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  /// Generate a random TagType.
  static TagType randomTagType() {
    const types = TagType.values;
    return types[_random.nextInt(types.length)];
  }

  /// Generate a random boolean.
  static bool randomBool() => _random.nextBool();

  /// Generate a random tag with random type and isGroup.
  /// If the tag is a group, it gets PlaylistMetadata (groups are collections).
  static Tag randomTag({String? id}) {
    final tagId = id ?? _uuid.v4();
    final type = randomTagType();
    final isGroup = randomBool();
    final name = 'Tag_${tagId.substring(0, 8)}';

    // Groups must be collections (have PlaylistMetadata)
    PlaylistMetadata? metadata;
    if (isGroup) {
      metadata = PlaylistMetadata.empty();
    } else if (randomBool()) {
      // Some non-group tags may also be collections
      metadata = PlaylistMetadata.empty();
    }

    return Tag(
      id: tagId,
      name: name,
      type: type,
      isGroup: isGroup,
      playlistMetadata: metadata,
    );
  }

  /// Generate a set of random tags with a guaranteed mix of types and isGroup values.
  static List<Tag> randomTagSet({int minCount = 5, int maxCount = 20}) {
    final count = minCount + _random.nextInt(maxCount - minCount + 1);
    final tags = <Tag>[];

    for (var i = 0; i < count; i++) {
      tags.add(randomTag());
    }

    return tags;
  }
}

// ============================================================================
// Test context helper
// ============================================================================

class TagPanelFilterTestContext {
  TagPanelFilterTestContext() {
    songUnitStorage = InMemorySongUnitStorage();
    tagStorage = InMemoryTagStorage();
    libraryRepo = MockLibraryRepository(songUnitStorage);
    tagRepo = MockTagRepository(tagStorage);
    settingsRepo = MockSettingsRepository();
    playbackStorage = MockPlaybackStateStorage();

    // Create default queue (required by TagViewModel)
    tagStorage.add(
      Tag(
        id: 'default',
        name: 'Default Queue',
        type: TagType.user,
        playlistMetadata: PlaylistMetadata.empty().copyWith(currentIndex: 0),
      ),
    );

    viewModel = TagViewModel(
      tagRepository: tagRepo,
      libraryRepository: libraryRepo,
      settingsRepository: settingsRepo,
      playbackStateStorage: playbackStorage,
    );
  }

  late final InMemorySongUnitStorage songUnitStorage;
  late final InMemoryTagStorage tagStorage;
  late final MockLibraryRepository libraryRepo;
  late final MockTagRepository tagRepo;
  late final MockSettingsRepository settingsRepo;
  late final MockPlaybackStateStorage playbackStorage;
  late final TagViewModel viewModel;

  /// Load a set of tags into the storage and refresh the ViewModel.
  Future<void> loadTags(List<Tag> tags) async {
    for (final tag in tags) {
      tagStorage.add(tag);
    }
    await viewModel.loadTags();
  }

  void dispose() {
    viewModel.dispose();
    libraryRepo.dispose();
    tagRepo.dispose();
    songUnitStorage.clear();
    tagStorage.clear();
  }
}

// ============================================================================
// Property tests
// ============================================================================

void main() {
  group('Tag Panel Filter Property Tests (Task 19.2)', () {
    // ========================================================================
    // Feature: queue-playlist-system, Property 38: Tag Panel Filter Shows Only User Non-Group Tags
    // **Validates: Requirements 19.1, 19.2, 19.3, 19.4**
    //
    // For any set of tags in the system (including built-in, user, automatic,
    // and group tags), the tag panel filter should return exactly the subset
    // where type == TagType.user and isGroup == false.
    // ========================================================================
    test(
      'Property 38: Tag Panel Filter Shows Only User Non-Group Non-Collection Tags - '
      'getTagPanelTags returns exactly user tags where isGroup is false and isCollection is false',
      () async {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final ctx = TagPanelFilterTestContext();
          await Future.delayed(const Duration(milliseconds: 10));

          // Generate a random set of tags
          final tags = TagPanelFilterGenerators.randomTagSet();

          // Load them into the ViewModel
          await ctx.loadTags(tags);

          // Call getTagPanelTags
          final panelTags = ctx.viewModel.getTagPanelTags();

          // Compute the expected set: all tags (including the default queue)
          // that have type == user and isGroup == false and isCollection == false
          final allTagsInSystem = [
            ...tags,
            Tag(
              id: 'default',
              name: 'Default Queue',
              type: TagType.user,
              playlistMetadata: PlaylistMetadata.empty().copyWith(
                currentIndex: 0,
              ),
            ),
          ];
          final expected = allTagsInSystem
              .where(
                (t) => t.type == TagType.user && !t.isGroup && !t.isCollection,
              )
              .toList();

          // Verify: the result set has the same size
          expect(
            panelTags.length,
            equals(expected.length),
            reason:
                'Iteration $i: panelTags count should match expected '
                '(got ${panelTags.length}, expected ${expected.length})',
          );

          // Verify: every tag in panelTags is user type and not a group
          for (final tag in panelTags) {
            expect(
              tag.type,
              equals(TagType.user),
              reason:
                  'Iteration $i: tag "${tag.name}" should be user type, '
                  'got ${tag.type}',
            );
            expect(
              tag.isGroup,
              isFalse,
              reason: 'Iteration $i: tag "${tag.name}" should not be a group',
            );
          }

          // Verify: every expected tag is present in panelTags
          final panelTagIds = panelTags.map((t) => t.id).toSet();
          for (final tag in expected) {
            expect(
              panelTagIds.contains(tag.id),
              isTrue,
              reason:
                  'Iteration $i: expected tag "${tag.name}" (id=${tag.id}) '
                  'should be in panelTags',
            );
          }

          // Verify: no built-in tags are present
          final builtInInPanel = panelTags
              .where((t) => t.type == TagType.builtIn)
              .toList();
          expect(
            builtInInPanel,
            isEmpty,
            reason: 'Iteration $i: no built-in tags should be in panel',
          );

          // Verify: no automatic tags are present
          final automaticInPanel = panelTags
              .where((t) => t.type == TagType.automatic)
              .toList();
          expect(
            automaticInPanel,
            isEmpty,
            reason: 'Iteration $i: no automatic tags should be in panel',
          );

          // Verify: no group tags are present
          final groupsInPanel = panelTags.where((t) => t.isGroup).toList();
          expect(
            groupsInPanel,
            isEmpty,
            reason: 'Iteration $i: no group tags should be in panel',
          );

          // Verify: no collection tags are present
          final collectionsInPanel = panelTags
              .where((t) => t.isCollection)
              .toList();
          expect(
            collectionsInPanel,
            isEmpty,
            reason: 'Iteration $i: no collection tags should be in panel',
          );

          ctx.dispose();
        }
      },
    );
  });
}
