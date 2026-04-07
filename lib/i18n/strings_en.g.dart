///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final TranslationsCommonEn common = TranslationsCommonEn._(_root);
	late final TranslationsNavEn nav = TranslationsNavEn._(_root);
	late final TranslationsAppEn app = TranslationsAppEn._(_root);
	late final TranslationsLibraryEn library = TranslationsLibraryEn._(_root);
	late final TranslationsPlayerEn player = TranslationsPlayerEn._(_root);
	late final TranslationsQueueEn queue = TranslationsQueueEn._(_root);
	late final TranslationsSearchEn search = TranslationsSearchEn._(_root);
	late final TranslationsTagsEn tags = TranslationsTagsEn._(_root);
	late final TranslationsPlaylistsEn playlists = TranslationsPlaylistsEn._(_root);
	late final TranslationsSongEditorEn songEditor = TranslationsSongEditorEn._(_root);
	late final TranslationsSettingsEn settings = TranslationsSettingsEn._(_root);
	late final TranslationsLibraryLocationsEn libraryLocations = TranslationsLibraryLocationsEn._(_root);
	late final TranslationsLocationSetupEn locationSetup = TranslationsLocationSetupEn._(_root);
	late final TranslationsConfigModeEn configMode = TranslationsConfigModeEn._(_root);
	late final TranslationsOnlineProvidersEn onlineProviders = TranslationsOnlineProvidersEn._(_root);
	late final TranslationsDisplayEn display = TranslationsDisplayEn._(_root);
	late final TranslationsLyricsEn lyrics = TranslationsLyricsEn._(_root);
	late final TranslationsFloatingLyricsEn floatingLyrics = TranslationsFloatingLyricsEn._(_root);
	late final TranslationsSongPickerEn songPicker = TranslationsSongPickerEn._(_root);
	late final TranslationsVideoRemovalEn videoRemoval = TranslationsVideoRemovalEn._(_root);
	late final TranslationsDebugEn debug = TranslationsDebugEn._(_root);
	late final TranslationsDialogsEn dialogs = TranslationsDialogsEn._(_root);
	late final TranslationsConfigModeChangeEn configModeChange = TranslationsConfigModeChangeEn._(_root);
	late final TranslationsAppRoutesEn app_routes = TranslationsAppRoutesEn._(_root);
	late final TranslationsLoadingIndicatorEn loading_indicator = TranslationsLoadingIndicatorEn._(_root);
	late final TranslationsVideoRemovalPromptEn video_removal_prompt = TranslationsVideoRemovalPromptEn._(_root);
	late final TranslationsLibraryLocationSetupDialogEn library_location_setup_dialog = TranslationsLibraryLocationSetupDialogEn._(_root);
	late final TranslationsHomePageEn home_page = TranslationsHomePageEn._(_root);
	late final TranslationsSongUnitEditorEn song_unit_editor = TranslationsSongUnitEditorEn._(_root);
}

// Path: common
class TranslationsCommonEn {
	TranslationsCommonEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Refresh'
	String get refresh => 'Refresh';

	/// en: 'Search'
	String get search => 'Search';

	/// en: 'OK'
	String get ok => 'OK';

	/// en: 'Yes'
	String get yes => 'Yes';

	/// en: 'No'
	String get no => 'No';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Skip for Now'
	String get skip => 'Skip for Now';

	/// en: 'Apply'
	String get apply => 'Apply';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Duplicate'
	String get duplicate => 'Duplicate';

	/// en: 'Export'
	String get export => 'Export';

	/// en: 'Import'
	String get import => 'Import';

	/// en: 'Migrate'
	String get migrate => 'Migrate';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Grant'
	String get grant => 'Grant';

	/// en: 'Enabled'
	String get enabled => 'Enabled';

	/// en: 'Disabled'
	String get disabled => 'Disabled';

	/// en: 'ON'
	String get on => 'ON';

	/// en: 'OFF'
	String get off => 'OFF';

	/// en: 'Error'
	String get error => 'Error';

	/// en: 'Loading...'
	String get loading => 'Loading...';

	/// en: 'songs'
	String get songs => 'songs';

	/// en: 'selected'
	String get selected => 'selected';

	/// en: 'items'
	String get items => 'items';

	/// en: 'ms'
	String get ms => 'ms';

	/// en: 'Dismiss'
	String get dismiss => 'Dismiss';

	/// en: 'Extract'
	String get extract => 'Extract';

	/// en: 'Extracting thumbnails...'
	String get extractingThumbnails => 'Extracting thumbnails...';

	/// en: 'No thumbnails available'
	String get noThumbnailsAvailable => 'No thumbnails available';

	/// en: 'Display (Video/Image)'
	String get displayVideoImage => 'Display (Video/Image)';

	/// en: 'ID'
	String get id => 'ID';

	/// en: 'URL'
	String get url => 'URL';

	/// en: 'API Key'
	String get apiKey => 'API Key';

	/// en: '('
	String get openParen => '(';

	/// en: ')'
	String get closeParen => ')';

	/// en: 'Route not found: {name}'
	String get routeNotFound => 'Route not found: {name}';

	/// en: 'No results. Enter a search query and press search.'
	String get noResultsEnterSearch => 'No results. Enter a search query and press search.';

	/// en: 'Artist:'
	String get artistLabel => 'Artist:';

	/// en: 'Album:'
	String get albumLabel => 'Album:';

	/// en: 'Platform:'
	String get platformLabel => 'Platform:';

	/// en: '{percentage}%'
	String get percentage => '{percentage}%';

	/// en: 'Test Connection'
	String get testConnection => 'Test Connection';

	/// en: 'Disabled in KTV mode'
	String get disabledInKtvMode => 'Disabled in KTV mode';

	/// en: 'Failed to rename: {error}'
	String get failedToRename => 'Failed to rename: {error}';

	/// en: 'Continue'
	String get continueText => 'Continue';

	/// en: 'artist'
	String get artist => 'artist';

	/// en: 'album'
	String get album => 'album';

	/// en: 'platform'
	String get platform => 'platform';

	/// en: 'Add Image'
	String get addImage => 'Add Image';

	/// en: 'Shuffle'
	String get shuffle => 'Shuffle';

	/// en: 'Already in playlist'
	String get alreadyInPlaylist => 'Already in playlist';

	/// en: 'Create & Add'
	String get createAndAdd => 'Create & Add';
}

// Path: nav
class TranslationsNavEn {
	TranslationsNavEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Home'
	String get home => 'Home';

	/// en: 'Library'
	String get library => 'Library';

	/// en: 'Playlists'
	String get playlists => 'Playlists';

	/// en: 'Tags'
	String get tags => 'Tags';

	/// en: 'Settings'
	String get settings => 'Settings';
}

// Path: app
class TranslationsAppEn {
	TranslationsAppEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Beadline'
	String get name => 'Beadline';
}

// Path: library
class TranslationsLibraryEn {
	TranslationsLibraryEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Library'
	String get title => 'Library';

	/// en: 'Loading library...'
	String get loading => 'Loading library...';

	/// en: 'Search library...'
	String get searchHint => 'Search library...';

	/// en: 'No library locations'
	String get noLocations => 'No library locations';

	/// en: 'All Locations'
	String get allLocations => 'All Locations';

	/// en: 'Filter by Library Location'
	String get filterByLocation => 'Filter by Library Location';

	/// en: 'List view'
	String get listView => 'List view';

	/// en: 'Grid view'
	String get gridView => 'Grid view';

	/// en: 'No library items'
	String get noItems => 'No library items';

	/// en: 'No songs found'
	String get noResults => 'No songs found';

	/// en: 'Try a different search term'
	String get tryDifferentSearch => 'Try a different search term';

	/// en: 'Audio Only'
	String get audioOnly => 'Audio Only';

	/// en: 'No song'
	String get noSong => 'No song';

	late final TranslationsLibraryActionsEn actions = TranslationsLibraryActionsEn._(_root);

	/// en: 'Processing...'
	String get processing => 'Processing...';

	/// en: 'Exported to {path}'
	String get exportedTo => 'Exported to {path}';

	/// en: 'Import Complete'
	String get importComplete => 'Import Complete';

	/// en: 'Imported: {count}'
	String get imported => 'Imported: {count}';

	/// en: 'Skipped (duplicates): {count}'
	String get skippedDuplicates => 'Skipped (duplicates): {count}';

	/// en: '... and {count} more'
	String get importMore => '... and {count} more';

	/// en: 'Promoted "{name}" to Song Unit'
	String get promotedToSongUnit => 'Promoted "{name}" to Song Unit';

	/// en: 'Are you sure you want to delete {count} item(s)?'
	String get deleteItemsConfirm => 'Are you sure you want to delete {count} item(s)?';

	/// en: 'Deleted {count} item(s)'
	String get deletedItems => 'Deleted {count} item(s)';

	/// en: 'Added {count} item(s) to queue'
	String get addedItemsToQueue => 'Added {count} item(s) to queue';

	/// en: 'No temporary entries selected'
	String get noTemporaryEntriesSelected => 'No temporary entries selected';

	/// en: 'Add {count} song(s) to Playlist'
	String get addSongsToPlaylistTitle => 'Add {count} song(s) to Playlist';

	/// en: 'No playlists yet. Create one first.'
	String get noPlaylistsCreateFirst => 'No playlists yet. Create one first.';

	/// en: 'Metadata'
	String get sectionMetadata => 'Metadata';

	/// en: 'Sources'
	String get sectionSources => 'Sources';

	/// en: 'Tags'
	String get sectionTags => 'Tags';

	/// en: 'Error loading library'
	String get errorLoadingLibrary => 'Error loading library';

	/// en: 'Delete Song Unit'
	String get deleteSongUnit => 'Delete Song Unit';

	/// en: 'Also delete configuration file'
	String get alsoDeleteConfigFile => 'Also delete configuration file';

	/// en: 'Removes the beadline-*.json file. Source files are not affected.'
	String get configFileNote => 'Removes the beadline-*.json file. Source files are not affected.';

	/// en: 'Delete original song units after merge'
	String get deleteOriginalAfterMerge => 'Delete original song units after merge';

	/// en: '{count} selected'
	String get selectedCount => '{count} selected';

	/// en: 'Already in playlist'
	String get alreadyInPlaylist => 'Already in playlist';

	/// en: 'Create & Add'
	String get createAndAdd => 'Create & Add';

	/// en: 'Promoted "{displayName}" to Song Unit'
	String get promoted => 'Promoted "{displayName}" to Song Unit';
}

// Path: player
class TranslationsPlayerEn {
	TranslationsPlayerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No song playing'
	String get noSongPlaying => 'No song playing';

	/// en: 'Source'
	String get source => 'Source';

	/// en: 'Display'
	String get display => 'Display';

	/// en: 'Audio'
	String get audio => 'Audio';

	/// en: 'Playback'
	String get playback => 'Playback';

	/// en: 'Lyrics'
	String get lyrics => 'Lyrics';

	/// en: 'Fullscreen'
	String get fullscreen => 'Fullscreen';

	/// en: 'Exit fullscreen (ESC)'
	String get exitFullscreen => 'Exit fullscreen (ESC)';

	/// en: 'Select sources'
	String get selectSources => 'Select sources';

	/// en: 'Play'
	String get play => 'Play';

	/// en: 'Pause'
	String get pause => 'Pause';

	/// en: 'Next'
	String get next => 'Next';

	late final TranslationsPlayerDisplayModeEn displayMode = TranslationsPlayerDisplayModeEn._(_root);
	late final TranslationsPlayerAudioModeEn audioMode = TranslationsPlayerAudioModeEn._(_root);
	late final TranslationsPlayerPlaybackModeEn playbackMode = TranslationsPlayerPlaybackModeEn._(_root);
	late final TranslationsPlayerLyricsModeEn lyricsMode = TranslationsPlayerLyricsModeEn._(_root);
}

