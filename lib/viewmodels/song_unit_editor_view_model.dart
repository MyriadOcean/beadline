import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:uuid/uuid.dart';

import '../models/configuration_mode.dart';
import '../models/metadata.dart';
import '../models/online_provider_config.dart';
import '../models/playback_preferences.dart';
import '../models/song_unit.dart';
import '../models/source.dart';
import '../models/source_collection.dart';
import '../models/source_origin.dart';
import '../services/metadata_extractor.dart';
import '../services/source_auto_matcher.dart';
import '../services/thumbnail_cache.dart';
import '../services/thumbnail_extractor.dart';
import '../services/video_audio_extraction_service.dart';
import '../viewmodels/library_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../views/song_unit_editor/source_with_validation.dart';

/// ViewModel for the Song Unit editor.
/// Owns all business logic: metadata extraction, thumbnail management,
/// source validation, duration calculation, auto-discovery, and save/load.
class SongUnitEditorViewModel extends ChangeNotifier {
  SongUnitEditorViewModel({
    required LibraryViewModel libraryViewModel,
    required SettingsViewModel settingsViewModel,
    MetadataExtractor? metadataExtractor,
    ThumbnailExtractor? thumbnailExtractor,
    SourceAutoMatcher? sourceAutoMatcher,
    VideoAudioExtractionService? videoAudioExtractionService,
  })  : _libraryViewModel = libraryViewModel,
        _settingsViewModel = settingsViewModel,
        _metadataExtractor = metadataExtractor ?? MetadataExtractor(),
        _thumbnailExtractor = thumbnailExtractor ?? ThumbnailExtractor(),
        _sourceAutoMatcher = sourceAutoMatcher ?? SourceAutoMatcher(),
        _videoAudioExtractionService =
            videoAudioExtractionService ?? VideoAudioExtractionService();

  final LibraryViewModel _libraryViewModel;
  final SettingsViewModel _settingsViewModel;
  final MetadataExtractor _metadataExtractor;
  final ThumbnailExtractor _thumbnailExtractor;
  final SourceAutoMatcher _sourceAutoMatcher;
  final VideoAudioExtractionService _videoAudioExtractionService;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String _name = '';
  String _album = '';
  String _time = '';
  List<String> _artistValues = [];

  String? _thumbnailPath;
  final Map<String, String> _availableThumbnails = {};
  final Map<String, String> _thumbnailToSourceId = {};
  bool _isExtractingThumbnails = false;

  List<SourceWithValidation> _displaySources = [];
  List<SourceWithValidation> _audioSources = [];
  List<SourceWithValidation> _accompanimentSources = [];
  List<SourceWithValidation> _hoverSources = [];

  Set<String> _selectedUserTagIds = {};

  bool _isLoading = false;
  bool _isEditing = false;
  SongUnit? _originalSongUnit;

  /// User-facing message from the last operation.
  EditorMessage? _message;

  /// Whether the last save succeeded and the view should pop.
  bool _shouldPop = false;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  String get name => _name;
  String get album => _album;
  String get time => _time;
  List<String> get artistValues => List.unmodifiable(_artistValues);

  String? get thumbnailPath => _thumbnailPath;
  Map<String, String> get availableThumbnails =>
      Map.unmodifiable(_availableThumbnails);
  bool get isExtractingThumbnails => _isExtractingThumbnails;

  List<SourceWithValidation> get displaySources => _displaySources;
  List<SourceWithValidation> get audioSources => _audioSources;
  List<SourceWithValidation> get accompanimentSources => _accompanimentSources;
  List<SourceWithValidation> get hoverSources => _hoverSources;

  Set<String> get selectedUserTagIds => Set.unmodifiable(_selectedUserTagIds);

  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  bool get hasAudioSources =>
      _audioSources.isNotEmpty || _accompanimentSources.isNotEmpty;

  EditorMessage? consumeMessage() {
    final msg = _message;
    _message = null;
    return msg;
  }

  bool consumeShouldPop() {
    final v = _shouldPop;
    _shouldPop = false;
    return v;
  }

  // ---------------------------------------------------------------------------
  // Metadata setters (called from text field callbacks)
  // ---------------------------------------------------------------------------

  void setName(String v) => _name = v;
  void setAlbum(String v) => _album = v;
  void setTime(String v) => _time = v;

  void addArtists(String artistString) {
    _artistValues.addAll(_parseArtists(artistString));
    notifyListeners();
  }

  void removeArtist(int index) {
    _artistValues.removeAt(index);
    notifyListeners();
  }

