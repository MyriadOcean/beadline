import 'dart:math';
import 'package:beadline/models/entry_point_file.dart';
import 'package:beadline/models/library_location.dart';
import 'package:beadline/models/metadata.dart';
import 'package:beadline/models/playback_preferences.dart';
import 'package:beadline/models/song_unit.dart';
import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_collection.dart';
import 'package:beadline/models/source_origin.dart';
import 'package:beadline/models/tag.dart';
import 'package:uuid/uuid.dart';

/// Test data generators for property-based testing
class TestGenerators {
  static final Random _random = Random();
  static const Uuid _uuid = Uuid();

  /// Generate a random string
  static String randomString({int minLength = 1, int maxLength = 20}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  /// Generate a random integer in range
  static int randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  /// Generate a random duration
  static Duration randomDuration() {
    return Duration(seconds: randomInt(30, 600));
  }

  /// Generate a random year
  static int randomYear() {
    return randomInt(1950, 2024);
  }

  /// Generate a random SourceOrigin
  static SourceOrigin randomSourceOrigin() {
    final type = _random.nextInt(3);
    switch (type) {
      case 0:
        return LocalFileOrigin('/path/to/${randomString()}.mp3');
      case 1:
        return UrlOrigin('https://example.com/${randomString()}');
      case 2:
        return ApiOrigin(randomString(), randomString());
      default:
        return const LocalFileOrigin('/path/to/file.mp3');
    }
  }

  /// Generate a random DisplaySource
  static DisplaySource randomDisplaySource({int? priority}) {
    return DisplaySource(
      id: _uuid.v4(),
      origin: randomSourceOrigin(),
      priority: priority ?? randomInt(0, 10),
      displayType: _random.nextBool() ? DisplayType.video : DisplayType.image,
      duration: _random.nextBool() ? randomDuration() : null,
    );
  }

  /// Generate a random DisplaySource that is always a video.
  static DisplaySource randomVideoDisplaySource({int? priority}) {
    return DisplaySource(
      id: _uuid.v4(),
      origin: randomSourceOrigin(),
      priority: priority ?? randomInt(0, 10),
      displayType: DisplayType.video,
      duration: _random.nextBool() ? randomDuration() : null,
    );
  }

  /// Generate a random AudioSource with optional linkedVideoSourceId.
  /// By default, ~50% of generated sources will have a linked video ID.
  static AudioSource randomAudioSource({
    int? priority,
    String? linkedVideoSourceId,
    bool? includeLinkedVideoSourceId,
  }) {
    final shouldLink = includeLinkedVideoSourceId ?? _random.nextBool();
    return AudioSource(
      id: _uuid.v4(),
      origin: randomSourceOrigin(),
      priority: priority ?? randomInt(0, 10),
      format: AudioFormat.values[_random.nextInt(AudioFormat.values.length)],
      duration: randomDuration(),
      linkedVideoSourceId:
          linkedVideoSourceId ?? (shouldLink ? _uuid.v4() : null),
    );
  }

  /// Generate a random AccompanimentSource
  static AccompanimentSource randomAccompanimentSource({int? priority}) {
    return AccompanimentSource(
      id: _uuid.v4(),
      origin: randomSourceOrigin(),
      priority: priority ?? randomInt(0, 10),
      format: AudioFormat.values[_random.nextInt(AudioFormat.values.length)],
      duration: randomDuration(),
    );
  }

  /// Generate a random HoverSource
  static HoverSource randomHoverSource({int? priority}) {
    return HoverSource(
      id: _uuid.v4(),
      origin: randomSourceOrigin(),
      priority: priority ?? randomInt(0, 10),
      format: LyricsFormat.lrc,
    );
  }

  /// Generate a random Metadata
  static Metadata randomMetadata() {
    return Metadata(
      title: randomString(),
      artists: [randomString()],
      album: randomString(),
      year: _random.nextBool() ? randomYear() : null,
      duration: randomDuration(),
    );
  }

  /// Generate a random SourceCollection
  static SourceCollection randomSourceCollection({
    int maxDisplaySources = 3,
    int maxAudioSources = 3,
    int maxAccompanimentSources = 2,
    int maxHoverSources = 2,
  }) {
    return SourceCollection(
      displaySources: List.generate(
        _random.nextInt(maxDisplaySources + 1),
        (i) => randomDisplaySource(priority: i),
      ),
      audioSources: List.generate(
        _random.nextInt(maxAudioSources + 1),
        (i) => randomAudioSource(priority: i),
      ),
      accompanimentSources: List.generate(
        _random.nextInt(maxAccompanimentSources + 1),
        (i) => randomAccompanimentSource(priority: i),
      ),
      hoverSources: List.generate(
        _random.nextInt(maxHoverSources + 1),
        (i) => randomHoverSource(priority: i),
      ),
    );
  }

  /// Generate a random SourceCollection that contains at least one video
  /// DisplaySource and its linked AudioSource, plus optional extra sources.
  static SourceCollection randomSourceCollectionWithVideoAudioLinks({
    int linkedPairs = 1,
    int maxExtraDisplaySources = 2,
    int maxExtraAudioSources = 2,
    int maxAccompanimentSources = 2,
    int maxHoverSources = 2,
  }) {
    final displaySources = <DisplaySource>[];
    final audioSources = <AudioSource>[];

    // Create linked video-audio pairs
    for (var i = 0; i < linkedPairs; i++) {
      final video = randomVideoDisplaySource(priority: i);
      final linkedAudio = AudioSource(
        id: _uuid.v4(),
        origin: video.origin,
        priority: i,
        format: AudioFormat.other,
        duration: video.duration,
        displayName:
            'Audio from ${video.displayName ?? video.id}',
        linkedVideoSourceId: video.id,
      );
      displaySources.add(video);
      audioSources.add(linkedAudio);
    }

    // Add extra unlinked display sources
    final extraDisplayCount = _random.nextInt(maxExtraDisplaySources + 1);
    for (var i = 0; i < extraDisplayCount; i++) {
      displaySources.add(
        randomDisplaySource(priority: linkedPairs + i),
      );
    }

    // Add extra unlinked audio sources
    final extraAudioCount = _random.nextInt(maxExtraAudioSources + 1);
    for (var i = 0; i < extraAudioCount; i++) {
      audioSources.add(
        randomAudioSource(
          priority: linkedPairs + i,
          includeLinkedVideoSourceId: false,
        ),
      );
    }

    return SourceCollection(
      displaySources: displaySources,
      audioSources: audioSources,
      accompanimentSources: List.generate(
        _random.nextInt(maxAccompanimentSources + 1),
        (i) => randomAccompanimentSource(priority: i),
      ),
      hoverSources: List.generate(
        _random.nextInt(maxHoverSources + 1),
        (i) => randomHoverSource(priority: i),
      ),
    );
  }

  /// Generate a random Tag
  static Tag randomTag({TagType? type, String? parentId}) {
    return Tag(
      id: _uuid.v4(),
      name: randomString(),
      type: type ?? TagType.values[_random.nextInt(TagType.values.length)],
      parentId: parentId,
      aliasNames: List.generate(_random.nextInt(3), (_) => randomString()),
      includeChildren: _random.nextBool(),
    );
  }

  /// Generate a random user tag ID
  static String randomUserTagId() {
    return 'user:${randomString(minLength: 2, maxLength: 10)}';
  }

  /// Generate a random SongUnit
  static SongUnit randomSongUnit({
    Metadata? metadata,
    SourceCollection? sources,
    List<String>? tagIds,
    bool includeUserTag = false,
  }) {
    final generatedTagIds = tagIds ?? [];
    if (includeUserTag &&
        !generatedTagIds.any((id) => id.startsWith('user:'))) {
      generatedTagIds.add(randomUserTagId());
    }

    return SongUnit(
      id: _uuid.v4(),
      metadata: metadata ?? randomMetadata(),
      sources: sources ?? randomSourceCollection(),
      tagIds: generatedTagIds,
      preferences: PlaybackPreferences.defaults(),
    );
  }

  /// Generate a random LibraryLocation
  static LibraryLocation randomLibraryLocation({
    bool? isDefault,
    bool? isAccessible,
  }) {
    return LibraryLocation(
      id: _uuid.v4(),
      name: randomString(minLength: 3),
      rootPath: '/library/${randomString(minLength: 5, maxLength: 15)}',
      isDefault: isDefault ?? _random.nextBool(),
      addedAt: DateTime.now().subtract(Duration(days: randomInt(0, 365))),
      isAccessible: isAccessible ?? true,
    );
  }

  /// Alias for backward compatibility
  static LibraryLocation randomStorageLocation({
    bool? isDefault,
    bool? isAccessible,
  }) => randomLibraryLocation(isDefault: isDefault, isAccessible: isAccessible);

  /// Generate a list of random LibraryLocations
  static List<LibraryLocation> randomLibraryLocations({
    int minCount = 1,
    int maxCount = 5,
  }) {
    final count = randomInt(minCount, maxCount);
    final locations = <LibraryLocation>[];

    for (var i = 0; i < count; i++) {
      locations.add(
        randomLibraryLocation(
          isDefault: i == 0, // First one is default
        ),
      );
    }

    return locations;
  }

  /// Alias for backward compatibility
  static List<LibraryLocation> randomStorageLocations({
    int minCount = 1,
    int maxCount = 5,
  }) => randomLibraryLocations(minCount: minCount, maxCount: maxCount);

  /// Generate a random SongUnit with library location association
  static SongUnit randomSongUnitWithLibraryLocation({
    String? libraryLocationId,
    Metadata? metadata,
    SourceCollection? sources,
    List<String>? tagIds,
  }) {
    return SongUnit(
      id: _uuid.v4(),
      metadata: metadata ?? randomMetadata(),
      sources: sources ?? randomSourceCollection(),
      tagIds: tagIds ?? [],
      preferences: PlaybackPreferences.defaults(),
      libraryLocationId: libraryLocationId,
    );
  }

  /// Alias for backward compatibility
  static SongUnit randomSongUnitWithStorageLocation({
    String? storageLocationId,
    Metadata? metadata,
    SourceCollection? sources,
    List<String>? tagIds,
  }) => randomSongUnitWithLibraryLocation(
    libraryLocationId: storageLocationId,
    metadata: metadata,
    sources: sources,
    tagIds: tagIds,
  );

  /// Generate a random relative path segment (no leading/trailing slashes)
  static String randomPathSegment({int minLength = 1, int maxLength = 15}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
  }

  /// Generate a random file extension
  static String randomFileExtension() {
    const extensions = [
      'mp3',
      'mp4',
      'wav',
      'flac',
      'ogg',
      'lrc',
      'txt',
      'json',
    ];
    return extensions[_random.nextInt(extensions.length)];
  }

  /// Generate a random absolute path within a library location
  static String randomAbsolutePathInStorage(
    LibraryLocation location, {
    int maxDepth = 3,
  }) {
    final depth = randomInt(0, maxDepth);
    final segments = <String>[location.rootPath];

    for (var i = 0; i < depth; i++) {
      segments.add(randomPathSegment());
    }

    // Add filename with extension
    segments.add('${randomPathSegment()}.${randomFileExtension()}');

    return segments.join('/');
  }

  /// Generate a random absolute path outside any library location
  static String randomAbsolutePathOutsideStorage(
    List<LibraryLocation> locations,
  ) {
    // Generate a path that doesn't start with any library location root
    String basePath;
    do {
      basePath = '/other/${randomPathSegment()}/${randomPathSegment()}';
    } while (locations.any((loc) => basePath.startsWith(loc.rootPath)));

    return '$basePath/${randomPathSegment()}.${randomFileExtension()}';
  }

  /// Generate a random entry point file path within a library location
  static String randomEntryPointPath(
    LibraryLocation location, {
    int maxDepth = 2,
  }) {
    final depth = randomInt(0, maxDepth);
    final segments = <String>[location.rootPath];

    for (var i = 0; i < depth; i++) {
      segments.add(randomPathSegment());
    }

    // Add entry point filename
    segments.add('.beadline-${randomPathSegment()}.json');

    return segments.join('/');
  }

  /// Generate a random SourceReference
  static SourceReference randomSourceReference({
    String? sourceType,
    bool useLocalFile = true,
  }) {
    final type =
        sourceType ??
        ['display', 'audio', 'accompaniment', 'hover'][_random.nextInt(4)];
    String originType;
    String path;
    final metadata = <String, dynamic>{};

    if (useLocalFile) {
      originType = 'localFile';
      // Use relative path format
      path = './${randomPathSegment()}.${randomFileExtension()}';
    } else {
      final originChoice = _random.nextInt(3);
      switch (originChoice) {
        case 0:
          originType = 'localFile';
          path = './${randomPathSegment()}.${randomFileExtension()}';
        case 1:
          originType = 'url';
          path =
              'https://example.com/${randomPathSegment()}.${randomFileExtension()}';
        default:
          originType = 'api';
          path = '${randomString()}:${randomString()}';
          metadata['provider'] = randomString();
          metadata['resourceId'] = randomString();
      }
    }

    // Add type-specific metadata
    switch (type) {
      case 'display':
        metadata['displayType'] = _random.nextBool() ? 'video' : 'image';
        if (_random.nextBool()) {
          metadata['duration'] = randomDuration().inMicroseconds;
        }
      case 'audio':
      case 'accompaniment':
        metadata['format'] =
            AudioFormat.values[_random.nextInt(AudioFormat.values.length)].name;
        metadata['duration'] = randomDuration().inMicroseconds;
      case 'hover':
        metadata['format'] = 'lrc';
    }

    return SourceReference(
      id: _uuid.v4(),
      sourceType: type,
      originType: originType,
      path: path,
      priority: randomInt(0, 10),
      metadata: metadata,
    );
  }

  /// Generate a random EntryPointFile
  static EntryPointFile randomEntryPointFile({
    int? sourceCount,
    List<String>? tagIds,
  }) {
    final now = DateTime.now();
    final createdAt = now.subtract(Duration(days: randomInt(0, 365)));

    return EntryPointFile(
      songUnitId: _uuid.v4(),
      name: randomString(minLength: 3, maxLength: 30),
      metadata: randomMetadata(),
      sources: List.generate(
        sourceCount ?? randomInt(1, 5),
        (_) => randomSourceReference(),
      ),
      tagIds: tagIds ?? List.generate(randomInt(0, 3), (_) => _uuid.v4()),
      playbackPreferences: _random.nextBool()
          ? PlaybackPreferences.defaults()
          : null,
      createdAt: createdAt,
      modifiedAt: now,
    );
  }

  /// Generate a random Song Unit name with potentially invalid filename characters
  static String randomSongUnitNameWithSpecialChars() {
    const baseChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
    const specialChars = r'<>:"/\|?*';

    final length = randomInt(5, 30);
    final buffer = StringBuffer();

    for (var i = 0; i < length; i++) {
      // 20% chance of special character
      if (_random.nextInt(5) == 0) {
        buffer.write(specialChars[_random.nextInt(specialChars.length)]);
      } else {
        buffer.write(baseChars[_random.nextInt(baseChars.length)]);
      }
    }

    return buffer.toString();
  }

  /// Generate a SongUnit with sources that have local file origins within a library location
  static SongUnit randomSongUnitWithLocalSources(LibraryLocation location) {
    final entryPointDir = '${location.rootPath}/${randomPathSegment()}';

    // Generate sources with absolute paths within the storage location
    final displaySources = <DisplaySource>[];
    final audioSources = <AudioSource>[];
    final hoverSources = <HoverSource>[];

    // Add at least one audio source
    audioSources.add(
      AudioSource(
        id: _uuid.v4(),
        origin: LocalFileOrigin('$entryPointDir/${randomPathSegment()}.mp3'),
        priority: 0,
        format: AudioFormat.mp3,
        duration: randomDuration(),
      ),
    );

    // Optionally add display source
    if (_random.nextBool()) {
      displaySources.add(
        DisplaySource(
          id: _uuid.v4(),
          origin: LocalFileOrigin('$entryPointDir/${randomPathSegment()}.mp4'),
          priority: 0,
          displayType: DisplayType.video,
          duration: randomDuration(),
        ),
      );
    }

    // Optionally add hover source
    if (_random.nextBool()) {
      hoverSources.add(
        HoverSource(
          id: _uuid.v4(),
          origin: LocalFileOrigin('$entryPointDir/${randomPathSegment()}.lrc'),
          priority: 0,
          format: LyricsFormat.lrc,
        ),
      );
    }

    return SongUnit(
      id: _uuid.v4(),
      metadata: randomMetadata(),
      sources: SourceCollection(
        displaySources: displaySources,
        audioSources: audioSources,
        accompanimentSources: [],
        hoverSources: hoverSources,
      ),
      tagIds: [],
      preferences: PlaybackPreferences.defaults(),
    );
  }
}