// Path: queue
class TranslationsQueueEn {
	TranslationsQueueEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Queue'
	String get title => 'Queue';

	/// en: 'Manage queues'
	String get manage => 'Manage queues';

	/// en: 'Remove duplicates'
	String get removeDuplicates => 'Remove duplicates';

	/// en: 'Shuffle'
	String get shuffle => 'Shuffle';

	/// en: 'Remove after play: ON'
	String get removeAfterPlayOn => 'Remove after play: ON';

	/// en: 'Remove after play: OFF'
	String get removeAfterPlayOff => 'Remove after play: OFF';

	/// en: 'Clear queue'
	String get clearQueue => 'Clear queue';

	/// en: 'Removed {count} duplicate(s)'
	String get removedDuplicates => 'Removed {count} duplicate(s)';

	/// en: 'No duplicates found'
	String get noDuplicates => 'No duplicates found';

	/// en: 'Manage Queues'
	String get manageQueues => 'Manage Queues';

	/// en: 'Queue Content'
	String get queueContent => 'Queue Content';

	/// en: 'Back to queues'
	String get backToQueues => 'Back to queues';

	/// en: 'Create New Queue'
	String get createQueue => 'Create New Queue';

	/// en: 'Queue Name'
	String get queueName => 'Queue Name';

	/// en: 'Enter queue name'
	String get enterQueueName => 'Enter queue name';

	/// en: 'Rename Queue'
	String get renameQueue => 'Rename Queue';

	/// en: 'Enter new name'
	String get enterNewName => 'Enter new name';

	/// en: 'Delete Queue'
	String get deleteQueue => 'Delete Queue';

	/// en: 'Are you sure you want to delete'
	String get deleteQueueConfirm => 'Are you sure you want to delete';

	/// en: 'This will remove'
	String get deleteQueueWillRemove => 'This will remove';

	/// en: 'songs from this queue'
	String get deleteQueueFromQueue => 'songs from this queue';

	/// en: 'Switch to this queue'
	String get switchToQueue => 'Switch to this queue';

	/// en: 'Queue is empty'
	String get empty => 'Queue is empty';

	/// en: '{count} songs'
	String get songs => '{count} songs';

	/// en: 'Queue actions'
	String get actions => 'Queue actions';

	/// en: 'Collapse'
	String get collapse => 'Collapse';

	/// en: 'Expand'
	String get expand => 'Expand';

	/// en: 'Group actions'
	String get groupActions => 'Group actions';
}

// Path: search
class TranslationsSearchEn {
	TranslationsSearchEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Search'
	String get title => 'Search';

	/// en: 'Song Units'
	String get songUnits => 'Song Units';

	/// en: 'Sources'
	String get sources => 'Sources';

	/// en: 'Search...'
	String get hint => 'Search...';

	/// en: 'Text mode'
	String get textMode => 'Text mode';

	/// en: 'Query builder'
	String get queryBuilder => 'Query builder';

	/// en: 'Tag'
	String get tag => 'Tag';

	/// en: 'e.g., artist:value'
	String get tagExample => 'e.g., artist:value';

	/// en: 'Range'
	String get range => 'Range';

	/// en: 'e.g., time:[2020-2024]'
	String get rangeExample => 'e.g., time:[2020-2024]';

	/// en: 'Searching...'
	String get searching => 'Searching...';

	/// en: 'Search error'
	String get searchError => 'Search error';

	/// en: 'No song units found'
	String get noSongUnitsFound => 'No song units found';

	/// en: 'Load more'
	String get loadMore => 'Load more';

	/// en: 'Play'
	String get play => 'Play';

	/// en: 'Add to queue'
	String get addToQueue => 'Add to queue';

	/// en: 'All'
	String get all => 'All';

	/// en: 'Local'
	String get local => 'Local';

	/// en: 'Online'
	String get online => 'Online';

	/// en: 'Searching sources...'
	String get searchingSources => 'Searching sources...';

	/// en: 'No online sources found'
	String get noOnlineSources => 'No online sources found';

	/// en: 'No local sources found'
	String get noLocalSources => 'No local sources found';

	/// en: 'No sources found'
	String get noSources => 'No sources found';

	/// en: 'Add to Song Unit'
	String get addToSongUnit => 'Add to Song Unit';

	/// en: 'OR'
	String get or => 'OR';

	/// en: 'NOT'
	String get not => 'NOT';

	/// en: 'Added "{title}" to queue'
	String get addedToQueue => 'Added "{title}" to queue';

	/// en: 'Add source: {title}'
	String get addSource => 'Add source: {title}';
}

// Path: tags
class TranslationsTagsEn {
	TranslationsTagsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Tags'
	String get title => 'Tags';

	/// en: 'No tags yet'
	String get noTags => 'No tags yet';

	/// en: 'Create tags to organize your music'
	String get noTagsHint => 'Create tags to organize your music';

	/// en: 'Error loading tags'
	String get loadError => 'Error loading tags';

	/// en: 'Create Tag'
	String get createTag => 'Create Tag';

	/// en: 'Create Child Tag'
	String get createChildTag => 'Create Child Tag';

	/// en: 'Tag name'
	String get tagName => 'Tag name';

	/// en: 'Add Alias'
	String get addAlias => 'Add Alias';

	/// en: 'Add Alias for'
	String get addAliasFor => 'Add Alias for';

	/// en: 'Alias name'
	String get aliasName => 'Alias name';

	/// en: 'Enter alias'
	String get enterAlias => 'Enter alias';

	/// en: 'Add child tag'
	String get addChildTag => 'Add child tag';

	/// en: 'Delete tag'
	String get deleteTag => 'Delete tag';

	/// en: 'Delete tag?'
	String get deleteTagTitle => 'Delete tag?';

	/// en: 'This action cannot be undone'
	String get deleteTagConfirm => 'This action cannot be undone';

	/// en: 'This tag has child tags. They will become root tags.'
	String get deleteTagHasChildren => 'This tag has child tags. They will become root tags.';

	/// en: 'Aliases will also be deleted.'
	String get deleteTagAliases => 'Aliases will also be deleted.';

	/// en: 'Deleted tag'
	String get deletedTag => 'Deleted tag';

	/// en: 'Remove tag from this song'
	String get removeFromSong => 'Remove tag from this song';

	/// en: 'Remove All'
	String get removeAll => 'Remove All';

	/// en: 'View song units'
	String get viewSongUnits => 'View song units';

	/// en: 'item'
	String get item => 'item';

	/// en: 'items'
	String get items => 'items';

	/// en: 'song unit'
	String get songUnit => 'song unit';

	/// en: 'song units'
	String get songUnits => 'song units';

	/// en: 'Locked collection'
	String get lockedCollection => 'Locked collection';

	/// en: 'Collection'
	String get collection => 'Collection';

	/// en: 'Locked'
	String get locked => 'Locked';
}

// Path: playlists
class TranslationsPlaylistsEn {
	TranslationsPlaylistsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Playlists'
	String get title => 'Playlists';

	/// en: 'No playlists yet'
	String get noPlaylists => 'No playlists yet';

	/// en: 'Right-click or long-press to create a playlist'
	String get noPlaylistsHint => 'Right-click or long-press to create a playlist';

	/// en: 'Select a playlist to view its contents'
	String get selectPlaylist => 'Select a playlist to view its contents';

	/// en: 'Create Playlist'
	String get createPlaylist => 'Create Playlist';

	/// en: 'Add Songs'
	String get addSongs => 'Add Songs';

	/// en: 'Create Group'
	String get createGroup => 'Create Group';

	/// en: 'Move to Group'
	String get moveToGroup => 'Move to Group';

	/// en: 'Add Collection Reference'
	String get addCollectionRef => 'Add Collection Reference';

	/// en: 'Rename Playlist'
	String get renamePlaylist => 'Rename Playlist';

	/// en: 'Delete Playlist'
	String get deletePlaylist => 'Delete Playlist';

	/// en: 'Are you sure you want to delete'
	String get deletePlaylistConfirm => 'Are you sure you want to delete';

	/// en: 'Songs will not be deleted, only this playlist'
	String get deletePlaylistNote => 'Songs will not be deleted, only this playlist';

	/// en: 'Create Group'
	String get createGroupTitle => 'Create Group';

	/// en: 'Create a group'
	String get createGroupHint => 'Create a group';

	/// en: 'Group Name'
	String get groupName => 'Group Name';

	/// en: 'Enter group name'
	String get enterGroupName => 'Enter group name';

	/// en: 'Add Collection Reference'
	String get addCollectionRefTitle => 'Add Collection Reference';

	/// en: 'No other collections available'
	String get noOtherCollections => 'No other collections available';

	/// en: 'Add reference to'
	String get addReferenceTo => 'Add reference to';

	/// en: 'Lock'
	String get lock => 'Lock';

	/// en: 'Unlock'
	String get unlock => 'Unlock';

	/// en: 'View content'
	String get viewContent => 'View content';

	/// en: 'Toggle selection mode'
	String get toggleSelectionMode => 'Toggle selection mode';

	/// en: 'No groups available. Create a group first.'
	String get noGroupsAvailable => 'No groups available. Create a group first.';

	/// en: 'song'
	String get song => 'song';

	/// en: 'songs'
	String get songs => 'songs';

	/// en: 'Locked'
	String get locked => 'Locked';

	/// en: 'Clear selection'
	String get clearSelection => 'Clear selection';

	/// en: 'selected'
	String get selected => 'selected';

	/// en: 'Remove from Group'
	String get removeFromGroup => 'Remove from Group';

	/// en: 'Already in playlist'
	String get alreadyInPlaylist => 'Already in playlist';

	/// en: 'Added to "{name}"'
	String get addedToPlaylist => 'Added to "{name}"';

	/// en: 'Created playlist "{name}" and added song'
	String get createdPlaylistAndAdded => 'Created playlist "{name}" and added song';

	/// en: 'Create & Add'
	String get createAndAdd => 'Create & Add';

	/// en: '{count} songs'
	String get songCount => '{count} songs';

	/// en: 'No songs in this group'
	String get noSongsInGroup => 'No songs in this group';

	/// en: 'drop here'
	String get dropHere => 'drop here';

	/// en: 'Group "{name}" created'
	String get groupCreated => 'Group "{name}" created';

	/// en: 'Failed to create group: {error}'
	String get failedToCreateGroup => 'Failed to create group: {error}';
}

// Path: songEditor
class TranslationsSongEditorEn {
	TranslationsSongEditorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Edit Song Unit'
	String get titleEdit => 'Edit Song Unit';

	/// en: 'New Song Unit'
	String get titleNew => 'New Song Unit';

	/// en: 'Reload metadata from source'
	String get reloadMetadata => 'Reload metadata from source';

	/// en: 'Write metadata to source'
	String get writeMetadata => 'Write metadata to source';

	/// en: 'Sources'
	String get sources => 'Sources';

	/// en: 'Display'
	String get display => 'Display';

	/// en: 'Audio'
	String get audio => 'Audio';

	/// en: 'Accompaniment'
	String get accompaniment => 'Accompaniment';

	/// en: 'Lyrics'
	String get lyricsLabel => 'Lyrics';

	/// en: 'No display sources'
	String get noDisplaySources => 'No display sources';

	/// en: 'No audio sources'
	String get noAudioSources => 'No audio sources';

	/// en: 'No accompaniment sources'
	String get noAccompanimentSources => 'No accompaniment sources';

	/// en: 'No lyrics sources'
	String get noLyricsSources => 'No lyrics sources';