  void toggleUserTag(String tagId, bool selected) {
    if (selected) {
      _selectedUserTagIds.add(tagId);
    } else {
      _selectedUserTagIds.remove(tagId);
    }
    notifyListeners();
  }

  void clearThumbnail() {
    _thumbnailPath = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> loadSongUnit(String songUnitId) async {
    _isEditing = true;
    _isLoading = true;
    notifyListeners();

    final songUnit = await _libraryViewModel.getSongUnit(songUnitId);

    if (songUnit != null) {
      _originalSongUnit = songUnit;
      _name = songUnit.metadata.title;
      _artistValues = List.from(songUnit.metadata.artists);
      _album = songUnit.metadata.album;
      _time = songUnit.metadata.year?.toString() ?? '';

      _displaySources = songUnit.sources.displaySources
          .map((s) => SourceWithValidation(s, null))
          .toList();
      _audioSources = songUnit.sources.audioSources
          .map((s) => SourceWithValidation(s, null))
          .toList();
      _accompanimentSources = songUnit.sources.accompanimentSources
          .map((s) => SourceWithValidation(s, null))
          .toList();
      _hoverSources = songUnit.sources.hoverSources
          .map((s) => SourceWithValidation(s, null))
          .toList();

      _selectedUserTagIds = Set.from(songUnit.tagIds);
      _isLoading = false;
      notifyListeners();

      // Load thumbnail from cache
      await _loadThumbnailFromCache(songUnit);

      // Extract thumbnails silently in background
      await _extractThumbnailsSilently();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadThumbnailFromCache(SongUnit songUnit) async {
    if (songUnit.metadata.thumbnailSourceId == null) return;

    final cachedPath = await ThumbnailCache.instance.getThumbnail(
      songUnit.metadata.thumbnailSourceId!,
    );
    if (cachedPath == null) return;

    _thumbnailPath = cachedPath;
    _thumbnailToSourceId[cachedPath] = songUnit.metadata.thumbnailSourceId!;

    final isCustom =
        songUnit.metadata.thumbnailSourceId!.startsWith('custom_');
    String displayName;

    if (isCustom) {
      displayName =
          'Custom: ${songUnit.metadata.thumbnailSourceId!.substring(7, 15)}...';
    } else {
      final matchingSource = [
        ...songUnit.sources.audioSources,
        ...songUnit.sources.accompanimentSources,
      ]
          .where((s) => s.id == songUnit.metadata.thumbnailSourceId)
          .firstOrNull;

      if (matchingSource != null &&
          matchingSource.origin is LocalFileOrigin) {
        final fileName = (matchingSource.origin as LocalFileOrigin)
            .path
            .split('/')
            .last
            .split('\\')
            .last;
        displayName = 'From: $fileName';
      } else {
        displayName =
            'From: ${songUnit.metadata.thumbnailSourceId!.substring(0, 8)}...';
      }
    }

    _availableThumbnails[displayName] = cachedPath;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  /// Returns true if validation passes and save can proceed.
  /// The view should check [consumeShouldPop] after calling this.
  Future<bool> saveSongUnit() async {
    if (_settingsViewModel.configMode == ConfigurationMode.inPlace &&
        _settingsViewModel.settings.libraryLocations.isEmpty) {
      _message = const EditorMessage.cannotSaveInPlaceNoLocations();
      notifyListeners();
      return false;
    }

    final duration = _calculateDurationFromSources();

    String? thumbnailSourceId;
    if (_thumbnailPath != null) {
      final fileName = _thumbnailPath!.split('/').last.split('\\').last;
      final hash = fileName.endsWith('.jpg')
          ? fileName.substring(0, fileName.length - 4)
          : fileName;
      if (hash.length == 64) thumbnailSourceId = hash;
    }

    final metadata = Metadata(
      title: _name,
      artists: _artistValues,
      album: _album,
      year: _time.isNotEmpty ? int.tryParse(_time) : null,
      duration: duration,
      thumbnailSourceId: thumbnailSourceId,
    );

    final sources = SourceCollection(
      displaySources:
          _displaySources.map((s) => s.source as DisplaySource).toList(),
      audioSources:
          _audioSources.map((s) => s.source as AudioSource).toList(),
      accompanimentSources: _accompanimentSources
          .map((s) => s.source as AccompanimentSource)
          .toList(),
      hoverSources:
          _hoverSources.map((s) => s.source as HoverSource).toList(),
    );

    if (_isEditing && _originalSongUnit != null) {
      final updated = _originalSongUnit!.copyWith(
        metadata: metadata,
        sources: sources,
        tagIds: _selectedUserTagIds.toList(),
      );
      await _libraryViewModel.updateSongUnitWithConfig(
        songUnit: updated,
        configMode: _settingsViewModel.configMode,
        libraryLocations: _settingsViewModel.settings.libraryLocations,
      );
    } else {
      final songUnit = SongUnit(
        id: _uuid.v4(),
        metadata: metadata,
        sources: sources,
        tagIds: _selectedUserTagIds.toList(),
        preferences: const PlaybackPreferences(),
      );
      await _libraryViewModel.addSongUnitWithConfig(
        songUnit: songUnit,
        configMode: _settingsViewModel.configMode,
        libraryLocations: _settingsViewModel.settings.libraryLocations,
      );
    }

    _shouldPop = true;
    notifyListeners();
    return true;
  }

  Duration _calculateDurationFromSources() {
    for (final s in _audioSources) {
      final d = s.source.getDuration();
      if (d != null && d > Duration.zero) return d;
    }
    for (final s in _accompanimentSources) {
      final d = s.source.getDuration();
      if (d != null && d > Duration.zero) return d;
    }
    return Duration.zero;
  }

  // ---------------------------------------------------------------------------
  // Source operations
  // ---------------------------------------------------------------------------

  void reorderSources(
    List<SourceWithValidation> sources,
    SourceType type,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final item = sources.removeAt(oldIndex);
    sources.insert(newIndex, item);
    _updateSourcePriorities(sources, type);
    notifyListeners();
  }

  /// Remove a source. Returns a [VideoRemovalQuery] if the view needs to
  /// prompt the user about linked video/audio removal, otherwise null.
  VideoRemovalQuery? prepareRemoveSource(
    List<SourceWithValidation> sources,
    SourceType type,
    int index,
  ) {
    if (type == SourceType.display) {
      final source = sources[index].source;
      if (source is DisplaySource && source.displayType == DisplayType.video) {
        for (var i = 0; i < _audioSources.length; i++) {
          final audio = _audioSources[i].source;
          if (audio is AudioSource && audio.linkedVideoSourceId == source.id) {
            return VideoRemovalQuery(
              sources: sources,
              type: type,
              index: index,
              videoSource: source,
              linkedAudio: audio,
              linkedAudioIndex: i,
            );
          }
        }
      }
    }
    // No prompt needed — remove directly
    sources.removeAt(index);
    _updateSourcePriorities(sources, type);
    notifyListeners();
    return null;
  }

  /// Execute removal after user chose an action from the video removal prompt.
  void executeVideoRemoval(VideoRemovalQuery query, VideoRemovalChoice choice) {
    switch (choice) {
      case VideoRemovalChoice.cancel:
        return;
      case VideoRemovalChoice.removeBoth:
        query.sources.removeAt(query.index);
        _updateSourcePriorities(query.sources, query.type);
        _audioSources.removeAt(query.linkedAudioIndex);
        _updateSourcePriorities(_audioSources, SourceType.audio);
      case VideoRemovalChoice.keepAudio:
        query.sources.removeAt(query.index);
        _updateSourcePriorities(query.sources, query.type);
        final la = query.linkedAudio;
        final updated = AudioSource(
          id: la.id,
          origin: la.origin,
          priority: la.priority,
          displayName: la.displayName,
          format: la.format,
          duration: la.duration,
          offset: la.offset,
        );
        _audioSources[query.linkedAudioIndex] = SourceWithValidation(
          updated,
          _audioSources[query.linkedAudioIndex].error,
        );
        _updateSourcePriorities(_audioSources, SourceType.audio);
    }
    notifyListeners();
  }

  void updateSourceOffset(
    List<SourceWithValidation> sources,
    SourceType type,
    int index,
    Duration offset,
  ) {
    final item = sources[index];
    Source updated;
    switch (type) {
      case SourceType.display:
        updated = (item.source as DisplaySource).copyWith(offset: offset);
      case SourceType.audio:
        updated = (item.source as AudioSource).copyWith(offset: offset);
      case SourceType.accompaniment:
        updated =
            (item.source as AccompanimentSource).copyWith(offset: offset);
      case SourceType.hover:
        updated = (item.source as HoverSource).copyWith(offset: offset);
    }
    sources[index] = SourceWithValidation(updated, item.error);
    notifyListeners();
  }

  void updateSourceDisplayName(
    List<SourceWithValidation> sources,
    SourceType type,
    int index,
    String? displayName,
  ) {
    final item = sources[index];
    Source updated;
    switch (type) {
      case SourceType.display:
        updated =
            (item.source as DisplaySource).copyWith(displayName: displayName);
      case SourceType.audio:
        updated =
            (item.source as AudioSource).copyWith(displayName: displayName);
      case SourceType.accompaniment:
        updated = (item.source as AccompanimentSource).copyWith(
          displayName: displayName,
        );
      case SourceType.hover:
        updated =
            (item.source as HoverSource).copyWith(displayName: displayName);
    }
    sources[index] = SourceWithValidation(updated, item.error);
    notifyListeners();
  }

  void _updateSourcePriorities(
    List<SourceWithValidation> sources,
    SourceType type,
  ) {
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i].source;
      Source updated;
      switch (type) {
        case SourceType.display:
          updated = (s as DisplaySource).copyWith(priority: i);
        case SourceType.audio:
          updated = (s as AudioSource).copyWith(priority: i);
        case SourceType.accompaniment:
          updated = (s as AccompanimentSource).copyWith(priority: i);
        case SourceType.hover:
          updated = (s as HoverSource).copyWith(priority: i);
      }
      sources[i] = SourceWithValidation(updated, sources[i].error);
    }
  }

  List<SourceWithValidation> getSourceList(SourceType type) {
    switch (type) {
      case SourceType.display:
        return _displaySources;
      case SourceType.audio:
        return _audioSources;
      case SourceType.accompaniment:
        return _accompanimentSources;
      case SourceType.hover:
        return _hoverSources;
    }
  }

  // ---------------------------------------------------------------------------
  // Add source
  // ---------------------------------------------------------------------------

  /// Add a source. Returns true if a URL validation warning should be shown.
  Future<bool> addSource(SourceType type, SourceOrigin origin) async {
    final id = _uuid.v4();
    Source source;
    bool urlWarning = false;

    // Validate URL
    if (origin is UrlOrigin &&
        (type == SourceType.audio ||
            type == SourceType.accompaniment ||
            type == SourceType.display)) {
      final uri = Uri.tryParse(origin.url);
      if (uri != null) {
        final path = uri.path.toLowerCase();
        final hasMediaExtension = path.endsWith('.mp3') ||
            path.endsWith('.m4a') || path.endsWith('.aac') ||
            path.endsWith('.wav') || path.endsWith('.flac') ||
            path.endsWith('.ogg') || path.endsWith('.mp4') ||
            path.endsWith('.mkv') || path.endsWith('.webm') ||
            path.endsWith('.avi') || path.endsWith('.mov');
        if (!hasMediaExtension) {
          urlWarning = true;
        }
      }
    }

    // Create source immediately
    switch (type) {
      case SourceType.display:
        source = DisplaySource(
          id: id,
          origin: origin,
          priority: _displaySources.length,
          displayType: _isVideoOrigin(origin)
              ? DisplayType.video
              : DisplayType.image,
        );
        _displaySources.add(SourceWithValidation(source, null));
      case SourceType.audio:
        source = AudioSource(
          id: id,
          origin: origin,
          priority: _audioSources.length,
          format: _getAudioFormat(origin),
        );
        _audioSources.add(SourceWithValidation(source, null));
      case SourceType.accompaniment:
        source = AccompanimentSource(
          id: id,
          origin: origin,
          priority: _accompanimentSources.length,
          format: _getAudioFormat(origin),
        );
        _accompanimentSources.add(SourceWithValidation(source, null));
      case SourceType.hover:
        source = HoverSource(
          id: id,
          origin: origin,
          priority: _hoverSources.length,
          format: LyricsFormat.lrc,
        );
        _hoverSources.add(SourceWithValidation(source, null));
    }
    notifyListeners();

    // Background: extract duration
    if (type == SourceType.audio ||
        type == SourceType.accompaniment ||
        type == SourceType.display) {
      final duration = await _extractDuration(origin);
      if (duration != null) {
        final sourceList = getSourceList(type);
        final idx = sourceList.indexWhere((s) => s.source.id == id);
        if (idx != -1) {
          Source updatedSource;
          switch (type) {
            case SourceType.display:
              updatedSource = (sourceList[idx].source as DisplaySource)
                  .copyWith(duration: duration);
            case SourceType.audio:
              updatedSource = (sourceList[idx].source as AudioSource)
                  .copyWith(duration: duration);
            case SourceType.accompaniment:
              updatedSource =
                  (sourceList[idx].source as AccompanimentSource)
                      .copyWith(duration: duration);
            default:
              updatedSource = sourceList[idx].source;
          }
          sourceList[idx] = SourceWithValidation(updatedSource, null);
          notifyListeners();
        }
      }
      if (duration == null && origin is UrlOrigin) {
        _message = const EditorMessage.failedToLoadUrl();
        notifyListeners();
      }
    }

    // Extract metadata from first real audio source
    if (type == SourceType.audio) {
      final hasOtherReal = _audioSources.any((s) {
        final src = s.source;
        return src.id != id &&
            src is AudioSource &&
            src.linkedVideoSourceId == null;
      });
      if (!hasOtherReal) {
        await _extractMetadataFromOrigin(origin);
      }
    }

    // Extract thumbnail
    if (type == SourceType.audio || type == SourceType.accompaniment) {
      await _extractThumbnailFromOrigin(origin, id);
    }

    // Auto-discover related sources
    if (origin is LocalFileOrigin) {
      await _autoDiscoverRelatedSources(origin.path);
    }

    // Extract audio from video
    if (type == SourceType.display &&
        source is DisplaySource &&
        source.displayType == DisplayType.video) {
      await _tryExtractAudioFromVideo(source);
    }

    return urlWarning;
  }

  // ---------------------------------------------------------------------------
  // Format / type helpers
  // ---------------------------------------------------------------------------

  static String getSourceName(Source source) {
    switch (source.origin) {
      case LocalFileOrigin(:final path):
        return path.split('/').last.split('\\').last;
      case UrlOrigin(:final url):
        return Uri.tryParse(url)?.pathSegments.lastOrNull ?? url;
      case ApiOrigin(:final provider, :final resourceId):
        return '$provider: $resourceId';
    }
  }

  String? getLinkedVideoName(Source source) {
    if (source is! AudioSource || source.linkedVideoSourceId == null) {
      return null;
    }
    final videoId = source.linkedVideoSourceId!;
    for (final item in _displaySources) {
      if (item.source.id == videoId) {
        return item.source.displayName ?? getSourceName(item.source);
      }
    }
    return videoId.substring(0, 8);
  }

  bool _isVideoOrigin(SourceOrigin origin) {
    switch (origin) {
      case LocalFileOrigin(:final path):
        return _isVideoPath(path);
      case UrlOrigin(:final url):
        return _isVideoPath(url);
      case ApiOrigin():
        return true;
    }
  }

  bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext);
  }

