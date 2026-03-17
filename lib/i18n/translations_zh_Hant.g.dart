///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'translations.g.dart';

// Path: <root>
class TranslationsZhHant extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZhHant({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhHant,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-Hant>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsZhHant _root = this; // ignore: unused_field

	@override 
	TranslationsZhHant $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZhHant(meta: meta ?? this.$meta);

	// Translations
	@override late final _TranslationsCommonZhHant common = _TranslationsCommonZhHant._(_root);
	@override late final _TranslationsNavZhHant nav = _TranslationsNavZhHant._(_root);
	@override late final _TranslationsAppZhHant app = _TranslationsAppZhHant._(_root);
	@override late final _TranslationsLibraryZhHant library = _TranslationsLibraryZhHant._(_root);
	@override late final _TranslationsPlayerZhHant player = _TranslationsPlayerZhHant._(_root);
	@override late final _TranslationsQueueZhHant queue = _TranslationsQueueZhHant._(_root);
	@override late final _TranslationsSearchZhHant search = _TranslationsSearchZhHant._(_root);
	@override late final _TranslationsTagsZhHant tags = _TranslationsTagsZhHant._(_root);
	@override late final _TranslationsPlaylistsZhHant playlists = _TranslationsPlaylistsZhHant._(_root);
	@override late final _TranslationsSongEditorZhHant songEditor = _TranslationsSongEditorZhHant._(_root);
	@override late final _TranslationsSettingsZhHant settings = _TranslationsSettingsZhHant._(_root);
	@override late final _TranslationsLibraryLocationsZhHant libraryLocations = _TranslationsLibraryLocationsZhHant._(_root);
	@override late final _TranslationsLocationSetupZhHant locationSetup = _TranslationsLocationSetupZhHant._(_root);
	@override late final _TranslationsConfigModeZhHant configMode = _TranslationsConfigModeZhHant._(_root);
	@override late final _TranslationsOnlineProvidersZhHant onlineProviders = _TranslationsOnlineProvidersZhHant._(_root);
	@override late final _TranslationsDisplayZhHant display = _TranslationsDisplayZhHant._(_root);
	@override late final _TranslationsLyricsZhHant lyrics = _TranslationsLyricsZhHant._(_root);
	@override late final _TranslationsFloatingLyricsZhHant floatingLyrics = _TranslationsFloatingLyricsZhHant._(_root);
	@override late final _TranslationsSongPickerZhHant songPicker = _TranslationsSongPickerZhHant._(_root);
	@override late final _TranslationsVideoRemovalZhHant videoRemoval = _TranslationsVideoRemovalZhHant._(_root);
	@override late final _TranslationsDebugZhHant debug = _TranslationsDebugZhHant._(_root);
	@override late final _TranslationsDialogsZhHant dialogs = _TranslationsDialogsZhHant._(_root);
	@override late final _TranslationsConfigModeChangeZhHant configModeChange = _TranslationsConfigModeChangeZhHant._(_root);
	@override late final _TranslationsAppRoutesZhHant app_routes = _TranslationsAppRoutesZhHant._(_root);
	@override late final _TranslationsLoadingIndicatorZhHant loading_indicator = _TranslationsLoadingIndicatorZhHant._(_root);
	@override late final _TranslationsVideoRemovalPromptZhHant video_removal_prompt = _TranslationsVideoRemovalPromptZhHant._(_root);
	@override late final _TranslationsLibraryLocationSetupDialogZhHant library_location_setup_dialog = _TranslationsLibraryLocationSetupDialogZhHant._(_root);
	@override late final _TranslationsHomePageZhHant home_page = _TranslationsHomePageZhHant._(_root);
	@override late final _TranslationsSongUnitEditorZhHant song_unit_editor = _TranslationsSongUnitEditorZhHant._(_root);
}

// Path: common
class _TranslationsCommonZhHant extends TranslationsCommonEn {
	_TranslationsCommonZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get cancel => '取消';
	@override String get save => '儲存';
	@override String get delete => '刪除';
	@override String get add => '新增';
	@override String get edit => '編輯';
	@override String get rename => '重新命名';
	@override String get create => '建立';
	@override String get close => '關閉';
	@override String get retry => '重試';
	@override String get refresh => '重新整理';
	@override String get search => '搜尋';
	@override String get ok => '確定';
	@override String get yes => '是';
	@override String get no => '否';
	@override String get back => '返回';
	@override String get skip => '暫時略過';
	@override String get apply => '套用';
	@override String get remove => '移除';
	@override String get duplicate => '複製';
	@override String get export => '匯出';
	@override String get import => '匯入';
	@override String get migrate => '遷移';
	@override String get reset => '重設';
	@override String get grant => '授權';
	@override String get enabled => '已啟用';
	@override String get disabled => '已停用';
	@override String get on => '開';
	@override String get off => '關';
	@override String get error => '錯誤';
	@override String get loading => '載入中...';
	@override String get songs => '首歌曲';
	@override String get selected => '已選取';
	@override String get items => '項';
	@override String get ms => '毫秒';
	@override String get dismiss => '關閉';
	@override String get extract => '擷取';
	@override String get extractingThumbnails => '正在擷取縮圖...';
	@override String get noThumbnailsAvailable => '沒有可用縮圖';
	@override String get displayVideoImage => '顯示（影片/圖片）';
	@override String get id => 'ID';
	@override String get url => 'URL';
	@override String get apiKey => 'API 金鑰';
	@override String get openParen => '(';
	@override String get closeParen => ')';
	@override String get routeNotFound => '未找到路由：{name}';
	@override String get noResultsEnterSearch => '未找到結果。請輸入搜尋詞並按搜尋。';
	@override String get artistLabel => '藝人：';
	@override String get albumLabel => '專輯：';
	@override String get platformLabel => '平台：';
	@override String get percentage => '{percentage}%';
	@override String get testConnection => '測試連接';
	@override String get disabledInKtvMode => 'KTV 模式下禁用';
	@override String get failedToRename => '重命名失敗：{error}';
	@override String get continueText => '繼續';
	@override String get artist => '藝人';
	@override String get album => '專輯';
	@override String get platform => '平台';
	@override String get addImage => '新增圖片';
	@override String get shuffle => '隨機排序';
	@override String get alreadyInPlaylist => '已在播放清單中';
	@override String get createAndAdd => '建立並加入';
}

// Path: nav
class _TranslationsNavZhHant extends TranslationsNavEn {
	_TranslationsNavZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get home => '主頁';
	@override String get library => '音樂庫';
	@override String get playlists => '播放清單';
	@override String get tags => '標籤';
	@override String get settings => '設定';
}

// Path: app
class _TranslationsAppZhHant extends TranslationsAppEn {
	_TranslationsAppZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get name => '珠鏈';
}

// Path: library
class _TranslationsLibraryZhHant extends TranslationsLibraryEn {
	_TranslationsLibraryZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '音樂庫';
	@override String get loading => '正在載入音樂庫...';
	@override String get searchHint => '搜尋音樂庫...';
	@override String get noLocations => '未設定音樂庫位置';
	@override String get allLocations => '所有位置';
	@override String get filterByLocation => '依音樂庫位置篩選';
	@override String get listView => '清單檢視';
	@override String get gridView => '格狀檢視';
	@override String get noItems => '音樂庫為空';
	@override String get noResults => '找不到歌曲';
	@override String get tryDifferentSearch => '請嘗試其他搜尋詞';
	@override String get audioOnly => '僅音訊';
	@override String get noSong => '無歌曲';
	@override late final _TranslationsLibraryActionsZhHant actions = _TranslationsLibraryActionsZhHant._(_root);
	@override String get processing => '處理中...';
	@override String get exportedTo => '已匯出到 {path}';
	@override String get importComplete => '匯入完成';
	@override String get imported => '已匯入：{count}';
	@override String get skippedDuplicates => '已略過（重複）：{count}';
	@override String get importMore => '... 還有 {count} 項';
	@override String get promotedToSongUnit => '已將 "{name}" 提升為歌曲單元';
	@override String get deleteItemsConfirm => '確定要刪除 {count} 項嗎？';
	@override String get deletedItems => '已刪除 {count} 項';
	@override String get addedItemsToQueue => '已將 {count} 項加入佇列';
	@override String get noTemporaryEntriesSelected => '未選取臨時項目';
	@override String get addSongsToPlaylistTitle => '將 {count} 首歌曲加入播放清單';
	@override String get noPlaylistsCreateFirst => '尚無播放清單。請先建立一個。';
	@override String get sectionMetadata => '元數據';
	@override String get sectionSources => '源';
	@override String get sectionTags => '標籤';
	@override String get errorLoadingLibrary => '載入音樂庫出錯';
	@override String get deleteSongUnit => '刪除歌曲單元';
	@override String get alsoDeleteConfigFile => '同時刪除設定檔';
	@override String get configFileNote => '刪除 beadline-*.json 檔案。原始檔案不受影響。';
	@override String get deleteOriginalAfterMerge => '合併後刪除原始歌曲單元';
	@override String get selectedCount => '{count} 已選取';
	@override String get alreadyInPlaylist => '已在播放清單中';
	@override String get createAndAdd => '建立並加入';
	@override String get promoted => '已將 "{displayName}" 提升為歌曲單元';
}

// Path: player
class _TranslationsPlayerZhHant extends TranslationsPlayerEn {
	_TranslationsPlayerZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get noSongPlaying => '未在播放';
	@override String get source => '源';
	@override String get display => '畫面';
	@override String get audio => '音訊';
	@override String get playback => '播放';
	@override String get lyrics => '歌詞';
	@override String get fullscreen => '全螢幕';
	@override String get exitFullscreen => '退出全螢幕 (ESC)';
	@override String get selectSources => '選擇源';
	@override String get play => '播放';
	@override String get pause => '暫停';
	@override String get next => '下一首';
	@override late final _TranslationsPlayerDisplayModeZhHant displayMode = _TranslationsPlayerDisplayModeZhHant._(_root);
	@override late final _TranslationsPlayerAudioModeZhHant audioMode = _TranslationsPlayerAudioModeZhHant._(_root);
	@override late final _TranslationsPlayerPlaybackModeZhHant playbackMode = _TranslationsPlayerPlaybackModeZhHant._(_root);
	@override late final _TranslationsPlayerLyricsModeZhHant lyricsMode = _TranslationsPlayerLyricsModeZhHant._(_root);
}

// Path: queue
class _TranslationsQueueZhHant extends TranslationsQueueEn {
	_TranslationsQueueZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '佇列';
	@override String get manage => '管理佇列';
	@override String get removeDuplicates => '移除重複';
	@override String get shuffle => '隨機排序';
	@override String get removeAfterPlayOn => '播完移除：開';
	@override String get removeAfterPlayOff => '播完移除：關';
	@override String get clearQueue => '清空佇列';
	@override String get removedDuplicates => '已移除 {count} 個重複項目';
	@override String get noDuplicates => '未發現重複項目';
	@override String get manageQueues => '管理佇列';
	@override String get queueContent => '佇列內容';
	@override String get backToQueues => '返回佇列清單';
	@override String get createQueue => '新建佇列';
	@override String get queueName => '佇列名稱';
	@override String get enterQueueName => '輸入佇列名稱';
	@override String get renameQueue => '重新命名佇列';
	@override String get enterNewName => '輸入新名稱';
	@override String get deleteQueue => '刪除佇列';
	@override String get deleteQueueConfirm => '確定要刪除';
	@override String get deleteQueueWillRemove => '這將從此佇列中移除';
	@override String get deleteQueueFromQueue => '首歌曲';
	@override String get switchToQueue => '切換到此佇列';
	@override String get empty => '佇列為空';
	@override String get songs => '{count} 首歌曲';
	@override String get actions => '佇列操作';
	@override String get collapse => '折疊';
	@override String get expand => '展開';
	@override String get groupActions => '分組操作';
}

// Path: search
class _TranslationsSearchZhHant extends TranslationsSearchEn {
	_TranslationsSearchZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '搜尋';
	@override String get songUnits => '歌曲單元';
	@override String get sources => '源';
	@override String get hint => '搜尋...';
	@override String get textMode => '文字模式';
	@override String get queryBuilder => '條件建構器';
	@override String get tag => '標籤';
	@override String get tagExample => '例：artist:value';
	@override String get range => '範圍';
	@override String get rangeExample => '例：time:[2020-2024]';
	@override String get searching => '搜尋中...';
	@override String get searchError => '搜尋發生錯誤';
	@override String get noSongUnitsFound => '找不到歌曲單元';
	@override String get loadMore => '載入更多';
	@override String get play => '播放';
	@override String get addToQueue => '加入佇列';
	@override String get all => '全部';
	@override String get local => '本機';
	@override String get online => '線上';
	@override String get searchingSources => '正在搜尋源...';
	@override String get noOnlineSources => '找不到線上源';
	@override String get noLocalSources => '找不到本機源';
	@override String get noSources => '找不到源';
	@override String get addToSongUnit => '加入歌曲單元';
	@override String get or => '或';
	@override String get not => '非';
	@override String get addedToQueue => '已將"{title}"加入佇列';
	@override String get addSource => '加入源：{title}';
}

// Path: tags
class _TranslationsTagsZhHant extends TranslationsTagsEn {
	_TranslationsTagsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '標籤';
	@override String get noTags => '尚無標籤';
	@override String get noTagsHint => '建立標籤來整理你的音樂';
	@override String get loadError => '載入標籤失敗';
	@override String get createTag => '建立標籤';
	@override String get createChildTag => '建立子標籤';
	@override String get tagName => '標籤名稱';
	@override String get addAlias => '新增別名';
	@override String get addAliasFor => '為以下標籤新增別名';
	@override String get aliasName => '別名';
	@override String get enterAlias => '輸入別名';
	@override String get addChildTag => '新增子標籤';
	@override String get deleteTag => '刪除標籤';
	@override String get deleteTagTitle => '刪除標籤？';
	@override String get deleteTagConfirm => '此操作無法復原';
	@override String get deleteTagHasChildren => '此標籤有子標籤，它們將成為根標籤。';
	@override String get deleteTagAliases => '別名也將被刪除。';
	@override String get deletedTag => '已刪除標籤';
	@override String get removeFromSong => '從此歌曲移除標籤';
	@override String get removeAll => '全部移除';
	@override String get viewSongUnits => '檢視歌曲單元';
	@override String get item => '項';
	@override String get items => '項';
	@override String get songUnit => '個歌曲單元';
	@override String get songUnits => '個歌曲單元';
	@override String get lockedCollection => '已鎖定的集合';
	@override String get collection => '集合';
	@override String get locked => '已鎖定';
}

// Path: playlists
class _TranslationsPlaylistsZhHant extends TranslationsPlaylistsEn {
	_TranslationsPlaylistsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '播放清單';
	@override String get noPlaylists => '尚無播放清單';
	@override String get noPlaylistsHint => '右鍵或長按以建立播放清單';
	@override String get selectPlaylist => '選擇播放清單以檢視內容';
	@override String get createPlaylist => '建立播放清單';
	@override String get addSongs => '新增歌曲';
	@override String get createGroup => '建立群組';
	@override String get addCollectionRef => '新增合集參照';
	@override String get renamePlaylist => '重新命名播放清單';
	@override String get deletePlaylist => '刪除播放清單';
	@override String get deletePlaylistConfirm => '確定要刪除';
	@override String get deletePlaylistNote => '歌曲不會被刪除，僅刪除此播放清單';
	@override String get createGroupTitle => '建立群組';
	@override String get createGroupHint => '建立一個群組';
	@override String get groupName => '群組名稱';
	@override String get enterGroupName => '輸入群組名稱';
	@override String get addCollectionRefTitle => '新增合集參照';
	@override String get noOtherCollections => '沒有其他可用合集';
	@override String get addReferenceTo => '新增參照到';
	@override String get lock => '鎖定';
	@override String get unlock => '解鎖';
	@override String get viewContent => '檢視內容';
	@override String get toggleSelectionMode => '切換選擇模式';
	@override String get moveToGroup => '移動到群組';
	@override String get noGroupsAvailable => '沒有可用的群組。請先建立一個群組。';
	@override String get song => '首歌曲';
	@override String get songs => '首歌曲';
	@override String get locked => '已鎖定';
	@override String get clearSelection => '清除選擇';
	@override String get selected => '已選擇';
	@override String get removeFromGroup => '從群組中移除';
	@override String get alreadyInPlaylist => '已在播放清單中';
	@override String get addedToPlaylist => '已加入 "{name}"';
	@override String get createdPlaylistAndAdded => '已建立播放清單 "{name}" 並加入歌曲';
	@override String get createAndAdd => '建立並加入';
	@override String get songCount => '{count} 首歌曲';
	@override String get noSongsInGroup => '此群組中沒有歌曲';
	@override String get dropHere => '拖放到此處';
	@override String get groupCreated => '已建立群組 "{name}"';
	@override String get failedToCreateGroup => '建立群組失敗：{error}';
}

// Path: songEditor
class _TranslationsSongEditorZhHant extends TranslationsSongEditorEn {
	_TranslationsSongEditorZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get titleEdit => '編輯歌曲單元';
	@override String get titleNew => '新建歌曲單元';
	@override String get reloadMetadata => '從源重新載入中繼資料';
	@override String get writeMetadata => '將中繼資料寫入源';
	@override String get sources => '源';
	@override String get display => '畫面';
	@override String get audio => '音訊';
	@override String get accompaniment => '伴奏';
	@override String get lyricsLabel => '歌詞';
	@override String get noDisplaySources => '無畫面源';
	@override String get noAudioSources => '無音訊源';
	@override String get noAccompanimentSources => '無伴奏源';
	@override String get noLyricsSources => '無歌詞源';
	@override String get addDisplaySource => '新增畫面源';
	@override String get addAudioSource => '新增音訊源';
	@override String get addAccompanimentSource => '新增伴奏源';
	@override String get addLyricsSource => '新增歌詞源';
	@override String get editDisplayName => '編輯顯示名稱';
	@override String get setOffset => '設定偏移';
	@override String get setOffsetTitle => '設定偏移量';
	@override String get offsetHint => '與音訊對齊的毫秒偏移量';
	@override String get offsetNote => '正值 = 延遲，負值 = 提前';
	@override String get offsetLabel => '偏移量（毫秒）';
	@override String get editDisplayNameTitle => '編輯顯示名稱';
	@override String get originalName => '原始';
	@override String get displayNameLabel => '顯示名稱';
	@override String get displayNameHint => '留空則使用原始名稱';
	@override String get addSource => '新增源';
	@override String get localFile => '本機檔案';
	@override String get enterUrl => '輸入 URL';
	@override String get urlLabel => 'URL';
	@override String get urlHint => 'https://...';
	@override String get selectSong => '選擇歌曲';
	@override String get selectSongs => '選擇歌曲';
	@override String get addSongs => '新增歌曲';
	@override String get artist => '藝人';
	@override String get thumbnail => '縮圖';
	@override String get addImage => '新增圖片';
	@override String get selectThumbnails => '選擇 ({count})';
	@override String get selectThumbnailTitle => '選擇縮圖';
	@override String get errorAddingCustomThumbnail => '新增自訂縮圖時發生錯誤：{error}';
	@override String get audioExtracted => '從 {name} 擷取的音訊軌道';
	@override String get noAudioFound => '在 {name} 中找不到音訊軌道';
	@override String get autoDiscovered => '自動發現：{types}';
	@override String get chooseMetadataValues => '為每個元數據欄位選擇值：';
}

// Path: settings
class _TranslationsSettingsZhHant extends TranslationsSettingsEn {
	_TranslationsSettingsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '設定';
	@override String get user => '使用者';
	@override String get username => '使用者名稱';
	@override String get appearance => '外觀';
	@override String get theme => '主題';
	@override String get themeSystem => '跟隨系統';
	@override String get themeLight => '淺色';
	@override String get themeDark => '深色';
	@override String get accentColor => '強調色';
	@override String get accentColorHint => '自訂應用程式顏色';
	@override String get language => '語言';
	@override String get playback => '播放';
	@override String get lyricsMode => '歌詞模式';
	@override String get ktvMode => 'KTV 模式';
	@override String get ktvModeHint => '強制螢幕歌詞，停用浮動視窗';
	@override String get hideDisplayPanel => '隱藏畫面面板';
	@override String get hideDisplayPanelHint => '僅顯示歌詞和控制列（純音樂模式）';
	@override String get thumbnailBgLibrary => '音樂庫使用縮圖背景';
	@override String get thumbnailBgLibraryHint => '在音樂庫檢視中將縮圖用作背景';
	@override String get thumbnailBgQueue => '佇列使用縮圖背景';
	@override String get thumbnailBgQueueHint => '在佇列中將縮圖用作背景';
	@override String get storage => '儲存';
	@override String get configMode => '設定模式';
	@override String get configModeCentralized => '集中儲存';
	@override String get configModeInPlace => '就地儲存';
	@override String get libraryLocations => '音樂庫位置';
	@override String get libraryLocationsHint => '管理音樂檔案的儲存位置';
	@override String get metadataWriteback => '中繼資料回寫';
	@override String get metadataWritebackHint => '將標籤變更同步到原始檔案';
	@override String get autoDiscoverAudio => '自動探索音訊檔案';
	@override String get autoDiscoverAudioHint => '自動從音樂庫位置新增音訊檔案';
	@override String get debug => '除錯';
	@override String get audioEntriesDebug => '音訊項目除錯';
	@override String get audioEntriesDebugHint => '檢視已探索的音訊項目';
	@override String get rescanAudio => '重新掃描音訊檔案';
	@override String get rescanAudioHint => '清除並重新探索所有音訊檔案（含更新的中繼資料）';
	@override String get about => '關於';
	@override String get version => '版本';
	@override String get license => '授權條款';
	@override String get licenseValue => 'GNU Affero 通用公共授權條款 v3.0 (AGPL-3.0)';
	@override String get resetFactory => '恢復原廠設定';
	@override String get resetFactoryHint => '將所有設定重設為預設值';
	@override String get system => '系統';
	@override String get resetFactoryTitle => '恢復原廠設定？';
	@override String get resetFactoryBody => '這將把應用程式完全重設為初始狀態';
	@override String get resetFactoryItems => '所有設定和偏好\n歌曲單元庫和標籤\n播放清單、佇列和群組\n播放狀態';
	@override String get resetFactoryNote => '磁碟上的實際音樂檔案不會被刪除';
	@override String get resetFactoryRestart => '重設後應用程式將重新啟動';
	@override String get resetEverything => '全部重設';
	@override String get rescanTitle => '重新掃描音訊檔案';
	@override String get rescanBody => '這將清除所有已探索的音訊項目並重新掃描音樂庫位置';
	@override String get rescanNote => '大型音樂庫可能需要幾分鐘。是否繼續？';
	@override String get rescan => '重新掃描';
	@override String get migratingConfig => '正在遷移設定';
	@override String get migratingEntryPoints => '正在遷移進入點檔案...';
	@override String get scanningForSongUnits => '正在掃描歌曲單元...';
	@override String get storagePermissionTitle => '需要儲存權限';
	@override String get storagePermissionBody => '珠鏈需要存取你的音樂檔案以探索和播放音訊';
	@override String get storagePermissionNote => '請在下一個對話框中授予儲存權限，或前往系統設定手動開啟';
	@override String get openSettings => '開啟設定';
	@override String get foundAudioFiles => '找到 {count} 個音訊檔案';
	@override String get errorScanning => '掃描發生錯誤：{error}';
	@override String get audioEntriesCleared => '音訊項目已清除';
	@override String get errorClearingAudio => '清除音訊項目發生錯誤：{error}';
	@override String get audioRescanSuccess => '音訊檔案重新掃描成功';
	@override String get errorRescanning => '重新掃描發生錯誤：{error}';
	@override String get testingConnection => '正在測試連線...';
	@override String get connectionSuccess => '連線成功！';
	@override String get connectionFailed => '連線失敗';
	@override String get onlineProviders => '線上源提供者';
}

// Path: libraryLocations
class _TranslationsLibraryLocationsZhHant extends TranslationsLibraryLocationsEn {
	_TranslationsLibraryLocationsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '音樂庫位置';
	@override String get selectLocation => '選擇音樂庫位置';
	@override String get nameLocation => '為此位置命名';
	@override String get enterLocationName => '輸入此位置的名稱';
	@override String get locationAdded => '音樂庫位置已新增';
	@override String get discoveredImported => '已探索並匯入 {count} 個歌曲單元';
	@override String get switchToInPlace => '切換到就地儲存';
	@override String get switchToCentralized => '切換到集中儲存';
	@override String get migrateToInPlaceBody => '這將把所有進入點檔案從集中儲存移動到 {path}，與音訊源放在一起';
	@override String get migrateToCentralizedBody => '這將把所有進入點檔案從 {path} 移動到集中儲存';
	@override String get switchedToInPlace => '已切換到就地儲存模式';
	@override String get switchedToCentralized => '已切換到集中儲存模式';
	@override String get migrationFailed => '遷移失敗';
	@override String get migrationError => '遷移發生錯誤：{error}';
	@override String get renameLocation => '重新命名位置';
	@override String get nameLabel => '名稱';
	@override String get removeLocation => '移除音樂庫位置';
	@override String get removeLocationConfirm => '確定要移除 "{name}"？';
	@override String get removeLocationNote => '從此位置探索的歌曲單元和音訊項目將從音樂庫中移除。磁碟上的檔案不會被刪除。';
	@override String get removed => '已移除 "{name}"';
	@override String get failedToRemove => '移除失敗：{error}';
	@override String get isNowDefault => '現在是預設位置';
	@override String get failedToSetDefault => '設定預設位置失敗：{error}';
	@override String get accessible => '可存取';
	@override String get inaccessible => '無法存取';
	@override String get inPlace => '就地儲存';
	@override String get centralized => '集中儲存';
	@override String get setAsDefault => '設為預設';
}

// Path: locationSetup
class _TranslationsLocationSetupZhHant extends TranslationsLocationSetupEn {
	_TranslationsLocationSetupZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '設定音樂庫位置';
	@override String get description => '新增存放音樂檔案的資料夾。珠鏈將自動掃描這些位置並監控變更。';
	@override String get storagePermissionRequired => '需要儲存權限';
	@override String get selectedLocations => '已選位置';
	@override String get addLocation => '新增音樂庫位置';
	@override String get firstLocationNote => '第一個位置將作為新歌曲單元的預設位置';
}

// Path: configMode
class _TranslationsConfigModeZhHant extends TranslationsConfigModeEn {
	_TranslationsConfigModeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '歡迎使用珠鏈';
	@override String get subtitle => '選擇音樂庫設定的儲存方式';
	@override String get centralizedTitle => '集中儲存';
	@override String get centralizedDesc => '將所有設定儲存在應用程式資料目錄中';
	@override String get centralizedPros => '資料集中管理\n易於備份和還原\n標準應用程式行為';
	@override String get centralizedCons => '跨裝置可攜性較差\n共享需手動匯出';
	@override String get inPlaceTitle => '就地儲存';
	@override String get inPlaceDesc => '將歌曲單元中繼資料與音樂檔案存放在一起';
	@override String get inPlacePros => '跨裝置可攜\n自動探索歌曲單元\n中繼資料與檔案同在';
	@override String get inPlaceCons => '會在音樂資料夾中建立 beadline-*.json 檔案\n需要設定儲存位置';
	@override String get changeNote => '你可以稍後在 設定 > 儲存 中變更此設定';
}

// Path: onlineProviders
class _TranslationsOnlineProvidersZhHant extends TranslationsOnlineProvidersEn {
	_TranslationsOnlineProvidersZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '線上源提供者';
	@override String get noProviders => '未設定提供者';
	@override String get noProvidersHint => '新增提供者以搜尋線上源';
	@override String get addProvider => '新增提供者';
	@override String get editProvider => '編輯提供者';
	@override String get providerIdLabel => '提供者 ID';
	@override String get providerIdHint => 'bilibili、netease 等';
	@override String get displayNameLabel => '顯示名稱';
	@override String get displayNameHint => '嗶哩嗶哩、網易雲音樂等';
	@override String get baseUrlLabel => '基礎 URL';
	@override String get baseUrlHint => 'http://localhost:3000';
	@override String get apiKeyOptional => 'API 金鑰（選填）';
	@override String get apiKeyHint => '不需要則留空';
	@override String get timeoutLabel => '逾時（秒）';
	@override String get timeoutDefault => '10';
	@override String get timeoutError => '逾時必須為正數';
}

// Path: display
class _TranslationsDisplayZhHant extends TranslationsDisplayEn {
	_TranslationsDisplayZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get noSource => '無畫面源';
	@override String get loading => '載入中：{name}';
	@override String get failedToLoad => '載入失敗：{name}';
}

// Path: lyrics
class _TranslationsLyricsZhHant extends TranslationsLyricsEn {
	_TranslationsLyricsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get noLyrics => '尚無歌詞';
}

// Path: floatingLyrics
class _TranslationsFloatingLyricsZhHant extends TranslationsFloatingLyricsEn {
	_TranslationsFloatingLyricsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get noLyrics => '尚無歌詞';
}

// Path: songPicker
class _TranslationsSongPickerZhHant extends TranslationsSongPickerEn {
	_TranslationsSongPickerZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get selectSongs => '選擇歌曲';
	@override String get selectSong => '選擇歌曲';
	@override String get searchHint => '搜尋歌曲...';
	@override String get noSongsFound => '找不到歌曲';
	@override String get noSongsInLibrary => '音樂庫中沒有歌曲';
	@override String get addSongs => '新增歌曲';
}

// Path: videoRemoval
class _TranslationsVideoRemovalZhHant extends TranslationsVideoRemovalEn {
	_TranslationsVideoRemovalZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '移除畫面源';
	@override String get message => '畫面源"{videoName}"包含已擷取的音訊源"{audioName}"。是否也要刪除音訊源？';
	@override String get cancel => '取消';
	@override String get keepAudio => '保留音訊';
	@override String get removeBoth => '全部刪除';
}

// Path: debug
class _TranslationsDebugZhHant extends TranslationsDebugEn {
	_TranslationsDebugZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get audioEntriesTitle => '音訊條目除錯';
	@override String get temporarySongUnitsFound => '找到臨時歌曲單元：{count}';
	@override String get refresh => '重新整理';
	@override String get temporarySongUnits => '臨時歌曲單元';
	@override String get close => '關閉';
	@override String get showEntries => '顯示條目';
}

// Path: dialogs
class _TranslationsDialogsZhHant extends TranslationsDialogsEn {
	_TranslationsDialogsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get confirmModeChange => '確認模式更改';
	@override String get changeMode => '更改模式';
	@override String get discoveringAudioFiles => '正在探索音訊檔案';
	@override String get rescanningAudioFiles => '正在重新掃描音訊檔案';
	@override String get noLibraryLocationsConfigured => '未設定音樂庫位置';
	@override String get errorLoadingLocations => '載入位置出錯';
	@override String get kDefault => '預設';
	@override String get addLocationToStoreMusic => '新增位置以儲存音樂庫';
	@override String get noLocationsTitle => '未設定音樂庫位置';
	@override String get noLocationsMessage => '新增位置以儲存音樂庫';
	@override String get addNestedGroup => '新增巢狀群組';
	@override String get removeGroup => '移除群組';
	@override String get removeGroupQuestion => '如何移除 "{groupName}"？';
	@override String get ungroupKeepSongs => '取消群組（保留歌曲）';
	@override String get removeAll => '全部移除';
	@override String get renameGroup => '重新命名群組';
	@override String get createNestedGroup => '建立巢狀群組';
	@override String get createGroup => '建立群組';
	@override String get selectThumbnail => '選擇縮圖';
	@override String get errorAddingCustomThumbnail => '新增自訂縮圖時發生錯誤：{error}';
	@override String get noResultsEnterSearch => '未找到結果。請輸入搜尋詞並按搜尋。';
	@override String get editProvider => '編輯';
	@override String get deleteProvider => '刪除';
	@override String get providerId => 'ID: {providerId}';
	@override String get providerUrl => 'URL: {baseUrl}';
	@override String get providerApiKey => 'API 金鑰：•••••••- ';
	@override String get deleteSongUnit => '刪除歌曲單元';
	@override String get alsoDeleteConfigFile => '同時刪除設定檔';
	@override String get configFileNote => '刪除 beadline-*.json 檔案。原始檔案不受影響。';
	@override String get deleteOriginalAfterMerge => '合併後刪除原始歌曲單元';
	@override String get deleteItemsConfirm => '確定要刪除 {count} 項嗎？';
	@override String get deletedItems => '已刪除 {count} 項';
	@override String get importComplete => '匯入完成';
	@override String get imported => '已匯入：{count}';
	@override String get skippedDuplicates => '已略過（重複）：{count}';
	@override String get importMore => '... 還有 {count} 項';
	@override String get promotedToSongUnit => '已將 "{name}" 提升為歌曲單元';
	@override String get exportedTo => '已匯出到 {path}';
	@override String get promoted => '已將 "{displayName}" 提升為歌曲單元';
	@override String get resetFailed => '重設失敗：{error}';
	@override String get confirmTitle => '確認模式更改';
	@override String get changeModeButton => '更改模式';
	@override String get migratingConfig => '正在遷移設定';
	@override String get migratingEntryPoints => '正在遷移進入點檔案...';
	@override String get scanningForSongUnits => '正在掃描歌曲單元...';
	@override String get errorScanning => '掃描發生錯誤：{error}';
	@override String get errorClearingAudio => '清除音訊項目發生錯誤：{error}';
	@override String get errorRescanning => '重新掃描發生錯誤：{error}';
	@override String get failedToRename => '重命名失敗：{error}';
	@override String get failedToRemove => '移除失敗：{error}';
	@override String get failedToSetDefault => '設定預設失敗：{error}';
	@override String get migrationError => '遷移發生錯誤：{error}';
	@override late final _TranslationsDialogsHomeZhHant home = _TranslationsDialogsHomeZhHant._(_root);
	@override late final _TranslationsDialogsProgressDialogsZhHant progressDialogs = _TranslationsDialogsProgressDialogsZhHant._(_root);
	@override late final _TranslationsDialogsLibraryLocationsErrorZhHant libraryLocationsError = _TranslationsDialogsLibraryLocationsErrorZhHant._(_root);
}

// Path: configModeChange
class _TranslationsConfigModeChangeZhHant extends TranslationsConfigModeChangeEn {
	_TranslationsConfigModeChangeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '確認模式更改';
	@override String get description => '更改設定模式將遷移進入點檔案。這可能需要一些時間。';
	@override String get inPlaceDescription => '這將在音樂檔案旁邊建立 beadline-*.json 檔案。你的音樂庫將可以在不同裝置間攜帶。';
	@override String get centralizedDescription => '這將把進入點檔案移動到應用程式資料目錄。你的音樂庫將不再可攜帶。';
	@override String get changeMode => '更改模式';
}

// Path: app_routes
class _TranslationsAppRoutesZhHant extends TranslationsAppRoutesEn {
	_TranslationsAppRoutesZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get routeNotFound => '未找到路由：{name}';
}

// Path: loading_indicator
class _TranslationsLoadingIndicatorZhHant extends TranslationsLoadingIndicatorEn {
	_TranslationsLoadingIndicatorZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get percentage => '{percentage}%';
}

// Path: video_removal_prompt
class _TranslationsVideoRemovalPromptZhHant extends TranslationsVideoRemovalPromptEn {
	_TranslationsVideoRemovalPromptZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '移除畫面源';
	@override String get message => '畫面源"{videoName}"包含已擷取的音訊源"{audioName}"。是否也要刪除音訊源？';
	@override String get keepAudio => '保留音訊';
	@override String get removeBoth => '全部刪除';
}

// Path: library_location_setup_dialog
class _TranslationsLibraryLocationSetupDialogZhHant extends TranslationsLibraryLocationSetupDialogEn {
	_TranslationsLibraryLocationSetupDialogZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get title => '選擇音樂庫位置';
}

// Path: home_page
class _TranslationsHomePageZhHant extends TranslationsHomePageEn {
	_TranslationsHomePageZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get renameGroup => '重新命名群組';
}

// Path: song_unit_editor
class _TranslationsSongUnitEditorZhHant extends TranslationsSongUnitEditorEn {
	_TranslationsSongUnitEditorZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get addedToSources => '已將 {title} 加入到源';
	@override String get aliasHint => 'title';
}

// Path: library.actions
class _TranslationsLibraryActionsZhHant extends TranslationsLibraryActionsEn {
	_TranslationsLibraryActionsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get viewSongUnits => '檢視歌曲單元';
	@override String get convertToSongUnit => '轉換為歌曲單元';
	@override String get addToPlaylist => '加入播放清單';
	@override String get addToQueue => '加入佇列';
	@override String get promoteToSongUnits => '升級為完整歌曲單元';
	@override String get mergeSelected => '合併所選';
	@override String get exportSelected => '匯出所選';
	@override String get deleteSelected => '刪除所選';
	@override String get selectAll => '全選';
	@override String get addTagsToSelected => '新增標籤';
}

// Path: player.displayMode
class _TranslationsPlayerDisplayModeZhHant extends TranslationsPlayerDisplayModeEn {
	_TranslationsPlayerDisplayModeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get label => '畫面模式';
	@override String get enabled => '啟用';
	@override String get imageOnly => '僅圖片';
	@override String get disabled => '停用';
	@override String get hidden => '隱藏';
}

// Path: player.audioMode
class _TranslationsPlayerAudioModeZhHant extends TranslationsPlayerAudioModeEn {
	_TranslationsPlayerAudioModeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get label => '音訊模式';
	@override String get original => '原聲';
	@override String get accompaniment => '伴奏';
}

// Path: player.playbackMode
class _TranslationsPlayerPlaybackModeZhHant extends TranslationsPlayerPlaybackModeEn {
	_TranslationsPlayerPlaybackModeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get label => '播放模式';
	@override String get sequential => '循序播放';
	@override String get repeatOne => '單曲循環';
	@override String get repeatAll => '清單循環';
	@override String get random => '隨機播放';
}

// Path: player.lyricsMode
class _TranslationsPlayerLyricsModeZhHant extends TranslationsPlayerLyricsModeEn {
	_TranslationsPlayerLyricsModeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get label => '歌詞模式';
	@override String get off => '關閉';
	@override String get screen => '螢幕顯示';
	@override String get floating => '浮動視窗';
	@override String get rolling => '捲動顯示';
}

// Path: dialogs.home
class _TranslationsDialogsHomeZhHant extends TranslationsDialogsHomeEn {
	_TranslationsDialogsHomeZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get shuffle => '隨機排序';
	@override String get rename => '重新命名';
	@override String get addNestedGroup => '新增巢狀群組';
	@override String get remove => '移除';
	@override String get removeGroup => '移除群組';
	@override String get removeGroupQuestion => '如何移除 "{groupName}"？';
	@override String get ungroupKeepSongs => '取消群組（保留歌曲）';
	@override String get removeAll => '全部移除';
	@override String get renameGroup => '重新命名群組';
	@override String get createNestedGroup => '建立巢狀群組';
	@override String get create => '建立';
	@override String get createGroup => '建立群組';
}

// Path: dialogs.progressDialogs
class _TranslationsDialogsProgressDialogsZhHant extends TranslationsDialogsProgressDialogsEn {
	_TranslationsDialogsProgressDialogsZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get discovering => '正在探索音訊檔案';
	@override String get rescanning => '正在重新掃描音訊檔案';
}

// Path: dialogs.libraryLocationsError
class _TranslationsDialogsLibraryLocationsErrorZhHant extends TranslationsDialogsLibraryLocationsErrorEn {
	_TranslationsDialogsLibraryLocationsErrorZhHant._(TranslationsZhHant root) : this._root = root, super.internal(root);

	final TranslationsZhHant _root; // ignore: unused_field

	// Translations
	@override String get noLocationsConfigured => '未設定音樂庫位置';
	@override String get errorLoading => '載入位置出錯';
	@override String get retry => '重試';
}

/// The flat map containing all translations for locale <zh-Hant>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZhHant {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.cancel' => '取消',
			'common.save' => '儲存',
			'common.delete' => '刪除',
			'common.add' => '新增',
			'common.edit' => '編輯',
			'common.rename' => '重新命名',
			'common.create' => '建立',
			'common.close' => '關閉',
			'common.retry' => '重試',
			'common.refresh' => '重新整理',
			'common.search' => '搜尋',
			'common.ok' => '確定',
			'common.yes' => '是',
			'common.no' => '否',
			'common.back' => '返回',
			'common.skip' => '暫時略過',
			'common.apply' => '套用',
			'common.remove' => '移除',
			'common.duplicate' => '複製',
			'common.export' => '匯出',
			'common.import' => '匯入',
			'common.migrate' => '遷移',
			'common.reset' => '重設',
			'common.grant' => '授權',
			'common.enabled' => '已啟用',
			'common.disabled' => '已停用',
			'common.on' => '開',
			'common.off' => '關',
			'common.error' => '錯誤',
			'common.loading' => '載入中...',
			'common.songs' => '首歌曲',
			'common.selected' => '已選取',
			'common.items' => '項',
			'common.ms' => '毫秒',
			'common.dismiss' => '關閉',
			'common.extract' => '擷取',
			'common.extractingThumbnails' => '正在擷取縮圖...',
			'common.noThumbnailsAvailable' => '沒有可用縮圖',
			'common.displayVideoImage' => '顯示（影片/圖片）',
			'common.id' => 'ID',
			'common.url' => 'URL',
			'common.apiKey' => 'API 金鑰',
			'common.openParen' => '(',
			'common.closeParen' => ')',
			'common.routeNotFound' => '未找到路由：{name}',
			'common.noResultsEnterSearch' => '未找到結果。請輸入搜尋詞並按搜尋。',
			'common.artistLabel' => '藝人：',
			'common.albumLabel' => '專輯：',
			'common.platformLabel' => '平台：',
			'common.percentage' => '{percentage}%',
			'common.testConnection' => '測試連接',
			'common.disabledInKtvMode' => 'KTV 模式下禁用',
			'common.failedToRename' => '重命名失敗：{error}',
			'common.continueText' => '繼續',
			'common.artist' => '藝人',
			'common.album' => '專輯',
			'common.platform' => '平台',
			'common.addImage' => '新增圖片',
			'common.shuffle' => '隨機排序',
			'common.alreadyInPlaylist' => '已在播放清單中',
			'common.createAndAdd' => '建立並加入',
			'nav.home' => '主頁',
			'nav.library' => '音樂庫',
			'nav.playlists' => '播放清單',
			'nav.tags' => '標籤',
			'nav.settings' => '設定',
			'app.name' => '珠鏈',
			'library.title' => '音樂庫',
			'library.loading' => '正在載入音樂庫...',
			'library.searchHint' => '搜尋音樂庫...',
			'library.noLocations' => '未設定音樂庫位置',
			'library.allLocations' => '所有位置',
			'library.filterByLocation' => '依音樂庫位置篩選',
			'library.listView' => '清單檢視',
			'library.gridView' => '格狀檢視',
			'library.noItems' => '音樂庫為空',
			'library.noResults' => '找不到歌曲',
			'library.tryDifferentSearch' => '請嘗試其他搜尋詞',
			'library.audioOnly' => '僅音訊',
			'library.noSong' => '無歌曲',
			'library.actions.viewSongUnits' => '檢視歌曲單元',
			'library.actions.convertToSongUnit' => '轉換為歌曲單元',
			'library.actions.addToPlaylist' => '加入播放清單',
			'library.actions.addToQueue' => '加入佇列',
			'library.actions.promoteToSongUnits' => '升級為完整歌曲單元',
			'library.actions.mergeSelected' => '合併所選',
			'library.actions.exportSelected' => '匯出所選',
			'library.actions.deleteSelected' => '刪除所選',
			'library.actions.selectAll' => '全選',
			'library.actions.addTagsToSelected' => '新增標籤',
			'library.processing' => '處理中...',
			'library.exportedTo' => '已匯出到 {path}',
			'library.importComplete' => '匯入完成',
			'library.imported' => '已匯入：{count}',
			'library.skippedDuplicates' => '已略過（重複）：{count}',
			'library.importMore' => '... 還有 {count} 項',
			'library.promotedToSongUnit' => '已將 "{name}" 提升為歌曲單元',
			'library.deleteItemsConfirm' => '確定要刪除 {count} 項嗎？',
			'library.deletedItems' => '已刪除 {count} 項',
			'library.addedItemsToQueue' => '已將 {count} 項加入佇列',
			'library.noTemporaryEntriesSelected' => '未選取臨時項目',
			'library.addSongsToPlaylistTitle' => '將 {count} 首歌曲加入播放清單',
			'library.noPlaylistsCreateFirst' => '尚無播放清單。請先建立一個。',
			'library.sectionMetadata' => '元數據',
			'library.sectionSources' => '源',
			'library.sectionTags' => '標籤',
			'library.errorLoadingLibrary' => '載入音樂庫出錯',
			'library.deleteSongUnit' => '刪除歌曲單元',
			'library.alsoDeleteConfigFile' => '同時刪除設定檔',
			'library.configFileNote' => '刪除 beadline-*.json 檔案。原始檔案不受影響。',
			'library.deleteOriginalAfterMerge' => '合併後刪除原始歌曲單元',
			'library.selectedCount' => '{count} 已選取',
			'library.alreadyInPlaylist' => '已在播放清單中',
			'library.createAndAdd' => '建立並加入',
			'library.promoted' => '已將 "{displayName}" 提升為歌曲單元',
			'player.noSongPlaying' => '未在播放',
			'player.source' => '源',
			'player.display' => '畫面',
			'player.audio' => '音訊',
			'player.playback' => '播放',
			'player.lyrics' => '歌詞',
			'player.fullscreen' => '全螢幕',
			'player.exitFullscreen' => '退出全螢幕 (ESC)',
			'player.selectSources' => '選擇源',
			'player.play' => '播放',
			'player.pause' => '暫停',
			'player.next' => '下一首',
			'player.displayMode.label' => '畫面模式',
			'player.displayMode.enabled' => '啟用',
			'player.displayMode.imageOnly' => '僅圖片',
			'player.displayMode.disabled' => '停用',
			'player.displayMode.hidden' => '隱藏',
			'player.audioMode.label' => '音訊模式',
			'player.audioMode.original' => '原聲',
			'player.audioMode.accompaniment' => '伴奏',
			'player.playbackMode.label' => '播放模式',
			'player.playbackMode.sequential' => '循序播放',
			'player.playbackMode.repeatOne' => '單曲循環',
			'player.playbackMode.repeatAll' => '清單循環',
			'player.playbackMode.random' => '隨機播放',
			'player.lyricsMode.label' => '歌詞模式',
			'player.lyricsMode.off' => '關閉',
			'player.lyricsMode.screen' => '螢幕顯示',
			'player.lyricsMode.floating' => '浮動視窗',
			'player.lyricsMode.rolling' => '捲動顯示',
			'queue.title' => '佇列',
			'queue.manage' => '管理佇列',
			'queue.removeDuplicates' => '移除重複',
			'queue.shuffle' => '隨機排序',
			'queue.removeAfterPlayOn' => '播完移除：開',
			'queue.removeAfterPlayOff' => '播完移除：關',
			'queue.clearQueue' => '清空佇列',
			'queue.removedDuplicates' => '已移除 {count} 個重複項目',
			'queue.noDuplicates' => '未發現重複項目',
			'queue.manageQueues' => '管理佇列',
			'queue.queueContent' => '佇列內容',
			'queue.backToQueues' => '返回佇列清單',
			'queue.createQueue' => '新建佇列',
			'queue.queueName' => '佇列名稱',
			'queue.enterQueueName' => '輸入佇列名稱',
			'queue.renameQueue' => '重新命名佇列',
			'queue.enterNewName' => '輸入新名稱',
			'queue.deleteQueue' => '刪除佇列',
			'queue.deleteQueueConfirm' => '確定要刪除',
			'queue.deleteQueueWillRemove' => '這將從此佇列中移除',
			'queue.deleteQueueFromQueue' => '首歌曲',
			'queue.switchToQueue' => '切換到此佇列',
			'queue.empty' => '佇列為空',
			'queue.songs' => '{count} 首歌曲',
			'queue.actions' => '佇列操作',
			'queue.collapse' => '折疊',
			'queue.expand' => '展開',
			'queue.groupActions' => '分組操作',
			'search.title' => '搜尋',
			'search.songUnits' => '歌曲單元',
			'search.sources' => '源',
			'search.hint' => '搜尋...',
			'search.textMode' => '文字模式',
			'search.queryBuilder' => '條件建構器',
			'search.tag' => '標籤',
			'search.tagExample' => '例：artist:value',
			'search.range' => '範圍',
			'search.rangeExample' => '例：time:[2020-2024]',
			'search.searching' => '搜尋中...',
			'search.searchError' => '搜尋發生錯誤',
			'search.noSongUnitsFound' => '找不到歌曲單元',
			'search.loadMore' => '載入更多',
			'search.play' => '播放',
			'search.addToQueue' => '加入佇列',
			'search.all' => '全部',
			'search.local' => '本機',
			'search.online' => '線上',
			'search.searchingSources' => '正在搜尋源...',
			'search.noOnlineSources' => '找不到線上源',
			'search.noLocalSources' => '找不到本機源',
			'search.noSources' => '找不到源',
			'search.addToSongUnit' => '加入歌曲單元',
			'search.or' => '或',
			'search.not' => '非',
			'search.addedToQueue' => '已將"{title}"加入佇列',
			'search.addSource' => '加入源：{title}',
			'tags.title' => '標籤',
			'tags.noTags' => '尚無標籤',
			'tags.noTagsHint' => '建立標籤來整理你的音樂',
			'tags.loadError' => '載入標籤失敗',
			'tags.createTag' => '建立標籤',
			'tags.createChildTag' => '建立子標籤',
			'tags.tagName' => '標籤名稱',
			'tags.addAlias' => '新增別名',
			'tags.addAliasFor' => '為以下標籤新增別名',
			'tags.aliasName' => '別名',
			'tags.enterAlias' => '輸入別名',
			'tags.addChildTag' => '新增子標籤',
			'tags.deleteTag' => '刪除標籤',
			'tags.deleteTagTitle' => '刪除標籤？',
			'tags.deleteTagConfirm' => '此操作無法復原',
			'tags.deleteTagHasChildren' => '此標籤有子標籤，它們將成為根標籤。',
			'tags.deleteTagAliases' => '別名也將被刪除。',
			'tags.deletedTag' => '已刪除標籤',
			'tags.removeFromSong' => '從此歌曲移除標籤',
			'tags.removeAll' => '全部移除',
			'tags.viewSongUnits' => '檢視歌曲單元',
			'tags.item' => '項',
			'tags.items' => '項',
			'tags.songUnit' => '個歌曲單元',
			'tags.songUnits' => '個歌曲單元',
			'tags.lockedCollection' => '已鎖定的集合',
			'tags.collection' => '集合',
			'tags.locked' => '已鎖定',
			'playlists.title' => '播放清單',
			'playlists.noPlaylists' => '尚無播放清單',
			'playlists.noPlaylistsHint' => '右鍵或長按以建立播放清單',
			'playlists.selectPlaylist' => '選擇播放清單以檢視內容',
			'playlists.createPlaylist' => '建立播放清單',
			'playlists.addSongs' => '新增歌曲',
			'playlists.createGroup' => '建立群組',
			'playlists.addCollectionRef' => '新增合集參照',
			'playlists.renamePlaylist' => '重新命名播放清單',
			'playlists.deletePlaylist' => '刪除播放清單',
			'playlists.deletePlaylistConfirm' => '確定要刪除',
			'playlists.deletePlaylistNote' => '歌曲不會被刪除，僅刪除此播放清單',
			'playlists.createGroupTitle' => '建立群組',
			'playlists.createGroupHint' => '建立一個群組',
			'playlists.groupName' => '群組名稱',
			'playlists.enterGroupName' => '輸入群組名稱',
			'playlists.addCollectionRefTitle' => '新增合集參照',
			'playlists.noOtherCollections' => '沒有其他可用合集',
			'playlists.addReferenceTo' => '新增參照到',
			'playlists.lock' => '鎖定',
			'playlists.unlock' => '解鎖',
			'playlists.viewContent' => '檢視內容',
			'playlists.toggleSelectionMode' => '切換選擇模式',
			'playlists.moveToGroup' => '移動到群組',
			'playlists.noGroupsAvailable' => '沒有可用的群組。請先建立一個群組。',
			'playlists.song' => '首歌曲',
			'playlists.songs' => '首歌曲',
			'playlists.locked' => '已鎖定',
			'playlists.clearSelection' => '清除選擇',
			'playlists.selected' => '已選擇',
			'playlists.removeFromGroup' => '從群組中移除',
			'playlists.alreadyInPlaylist' => '已在播放清單中',
			'playlists.addedToPlaylist' => '已加入 "{name}"',
			'playlists.createdPlaylistAndAdded' => '已建立播放清單 "{name}" 並加入歌曲',
			'playlists.createAndAdd' => '建立並加入',
			'playlists.songCount' => '{count} 首歌曲',
			'playlists.noSongsInGroup' => '此群組中沒有歌曲',
			'playlists.dropHere' => '拖放到此處',
			'playlists.groupCreated' => '已建立群組 "{name}"',
			'playlists.failedToCreateGroup' => '建立群組失敗：{error}',
			'songEditor.titleEdit' => '編輯歌曲單元',
			'songEditor.titleNew' => '新建歌曲單元',
			'songEditor.reloadMetadata' => '從源重新載入中繼資料',
			'songEditor.writeMetadata' => '將中繼資料寫入源',
			'songEditor.sources' => '源',
			'songEditor.display' => '畫面',
			'songEditor.audio' => '音訊',
			'songEditor.accompaniment' => '伴奏',
			'songEditor.lyricsLabel' => '歌詞',
			'songEditor.noDisplaySources' => '無畫面源',
			'songEditor.noAudioSources' => '無音訊源',
			'songEditor.noAccompanimentSources' => '無伴奏源',
			'songEditor.noLyricsSources' => '無歌詞源',
			'songEditor.addDisplaySource' => '新增畫面源',
			'songEditor.addAudioSource' => '新增音訊源',
			'songEditor.addAccompanimentSource' => '新增伴奏源',
			'songEditor.addLyricsSource' => '新增歌詞源',
			'songEditor.editDisplayName' => '編輯顯示名稱',
			'songEditor.setOffset' => '設定偏移',
			'songEditor.setOffsetTitle' => '設定偏移量',
			'songEditor.offsetHint' => '與音訊對齊的毫秒偏移量',
			'songEditor.offsetNote' => '正值 = 延遲，負值 = 提前',
			'songEditor.offsetLabel' => '偏移量（毫秒）',
			'songEditor.editDisplayNameTitle' => '編輯顯示名稱',
			'songEditor.originalName' => '原始',
			'songEditor.displayNameLabel' => '顯示名稱',
			'songEditor.displayNameHint' => '留空則使用原始名稱',
			'songEditor.addSource' => '新增源',
			'songEditor.localFile' => '本機檔案',
			'songEditor.enterUrl' => '輸入 URL',
			'songEditor.urlLabel' => 'URL',
			'songEditor.urlHint' => 'https://...',
			'songEditor.selectSong' => '選擇歌曲',
			'songEditor.selectSongs' => '選擇歌曲',
			'songEditor.addSongs' => '新增歌曲',
			'songEditor.artist' => '藝人',
			'songEditor.thumbnail' => '縮圖',
			'songEditor.addImage' => '新增圖片',
			'songEditor.selectThumbnails' => '選擇 ({count})',
			'songEditor.selectThumbnailTitle' => '選擇縮圖',
			'songEditor.errorAddingCustomThumbnail' => '新增自訂縮圖時發生錯誤：{error}',
			'songEditor.audioExtracted' => '從 {name} 擷取的音訊軌道',
			'songEditor.noAudioFound' => '在 {name} 中找不到音訊軌道',
			'songEditor.autoDiscovered' => '自動發現：{types}',
			'songEditor.chooseMetadataValues' => '為每個元數據欄位選擇值：',
			'settings.title' => '設定',
			'settings.user' => '使用者',
			'settings.username' => '使用者名稱',
			'settings.appearance' => '外觀',
			'settings.theme' => '主題',
			'settings.themeSystem' => '跟隨系統',
			'settings.themeLight' => '淺色',
			'settings.themeDark' => '深色',
			'settings.accentColor' => '強調色',
			'settings.accentColorHint' => '自訂應用程式顏色',
			'settings.language' => '語言',
			'settings.playback' => '播放',
			'settings.lyricsMode' => '歌詞模式',
			'settings.ktvMode' => 'KTV 模式',
			'settings.ktvModeHint' => '強制螢幕歌詞，停用浮動視窗',
			'settings.hideDisplayPanel' => '隱藏畫面面板',
			'settings.hideDisplayPanelHint' => '僅顯示歌詞和控制列（純音樂模式）',
			'settings.thumbnailBgLibrary' => '音樂庫使用縮圖背景',
			'settings.thumbnailBgLibraryHint' => '在音樂庫檢視中將縮圖用作背景',
			'settings.thumbnailBgQueue' => '佇列使用縮圖背景',
			'settings.thumbnailBgQueueHint' => '在佇列中將縮圖用作背景',
			'settings.storage' => '儲存',
			'settings.configMode' => '設定模式',
			'settings.configModeCentralized' => '集中儲存',
			'settings.configModeInPlace' => '就地儲存',
			'settings.libraryLocations' => '音樂庫位置',
			'settings.libraryLocationsHint' => '管理音樂檔案的儲存位置',
			'settings.metadataWriteback' => '中繼資料回寫',
			'settings.metadataWritebackHint' => '將標籤變更同步到原始檔案',
			'settings.autoDiscoverAudio' => '自動探索音訊檔案',
			'settings.autoDiscoverAudioHint' => '自動從音樂庫位置新增音訊檔案',
			'settings.debug' => '除錯',
			'settings.audioEntriesDebug' => '音訊項目除錯',
			'settings.audioEntriesDebugHint' => '檢視已探索的音訊項目',
			'settings.rescanAudio' => '重新掃描音訊檔案',
			'settings.rescanAudioHint' => '清除並重新探索所有音訊檔案（含更新的中繼資料）',
			'settings.about' => '關於',
			'settings.version' => '版本',
			'settings.license' => '授權條款',
			'settings.licenseValue' => 'GNU Affero 通用公共授權條款 v3.0 (AGPL-3.0)',
			'settings.resetFactory' => '恢復原廠設定',
			'settings.resetFactoryHint' => '將所有設定重設為預設值',
			'settings.system' => '系統',
			'settings.resetFactoryTitle' => '恢復原廠設定？',
			'settings.resetFactoryBody' => '這將把應用程式完全重設為初始狀態',
			'settings.resetFactoryItems' => '所有設定和偏好\n歌曲單元庫和標籤\n播放清單、佇列和群組\n播放狀態',
			'settings.resetFactoryNote' => '磁碟上的實際音樂檔案不會被刪除',
			'settings.resetFactoryRestart' => '重設後應用程式將重新啟動',
			'settings.resetEverything' => '全部重設',
			'settings.rescanTitle' => '重新掃描音訊檔案',
			'settings.rescanBody' => '這將清除所有已探索的音訊項目並重新掃描音樂庫位置',
			'settings.rescanNote' => '大型音樂庫可能需要幾分鐘。是否繼續？',
			'settings.rescan' => '重新掃描',
			'settings.migratingConfig' => '正在遷移設定',
			'settings.migratingEntryPoints' => '正在遷移進入點檔案...',
			'settings.scanningForSongUnits' => '正在掃描歌曲單元...',
			'settings.storagePermissionTitle' => '需要儲存權限',
			'settings.storagePermissionBody' => '珠鏈需要存取你的音樂檔案以探索和播放音訊',
			'settings.storagePermissionNote' => '請在下一個對話框中授予儲存權限，或前往系統設定手動開啟',
			'settings.openSettings' => '開啟設定',
			'settings.foundAudioFiles' => '找到 {count} 個音訊檔案',
			'settings.errorScanning' => '掃描發生錯誤：{error}',
			'settings.audioEntriesCleared' => '音訊項目已清除',
			'settings.errorClearingAudio' => '清除音訊項目發生錯誤：{error}',
			'settings.audioRescanSuccess' => '音訊檔案重新掃描成功',
			'settings.errorRescanning' => '重新掃描發生錯誤：{error}',
			'settings.testingConnection' => '正在測試連線...',
			'settings.connectionSuccess' => '連線成功！',
			'settings.connectionFailed' => '連線失敗',
			'settings.onlineProviders' => '線上源提供者',
			'libraryLocations.title' => '音樂庫位置',
			'libraryLocations.selectLocation' => '選擇音樂庫位置',
			'libraryLocations.nameLocation' => '為此位置命名',
			'libraryLocations.enterLocationName' => '輸入此位置的名稱',
			'libraryLocations.locationAdded' => '音樂庫位置已新增',
			'libraryLocations.discoveredImported' => '已探索並匯入 {count} 個歌曲單元',
			'libraryLocations.switchToInPlace' => '切換到就地儲存',
			'libraryLocations.switchToCentralized' => '切換到集中儲存',
			'libraryLocations.migrateToInPlaceBody' => '這將把所有進入點檔案從集中儲存移動到 {path}，與音訊源放在一起',
			'libraryLocations.migrateToCentralizedBody' => '這將把所有進入點檔案從 {path} 移動到集中儲存',
			'libraryLocations.switchedToInPlace' => '已切換到就地儲存模式',
			'libraryLocations.switchedToCentralized' => '已切換到集中儲存模式',
			'libraryLocations.migrationFailed' => '遷移失敗',
			'libraryLocations.migrationError' => '遷移發生錯誤：{error}',
			'libraryLocations.renameLocation' => '重新命名位置',
			'libraryLocations.nameLabel' => '名稱',
			'libraryLocations.removeLocation' => '移除音樂庫位置',
			'libraryLocations.removeLocationConfirm' => '確定要移除 "{name}"？',
			'libraryLocations.removeLocationNote' => '從此位置探索的歌曲單元和音訊項目將從音樂庫中移除。磁碟上的檔案不會被刪除。',
			'libraryLocations.removed' => '已移除 "{name}"',
			'libraryLocations.failedToRemove' => '移除失敗：{error}',
			'libraryLocations.isNowDefault' => '現在是預設位置',
			'libraryLocations.failedToSetDefault' => '設定預設位置失敗：{error}',
			'libraryLocations.accessible' => '可存取',
			'libraryLocations.inaccessible' => '無法存取',
			'libraryLocations.inPlace' => '就地儲存',
			'libraryLocations.centralized' => '集中儲存',
			'libraryLocations.setAsDefault' => '設為預設',
			'locationSetup.title' => '設定音樂庫位置',
			'locationSetup.description' => '新增存放音樂檔案的資料夾。珠鏈將自動掃描這些位置並監控變更。',
			'locationSetup.storagePermissionRequired' => '需要儲存權限',
			'locationSetup.selectedLocations' => '已選位置',
			'locationSetup.addLocation' => '新增音樂庫位置',
			'locationSetup.firstLocationNote' => '第一個位置將作為新歌曲單元的預設位置',
			'configMode.title' => '歡迎使用珠鏈',
			'configMode.subtitle' => '選擇音樂庫設定的儲存方式',
			'configMode.centralizedTitle' => '集中儲存',
			'configMode.centralizedDesc' => '將所有設定儲存在應用程式資料目錄中',
			'configMode.centralizedPros' => '資料集中管理\n易於備份和還原\n標準應用程式行為',
			'configMode.centralizedCons' => '跨裝置可攜性較差\n共享需手動匯出',
			'configMode.inPlaceTitle' => '就地儲存',
			'configMode.inPlaceDesc' => '將歌曲單元中繼資料與音樂檔案存放在一起',
			'configMode.inPlacePros' => '跨裝置可攜\n自動探索歌曲單元\n中繼資料與檔案同在',
			'configMode.inPlaceCons' => '會在音樂資料夾中建立 beadline-*.json 檔案\n需要設定儲存位置',
			'configMode.changeNote' => '你可以稍後在 設定 > 儲存 中變更此設定',
			'onlineProviders.title' => '線上源提供者',
			'onlineProviders.noProviders' => '未設定提供者',
			'onlineProviders.noProvidersHint' => '新增提供者以搜尋線上源',
			'onlineProviders.addProvider' => '新增提供者',
			'onlineProviders.editProvider' => '編輯提供者',
			'onlineProviders.providerIdLabel' => '提供者 ID',
			'onlineProviders.providerIdHint' => 'bilibili、netease 等',
			'onlineProviders.displayNameLabel' => '顯示名稱',
			'onlineProviders.displayNameHint' => '嗶哩嗶哩、網易雲音樂等',
			'onlineProviders.baseUrlLabel' => '基礎 URL',
			'onlineProviders.baseUrlHint' => 'http://localhost:3000',
			'onlineProviders.apiKeyOptional' => 'API 金鑰（選填）',
			'onlineProviders.apiKeyHint' => '不需要則留空',
			'onlineProviders.timeoutLabel' => '逾時（秒）',
			'onlineProviders.timeoutDefault' => '10',
			'onlineProviders.timeoutError' => '逾時必須為正數',
			'display.noSource' => '無畫面源',
			'display.loading' => '載入中：{name}',
			'display.failedToLoad' => '載入失敗：{name}',
			'lyrics.noLyrics' => '尚無歌詞',
			'floatingLyrics.noLyrics' => '尚無歌詞',
			'songPicker.selectSongs' => '選擇歌曲',
			'songPicker.selectSong' => '選擇歌曲',
			'songPicker.searchHint' => '搜尋歌曲...',
			'songPicker.noSongsFound' => '找不到歌曲',
			'songPicker.noSongsInLibrary' => '音樂庫中沒有歌曲',
			'songPicker.addSongs' => '新增歌曲',
			'videoRemoval.title' => '移除畫面源',
			'videoRemoval.message' => '畫面源"{videoName}"包含已擷取的音訊源"{audioName}"。是否也要刪除音訊源？',
			'videoRemoval.cancel' => '取消',
			'videoRemoval.keepAudio' => '保留音訊',
			'videoRemoval.removeBoth' => '全部刪除',
			'debug.audioEntriesTitle' => '音訊條目除錯',
			'debug.temporarySongUnitsFound' => '找到臨時歌曲單元：{count}',
			'debug.refresh' => '重新整理',
			'debug.temporarySongUnits' => '臨時歌曲單元',
			'debug.close' => '關閉',
			'debug.showEntries' => '顯示條目',
			'dialogs.confirmModeChange' => '確認模式更改',
			'dialogs.changeMode' => '更改模式',
			'dialogs.discoveringAudioFiles' => '正在探索音訊檔案',
			'dialogs.rescanningAudioFiles' => '正在重新掃描音訊檔案',
			'dialogs.noLibraryLocationsConfigured' => '未設定音樂庫位置',
			'dialogs.errorLoadingLocations' => '載入位置出錯',
			'dialogs.kDefault' => '預設',
			'dialogs.addLocationToStoreMusic' => '新增位置以儲存音樂庫',
			'dialogs.noLocationsTitle' => '未設定音樂庫位置',
			'dialogs.noLocationsMessage' => '新增位置以儲存音樂庫',
			'dialogs.addNestedGroup' => '新增巢狀群組',
			'dialogs.removeGroup' => '移除群組',
			'dialogs.removeGroupQuestion' => '如何移除 "{groupName}"？',
			'dialogs.ungroupKeepSongs' => '取消群組（保留歌曲）',
			'dialogs.removeAll' => '全部移除',
			'dialogs.renameGroup' => '重新命名群組',
			'dialogs.createNestedGroup' => '建立巢狀群組',
			'dialogs.createGroup' => '建立群組',
			'dialogs.selectThumbnail' => '選擇縮圖',
			'dialogs.errorAddingCustomThumbnail' => '新增自訂縮圖時發生錯誤：{error}',
			'dialogs.noResultsEnterSearch' => '未找到結果。請輸入搜尋詞並按搜尋。',
			'dialogs.editProvider' => '編輯',
			'dialogs.deleteProvider' => '刪除',
			'dialogs.providerId' => 'ID: {providerId}',
			'dialogs.providerUrl' => 'URL: {baseUrl}',
			'dialogs.providerApiKey' => 'API 金鑰：•••••••- ',
			'dialogs.deleteSongUnit' => '刪除歌曲單元',
			'dialogs.alsoDeleteConfigFile' => '同時刪除設定檔',
			'dialogs.configFileNote' => '刪除 beadline-*.json 檔案。原始檔案不受影響。',
			'dialogs.deleteOriginalAfterMerge' => '合併後刪除原始歌曲單元',
			'dialogs.deleteItemsConfirm' => '確定要刪除 {count} 項嗎？',
			'dialogs.deletedItems' => '已刪除 {count} 項',
			'dialogs.importComplete' => '匯入完成',
			'dialogs.imported' => '已匯入：{count}',
			'dialogs.skippedDuplicates' => '已略過（重複）：{count}',
			'dialogs.importMore' => '... 還有 {count} 項',
			'dialogs.promotedToSongUnit' => '已將 "{name}" 提升為歌曲單元',
			'dialogs.exportedTo' => '已匯出到 {path}',
			'dialogs.promoted' => '已將 "{displayName}" 提升為歌曲單元',
			'dialogs.resetFailed' => '重設失敗：{error}',
			'dialogs.confirmTitle' => '確認模式更改',
			'dialogs.changeModeButton' => '更改模式',
			'dialogs.migratingConfig' => '正在遷移設定',
			'dialogs.migratingEntryPoints' => '正在遷移進入點檔案...',
			'dialogs.scanningForSongUnits' => '正在掃描歌曲單元...',
			_ => null,
		} ?? switch (path) {
			'dialogs.errorScanning' => '掃描發生錯誤：{error}',
			'dialogs.errorClearingAudio' => '清除音訊項目發生錯誤：{error}',
			'dialogs.errorRescanning' => '重新掃描發生錯誤：{error}',
			'dialogs.failedToRename' => '重命名失敗：{error}',
			'dialogs.failedToRemove' => '移除失敗：{error}',
			'dialogs.failedToSetDefault' => '設定預設失敗：{error}',
			'dialogs.migrationError' => '遷移發生錯誤：{error}',
			'dialogs.home.shuffle' => '隨機排序',
			'dialogs.home.rename' => '重新命名',
			'dialogs.home.addNestedGroup' => '新增巢狀群組',
			'dialogs.home.remove' => '移除',
			'dialogs.home.removeGroup' => '移除群組',
			'dialogs.home.removeGroupQuestion' => '如何移除 "{groupName}"？',
			'dialogs.home.ungroupKeepSongs' => '取消群組（保留歌曲）',
			'dialogs.home.removeAll' => '全部移除',
			'dialogs.home.renameGroup' => '重新命名群組',
			'dialogs.home.createNestedGroup' => '建立巢狀群組',
			'dialogs.home.create' => '建立',
			'dialogs.home.createGroup' => '建立群組',
			'dialogs.progressDialogs.discovering' => '正在探索音訊檔案',
			'dialogs.progressDialogs.rescanning' => '正在重新掃描音訊檔案',
			'dialogs.libraryLocationsError.noLocationsConfigured' => '未設定音樂庫位置',
			'dialogs.libraryLocationsError.errorLoading' => '載入位置出錯',
			'dialogs.libraryLocationsError.retry' => '重試',
			'configModeChange.title' => '確認模式更改',
			'configModeChange.description' => '更改設定模式將遷移進入點檔案。這可能需要一些時間。',
			'configModeChange.inPlaceDescription' => '這將在音樂檔案旁邊建立 beadline-*.json 檔案。你的音樂庫將可以在不同裝置間攜帶。',
			'configModeChange.centralizedDescription' => '這將把進入點檔案移動到應用程式資料目錄。你的音樂庫將不再可攜帶。',
			'configModeChange.changeMode' => '更改模式',
			'app_routes.routeNotFound' => '未找到路由：{name}',
			'loading_indicator.percentage' => '{percentage}%',
			'video_removal_prompt.title' => '移除畫面源',
			'video_removal_prompt.message' => '畫面源"{videoName}"包含已擷取的音訊源"{audioName}"。是否也要刪除音訊源？',
			'video_removal_prompt.keepAudio' => '保留音訊',
			'video_removal_prompt.removeBoth' => '全部刪除',
			'library_location_setup_dialog.title' => '選擇音樂庫位置',
			'home_page.renameGroup' => '重新命名群組',
			'song_unit_editor.addedToSources' => '已將 {title} 加入到源',
			'song_unit_editor.aliasHint' => 'title',
			_ => null,
		};
	}
}