	/// en: 'Add Display source'
	String get addDisplaySource => 'Add Display source';

	/// en: 'Add Audio source'
	String get addAudioSource => 'Add Audio source';

	/// en: 'Add Accompaniment source'
	String get addAccompanimentSource => 'Add Accompaniment source';

	/// en: 'Add Lyrics source'
	String get addLyricsSource => 'Add Lyrics source';

	/// en: 'Edit display name'
	String get editDisplayName => 'Edit display name';

	/// en: 'Set offset'
	String get setOffset => 'Set offset';

	/// en: 'Set Offset'
	String get setOffsetTitle => 'Set Offset';

	/// en: 'Offset in milliseconds to align with audio'
	String get offsetHint => 'Offset in milliseconds to align with audio';

	/// en: 'Positive = delay, Negative = advance'
	String get offsetNote => 'Positive = delay, Negative = advance';

	/// en: 'Offset (ms)'
	String get offsetLabel => 'Offset (ms)';

	/// en: 'Edit Display Name'
	String get editDisplayNameTitle => 'Edit Display Name';

	/// en: 'Original'
	String get originalName => 'Original';

	/// en: 'Display name'
	String get displayNameLabel => 'Display name';

	/// en: 'Leave empty to use original name'
	String get displayNameHint => 'Leave empty to use original name';

	/// en: 'Add source'
	String get addSource => 'Add source';

	/// en: 'Local file'
	String get localFile => 'Local file';

	/// en: 'Enter URL'
	String get enterUrl => 'Enter URL';

	/// en: 'URL'
	String get urlLabel => 'URL';

	/// en: 'https://...'
	String get urlHint => 'https://...';

	/// en: 'Select Song'
	String get selectSong => 'Select Song';

	/// en: 'Select Songs'
	String get selectSongs => 'Select Songs';

	/// en: 'Add songs'
	String get addSongs => 'Add songs';

	/// en: 'artist'
	String get artist => 'artist';

	/// en: 'thumbnail'
	String get thumbnail => 'thumbnail';

	/// en: 'Add Image'
	String get addImage => 'Add Image';

	/// en: 'Select ({count})'
	String get selectThumbnails => 'Select ({count})';

	/// en: 'Select Thumbnail'
	String get selectThumbnailTitle => 'Select Thumbnail';

	/// en: 'Error adding custom thumbnail: {error}'
	String get errorAddingCustomThumbnail => 'Error adding custom thumbnail: {error}';

	/// en: 'Audio track extracted from {name}'
	String get audioExtracted => 'Audio track extracted from {name}';

	/// en: 'No audio track found in {name}'
	String get noAudioFound => 'No audio track found in {name}';

	/// en: 'Auto-discovered: {types}'
	String get autoDiscovered => 'Auto-discovered: {types}';

	/// en: 'Choose values for each metadata field:'
	String get chooseMetadataValues => 'Choose values for each metadata field:';

	/// en: 'Built-in Tags (Metadata)'
	String get builtInTagsMetadata => 'Built-in Tags (Metadata)';

	/// en: 'User Tags'
	String get userTags => 'User Tags';

	/// en: 'No user tags available. Create tags in the Tags section.'
	String get noUserTags => 'No user tags available. Create tags in the Tags section.';

	/// en: 'name'
	String get tagNameName => 'name';

	/// en: 'album'
	String get tagNameAlbum => 'album';

	/// en: 'time'
	String get tagNameTime => 'time';

	/// en: 'title'
	String get aliasHintTitle => 'title';

	/// en: 'Add an image or extract from audio files'
	String get addImageOrExtract => 'Add an image or extract from audio files';

	/// en: '{count} thumbnail(s) available'
	String get thumbnailsAvailable => '{count} thumbnail(s) available';

	/// en: 'Remove from collection'
	String get removeFromCollection => 'Remove from collection';

	/// en: 'Metadata writing is not yet implemented. Requires external library integration.'
	String get metadataWriteNotImplemented => 'Metadata writing is not yet implemented. Requires external library integration.';

	/// en: 'From: {name}'
	String get linkedVideoFrom => 'From: {name}';

	/// en: 'Offset: {value}'
	String get offsetDisplay => 'Offset: {value}';

	/// en: 'Search Online Sources'
	String get searchOnlineSources => 'Search Online Sources';

	/// en: 'Provider'
	String get providerLabel => 'Provider';

	/// en: 'Source Type'
	String get sourceTypeLabel => 'Source Type';

	/// en: 'Search Query'
	String get searchQueryLabel => 'Search Query';

	/// en: 'Duration: {value}'
	String get durationDisplay => 'Duration: {value}';

	/// en: 'Add to Song Unit'
	String get addToSongUnit => 'Add to Song Unit';

	/// en: 'Cannot save Song Unit in in-place mode without library locations. Please configure at least one library location in Settings.'
	String get cannotSaveInPlaceNoLocations => 'Cannot save Song Unit in in-place mode without library locations. Please configure at least one library location in Settings.';

	/// en: 'Failed to load media from URL. The URL may be invalid or unreachable.'
	String get failedToLoadUrl => 'Failed to load media from URL. The URL may be invalid or unreachable.';

	/// en: 'Warning: URL does not appear to be a direct media file. Use direct links to audio/video files (e.g., .mp3, .mp4), not web pages.'
	String get urlNotDirectMedia => 'Warning: URL does not appear to be a direct media file. Use direct links to audio/video files (e.g., .mp3, .mp4), not web pages.';

	/// en: 'No audio sources to extract metadata from'
	String get noAudioSourcesForMetadata => 'No audio sources to extract metadata from';

	/// en: 'Cannot extract metadata from API source'
	String get cannotExtractFromApi => 'Cannot extract metadata from API source';

	/// en: 'Metadata reloaded'
	String get metadataReloaded => 'Metadata reloaded';

	/// en: 'Added {title}'
	String get addedSource => 'Added {title}';
}

// Path: settings
class TranslationsSettingsEn {
	TranslationsSettingsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Settings'
	String get title => 'Settings';

	/// en: 'User'
	String get user => 'User';

	/// en: 'Username'
	String get username => 'Username';

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'Theme'
	String get theme => 'Theme';

	/// en: 'System'
	String get themeSystem => 'System';

	/// en: 'Light'
	String get themeLight => 'Light';

	/// en: 'Dark'
	String get themeDark => 'Dark';

	/// en: 'Accent Color'
	String get accentColor => 'Accent Color';

	/// en: 'Customize app color'
	String get accentColorHint => 'Customize app color';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'System Default'
	String get languageSystemDefault => 'System Default';

	/// en: 'Choose Your Language'
	String get languageSelectorTitle => 'Choose Your Language';

	/// en: 'Select your preferred language for the app'
	String get languageSelectorSubtitle => 'Select your preferred language for the app';

	/// en: 'You can change the language later in Settings'
	String get languageSelectorHint => 'You can change the language later in Settings';

	/// en: 'Continue'
	String get languageSelectorContinue => 'Continue';

	/// en: 'Playback'
	String get playback => 'Playback';

	/// en: 'Lyrics Mode'
	String get lyricsMode => 'Lyrics Mode';

	/// en: 'KTV Mode'
	String get ktvMode => 'KTV Mode';

	/// en: 'Force screen lyrics, disable floating'
	String get ktvModeHint => 'Force screen lyrics, disable floating';

	/// en: 'Hide Display Panel'
	String get hideDisplayPanel => 'Hide Display Panel';

	/// en: 'Show only lyrics and controls (music-only mode)'
	String get hideDisplayPanelHint => 'Show only lyrics and controls (music-only mode)';

	/// en: 'Use Thumbnail Background in Library'
	String get thumbnailBgLibrary => 'Use Thumbnail Background in Library';

	/// en: 'Show thumbnails as backgrounds in library view'
	String get thumbnailBgLibraryHint => 'Show thumbnails as backgrounds in library view';

	/// en: 'Use Thumbnail Background in Queue'
	String get thumbnailBgQueue => 'Use Thumbnail Background in Queue';

	/// en: 'Show thumbnails as backgrounds in queue'
	String get thumbnailBgQueueHint => 'Show thumbnails as backgrounds in queue';

	/// en: 'Storage'
	String get storage => 'Storage';

	/// en: 'Configuration Mode'
	String get configMode => 'Configuration Mode';

	/// en: 'Centralized'
	String get configModeCentralized => 'Centralized';

	/// en: 'In-Place'
	String get configModeInPlace => 'In-Place';

	/// en: 'Library Locations'
	String get libraryLocations => 'Library Locations';

	/// en: 'Manage where your music is stored'
	String get libraryLocationsHint => 'Manage where your music is stored';

	/// en: 'Metadata Write-back'
	String get metadataWriteback => 'Metadata Write-back';

	/// en: 'Sync tag changes to source files'
	String get metadataWritebackHint => 'Sync tag changes to source files';

	/// en: 'Auto-Discover Audio Files'
	String get autoDiscoverAudio => 'Auto-Discover Audio Files';

	/// en: 'Automatically add audio files from library locations'
	String get autoDiscoverAudioHint => 'Automatically add audio files from library locations';

	/// en: 'Debug'
	String get debug => 'Debug';

	/// en: 'Audio Entries Debug'
	String get audioEntriesDebug => 'Audio Entries Debug';

	/// en: 'View discovered audio entries'
	String get audioEntriesDebugHint => 'View discovered audio entries';

	/// en: 'Re-scan Audio Files'
	String get rescanAudio => 'Re-scan Audio Files';

	/// en: 'Clear and re-discover all audio files with updated metadata'
	String get rescanAudioHint => 'Clear and re-discover all audio files with updated metadata';

	/// en: 'About'
	String get about => 'About';

	/// en: 'Version'
	String get version => 'Version';

	/// en: 'License'
	String get license => 'License';

	/// en: 'GNU Affero General Public License v3.0 (AGPL-3.0)'
	String get licenseValue => 'GNU Affero General Public License v3.0 (AGPL-3.0)';

	/// en: 'Reset to Factory'
	String get resetFactory => 'Reset to Factory';

	/// en: 'Reset all settings to defaults'
	String get resetFactoryHint => 'Reset all settings to defaults';

	/// en: 'System'
	String get system => 'System';

	/// en: 'Reset to Factory Settings?'
	String get resetFactoryTitle => 'Reset to Factory Settings?';

	/// en: 'This will completely reset the application to a fresh state'
	String get resetFactoryBody => 'This will completely reset the application to a fresh state';

	/// en: 'All settings and preferences Song Unit library and tags Playlists, queues, and groups Playback state'
	String get resetFactoryItems => 'All settings and preferences\nSong Unit library and tags\nPlaylists, queues, and groups\nPlayback state';

	/// en: 'Your actual music files on disk will NOT be deleted'
	String get resetFactoryNote => 'Your actual music files on disk will NOT be deleted';

	/// en: 'The app will restart after reset'
	String get resetFactoryRestart => 'The app will restart after reset';

	/// en: 'Reset Everything'
	String get resetEverything => 'Reset Everything';

	/// en: 'Re-scan Audio Files'
	String get rescanTitle => 'Re-scan Audio Files';

	/// en: 'This will clear all discovered audio entries and re-scan your library locations'
	String get rescanBody => 'This will clear all discovered audio entries and re-scan your library locations';

	/// en: 'This may take a few minutes for large libraries. Continue?'
	String get rescanNote => 'This may take a few minutes for large libraries. Continue?';

	/// en: 'Re-scan'
	String get rescan => 'Re-scan';

	/// en: 'Migrating Configuration'
	String get migratingConfig => 'Migrating Configuration';

	/// en: 'Migrating entry point files...'
	String get migratingEntryPoints => 'Migrating entry point files...';