  AudioFormat _getAudioFormat(SourceOrigin origin) {
    switch (origin) {
      case LocalFileOrigin(:final path):
        return _audioFormatFromPath(path);
      case UrlOrigin(:final url):
        return _audioFormatFromPath(url);
      case ApiOrigin():
        return AudioFormat.other;
    }
  }

  AudioFormat _audioFormatFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'mp3' => AudioFormat.mp3,
      'flac' => AudioFormat.flac,
      'wav' => AudioFormat.wav,
      'aac' => AudioFormat.aac,
      'ogg' => AudioFormat.ogg,
      'm4a' => AudioFormat.m4a,
      _ => AudioFormat.other,
    };
  }

  List<String> _parseArtists(String artistString) {
    if (artistString.isEmpty) return [];
    final normalized = artistString
        .replaceAll(RegExp(r'\s*[,;/&]\s*'), '|')
        .replaceAll(RegExp(r'\s+feat\.?\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+ft\.?\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+featuring\s+', caseSensitive: false), '|')
        .replaceAll(RegExp(r'\s+×\s+'), '|')
        .replaceAll(RegExp(r'\s+x\s+', caseSensitive: false), '|');
    return normalized
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// File extensions for the file picker per source type.
  List<String> getFileExtensions(SourceType type) {
    switch (type) {
      case SourceType.display:
        return [
          'mp4', 'mkv', 'avi', 'mov', 'webm',
          'jpg', 'jpeg', 'png', 'gif', 'webp',
        ];
      case SourceType.audio:
      case SourceType.accompaniment:
        return ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a'];
      case SourceType.hover:
        return ['lrc'];
    }
  }

  // ---------------------------------------------------------------------------
  // Extraction helpers
  // ---------------------------------------------------------------------------

  Future<void> _tryExtractAudioFromVideo(DisplaySource videoSource) async {
    try {
      final audioSource = await _videoAudioExtractionService
          .createLinkedAudioSource(videoSource);

      final videoName = videoSource.displayName ?? getSourceName(videoSource);

      if (audioSource != null) {
        _audioSources.add(SourceWithValidation(audioSource, null));
        _message = EditorMessage.audioExtracted(name: videoName);
      } else {
        _message = EditorMessage.noAudioFound(name: videoName);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Video audio extraction error: $e');
    }
  }

  Future<void> _autoDiscoverRelatedSources(String filePath) async {
    try {
      final discovered =
          await _sourceAutoMatcher.discoverAndCreateSources(filePath);
      if (!discovered.hasAnySources) return;

      final addedTypes = <String>[];

      _addDiscovered(discovered.audioSources, _audioSources, 'audio', addedTypes);
      _addDiscovered(discovered.videoSources, _displaySources, 'video', addedTypes);
      _addDiscovered(discovered.imageSources, _displaySources, 'image', addedTypes);
      _addDiscovered(discovered.lyricsSources, _hoverSources, 'lyrics', addedTypes);
      _addDiscovered(
        discovered.accompanimentSources,
        _accompanimentSources,
        'accompaniment',
        addedTypes,
      );

      if (addedTypes.isNotEmpty) {
        _message = EditorMessage.autoDiscovered(types: addedTypes.join(', '));
      }
      notifyListeners();

      // Extract thumbnails from newly added audio/accompaniment
      for (final source in [
        ...discovered.audioSources,
        ...discovered.accompanimentSources,
      ]) {
        if (source.origin is LocalFileOrigin) {
          await _extractThumbnailFromOrigin(source.origin, source.id);
        }
      }

      // Extract duration for video sources
      for (final source in discovered.videoSources) {
        if (source.origin is LocalFileOrigin) {
          final dur = await _extractDuration(source.origin);
          if (dur != null) {
            final idx =
                _displaySources.indexWhere((s) => s.source.id == source.id);
            if (idx != -1) {
              final updated = source.copyWith(duration: dur);
              _displaySources[idx] = SourceWithValidation(updated, null);
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error during auto-discovery: $e');
    }
  }

  void _addDiscovered<T extends Source>(
    List<T> discovered,
    List<SourceWithValidation> target,
    String label,
    List<String> addedTypes,
  ) {
    if (discovered.isEmpty) return;
    for (final source in discovered) {
      final alreadyExists = target.any((s) {
        final origin = s.source.origin;
        return origin is LocalFileOrigin &&
            source.origin is LocalFileOrigin &&
            origin.path == (source.origin as LocalFileOrigin).path;
      });
      if (!alreadyExists) {
        target.add(SourceWithValidation(source, null));
      }
    }
    if (discovered.isNotEmpty) {
      addedTypes.add('${discovered.length} $label');
    }
  }

  Future<Duration?> _extractDuration(SourceOrigin origin) async {
    try {
      String mediaPath;
      switch (origin) {
        case LocalFileOrigin(:final path):
          mediaPath = path;
        case UrlOrigin(:final url):
          mediaPath = url;
        case ApiOrigin():
          return null;
      }
      return await _extractDurationWithMediaKit(mediaPath);
    } catch (e) {
      return null;
    }
  }

  Future<Duration?> _extractDurationWithMediaKit(String mediaPath) async {
    try {
      final player = mk.Player();
      final completer = Completer<Duration?>();
      StreamSubscription? sub;

      sub = player.stream.duration.listen((d) {
        if (d > Duration.zero && !completer.isCompleted) {
          completer.complete(d);
          sub?.cancel();
        }
      });

      await player
          .open(mk.Media(mediaPath), play: false)
          .timeout(const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('timeout'));

      final duration = await completer.future
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint('Duration extraction error: $e');
      return null;
    }
  }

  Future<void> _extractMetadataFromOrigin(SourceOrigin origin) async {
    try {
      String? filePath;
      switch (origin) {
        case LocalFileOrigin(:final path):
          filePath = path;
        case UrlOrigin(:final url):
          filePath = url;
        case ApiOrigin():
          return;
      }

      final result = await _metadataExtractor.extractFromFile(filePath);
      if (result.success && result.metadata != null) {
        if (_name.isEmpty) _name = result.metadata!.title;
        if (_artistValues.isEmpty && result.metadata!.artist.isNotEmpty) {
          _artistValues = _parseArtists(result.metadata!.artist);
        }
        if (_album.isEmpty) _album = result.metadata!.album;
        if (_time.isEmpty && result.metadata!.year != null) {
          _time = result.metadata!.year.toString();
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Metadata extraction error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Thumbnail operations
  // ---------------------------------------------------------------------------

  Future<void> _extractThumbnailFromOrigin(
    SourceOrigin origin,
    String sourceId,
  ) async {
    try {
      if (origin is! LocalFileOrigin) return;
      final filePath = origin.path;
      final fileName = filePath.split('/').last.split('\\').last;
      final displayName = 'From: $fileName';
      if (_availableThumbnails.containsKey(displayName)) return;

      final artworkBytes =
          await _thumbnailExtractor.extractThumbnailBytes(filePath);
      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        final cachedPath =
            await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
        _availableThumbnails[displayName] = cachedPath;
        _thumbnailToSourceId[cachedPath] = sourceId;
        _thumbnailPath ??= cachedPath;
        notifyListeners();
      }
    } catch (e) {
      // Silently ignore
    }
  }

  Future<void> _extractThumbnailsSilently() async {
    final audioFilePaths = <String, String>{};
    for (final s in [..._audioSources, ..._accompanimentSources]) {
      final origin = s.source.origin;
      if (origin is LocalFileOrigin) {
        audioFilePaths[origin.path] = s.source.id;
      }
    }
    if (audioFilePaths.isEmpty) return;

    for (final entry in audioFilePaths.entries) {
      final fileName = entry.key.split('/').last.split('\\').last;
      final displayName = 'From: $fileName';
      if (_availableThumbnails.containsKey(displayName)) continue;

      try {
        final artworkBytes =
            await _thumbnailExtractor.extractThumbnailBytes(entry.key);
        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          final cachedPath =
              await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
          _availableThumbnails[displayName] = cachedPath;
          _thumbnailToSourceId[cachedPath] = entry.value;
          notifyListeners();
        }
      } catch (e) {
        // Silently ignore
      }
    }
  }

  Future<void> reloadThumbnailsFromSources() async {
    final audioFilePaths = <String, String>{};
    for (final s in [..._audioSources, ..._accompanimentSources]) {
      final origin = s.source.origin;
      if (origin is LocalFileOrigin) {
        audioFilePaths[origin.path] = s.source.id;
      }
    }
    if (audioFilePaths.isEmpty) return;

    _isExtractingThumbnails = true;
    notifyListeners();

    try {
      for (final entry in audioFilePaths.entries) {
        final fileName = entry.key.split('/').last.split('\\').last;
        final displayName = 'From: $fileName';
        if (_availableThumbnails.containsKey(displayName)) continue;

        final artworkBytes =
            await _thumbnailExtractor.extractThumbnailBytes(entry.key);
        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          final cachedPath =
              await ThumbnailCache.instance.cacheFromBytes(artworkBytes);
          _availableThumbnails[displayName] = cachedPath;
          _thumbnailToSourceId[cachedPath] = entry.value;
        }
      }
    } catch (e) {
      // Silently ignore
    }

    _isExtractingThumbnails = false;
    notifyListeners();
  }

  Future<void> pickThumbnailFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    final customId = 'custom_${_uuid.v4()}';
    final cachedPath = await ThumbnailCache.instance.cacheFromBytes(bytes);
    final displayName = 'Custom: $fileName';
    _availableThumbnails[displayName] = cachedPath;
    _thumbnailToSourceId[cachedPath] = customId;
    _thumbnailPath = cachedPath;
    notifyListeners();
  }

  void selectThumbnail(String path) {
    _thumbnailPath = path;
    notifyListeners();
  }

  void removeThumbnailEntry(String displayName) {
    final path = _availableThumbnails[displayName];
    _availableThumbnails.remove(displayName);
    if (_thumbnailPath == path) _thumbnailPath = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Metadata reload
  // ---------------------------------------------------------------------------

  Future<void> reloadMetadataFromSource() async {
    if (_audioSources.isEmpty) {
      _message = const EditorMessage.noAudioSourcesForMetadata();
      notifyListeners();
      return;
    }

    final source = _audioSources.first.source;
    String? filePath;
    switch (source.origin) {
      case LocalFileOrigin(:final path):
        filePath = path;
      case UrlOrigin(:final url):
        filePath = url;
      case ApiOrigin():
        _message = const EditorMessage.cannotExtractFromApi();
        notifyListeners();
        return;
    }

    final result = await _metadataExtractor.extractFromFile(filePath);
    if (result.success && result.metadata != null) {
      _name = result.metadata!.title;
      _artistValues = _parseArtists(result.metadata!.artist);
      _album = result.metadata!.album;
      _time = result.metadata!.year?.toString() ?? '';
      _message = const EditorMessage.metadataReloaded();
    } else {
      _message = EditorMessage.error(detail: result.errorMessage ?? '');
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Online source
  // ---------------------------------------------------------------------------

  void addOnlineSource(OnlineSourceResult result, SourceType sourceType) {
    Source source;
    final origin = UrlOrigin(result.url);
    final duration =
        result.duration != null ? Duration(seconds: result.duration!) : null;

    switch (sourceType) {
      case SourceType.display:
        source = DisplaySource(
          id: _uuid.v4(), origin: origin, priority: 0,
          displayName: result.title, displayType: DisplayType.video,
          duration: duration,
        );
      case SourceType.audio:
        source = AudioSource(
          id: _uuid.v4(), origin: origin, priority: 0,
          displayName: result.title, format: AudioFormat.other,
          duration: duration,
        );
      case SourceType.accompaniment:
        source = AccompanimentSource(
          id: _uuid.v4(), origin: origin, priority: 0,
          displayName: result.title, format: AudioFormat.other,
          duration: duration,
        );
      case SourceType.hover:
        source = HoverSource(
          id: _uuid.v4(), origin: origin, priority: 0,
          displayName: result.title, format: LyricsFormat.lrc,
        );
    }

    final sv = SourceWithValidation(source, null);
    switch (sourceType) {
      case SourceType.display:
        _displaySources.add(sv);
      case SourceType.audio:
        _audioSources.add(sv);
      case SourceType.accompaniment:
        _accompanimentSources.add(sv);
      case SourceType.hover:
        _hoverSources.add(sv);
    }

    _message = EditorMessage.addedSource(title: result.title);
    notifyListeners();

    if (sourceType == SourceType.display &&
        source is DisplaySource &&
        source.displayType == DisplayType.video) {
      _tryExtractAudioFromVideo(source);
    }
  }
}

// ---------------------------------------------------------------------------
// Helper types for video removal prompt
// ---------------------------------------------------------------------------

enum VideoRemovalChoice { cancel, removeBoth, keepAudio }

class VideoRemovalQuery {
  const VideoRemovalQuery({
    required this.sources,
    required this.type,
    required this.index,
    required this.videoSource,
    required this.linkedAudio,
    required this.linkedAudioIndex,
  });
  final List<SourceWithValidation> sources;
  final SourceType type;
  final int index;
  final DisplaySource videoSource;
  final AudioSource linkedAudio;
  final int linkedAudioIndex;
}

/// Typed messages emitted by the ViewModel.
/// The view translates these into localized strings via `context.t`.
sealed class EditorMessage {
  const EditorMessage();

  const factory EditorMessage.cannotSaveInPlaceNoLocations() =
      CannotSaveInPlaceNoLocationsMsg;
  const factory EditorMessage.failedToLoadUrl() = FailedToLoadUrlMsg;
  const factory EditorMessage.noAudioSourcesForMetadata() =
      NoAudioSourcesForMetadataMsg;
  const factory EditorMessage.cannotExtractFromApi() = CannotExtractFromApiMsg;
  const factory EditorMessage.metadataReloaded() = MetadataReloadedMsg;
  const factory EditorMessage.audioExtracted({required String name}) =
      AudioExtractedMsg;
  const factory EditorMessage.noAudioFound({required String name}) =
      NoAudioFoundMsg;
  const factory EditorMessage.autoDiscovered({required String types}) =
      AutoDiscoveredMsg;
  const factory EditorMessage.addedSource({required String title}) =
      AddedSourceMsg;
  const factory EditorMessage.error({required String detail}) = ErrorMsg;
}

class CannotSaveInPlaceNoLocationsMsg extends EditorMessage {
  const CannotSaveInPlaceNoLocationsMsg();
}

class FailedToLoadUrlMsg extends EditorMessage {
  const FailedToLoadUrlMsg();
}

class NoAudioSourcesForMetadataMsg extends EditorMessage {
  const NoAudioSourcesForMetadataMsg();
}

class CannotExtractFromApiMsg extends EditorMessage {
  const CannotExtractFromApiMsg();
}

class MetadataReloadedMsg extends EditorMessage {
  const MetadataReloadedMsg();
}

class AudioExtractedMsg extends EditorMessage {
  const AudioExtractedMsg({required this.name});
  final String name;
}

class NoAudioFoundMsg extends EditorMessage {
  const NoAudioFoundMsg({required this.name});
  final String name;
}

class AutoDiscoveredMsg extends EditorMessage {
  const AutoDiscoveredMsg({required this.types});
  final String types;
}

class AddedSourceMsg extends EditorMessage {
  const AddedSourceMsg({required this.title});
  final String title;
}

class ErrorMsg extends EditorMessage {
  const ErrorMsg({required this.detail});
  final String detail;
}
