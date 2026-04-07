import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/playback_state_storage.dart';
import '../../models/song_unit.dart';
import '../../models/tag_extensions.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/tag_repository.dart' show TagRepository, TagEvent;
import '../../views/player_control_panel.dart';
import '../player_view_model.dart';
import 'queue_display_item.dart';

/// Base class for TagViewModel containing shared state and lifecycle management.
///
/// All mixin methods operate on these shared fields. The final [TagViewModel]
/// composes this base with all mixins.
abstract class TagViewModelBase extends ChangeNotifier {
  TagViewModelBase({
    required TagRepository tagRepository,
    required LibraryRepository libraryRepository,
    required SettingsRepository settingsRepository,
    required PlaybackStateStorage playbackStateStorage,
  })  : tagRepository = tagRepository,
        libraryRepository = libraryRepository,
        settingsRepository = settingsRepository,
        playbackStateStorage = playbackStateStorage;

  // ---------------------------------------------------------------------------
  // Dependencies (protected — accessible by mixins)
  // ---------------------------------------------------------------------------

  @protected
  final TagRepository tagRepository;
  @protected
  final LibraryRepository libraryRepository;
  @protected
  final SettingsRepository settingsRepository;
  @protected
  final PlaybackStateStorage playbackStateStorage;
  @protected
  final Random random = Random();
  @protected
  final Uuid uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Player reference
  // ---------------------------------------------------------------------------

  @protected
  PlayerViewModel? playerViewModel;

  // ---------------------------------------------------------------------------
  // Tag state
  // ---------------------------------------------------------------------------

  @protected
  List<Tag> allTagsList = [];
  @protected
  List<Tag> builtInTagsList = [];
  @protected
  List<Tag> userTagsList = [];
  @protected
  List<Tag> automaticTagsList = [];

  // ---------------------------------------------------------------------------
  // Active queue state
  // ---------------------------------------------------------------------------

  @protected
  String activeQueueIdValue = 'default';
  @protected
  List<SongUnit> currentQueueSongsList = [];
  @protected
  List<QueueDisplayItem> queueDisplayItemsList = [];
  @protected
  int cachedCurrentIndex = -1;
  @protected
  bool cachedRemoveAfterPlay = false;
  @protected
  PlaybackMode playbackModeValue = PlaybackMode.sequential;

  // ---------------------------------------------------------------------------
  // Common state
  // ---------------------------------------------------------------------------

  @protected
  bool isLoadingValue = false;
  @protected
  String? errorValue;
  @protected
  bool suppressEvents = false;
  @protected
  StreamSubscription<TagEvent>? eventSubscription;
  @protected
  StreamSubscription<LibraryEvent>? librarySubscription;
  @protected
  Timer? saveDebounceTimer;

  // ---------------------------------------------------------------------------
  // Selection state
  // ---------------------------------------------------------------------------

  @protected
  final Set<String> selectedItemIdsSet = {};
  @protected
  bool selectionModeActiveValue = false;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// All tags
  List<Tag> get allTags => List.unmodifiable(allTagsList);

  /// Built-in tags only
  List<Tag> get builtInTags => List.unmodifiable(builtInTagsList);

  /// User-created tags only
  List<Tag> get userTags => List.unmodifiable(userTagsList);

  /// Automatic tags only
  List<Tag> get automaticTags => List.unmodifiable(automaticTagsList);

  /// Whether tags are loading
  bool get isLoading => isLoadingValue;

  /// Error message if any
  String? get error => errorValue;

  /// Get the active queue ID
  String get activeQueueId => activeQueueIdValue;

  /// Current playback queue (songs in active queue)
  List<SongUnit> get queueSongUnits => List.unmodifiable(currentQueueSongsList);

  /// Queue display items (songs + group headers for UI rendering)
  List<QueueDisplayItem> get queueDisplayItems =>
      List.unmodifiable(queueDisplayItemsList);

  /// Current index in the queue (-1 if nothing playing)
  int get currentIndex => cachedCurrentIndex;

  /// Currently playing Song Unit
  SongUnit? get currentSongUnit =>
      cachedCurrentIndex >= 0 &&
              cachedCurrentIndex < currentQueueSongsList.length
          ? currentQueueSongsList[cachedCurrentIndex]
          : null;

  /// Whether there's a next song in the queue
  bool get hasNext => cachedCurrentIndex < currentQueueSongsList.length - 1;

  /// Whether there's a previous song in the queue
  bool get hasPrevious => cachedCurrentIndex > 0;

  /// Number of songs in the queue
  int get queueLength => currentQueueSongsList.length;

  /// Whether the queue is empty
  bool get isEmpty => currentQueueSongsList.isEmpty;

  /// Current playback mode
  PlaybackMode get playbackMode => playbackModeValue;

  /// Whether to remove song from queue after playing (from active queue)
  bool get removeAfterPlay => cachedRemoveAfterPlay;

  /// Get the currently active queue tag
  Future<Tag?> get activeQueue async => getActiveQueue();

  // ---------------------------------------------------------------------------
  // Shared helpers used by multiple mixins
  // ---------------------------------------------------------------------------

  /// Get the active queue tag
  @protected
  Future<Tag?> getActiveQueue() async {
    return tagRepository.getCollectionTag(activeQueueIdValue);
  }

  /// Update the active queue's metadata
  @protected
  Future<void> updateActiveQueue(TagMetadata updatedMetadata) async {
    final updated = updatedMetadata.copyWith(updatedAt: DateTime.now().toIso8601String());
    await tagRepository.updateCollectionMetadata(activeQueueIdValue, updated);
  }

  /// Update cached values from active queue
  @protected
  Future<void> updateCachedValues() async {
    final aq = await getActiveQueue();
    if (aq?.metadata != null) {
      cachedCurrentIndex = aq!.metadata!.currentIndex;
      cachedRemoveAfterPlay = aq.metadata!.removeAfterPlay;
    } else {
      cachedCurrentIndex = -1;
      cachedRemoveAfterPlay = false;
    }
  }

  /// Categorize a single tag into the appropriate list
  @protected
  void categorizeTag(Tag tag) {
    switch (tag.tagType) {
      case TagType.builtIn:
        builtInTagsList = [...builtInTagsList, tag];
      case TagType.user:
        userTagsList = [...userTagsList, tag];
      case TagType.automatic:
        automaticTagsList = [...automaticTagsList, tag];
    }
  }

  /// Re-categorize all tags from allTagsList
  @protected
  void recategorizeTags() {
    builtInTagsList =
        allTagsList.where((t) => t.tagType == TagType.builtIn).toList();
    userTagsList = allTagsList.where((t) => t.tagType == TagType.user).toList();
    automaticTagsList =
        allTagsList.where((t) => t.tagType == TagType.automatic).toList();
  }

  /// Clear any error state
  void clearError() {
    errorValue = null;
    notifyListeners();
  }

  /// Set the PlayerViewModel reference for playing songs
  void setPlayerViewModel(PlayerViewModel pvm) {
    playerViewModel = pvm;
  }

  // ---------------------------------------------------------------------------
  // Methods that must be implemented by the composed class / mixins
  // ---------------------------------------------------------------------------

  /// Load all tags from the repository
  Future<void> loadTags();

  /// Load songs for the current active queue
  Future<void> loadCurrentQueueSongs();

  @override
  void dispose() {
    eventSubscription?.cancel();
    librarySubscription?.cancel();
    saveDebounceTimer?.cancel();
    super.dispose();
  }
}