	/// en: 'Scanning for Song Units...'
	String get scanningForSongUnits => 'Scanning for Song Units...';

	/// en: 'Storage Permission Required'
	String get storagePermissionTitle => 'Storage Permission Required';

	/// en: 'Beadline needs access to your music files to discover and play audio'
	String get storagePermissionBody => 'Beadline needs access to your music files to discover and play audio';

	/// en: 'Please grant storage permission in the next dialog, or go to Settings to enable it manually'
	String get storagePermissionNote => 'Please grant storage permission in the next dialog, or go to Settings to enable it manually';

	/// en: 'Open Settings'
	String get openSettings => 'Open Settings';

	/// en: 'Found {count} audio files'
	String get foundAudioFiles => 'Found {count} audio files';

	/// en: 'Error scanning: {error}'
	String get errorScanning => 'Error scanning: {error}';

	/// en: 'Audio entries cleared'
	String get audioEntriesCleared => 'Audio entries cleared';

	/// en: 'Error clearing audio entries: {error}'
	String get errorClearingAudio => 'Error clearing audio entries: {error}';

	/// en: 'Audio files re-scanned successfully'
	String get audioRescanSuccess => 'Audio files re-scanned successfully';

	/// en: 'Error re-scanning: {error}'
	String get errorRescanning => 'Error re-scanning: {error}';

	/// en: 'Testing connection...'
	String get testingConnection => 'Testing connection...';

	/// en: 'Connection successful!'
	String get connectionSuccess => 'Connection successful!';

	/// en: 'Connection failed'
	String get connectionFailed => 'Connection failed';

	/// en: 'Online Source Providers'
	String get onlineProviders => 'Online Source Providers';
}

// Path: libraryLocations
class TranslationsLibraryLocationsEn {
	TranslationsLibraryLocationsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Library Locations'
	String get title => 'Library Locations';

	/// en: 'Select Library Location'
	String get selectLocation => 'Select Library Location';

	/// en: 'Name this location'
	String get nameLocation => 'Name this location';

	/// en: 'Enter a name for this location'
	String get enterLocationName => 'Enter a name for this location';

	/// en: 'Library location added'
	String get locationAdded => 'Library location added';

	/// en: 'Discovered and imported {count} Song Unit(s)'
	String get discoveredImported => 'Discovered and imported {count} Song Unit(s)';

	/// en: 'Switch to In-Place'
	String get switchToInPlace => 'Switch to In-Place';

	/// en: 'Switch to Centralized'
	String get switchToCentralized => 'Switch to Centralized';

	/// en: 'This will move all entry point files from central storage into {path} alongside their audio sources'
	String get migrateToInPlaceBody => 'This will move all entry point files from central storage into {path} alongside their audio sources';

	/// en: 'This will move all entry point files from {path} into central storage'
	String get migrateToCentralizedBody => 'This will move all entry point files from {path} into central storage';

	/// en: 'Switched to In-Place mode'
	String get switchedToInPlace => 'Switched to In-Place mode';

	/// en: 'Switched to Centralized mode'
	String get switchedToCentralized => 'Switched to Centralized mode';

	/// en: 'Migration failed'
	String get migrationFailed => 'Migration failed';

	/// en: 'Migration error: {error}'
	String get migrationError => 'Migration error: {error}';

	/// en: 'Rename Location'
	String get renameLocation => 'Rename Location';

	/// en: 'Name'
	String get nameLabel => 'Name';

	/// en: 'Remove Library Location'
	String get removeLocation => 'Remove Library Location';

	/// en: 'Are you sure you want to remove "{name}"?'
	String get removeLocationConfirm => 'Are you sure you want to remove "{name}"?';

	/// en: 'Song units and audio entries discovered from this location will be removed from the library. No files will be deleted from disk.'
	String get removeLocationNote => 'Song units and audio entries discovered from this location will be removed from the library. No files will be deleted from disk.';

	/// en: 'Removed "{name}"'
	String get removed => 'Removed "{name}"';

	/// en: 'Failed to remove: {error}'
	String get failedToRemove => 'Failed to remove: {error}';

	/// en: '"{name}" is now the default'
	String get isNowDefault => '"{name}" is now the default';

	/// en: 'Failed to set default: {error}'
	String get failedToSetDefault => 'Failed to set default: {error}';

	/// en: 'Accessible'
	String get accessible => 'Accessible';

	/// en: 'Inaccessible'
	String get inaccessible => 'Inaccessible';

	/// en: 'In-Place'
	String get inPlace => 'In-Place';

	/// en: 'Centralized'
	String get centralized => 'Centralized';

	/// en: 'Set as Default'
	String get setAsDefault => 'Set as Default';
}

// Path: locationSetup
class TranslationsLocationSetupEn {
	TranslationsLocationSetupEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Set Up Library Locations'
	String get title => 'Set Up Library Locations';

	/// en: 'Add folders where your music files are stored. Beadline will automatically scan these locations and monitor for changes.'
	String get description => 'Add folders where your music files are stored. Beadline will automatically scan these locations and monitor for changes.';

	/// en: 'Storage permissions required'
	String get storagePermissionRequired => 'Storage permissions required';

	/// en: 'Selected Locations'
	String get selectedLocations => 'Selected Locations';

	/// en: 'Add Library Location'
	String get addLocation => 'Add Library Location';

	/// en: 'The first location will be used as the default for new song units'
	String get firstLocationNote => 'The first location will be used as the default for new song units';
}

// Path: configMode
class TranslationsConfigModeEn {
	TranslationsConfigModeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Welcome to Beadline'
	String get title => 'Welcome to Beadline';

	/// en: 'Choose how you want to store your library configuration'
	String get subtitle => 'Choose how you want to store your library configuration';

	/// en: 'Centralized Storage'
	String get centralizedTitle => 'Centralized Storage';

	/// en: 'Store all configuration in the app data directory'
	String get centralizedDesc => 'Store all configuration in the app data directory';

	/// en: 'All data in one place Easy backup and restore Standard app behavior'
	String get centralizedPros => 'All data in one place\nEasy backup and restore\nStandard app behavior';

	/// en: 'Less portable between devices Requires manual export for sharing'
	String get centralizedCons => 'Less portable between devices\nRequires manual export for sharing';

	/// en: 'In-Place Storage'
	String get inPlaceTitle => 'In-Place Storage';

	/// en: 'Store Song Unit metadata alongside your music files'
	String get inPlaceDesc => 'Store Song Unit metadata alongside your music files';

	/// en: 'Portable across devices Auto-discovery of Song Units Keep metadata with files'
	String get inPlacePros => 'Portable across devices\nAuto-discovery of Song Units\nKeep metadata with files';

	/// en: 'Creates beadline-*.json files in music folders Requires storage location setup'
	String get inPlaceCons => 'Creates beadline-*.json files in music folders\nRequires storage location setup';

	/// en: 'You can change this setting later in Settings > Storage'
	String get changeNote => 'You can change this setting later in Settings > Storage';
}

// Path: onlineProviders
class TranslationsOnlineProvidersEn {
	TranslationsOnlineProvidersEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Online Source Providers'
	String get title => 'Online Source Providers';

	/// en: 'No providers configured'
	String get noProviders => 'No providers configured';

	/// en: 'Add a provider to search for online sources'
	String get noProvidersHint => 'Add a provider to search for online sources';

	/// en: 'Add Provider'
	String get addProvider => 'Add Provider';

	/// en: 'Edit Provider'
	String get editProvider => 'Edit Provider';

	/// en: 'Provider ID'
	String get providerIdLabel => 'Provider ID';

	/// en: 'bilibili, netease, etc.'
	String get providerIdHint => 'bilibili, netease, etc.';

	/// en: 'Display Name'
	String get displayNameLabel => 'Display Name';

	/// en: 'Bilibili, NetEase Cloud Music, etc.'
	String get displayNameHint => 'Bilibili, NetEase Cloud Music, etc.';

	/// en: 'Base URL'
	String get baseUrlLabel => 'Base URL';

	/// en: 'http://localhost:3000'
	String get baseUrlHint => 'http://localhost:3000';

	/// en: 'API Key (Optional)'
	String get apiKeyOptional => 'API Key (Optional)';

	/// en: 'Leave empty if not required'
	String get apiKeyHint => 'Leave empty if not required';

	/// en: 'Timeout (seconds)'
	String get timeoutLabel => 'Timeout (seconds)';

	/// en: '10'
	String get timeoutDefault => '10';

	/// en: 'Timeout must be a positive number'
	String get timeoutError => 'Timeout must be a positive number';
}

// Path: display
class TranslationsDisplayEn {
	TranslationsDisplayEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No display source'
	String get noSource => 'No display source';

	/// en: 'Loading: {name}'
	String get loading => 'Loading: {name}';

	/// en: 'Failed to load: {name}'
	String get failedToLoad => 'Failed to load: {name}';
}

// Path: lyrics
class TranslationsLyricsEn {
	TranslationsLyricsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No lyrics'
	String get noLyrics => 'No lyrics';
}

// Path: floatingLyrics
class TranslationsFloatingLyricsEn {
	TranslationsFloatingLyricsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No lyrics'
	String get noLyrics => 'No lyrics';
}

// Path: songPicker
class TranslationsSongPickerEn {
	TranslationsSongPickerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Select Songs'
	String get selectSongs => 'Select Songs';

	/// en: 'Select Song'
	String get selectSong => 'Select Song';

	/// en: 'Search songs...'
	String get searchHint => 'Search songs...';

	/// en: 'No songs found'
	String get noSongsFound => 'No songs found';

	/// en: 'No songs in library'
	String get noSongsInLibrary => 'No songs in library';

	/// en: 'Add songs'
	String get addSongs => 'Add songs';
}

// Path: videoRemoval
class TranslationsVideoRemovalEn {
	TranslationsVideoRemovalEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Remove Display Source'
	String get title => 'Remove Display Source';

	/// en: 'The display source "{videoName}" has an extracted audio source "{audioName}". Would you like to also remove the audio source?'
	String get message => 'The display source "{videoName}" has an extracted audio source "{audioName}". Would you like to also remove the audio source?';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Keep Audio'
	String get keepAudio => 'Keep Audio';

	/// en: 'Remove Both'
	String get removeBoth => 'Remove Both';
}

// Path: debug
class TranslationsDebugEn {
	TranslationsDebugEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Audio Entries Debug'
	String get audioEntriesTitle => 'Audio Entries Debug';

	/// en: 'Temporary Song Units Found: {count}'
	String get temporarySongUnitsFound => 'Temporary Song Units Found: {count}';

	/// en: 'Refresh'
	String get refresh => 'Refresh';

	/// en: 'Temporary Song Units'
	String get temporarySongUnits => 'Temporary Song Units';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Show Entries'
	String get showEntries => 'Show Entries';
}

// Path: dialogs
class TranslationsDialogsEn {
	TranslationsDialogsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Confirm Mode Change'
	String get confirmModeChange => 'Confirm Mode Change';

	/// en: 'Change Mode'
	String get changeMode => 'Change Mode';

	/// en: 'Discovering Audio Files'
	String get discoveringAudioFiles => 'Discovering Audio Files';

	/// en: 'Re-scanning Audio Files'
	String get rescanningAudioFiles => 'Re-scanning Audio Files';

	/// en: 'No library locations configured'
	String get noLibraryLocationsConfigured => 'No library locations configured';

	/// en: 'Error loading locations'
	String get errorLoadingLocations => 'Error loading locations';

	/// en: 'Default'
	String get kDefault => 'Default';

	/// en: 'Add a location to store your music library'
	String get addLocationToStoreMusic => 'Add a location to store your music library';

	/// en: 'No library locations'
	String get noLocationsTitle => 'No library locations';

	/// en: 'Add a location to store your music library'
	String get noLocationsMessage => 'Add a location to store your music library';

	/// en: 'Add nested group'
	String get addNestedGroup => 'Add nested group';

	/// en: 'Remove Group'
	String get removeGroup => 'Remove Group';

	/// en: 'How would you like to remove "{groupName}"?'
	String get removeGroupQuestion => 'How would you like to remove "{groupName}"?';

	/// en: 'Ungroup (keep songs)'
	String get ungroupKeepSongs => 'Ungroup (keep songs)';

	/// en: 'Remove all'
	String get removeAll => 'Remove all';

	/// en: 'Rename Group'
	String get renameGroup => 'Rename Group';

	/// en: 'Create Nested Group'
	String get createNestedGroup => 'Create Nested Group';

	/// en: 'Create Group'
	String get createGroup => 'Create Group';

	/// en: 'Select Thumbnail'
	String get selectThumbnail => 'Select Thumbnail';

	/// en: 'Error adding custom thumbnail: {error}'
	String get errorAddingCustomThumbnail => 'Error adding custom thumbnail: {error}';

	/// en: 'No results. Enter a search query and press search.'
	String get noResultsEnterSearch => 'No results. Enter a search query and press search.';

	/// en: 'Edit'
	String get editProvider => 'Edit';

	/// en: 'Delete'
	String get deleteProvider => 'Delete';

	/// en: 'ID: {providerId}'
	String get providerId => 'ID: {providerId}';

	/// en: 'URL: {baseUrl}'
	String get providerUrl => 'URL: {baseUrl}';

	/// en: 'API Key: •••••••- '
	String get providerApiKey => 'API Key: •••••••- ';

	/// en: 'Delete Song Unit'
	String get deleteSongUnit => 'Delete Song Unit';

	/// en: 'Also delete configuration file'
	String get alsoDeleteConfigFile => 'Also delete configuration file';

	/// en: 'Removes the beadline-*.json file. Source files are not affected.'
	String get configFileNote => 'Removes the beadline-*.json file. Source files are not affected.';

	/// en: 'Delete original song units after merge'
	String get deleteOriginalAfterMerge => 'Delete original song units after merge';

	/// en: 'Are you sure you want to delete {count} item(s)?'
	String get deleteItemsConfirm => 'Are you sure you want to delete {count} item(s)?';

	/// en: 'Deleted {count} item(s)'
	String get deletedItems => 'Deleted {count} item(s)';

	/// en: 'Import Complete'
	String get importComplete => 'Import Complete';

	/// en: 'Imported: {count}'
	String get imported => 'Imported: {count}';

	/// en: 'Skipped (duplicates): {count}'
	String get skippedDuplicates => 'Skipped (duplicates): {count}';

	/// en: '... and {count} more'
	String get importMore => '... and {count} more';

	/// en: 'Promoted "{name}" to Song Unit'
	String get promotedToSongUnit => 'Promoted "{name}" to Song Unit';

	/// en: 'Exported to {path}'
	String get exportedTo => 'Exported to {path}';

	/// en: 'Promoted "{displayName}" to Song Unit'
	String get promoted => 'Promoted "{displayName}" to Song Unit';

	/// en: 'Reset failed: {error}'
	String get resetFailed => 'Reset failed: {error}';

	/// en: 'Confirm Mode Change'
	String get confirmTitle => 'Confirm Mode Change';

	/// en: 'Change Mode'
	String get changeModeButton => 'Change Mode';

	/// en: 'Migrating Configuration'
	String get migratingConfig => 'Migrating Configuration';

	/// en: 'Migrating entry point files...'
	String get migratingEntryPoints => 'Migrating entry point files...';

	/// en: 'Scanning for Song Units...'
	String get scanningForSongUnits => 'Scanning for Song Units...';

	/// en: 'Error scanning: {error}'
	String get errorScanning => 'Error scanning: {error}';

	/// en: 'Error clearing audio entries: {error}'
	String get errorClearingAudio => 'Error clearing audio entries: {error}';

	/// en: 'Error re-scanning: {error}'
	String get errorRescanning => 'Error re-scanning: {error}';

	/// en: 'Failed to rename: {error}'
	String get failedToRename => 'Failed to rename: {error}';

	/// en: 'Failed to remove: {error}'
	String get failedToRemove => 'Failed to remove: {error}';

	/// en: 'Failed to set default: {error}'
	String get failedToSetDefault => 'Failed to set default: {error}';

	/// en: 'Migration error: {error}'
	String get migrationError => 'Migration error: {error}';

	late final TranslationsDialogsHomeEn home = TranslationsDialogsHomeEn._(_root);
	late final TranslationsDialogsProgressDialogsEn progressDialogs = TranslationsDialogsProgressDialogsEn._(_root);
	late final TranslationsDialogsLibraryLocationsErrorEn libraryLocationsError = TranslationsDialogsLibraryLocationsErrorEn._(_root);
}

// Path: configModeChange
class TranslationsConfigModeChangeEn {
	TranslationsConfigModeChangeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Confirm Mode Change'
	String get title => 'Confirm Mode Change';

	/// en: 'Changing configuration mode will migrate your entry point files. This may take a moment.'
	String get description => 'Changing configuration mode will migrate your entry point files. This may take a moment.';

	/// en: 'This will create beadline-*.json files alongside your music files. Your library will become portable across devices.'
	String get inPlaceDescription => 'This will create beadline-*.json files alongside your music files. Your library will become portable across devices.';

	/// en: 'This will move entry point files to the app data directory. Your library will no longer be portable.'
	String get centralizedDescription => 'This will move entry point files to the app data directory. Your library will no longer be portable.';

	/// en: 'Change Mode'
	String get changeMode => 'Change Mode';
}

// Path: app_routes
class TranslationsAppRoutesEn {
	TranslationsAppRoutesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Route not found: {name}'
	String get routeNotFound => 'Route not found: {name}';
}

// Path: loading_indicator
class TranslationsLoadingIndicatorEn {
	TranslationsLoadingIndicatorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '{percentage}%'
	String get percentage => '{percentage}%';
}

// Path: video_removal_prompt
class TranslationsVideoRemovalPromptEn {
	TranslationsVideoRemovalPromptEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Remove Display Source'
	String get title => 'Remove Display Source';

	/// en: 'The display source "{videoName}" has an extracted audio source "{audioName}". Would you like to also remove the audio source?'
	String get message => 'The display source "{videoName}" has an extracted audio source "{audioName}". Would you like to also remove the audio source?';

	/// en: 'Keep Audio'
	String get keepAudio => 'Keep Audio';

	/// en: 'Remove Both'
	String get removeBoth => 'Remove Both';
}

// Path: library_location_setup_dialog
class TranslationsLibraryLocationSetupDialogEn {
	TranslationsLibraryLocationSetupDialogEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Select Music Library Location'
	String get title => 'Select Music Library Location';
}

// Path: home_page
class TranslationsHomePageEn {
	TranslationsHomePageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Rename Group'
	String get renameGroup => 'Rename Group';
}

// Path: song_unit_editor
class TranslationsSongUnitEditorEn {
	TranslationsSongUnitEditorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Added {title} to sources'
	String get addedToSources => 'Added {title} to sources';

	/// en: 'title'
	String get aliasHint => 'title';
}

// Path: library.actions
class TranslationsLibraryActionsEn {
	TranslationsLibraryActionsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'View song units'
	String get viewSongUnits => 'View song units';

	/// en: 'Convert to Song Unit'
	String get convertToSongUnit => 'Convert to Song Unit';

	/// en: 'Add to Playlist'
	String get addToPlaylist => 'Add to Playlist';

	/// en: 'Add to queue'
	String get addToQueue => 'Add to queue';

	/// en: 'Promote to full Song Units'
	String get promoteToSongUnits => 'Promote to full Song Units';

	/// en: 'Merge selected'
	String get mergeSelected => 'Merge selected';

	/// en: 'Export selected'
	String get exportSelected => 'Export selected';

	/// en: 'Delete selected'
	String get deleteSelected => 'Delete selected';

	/// en: 'Select all'
	String get selectAll => 'Select all';

	/// en: 'Add tags'
	String get addTagsToSelected => 'Add tags';
}

// Path: player.displayMode
class TranslationsPlayerDisplayModeEn {
	TranslationsPlayerDisplayModeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Display Mode'
	String get label => 'Display Mode';

	/// en: 'Enabled'
	String get enabled => 'Enabled';

	/// en: 'Image Only'
	String get imageOnly => 'Image Only';

	/// en: 'Disabled'
	String get disabled => 'Disabled';

	/// en: 'Hidden'
	String get hidden => 'Hidden';
}

// Path: player.audioMode
class TranslationsPlayerAudioModeEn {
	TranslationsPlayerAudioModeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Audio Mode'
	String get label => 'Audio Mode';

	/// en: 'Original'
	String get original => 'Original';

	/// en: 'Accompaniment'
	String get accompaniment => 'Accompaniment';
}

// Path: player.playbackMode
class TranslationsPlayerPlaybackModeEn {
	TranslationsPlayerPlaybackModeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Playback Mode'
	String get label => 'Playback Mode';

	/// en: 'Sequential'
	String get sequential => 'Sequential';

	/// en: 'Repeat One'
	String get repeatOne => 'Repeat One';

	/// en: 'Repeat All'
	String get repeatAll => 'Repeat All';

	/// en: 'Random'
	String get random => 'Random';
}

// Path: player.lyricsMode
class TranslationsPlayerLyricsModeEn {
	TranslationsPlayerLyricsModeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Lyrics Mode'
	String get label => 'Lyrics Mode';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'Screen'
	String get screen => 'Screen';

	/// en: 'Floating'
	String get floating => 'Floating';

	/// en: 'Rolling'
	String get rolling => 'Rolling';
}

// Path: dialogs.home
class TranslationsDialogsHomeEn {
	TranslationsDialogsHomeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Shuffle'
	String get shuffle => 'Shuffle';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Add nested group'
	String get addNestedGroup => 'Add nested group';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Remove Group'
	String get removeGroup => 'Remove Group';

	/// en: 'How would you like to remove "{groupName}"?'
	String get removeGroupQuestion => 'How would you like to remove "{groupName}"?';

	/// en: 'Ungroup (keep songs)'
	String get ungroupKeepSongs => 'Ungroup (keep songs)';

	/// en: 'Remove all'
	String get removeAll => 'Remove all';

	/// en: 'Rename Group'
	String get renameGroup => 'Rename Group';

	/// en: 'Create Nested Group'
	String get createNestedGroup => 'Create Nested Group';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Create Group'
	String get createGroup => 'Create Group';
}

// Path: dialogs.progressDialogs
class TranslationsDialogsProgressDialogsEn {
	TranslationsDialogsProgressDialogsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Discovering Audio Files'
	String get discovering => 'Discovering Audio Files';

	/// en: 'Re-scanning Audio Files'
	String get rescanning => 'Re-scanning Audio Files';
}

// Path: dialogs.libraryLocationsError
class TranslationsDialogsLibraryLocationsErrorEn {
	TranslationsDialogsLibraryLocationsErrorEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No library locations configured'
	String get noLocationsConfigured => 'No library locations configured';

	/// en: 'Error loading locations'
	String get errorLoading => 'Error loading locations';

	/// en: 'Retry'
	String get retry => 'Retry';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.cancel' => 'Cancel',
			'common.save' => 'Save',
			'common.delete' => 'Delete',
			'common.add' => 'Add',
			'common.edit' => 'Edit',
			'common.rename' => 'Rename',
			'common.create' => 'Create',
			'common.close' => 'Close',
			'common.retry' => 'Retry',
			'common.refresh' => 'Refresh',
			'common.search' => 'Search',
			'common.ok' => 'OK',
			'common.yes' => 'Yes',
			'common.no' => 'No',
			'common.back' => 'Back',
			'common.skip' => 'Skip for Now',
			'common.apply' => 'Apply',
			'common.remove' => 'Remove',
			'common.duplicate' => 'Duplicate',
			'common.export' => 'Export',
			'common.import' => 'Import',
			'common.migrate' => 'Migrate',
			'common.reset' => 'Reset',
			'common.grant' => 'Grant',
			'common.enabled' => 'Enabled',
			'common.disabled' => 'Disabled',
			'common.on' => 'ON',
			'common.off' => 'OFF',
			'common.error' => 'Error',
			'common.loading' => 'Loading...',
			'common.songs' => 'songs',
			'common.selected' => 'selected',
			'common.items' => 'items',
			'common.ms' => 'ms',
			'common.dismiss' => 'Dismiss',
			'common.extract' => 'Extract',
			'common.extractingThumbnails' => 'Extracting thumbnails...',
			'common.noThumbnailsAvailable' => 'No thumbnails available',
			'common.displayVideoImage' => 'Display (Video/Image)',
			'common.id' => 'ID',
			'common.url' => 'URL',
			'common.apiKey' => 'API Key',
			'common.openParen' => '(',
			'common.closeParen' => ')',
			'common.routeNotFound' => 'Route not found: {name}',
			'common.noResultsEnterSearch' => 'No results. Enter a search query and press search.',
			'common.artistLabel' => 'Artist:',
			'common.albumLabel' => 'Album:',
			'common.platformLabel' => 'Platform:',
			'common.percentage' => '{percentage}%',
			'common.testConnection' => 'Test Connection',
			'common.disabledInKtvMode' => 'Disabled in KTV mode',
			'common.failedToRename' => 'Failed to rename: {error}',
			'common.continueText' => 'Continue',
			'common.artist' => 'artist',
			'common.album' => 'album',
			'common.platform' => 'platform',
			'common.addImage' => 'Add Image',
			'common.shuffle' => 'Shuffle',
			'common.alreadyInPlaylist' => 'Already in playlist',
			'common.createAndAdd' => 'Create & Add',
			'nav.home' => 'Home',
			'nav.library' => 'Library',
			'nav.playlists' => 'Playlists',
			'nav.tags' => 'Tags',
			'nav.settings' => 'Settings',
			'app.name' => 'Beadline',
			'library.title' => 'Library',
			'library.loading' => 'Loading library...',
			'library.searchHint' => 'Search library...',
			'library.noLocations' => 'No library locations',
			'library.allLocations' => 'All Locations',
			'library.filterByLocation' => 'Filter by Library Location',
			'library.listView' => 'List view',
			'library.gridView' => 'Grid view',
			'library.noItems' => 'No library items',
			'library.noResults' => 'No songs found',
			'library.tryDifferentSearch' => 'Try a different search term',
			'library.audioOnly' => 'Audio Only',
			'library.noSong' => 'No song',
			'library.actions.viewSongUnits' => 'View song units',
			'library.actions.convertToSongUnit' => 'Convert to Song Unit',
			'library.actions.addToPlaylist' => 'Add to Playlist',
			'library.actions.addToQueue' => 'Add to queue',
			'library.actions.promoteToSongUnits' => 'Promote to full Song Units',
			'library.actions.mergeSelected' => 'Merge selected',
			'library.actions.exportSelected' => 'Export selected',
			'library.actions.deleteSelected' => 'Delete selected',
			'library.actions.selectAll' => 'Select all',
			'library.actions.addTagsToSelected' => 'Add tags',
			'library.processing' => 'Processing...',
			'library.exportedTo' => 'Exported to {path}',
			'library.importComplete' => 'Import Complete',
			'library.imported' => 'Imported: {count}',
			'library.skippedDuplicates' => 'Skipped (duplicates): {count}',
			'library.importMore' => '... and {count} more',
			'library.promotedToSongUnit' => 'Promoted "{name}" to Song Unit',
			'library.deleteItemsConfirm' => 'Are you sure you want to delete {count} item(s)?',
			'library.deletedItems' => 'Deleted {count} item(s)',
			'library.addedItemsToQueue' => 'Added {count} item(s) to queue',
			'library.noTemporaryEntriesSelected' => 'No temporary entries selected',
			'library.addSongsToPlaylistTitle' => 'Add {count} song(s) to Playlist',
			'library.noPlaylistsCreateFirst' => 'No playlists yet. Create one first.',
			'library.sectionMetadata' => 'Metadata',
			'library.sectionSources' => 'Sources',
			'library.sectionTags' => 'Tags',
			'library.errorLoadingLibrary' => 'Error loading library',
			'library.deleteSongUnit' => 'Delete Song Unit',
			'library.alsoDeleteConfigFile' => 'Also delete configuration file',
			'library.configFileNote' => 'Removes the beadline-*.json file. Source files are not affected.',
			'library.deleteOriginalAfterMerge' => 'Delete original song units after merge',
			'library.selectedCount' => '{count} selected',
			'library.alreadyInPlaylist' => 'Already in playlist',
			'library.createAndAdd' => 'Create & Add',
			'library.promoted' => 'Promoted "{displayName}" to Song Unit',
			'player.noSongPlaying' => 'No song playing',
			'player.source' => 'Source',
			'player.display' => 'Display',
			'player.audio' => 'Audio',
			'player.playback' => 'Playback',
			'player.lyrics' => 'Lyrics',
			'player.fullscreen' => 'Fullscreen',
			'player.exitFullscreen' => 'Exit fullscreen (ESC)',
			'player.selectSources' => 'Select sources',
			'player.play' => 'Play',
			'player.pause' => 'Pause',
			'player.next' => 'Next',
			'player.displayMode.label' => 'Display Mode',
			'player.displayMode.enabled' => 'Enabled',
			'player.displayMode.imageOnly' => 'Image Only',
			'player.displayMode.disabled' => 'Disabled',
			'player.displayMode.hidden' => 'Hidden',
			'player.audioMode.label' => 'Audio Mode',
			'player.audioMode.original' => 'Original',
			'player.audioMode.accompaniment' => 'Accompaniment',
			'player.playbackMode.label' => 'Playback Mode',
			'player.playbackMode.sequential' => 'Sequential',
			'player.playbackMode.repeatOne' => 'Repeat One',
			'player.playbackMode.repeatAll' => 'Repeat All',
			'player.playbackMode.random' => 'Random',
			'player.lyricsMode.label' => 'Lyrics Mode',
			'player.lyricsMode.off' => 'Off',
			'player.lyricsMode.screen' => 'Screen',
			'player.lyricsMode.floating' => 'Floating',
			'player.lyricsMode.rolling' => 'Rolling',
			'queue.title' => 'Queue',
			'queue.manage' => 'Manage queues',
			'queue.removeDuplicates' => 'Remove duplicates',
			'queue.shuffle' => 'Shuffle',
			'queue.removeAfterPlayOn' => 'Remove after play: ON',
			'queue.removeAfterPlayOff' => 'Remove after play: OFF',
			'queue.clearQueue' => 'Clear queue',
			'queue.removedDuplicates' => 'Removed {count} duplicate(s)',
			'queue.noDuplicates' => 'No duplicates found',
			'queue.manageQueues' => 'Manage Queues',
			'queue.queueContent' => 'Queue Content',
			'queue.backToQueues' => 'Back to queues',
			'queue.createQueue' => 'Create New Queue',
			'queue.queueName' => 'Queue Name',
			'queue.enterQueueName' => 'Enter queue name',
			'queue.renameQueue' => 'Rename Queue',
			'queue.enterNewName' => 'Enter new name',
			'queue.deleteQueue' => 'Delete Queue',
			'queue.deleteQueueConfirm' => 'Are you sure you want to delete',
			'queue.deleteQueueWillRemove' => 'This will remove',
			'queue.deleteQueueFromQueue' => 'songs from this queue',
			'queue.switchToQueue' => 'Switch to this queue',
			'queue.empty' => 'Queue is empty',
			'queue.songs' => '{count} songs',
			'queue.actions' => 'Queue actions',
			'queue.collapse' => 'Collapse',
			'queue.expand' => 'Expand',
			'queue.groupActions' => 'Group actions',
			'search.title' => 'Search',
			'search.songUnits' => 'Song Units',
			'search.sources' => 'Sources',
			'search.hint' => 'Search...',
			'search.textMode' => 'Text mode',
			'search.queryBuilder' => 'Query builder',
			'search.tag' => 'Tag',
			'search.tagExample' => 'e.g., artist:value',
			'search.range' => 'Range',
			'search.rangeExample' => 'e.g., time:[2020-2024]',
			'search.searching' => 'Searching...',
			'search.searchError' => 'Search error',
			'search.noSongUnitsFound' => 'No song units found',
			'search.loadMore' => 'Load more',
			'search.play' => 'Play',
			'search.addToQueue' => 'Add to queue',
			'search.all' => 'All',
			'search.local' => 'Local',
			'search.online' => 'Online',
			'search.searchingSources' => 'Searching sources...',
			'search.noOnlineSources' => 'No online sources found',
			'search.noLocalSources' => 'No local sources found',
			'search.noSources' => 'No sources found',
			'search.addToSongUnit' => 'Add to Song Unit',
			'search.or' => 'OR',
			'search.not' => 'NOT',
			'search.addedToQueue' => 'Added "{title}" to queue',
			'search.addSource' => 'Add source: {title}',
			'tags.title' => 'Tags',
			'tags.noTags' => 'No tags yet',
			'tags.noTagsHint' => 'Create tags to organize your music',
			'tags.loadError' => 'Error loading tags',
			'tags.createTag' => 'Create Tag',
			'tags.createChildTag' => 'Create Child Tag',
			'tags.tagName' => 'Tag name',
			'tags.addAlias' => 'Add Alias',
			'tags.addAliasFor' => 'Add Alias for',
			'tags.aliasName' => 'Alias name',
			'tags.enterAlias' => 'Enter alias',
			'tags.addChildTag' => 'Add child tag',
			'tags.deleteTag' => 'Delete tag',
			'tags.deleteTagTitle' => 'Delete tag?',
			'tags.deleteTagConfirm' => 'This action cannot be undone',
			'tags.deleteTagHasChildren' => 'This tag has child tags. They will become root tags.',
			'tags.deleteTagAliases' => 'Aliases will also be deleted.',
			'tags.deletedTag' => 'Deleted tag',
			'tags.removeFromSong' => 'Remove tag from this song',
			'tags.removeAll' => 'Remove All',
			'tags.viewSongUnits' => 'View song units',
			'tags.item' => 'item',
			'tags.items' => 'items',
			'tags.songUnit' => 'song unit',
			'tags.songUnits' => 'song units',
			'tags.lockedCollection' => 'Locked collection',
			'tags.collection' => 'Collection',
			'tags.locked' => 'Locked',
			'playlists.title' => 'Playlists',
			'playlists.noPlaylists' => 'No playlists yet',
			'playlists.noPlaylistsHint' => 'Right-click or long-press to create a playlist',
			'playlists.selectPlaylist' => 'Select a playlist to view its contents',
			'playlists.createPlaylist' => 'Create Playlist',
			'playlists.addSongs' => 'Add Songs',
			'playlists.createGroup' => 'Create Group',
			'playlists.moveToGroup' => 'Move to Group',
			'playlists.addCollectionRef' => 'Add Collection Reference',
			'playlists.renamePlaylist' => 'Rename Playlist',
			'playlists.deletePlaylist' => 'Delete Playlist',
			'playlists.deletePlaylistConfirm' => 'Are you sure you want to delete',
			'playlists.deletePlaylistNote' => 'Songs will not be deleted, only this playlist',
			'playlists.createGroupTitle' => 'Create Group',
			'playlists.createGroupHint' => 'Create a group',
			'playlists.groupName' => 'Group Name',
			'playlists.enterGroupName' => 'Enter group name',
			'playlists.addCollectionRefTitle' => 'Add Collection Reference',
			'playlists.noOtherCollections' => 'No other collections available',
			'playlists.addReferenceTo' => 'Add reference to',
			'playlists.lock' => 'Lock',
			'playlists.unlock' => 'Unlock',
			'playlists.viewContent' => 'View content',
			'playlists.toggleSelectionMode' => 'Toggle selection mode',
			'playlists.noGroupsAvailable' => 'No groups available. Create a group first.',
			'playlists.song' => 'song',
			'playlists.songs' => 'songs',
			'playlists.locked' => 'Locked',
			'playlists.clearSelection' => 'Clear selection',
			'playlists.selected' => 'selected',
			'playlists.removeFromGroup' => 'Remove from Group',
			'playlists.alreadyInPlaylist' => 'Already in playlist',
			'playlists.addedToPlaylist' => 'Added to "{name}"',
			'playlists.createdPlaylistAndAdded' => 'Created playlist "{name}" and added song',
			'playlists.createAndAdd' => 'Create & Add',
			'playlists.songCount' => '{count} songs',
			'playlists.noSongsInGroup' => 'No songs in this group',
			'playlists.dropHere' => 'drop here',
			'playlists.groupCreated' => 'Group "{name}" created',
			'playlists.failedToCreateGroup' => 'Failed to create group: {error}',
			'songEditor.titleEdit' => 'Edit Song Unit',
			'songEditor.titleNew' => 'New Song Unit',
			'songEditor.reloadMetadata' => 'Reload metadata from source',
			'songEditor.writeMetadata' => 'Write metadata to source',
			'songEditor.sources' => 'Sources',
			'songEditor.display' => 'Display',
			'songEditor.audio' => 'Audio',
			'songEditor.accompaniment' => 'Accompaniment',
			'songEditor.lyricsLabel' => 'Lyrics',
			'songEditor.noDisplaySources' => 'No display sources',
			'songEditor.noAudioSources' => 'No audio sources',
			'songEditor.noAccompanimentSources' => 'No accompaniment sources',
			'songEditor.noLyricsSources' => 'No lyrics sources',
			'songEditor.addDisplaySource' => 'Add Display source',
			'songEditor.addAudioSource' => 'Add Audio source',
			'songEditor.addAccompanimentSource' => 'Add Accompaniment source',
			'songEditor.addLyricsSource' => 'Add Lyrics source',
			'songEditor.editDisplayName' => 'Edit display name',
			'songEditor.setOffset' => 'Set offset',
			'songEditor.setOffsetTitle' => 'Set Offset',
			'songEditor.offsetHint' => 'Offset in milliseconds to align with audio',
			'songEditor.offsetNote' => 'Positive = delay, Negative = advance',
			'songEditor.offsetLabel' => 'Offset (ms)',
			'songEditor.editDisplayNameTitle' => 'Edit Display Name',
			'songEditor.originalName' => 'Original',
			'songEditor.displayNameLabel' => 'Display name',
			'songEditor.displayNameHint' => 'Leave empty to use original name',
			'songEditor.addSource' => 'Add source',
			'songEditor.localFile' => 'Local file',
			'songEditor.enterUrl' => 'Enter URL',
			'songEditor.urlLabel' => 'URL',
			'songEditor.urlHint' => 'https://...',
			'songEditor.selectSong' => 'Select Song',
			'songEditor.selectSongs' => 'Select Songs',
			'songEditor.addSongs' => 'Add songs',
			'songEditor.artist' => 'artist',
			'songEditor.thumbnail' => 'thumbnail',
			'songEditor.addImage' => 'Add Image',
			'songEditor.selectThumbnails' => 'Select ({count})',
			'songEditor.selectThumbnailTitle' => 'Select Thumbnail',
			'songEditor.errorAddingCustomThumbnail' => 'Error adding custom thumbnail: {error}',
			'songEditor.audioExtracted' => 'Audio track extracted from {name}',
			'songEditor.noAudioFound' => 'No audio track found in {name}',
			'songEditor.autoDiscovered' => 'Auto-discovered: {types}',
			'songEditor.chooseMetadataValues' => 'Choose values for each metadata field:',
			'songEditor.builtInTagsMetadata' => 'Built-in Tags (Metadata)',
			'songEditor.userTags' => 'User Tags',
			'songEditor.noUserTags' => 'No user tags available. Create tags in the Tags section.',
			'songEditor.tagNameName' => 'name',
			'songEditor.tagNameAlbum' => 'album',
			'songEditor.tagNameTime' => 'time',
			'songEditor.aliasHintTitle' => 'title',
			'songEditor.addImageOrExtract' => 'Add an image or extract from audio files',
			'songEditor.thumbnailsAvailable' => '{count} thumbnail(s) available',
			'songEditor.removeFromCollection' => 'Remove from collection',
			'songEditor.metadataWriteNotImplemented' => 'Metadata writing is not yet implemented. Requires external library integration.',
			'songEditor.linkedVideoFrom' => 'From: {name}',
			'songEditor.offsetDisplay' => 'Offset: {value}',
			'songEditor.searchOnlineSources' => 'Search Online Sources',
			'songEditor.providerLabel' => 'Provider',
			'songEditor.sourceTypeLabel' => 'Source Type',
			'songEditor.searchQueryLabel' => 'Search Query',
			'songEditor.durationDisplay' => 'Duration: {value}',
			'songEditor.addToSongUnit' => 'Add to Song Unit',
			'songEditor.cannotSaveInPlaceNoLocations' => 'Cannot save Song Unit in in-place mode without library locations. Please configure at least one library location in Settings.',
			'songEditor.failedToLoadUrl' => 'Failed to load media from URL. The URL may be invalid or unreachable.',
			'songEditor.urlNotDirectMedia' => 'Warning: URL does not appear to be a direct media file. Use direct links to audio/video files (e.g., .mp3, .mp4), not web pages.',
			'songEditor.noAudioSourcesForMetadata' => 'No audio sources to extract metadata from',
			'songEditor.cannotExtractFromApi' => 'Cannot extract metadata from API source',
			'songEditor.metadataReloaded' => 'Metadata reloaded',
			'songEditor.addedSource' => 'Added {title}',
			'settings.title' => 'Settings',
			'settings.user' => 'User',
			'settings.username' => 'Username',
			'settings.appearance' => 'Appearance',
			'settings.theme' => 'Theme',
			'settings.themeSystem' => 'System',
			'settings.themeLight' => 'Light',
			'settings.themeDark' => 'Dark',
			'settings.accentColor' => 'Accent Color',
			'settings.accentColorHint' => 'Customize app color',
			'settings.language' => 'Language',
			'settings.languageSystemDefault' => 'System Default',
			'settings.languageSelectorTitle' => 'Choose Your Language',
			'settings.languageSelectorSubtitle' => 'Select your preferred language for the app',
			'settings.languageSelectorHint' => 'You can change the language later in Settings',
			'settings.languageSelectorContinue' => 'Continue',
			'settings.playback' => 'Playback',
			'settings.lyricsMode' => 'Lyrics Mode',
			'settings.ktvMode' => 'KTV Mode',
			'settings.ktvModeHint' => 'Force screen lyrics, disable floating',
			'settings.hideDisplayPanel' => 'Hide Display Panel',
			'settings.hideDisplayPanelHint' => 'Show only lyrics and controls (music-only mode)',
			'settings.thumbnailBgLibrary' => 'Use Thumbnail Background in Library',
			'settings.thumbnailBgLibraryHint' => 'Show thumbnails as backgrounds in library view',
			'settings.thumbnailBgQueue' => 'Use Thumbnail Background in Queue',
			'settings.thumbnailBgQueueHint' => 'Show thumbnails as backgrounds in queue',
			'settings.storage' => 'Storage',
			'settings.configMode' => 'Configuration Mode',
			'settings.configModeCentralized' => 'Centralized',
			'settings.configModeInPlace' => 'In-Place',
			'settings.libraryLocations' => 'Library Locations',
			'settings.libraryLocationsHint' => 'Manage where your music is stored',
			'settings.metadataWriteback' => 'Metadata Write-back',
			'settings.metadataWritebackHint' => 'Sync tag changes to source files',
			'settings.autoDiscoverAudio' => 'Auto-Discover Audio Files',
			'settings.autoDiscoverAudioHint' => 'Automatically add audio files from library locations',
			'settings.debug' => 'Debug',
			'settings.audioEntriesDebug' => 'Audio Entries Debug',
			'settings.audioEntriesDebugHint' => 'View discovered audio entries',
			'settings.rescanAudio' => 'Re-scan Audio Files',
			'settings.rescanAudioHint' => 'Clear and re-discover all audio files with updated metadata',
			'settings.about' => 'About',
			'settings.version' => 'Version',
			'settings.license' => 'License',
			'settings.licenseValue' => 'GNU Affero General Public License v3.0 (AGPL-3.0)',
			'settings.resetFactory' => 'Reset to Factory',
			'settings.resetFactoryHint' => 'Reset all settings to defaults',
			'settings.system' => 'System',
			'settings.resetFactoryTitle' => 'Reset to Factory Settings?',
			'settings.resetFactoryBody' => 'This will completely reset the application to a fresh state',
			'settings.resetFactoryItems' => 'All settings and preferences\nSong Unit library and tags\nPlaylists, queues, and groups\nPlayback state',
			'settings.resetFactoryNote' => 'Your actual music files on disk will NOT be deleted',
			'settings.resetFactoryRestart' => 'The app will restart after reset',
			'settings.resetEverything' => 'Reset Everything',
			'settings.rescanTitle' => 'Re-scan Audio Files',
			'settings.rescanBody' => 'This will clear all discovered audio entries and re-scan your library locations',
			'settings.rescanNote' => 'This may take a few minutes for large libraries. Continue?',
			'settings.rescan' => 'Re-scan',
			'settings.migratingConfig' => 'Migrating Configuration',
			'settings.migratingEntryPoints' => 'Migrating entry point files...',
			'settings.scanningForSongUnits' => 'Scanning for Song Units...',
			'settings.storagePermissionTitle' => 'Storage Permission Required',
			'settings.storagePermissionBody' => 'Beadline needs access to your music files to discover and play audio',
			'settings.storagePermissionNote' => 'Please grant storage permission in the next dialog, or go to Settings to enable it manually',
			'settings.openSettings' => 'Open Settings',
			'settings.foundAudioFiles' => 'Found {count} audio files',
			'settings.errorScanning' => 'Error scanning: {error}',
			'settings.audioEntriesCleared' => 'Audio entries cleared',
			'settings.errorClearingAudio' => 'Error clearing audio entries: {error}',
			'settings.audioRescanSuccess' => 'Audio files re-scanned successfully',
			'settings.errorRescanning' => 'Error re-scanning: {error}',
			'settings.testingConnection' => 'Testing connection...',
			'settings.connectionSuccess' => 'Connection successful!',
			'settings.connectionFailed' => 'Connection failed',
			'settings.onlineProviders' => 'Online Source Providers',
			'libraryLocations.title' => 'Library Locations',
			'libraryLocations.selectLocation' => 'Select Library Location',
			'libraryLocations.nameLocation' => 'Name this location',
			'libraryLocations.enterLocationName' => 'Enter a name for this location',
			'libraryLocations.locationAdded' => 'Library location added',
			'libraryLocations.discoveredImported' => 'Discovered and imported {count} Song Unit(s)',
			'libraryLocations.switchToInPlace' => 'Switch to In-Place',
			'libraryLocations.switchToCentralized' => 'Switch to Centralized',
			'libraryLocations.migrateToInPlaceBody' => 'This will move all entry point files from central storage into {path} alongside their audio sources',
			'libraryLocations.migrateToCentralizedBody' => 'This will move all entry point files from {path} into central storage',
			'libraryLocations.switchedToInPlace' => 'Switched to In-Place mode',
			'libraryLocations.switchedToCentralized' => 'Switched to Centralized mode',
			'libraryLocations.migrationFailed' => 'Migration failed',
			'libraryLocations.migrationError' => 'Migration error: {error}',
			'libraryLocations.renameLocation' => 'Rename Location',
			'libraryLocations.nameLabel' => 'Name',
			'libraryLocations.removeLocation' => 'Remove Library Location',
			'libraryLocations.removeLocationConfirm' => 'Are you sure you want to remove "{name}"?',
			'libraryLocations.removeLocationNote' => 'Song units and audio entries discovered from this location will be removed from the library. No files will be deleted from disk.',
			'libraryLocations.removed' => 'Removed "{name}"',
			'libraryLocations.failedToRemove' => 'Failed to remove: {error}',
			'libraryLocations.isNowDefault' => '"{name}" is now the default',
			'libraryLocations.failedToSetDefault' => 'Failed to set default: {error}',
			'libraryLocations.accessible' => 'Accessible',
			'libraryLocations.inaccessible' => 'Inaccessible',
			'libraryLocations.inPlace' => 'In-Place',
			'libraryLocations.centralized' => 'Centralized',
			'libraryLocations.setAsDefault' => 'Set as Default',
			'locationSetup.title' => 'Set Up Library Locations',
			'locationSetup.description' => 'Add folders where your music files are stored. Beadline will automatically scan these locations and monitor for changes.',
			'locationSetup.storagePermissionRequired' => 'Storage permissions required',
			'locationSetup.selectedLocations' => 'Selected Locations',
			'locationSetup.addLocation' => 'Add Library Location',
			'locationSetup.firstLocationNote' => 'The first location will be used as the default for new song units',
			'configMode.title' => 'Welcome to Beadline',
			'configMode.subtitle' => 'Choose how you want to store your library configuration',
			'configMode.centralizedTitle' => 'Centralized Storage',
			'configMode.centralizedDesc' => 'Store all configuration in the app data directory',
			'configMode.centralizedPros' => 'All data in one place\nEasy backup and restore\nStandard app behavior',
			'configMode.centralizedCons' => 'Less portable between devices\nRequires manual export for sharing',
			'configMode.inPlaceTitle' => 'In-Place Storage',
			'configMode.inPlaceDesc' => 'Store Song Unit metadata alongside your music files',
			'configMode.inPlacePros' => 'Portable across devices\nAuto-discovery of Song Units\nKeep metadata with files',
			'configMode.inPlaceCons' => 'Creates beadline-*.json files in music folders\nRequires storage location setup',
			'configMode.changeNote' => 'You can change this setting later in Settings > Storage',
			'onlineProviders.title' => 'Online Source Providers',
			'onlineProviders.noProviders' => 'No providers configured',
			'onlineProviders.noProvidersHint' => 'Add a provider to search for online sources',
			'onlineProviders.addProvider' => 'Add Provider',
			'onlineProviders.editProvider' => 'Edit Provider',
			'onlineProviders.providerIdLabel' => 'Provider ID',
			'onlineProviders.providerIdHint' => 'bilibili, netease, etc.',
			'onlineProviders.displayNameLabel' => 'Display Name',
			'onlineProviders.displayNameHint' => 'Bilibili, NetEase Cloud Music, etc.',
			'onlineProviders.baseUrlLabel' => 'Base URL',
			'onlineProviders.baseUrlHint' => 'http://localhost:3000',
			'onlineProviders.apiKeyOptional' => 'API Key (Optional)',
			'onlineProviders.apiKeyHint' => 'Leave empty if not required',
			'onlineProviders.timeoutLabel' => 'Timeout (seconds)',
			'onlineProviders.timeoutDefault' => '10',
			'onlineProviders.timeoutError' => 'Timeout must be a positive number',
			'display.noSource' => 'No display source',
			'display.loading' => 'Loading: {name}',
			'display.failedToLoad' => 'Failed to load: {name}',
			'lyrics.noLyrics' => 'No lyrics',
			'floatingLyrics.noLyrics' => 'No lyrics',
			'songPicker.selectSongs' => 'Select Songs',
			'songPicker.selectSong' => 'Select Song',
			'songPicker.searchHint' => 'Search songs...',
			'songPicker.noSongsFound' => 'No songs found',
			'songPicker.noSongsInLibrary' => 'No songs in library',
			'songPicker.addSongs' => 'Add songs',
			'videoRemoval.title' => 'Remove Display Source',
			'videoRemoval.message' => 'The display source "{videoName}" has an extracted audio source "{audioName}". Would you like to also remove the audio source?',
			'videoRemoval.cancel' => 'Cancel',
			'videoRemoval.keepAudio' => 'Keep Audio',
			'videoRemoval.removeBoth' => 'Remove Both',
			'debug.audioEntriesTitle' => 'Audio Entries Debug',
			'debug.temporarySongUnitsFound' => 'Temporary Song Units Found: {count}',
			'debug.refresh' => 'Refresh',
			'debug.temporarySongUnits' => 'Temporary Song Units',
			'debug.close' => 'Close',
			'debug.showEntries' => 'Show Entries',
			'dialogs.confirmModeChange' => 'Confirm Mode Change',
			'dialogs.changeMode' => 'Change Mode',
			'dialogs.discoveringAudioFiles' => 'Discovering Audio Files',
			'dialogs.rescanningAudioFiles' => 'Re-scanning Audio Files',
			'dialogs.noLibraryLocationsConfigured' => 'No library locations configured',
			'dialogs.errorLoadingLocations' => 'Error loading locations',
			'dialogs.kDefault' => 'Default',
			'dialogs.addLocationToStoreMusic' => 'Add a location to store your music library',
			'dialogs.noLocationsTitle' => 'No library locations',
			'dialogs.noLocationsMessage' => 'Add a location to store your music library',
			'dialogs.addNestedGroup' => 'Add nested group',
			'dialogs.removeGroup' => 'Remove Group',
			'dialogs.removeGroupQuestion' => 'How would you like to remove "{groupName}"?',
			'dialogs.ungroupKeepSongs' => 'Ungroup (keep songs)',
			_ => null,
		} ?? switch (path) {
			'dialogs.removeAll' => 'Remove all',
			'dialogs.renameGroup' => 'Rename Group',
			'dialogs.createNestedGroup' => 'Create Nested Group',
			'dialogs.createGroup' => 'Create Group',
			'dialogs.selectThumbnail' => 'Select Thumbnail',
			'dialogs.errorAddingCustomThumbnail' => 'Error adding custom thumbnail: {error}',
			'dialogs.noResultsEnterSearch' => 'No results. Enter a search query and press search.',
			'dialogs.editProvider' => 'Edit',
			'dialogs.deleteProvider' => 'Delete',
			'dialogs.providerId' => 'ID: {providerId}',
			'dialogs.providerUrl' => 'URL: {baseUrl}',
			'dialogs.providerApiKey' => 'API Key: •••••••- ',
			'dialogs.deleteSongUnit' => 'Delete Song Unit',
			'dialogs.alsoDeleteConfigFile' => 'Also delete configuration file',
			'dialogs.configFileNote' => 'Removes the beadline-*.json file. Source files are not affected.',
			'dialogs.deleteOriginalAfterMerge' => 'Delete original song units after merge',
			'dialogs.deleteItemsConfirm' => 'Are you sure you want to delete {count} item(s)?',
			'dialogs.deletedItems' => 'Deleted {count} item(s)',
			'dialogs.importComplete' => 'Import Complete',
			'dialogs.imported' => 'Imported: {count}',
			'dialogs.skippedDuplicates' => 'Skipped (duplicates): {count}',
			'dialogs.importMore' => '... and {count} more',
			'dialogs.promotedToSongUnit' => 'Promoted "{name}" to Song Unit',
			'dialogs.exportedTo' => 'Exported to {path}',
			'dialogs.promoted' => 'Promoted "{displayName}" to Song Unit',
			'dialogs.resetFailed' => 'Reset failed: {error}',
			'dialogs.confirmTitle' => 'Confirm Mode Change',
			'dialogs.changeModeButton' => 'Change Mode',
			'dialogs.migratingConfig' => 'Migrating Configuration',
			'dialogs.migratingEntryPoints' => 'Migrating entry point files...',
			'dialogs.scanningForSongUnits' => 'Scanning for Song Units...',
			'dialogs.errorScanning' => 'Error scanning: {error}',
			'dialogs.errorClearingAudio' => 'Error clearing audio entries: {error}',
			'dialogs.errorRescanning' => 'Error re-scanning: {error}',
			'dialogs.failedToRename' => 'Failed to rename: {error}',
			'dialogs.failedToRemove' => 'Failed to remove: {error}',
			'dialogs.failedToSetDefault' => 'Failed to set default: {error}',
			'dialogs.migrationError' => 'Migration error: {error}',
			'dialogs.home.shuffle' => 'Shuffle',
			'dialogs.home.rename' => 'Rename',
			'dialogs.home.addNestedGroup' => 'Add nested group',
			'dialogs.home.remove' => 'Remove',
			'dialogs.home.removeGroup' => 'Remove Group',
			'dialogs.home.removeGroupQuestion' => 'How would you like to remove "{groupName}"?',
			'dialogs.home.ungroupKeepSongs' => 'Ungroup (keep songs)',
			'dialogs.home.removeAll' => 'Remove all',
			'dialogs.home.renameGroup' => 'Rename Group',
			'dialogs.home.createNestedGroup' => 'Create Nested Group',
			'dialogs.home.create' => 'Create',
			'dialogs.home.createGroup' => 'Create Group',
			'dialogs.progressDialogs.discovering' => 'Discovering Audio Files',
			'dialogs.progressDialogs.rescanning' => 'Re-scanning Audio Files',
			'dialogs.libraryLocationsError.noLocationsConfigured' => 'No library locations configured',
			'dialogs.libraryLocationsError.errorLoading' => 'Error loading locations',
			'dialogs.libraryLocationsError.retry' => 'Retry',
			'configModeChange.title' => 'Confirm Mode Change',
			'configModeChange.description' => 'Changing configuration mode will migrate your entry point files. This may take a moment.',
			'configModeChange.inPlaceDescription' => 'This will create beadline-*.json files alongside your music files. Your library will become portable across devices.',
			'configModeChange.centralizedDescription' => 'This will move entry point files to the app data directory. Your library will no longer be portable.',
			'configModeChange.changeMode' => 'Change Mode',
			'app_routes.routeNotFound' => 'Route not found: {name}',
			'loading_indicator.percentage' => '{percentage}%',
			'video_removal_prompt.title' => 'Remove Display Source',
			'video_removal_prompt.message' => 'The display source "{videoName}" has an extracted audio source "{audioName}". Would you like to also remove the audio source?',
			'video_removal_prompt.keepAudio' => 'Keep Audio',
			'video_removal_prompt.removeBoth' => 'Remove Both',
			'library_location_setup_dialog.title' => 'Select Music Library Location',
			'home_page.renameGroup' => 'Rename Group',
			'song_unit_editor.addedToSources' => 'Added {title} to sources',
			'song_unit_editor.aliasHint' => 'title',
			_ => null,
		};
	}
}
