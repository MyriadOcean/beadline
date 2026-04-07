///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsZhHans with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZhHans({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhHans,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-Hans>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsZhHans _root = this; // ignore: unused_field

	@override 
	TranslationsZhHans $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZhHans(meta: meta ?? this.$meta);

	// Translations
	@override late final _TranslationsCommonZhHans common = _TranslationsCommonZhHans._(_root);
	@override late final _TranslationsNavZhHans nav = _TranslationsNavZhHans._(_root);
	@override late final _TranslationsAppZhHans app = _TranslationsAppZhHans._(_root);
	@override late final _TranslationsLibraryZhHans library = _TranslationsLibraryZhHans._(_root);
	@override late final _TranslationsPlayerZhHans player = _TranslationsPlayerZhHans._(_root);
	@override late final _TranslationsQueueZhHans queue = _TranslationsQueueZhHans._(_root);
	@override late final _TranslationsSearchZhHans search = _TranslationsSearchZhHans._(_root);
	@override late final _TranslationsTagsZhHans tags = _TranslationsTagsZhHans._(_root);
	@override late final _TranslationsPlaylistsZhHans playlists = _TranslationsPlaylistsZhHans._(_root);
	@override late final _TranslationsSongEditorZhHans songEditor = _TranslationsSongEditorZhHans._(_root);
	@override late final _TranslationsSettingsZhHans settings = _TranslationsSettingsZhHans._(_root);
	@override late final _TranslationsLibraryLocationsZhHans libraryLocations = _TranslationsLibraryLocationsZhHans._(_root);
	@override late final _TranslationsLocationSetupZhHans locationSetup = _TranslationsLocationSetupZhHans._(_root);
	@override late final _TranslationsConfigModeZhHans configMode = _TranslationsConfigModeZhHans._(_root);
	@override late final _TranslationsOnlineProvidersZhHans onlineProviders = _TranslationsOnlineProvidersZhHans._(_root);
	@override late final _TranslationsDisplayZhHans display = _TranslationsDisplayZhHans._(_root);
	@override late final _TranslationsLyricsZhHans lyrics = _TranslationsLyricsZhHans._(_root);
	@override late final _TranslationsFloatingLyricsZhHans floatingLyrics = _TranslationsFloatingLyricsZhHans._(_root);
	@override late final _TranslationsSongPickerZhHans songPicker = _TranslationsSongPickerZhHans._(_root);
	@override late final _TranslationsVideoRemovalZhHans videoRemoval = _TranslationsVideoRemovalZhHans._(_root);
	@override late final _TranslationsDebugZhHans debug = _TranslationsDebugZhHans._(_root);
	@override late final _TranslationsDialogsZhHans dialogs = _TranslationsDialogsZhHans._(_root);
	@override late final _TranslationsConfigModeChangeZhHans configModeChange = _TranslationsConfigModeChangeZhHans._(_root);
	@override late final _TranslationsAppRoutesZhHans app_routes = _TranslationsAppRoutesZhHans._(_root);
	@override late final _TranslationsLoadingIndicatorZhHans loading_indicator = _TranslationsLoadingIndicatorZhHans._(_root);
	@override late final _TranslationsVideoRemovalPromptZhHans video_removal_prompt = _TranslationsVideoRemovalPromptZhHans._(_root);
	@override late final _TranslationsLibraryLocationSetupDialogZhHans library_location_setup_dialog = _TranslationsLibraryLocationSetupDialogZhHans._(_root);
	@override late final _TranslationsHomePageZhHans home_page = _TranslationsHomePageZhHans._(_root);
	@override late final _TranslationsSongUnitEditorZhHans song_unit_editor = _TranslationsSongUnitEditorZhHans._(_root);
}

// Path: common
class _TranslationsCommonZhHans implements TranslationsCommonEn {
	_TranslationsCommonZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get cancel => '取消';
	@override String get save => '保存';
	@override String get delete => '删除';
	@override String get add => '添加';
	@override String get edit => '编辑';
	@override String get rename => '重命名';
	@override String get create => '创建';
	@override String get close => '关闭';
	@override String get retry => '重试';
	@override String get refresh => '刷新';
	@override String get search => '搜索';
	@override String get ok => '确定';
	@override String get yes => '是';
	@override String get no => '否';
	@override String get back => '返回';
	@override String get skip => '暂时跳过';
	@override String get apply => '应用';
	@override String get remove => '移除';
	@override String get duplicate => '复制';
	@override String get export => '导出';
	@override String get import => '导入';
	@override String get migrate => '迁移';
	@override String get reset => '重置';
	@override String get grant => '授权';
	@override String get enabled => '已启用';
	@override String get disabled => '已禁用';
	@override String get on => '开';
	@override String get off => '关';
	@override String get error => '错误';
	@override String get loading => '加载中...';
	@override String get songs => '首歌曲';
	@override String get selected => '已选择';
	@override String get items => '项';
	@override String get ms => '毫秒';
	@override String get dismiss => '关闭';
	@override String get extract => '提取';
	@override String get extractingThumbnails => '正在提取缩略图...';
	@override String get noThumbnailsAvailable => '没有可用的缩略图';
	@override String get displayVideoImage => '显示（视频/图片）';
	@override String get id => 'ID';
	@override String get url => 'URL';
	@override String get apiKey => 'API 密钥';
	@override String get openParen => '(';
	@override String get closeParen => ')';
	@override String get routeNotFound => '未找到路由：{name}';
	@override String get noResultsEnterSearch => '未找到结果。请输入搜索词并按搜索。';
	@override String get artistLabel => '艺术家：';
	@override String get albumLabel => '专辑：';
	@override String get platformLabel => '平台：';
	@override String get percentage => '{percentage}%';
	@override String get testConnection => '测试连接';
	@override String get disabledInKtvMode => 'KTV 模式下禁用';
	@override String get failedToRename => '重命名失败：{error}';
	@override String get continueText => '继续';
	@override String get artist => '艺术家';
	@override String get album => '专辑';
	@override String get platform => '平台';
	@override String get addImage => '添加图片';
	@override String get shuffle => '随机排序';
	@override String get alreadyInPlaylist => '已在播放列表中';
	@override String get createAndAdd => '创建并添加';
}

// Path: nav
class _TranslationsNavZhHans implements TranslationsNavEn {
	_TranslationsNavZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get home => '主页';
	@override String get library => '曲库';
	@override String get playlists => '播放列表';
	@override String get tags => '标签';
	@override String get settings => '设置';
}

// Path: app
class _TranslationsAppZhHans implements TranslationsAppEn {
	_TranslationsAppZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get name => '珠链';
}

// Path: library
class _TranslationsLibraryZhHans implements TranslationsLibraryEn {
	_TranslationsLibraryZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '曲库';
	@override String get loading => '正在加载曲库...';
	@override String get searchHint => '搜索曲库...';
	@override String get noLocations => '未设置曲库位置';
	@override String get allLocations => '所有位置';
	@override String get filterByLocation => '按曲库位置筛选';
	@override String get listView => '列表视图';
	@override String get gridView => '网格视图';
	@override String get noItems => '曲库为空';
	@override String get noResults => '未找到歌曲';
	@override String get tryDifferentSearch => '请尝试其他搜索词';
	@override String get audioOnly => '仅音频';
	@override String get noSong => '无歌曲';
	@override late final _TranslationsLibraryActionsZhHans actions = _TranslationsLibraryActionsZhHans._(_root);
	@override String get processing => '处理中...';
	@override String get exportedTo => '已导出到 {path}';
	@override String get importComplete => '导入完成';
	@override String get imported => '已导入：{count}';
	@override String get skippedDuplicates => '已跳过（重复）：{count}';
	@override String get importMore => '... 还有 {count} 条';
	@override String get promotedToSongUnit => '已将 "{name}" 提升为歌曲单元';
	@override String get deleteItemsConfirm => '确定要删除 {count} 项吗？';
	@override String get deletedItems => '已删除 {count} 项';
	@override String get addedItemsToQueue => '已将 {count} 项加入队列';
	@override String get noTemporaryEntriesSelected => '未选择临时条目';
	@override String get addSongsToPlaylistTitle => '将 {count} 首歌曲添加到播放列表';
	@override String get noPlaylistsCreateFirst => '暂无播放列表。请先创建一个。';
	@override String get sectionMetadata => '元数据';
	@override String get sectionSources => '源';
	@override String get sectionTags => '标签';
	@override String get errorLoadingLibrary => '加载曲库出错';
	@override String get deleteSongUnit => '删除歌曲单元';
	@override String get alsoDeleteConfigFile => '同时删除配置文件';
	@override String get configFileNote => '删除 beadline-*.json 文件。源文件不受影响。';
	@override String get deleteOriginalAfterMerge => '合并后删除原始歌曲单元';
	@override String get selectedCount => '{count} 已选择';
	@override String get alreadyInPlaylist => '已在播放列表中';
	@override String get createAndAdd => '创建并添加';
	@override String get promoted => '已将 "{displayName}" 提升为歌曲单元';
}

// Path: player
class _TranslationsPlayerZhHans implements TranslationsPlayerEn {
	_TranslationsPlayerZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get noSongPlaying => '未在播放';
	@override String get source => '源';
	@override String get display => '画面';
	@override String get audio => '音频';
	@override String get playback => '播放';
	@override String get lyrics => '歌词';
	@override String get fullscreen => '全屏';
	@override String get exitFullscreen => '退出全屏 (ESC)';
	@override String get selectSources => '选择源';
	@override String get play => '播放';
	@override String get pause => '暂停';
	@override String get next => '下一首';
	@override late final _TranslationsPlayerDisplayModeZhHans displayMode = _TranslationsPlayerDisplayModeZhHans._(_root);
	@override late final _TranslationsPlayerAudioModeZhHans audioMode = _TranslationsPlayerAudioModeZhHans._(_root);
	@override late final _TranslationsPlayerPlaybackModeZhHans playbackMode = _TranslationsPlayerPlaybackModeZhHans._(_root);
	@override late final _TranslationsPlayerLyricsModeZhHans lyricsMode = _TranslationsPlayerLyricsModeZhHans._(_root);
}

// Path: queue
class _TranslationsQueueZhHans implements TranslationsQueueEn {
	_TranslationsQueueZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '队列';
	@override String get manage => '管理队列';
	@override String get removeDuplicates => '移除重复';
	@override String get shuffle => '随机排序';
	@override String get removeAfterPlayOn => '播完移除：开';
	@override String get removeAfterPlayOff => '播完移除：关';
	@override String get clearQueue => '清空队列';
	@override String get removedDuplicates => '已移除 {count} 个重复项';
	@override String get noDuplicates => '未发现重复项';
	@override String get manageQueues => '管理队列';
	@override String get queueContent => '队列内容';
	@override String get backToQueues => '返回队列列表';
	@override String get createQueue => '新建队列';
	@override String get queueName => '队列名称';
	@override String get enterQueueName => '输入队列名称';
	@override String get renameQueue => '重命名队列';
	@override String get enterNewName => '输入新名称';
	@override String get deleteQueue => '删除队列';
	@override String get deleteQueueConfirm => '确定要删除';
	@override String get deleteQueueWillRemove => '这将从此队列中移除';
	@override String get deleteQueueFromQueue => '首歌曲';
	@override String get switchToQueue => '切换到此队列';
	@override String get empty => '队列为空';
	@override String get songs => '{count} 首歌曲';
	@override String get actions => '队列操作';
	@override String get collapse => '折叠';
	@override String get expand => '展开';
	@override String get groupActions => '分组操作';
}

// Path: search
class _TranslationsSearchZhHans implements TranslationsSearchEn {
	_TranslationsSearchZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '搜索';
	@override String get songUnits => '歌曲单元';
	@override String get sources => '源';
	@override String get hint => '搜索...';
	@override String get textMode => '文本模式';
	@override String get queryBuilder => '条件构建器';
	@override String get tag => '标签';
	@override String get tagExample => '例：artist:value';
	@override String get range => '范围';
	@override String get rangeExample => '例：time:[2020-2024]';
	@override String get searching => '搜索中...';
	@override String get searchError => '搜索出错';
	@override String get noSongUnitsFound => '未找到歌曲单元';
	@override String get loadMore => '加载更多';
	@override String get play => '播放';
	@override String get addToQueue => '添加到队列';
	@override String get all => '全部';
	@override String get local => '本地';
	@override String get online => '在线';
	@override String get searchingSources => '正在搜索源...';
	@override String get noOnlineSources => '未找到在线源';
	@override String get noLocalSources => '未找到本地源';
	@override String get noSources => '未找到源';
	@override String get addToSongUnit => '添加到歌曲单元';
	@override String get or => '或';
	@override String get not => '非';
	@override String get addedToQueue => '已将"{title}"添加到队列';
	@override String get addSource => '添加源：{title}';
}

// Path: tags
class _TranslationsTagsZhHans implements TranslationsTagsEn {
	_TranslationsTagsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '标签';
	@override String get noTags => '暂无标签';
	@override String get noTagsHint => '创建标签来整理你的音乐';
	@override String get loadError => '加载标签失败';
	@override String get createTag => '创建标签';
	@override String get createChildTag => '创建子标签';
	@override String get tagName => '标签名称';
	@override String get addAlias => '添加别名';
	@override String get addAliasFor => '为以下标签添加别名';
	@override String get aliasName => '别名';
	@override String get enterAlias => '输入别名';
	@override String get addChildTag => '添加子标签';
	@override String get deleteTag => '删除标签';
	@override String get deleteTagTitle => '删除标签？';
	@override String get deleteTagConfirm => '此操作无法撤销';
	@override String get deleteTagHasChildren => '此标签有子标签，它们将成为根标签。';
	@override String get deleteTagAliases => '别名也将被删除。';
	@override String get deletedTag => '已删除标签';
	@override String get removeFromSong => '从此歌曲移除标签';
	@override String get removeAll => '全部移除';
	@override String get viewSongUnits => '查看歌曲单元';
	@override String get item => '项';
	@override String get items => '项';
	@override String get songUnit => '个歌曲单元';
	@override String get songUnits => '个歌曲单元';
	@override String get lockedCollection => '已锁定的集合';
	@override String get collection => '集合';
	@override String get locked => '已锁定';
}

// Path: playlists
class _TranslationsPlaylistsZhHans implements TranslationsPlaylistsEn {
	_TranslationsPlaylistsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '播放列表';
	@override String get noPlaylists => '暂无播放列表';
	@override String get noPlaylistsHint => '右键或长按以创建播放列表';
	@override String get selectPlaylist => '选择播放列表以查看内容';
	@override String get createPlaylist => '创建播放列表';
	@override String get addSongs => '添加歌曲';
	@override String get createGroup => '创建分组';
	@override String get moveToGroup => '移动到分组';
	@override String get addCollectionRef => '添加合集引用';
	@override String get renamePlaylist => '重命名播放列表';
	@override String get deletePlaylist => '删除播放列表';
	@override String get deletePlaylistConfirm => '确定要删除';
	@override String get deletePlaylistNote => '歌曲不会被删除，仅删除此播放列表';
	@override String get createGroupTitle => '创建分组';
	@override String get createGroupHint => '创建一个分组';
	@override String get groupName => '分组名称';
	@override String get enterGroupName => '输入分组名称';
	@override String get addCollectionRefTitle => '添加合集引用';
	@override String get noOtherCollections => '没有其他可用合集';
	@override String get addReferenceTo => '添加引用到';
	@override String get lock => '锁定';
	@override String get unlock => '解锁';
	@override String get viewContent => '查看内容';
	@override String get toggleSelectionMode => '切换选择模式';
	@override String get noGroupsAvailable => '没有可用的分组。请先创建一个分组。';
	@override String get song => '首歌曲';
	@override String get songs => '首歌曲';
	@override String get locked => '已锁定';
	@override String get clearSelection => '清除选择';
	@override String get selected => '已选择';
	@override String get removeFromGroup => '从分组中移除';
	@override String get alreadyInPlaylist => '已在播放列表中';
	@override String get addedToPlaylist => '已添加到 "{name}"';
	@override String get createdPlaylistAndAdded => '已创建播放列表 "{name}" 并添加了歌曲';
	@override String get createAndAdd => '创建并添加';
	@override String get songCount => '{count} 首歌曲';
	@override String get noSongsInGroup => '此分组中没有歌曲';
	@override String get dropHere => '拖放到此处';
	@override String get groupCreated => '已创建分组 "{name}"';
	@override String get failedToCreateGroup => '创建分组失败：{error}';
}

// Path: songEditor
class _TranslationsSongEditorZhHans implements TranslationsSongEditorEn {
	_TranslationsSongEditorZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get titleEdit => '编辑歌曲单元';
	@override String get titleNew => '新建歌曲单元';
	@override String get reloadMetadata => '从源重新加载元数据';
	@override String get writeMetadata => '将元数据写入源';
	@override String get sources => '源';
	@override String get display => '画面';
	@override String get audio => '音频';
	@override String get accompaniment => '伴奏';
	@override String get lyricsLabel => '歌词';
	@override String get noDisplaySources => '无画面源';
	@override String get noAudioSources => '无音频源';
	@override String get noAccompanimentSources => '无伴奏源';
	@override String get noLyricsSources => '无歌词源';
	@override String get addDisplaySource => '添加画面源';
	@override String get addAudioSource => '添加音频源';
	@override String get addAccompanimentSource => '添加伴奏源';
	@override String get addLyricsSource => '添加歌词源';
	@override String get editDisplayName => '编辑显示名称';
	@override String get setOffset => '设置偏移';
	@override String get setOffsetTitle => '设置偏移量';
	@override String get offsetHint => '与音频对齐的毫秒偏移量';
	@override String get offsetNote => '正值 = 延迟，负值 = 提前';
	@override String get offsetLabel => '偏移量（毫秒）';
	@override String get editDisplayNameTitle => '编辑显示名称';
	@override String get originalName => '原始';
	@override String get displayNameLabel => '显示名称';
	@override String get displayNameHint => '留空则使用原始名称';
	@override String get addSource => '添加源';
	@override String get localFile => '本地文件';
	@override String get enterUrl => '输入 URL';
	@override String get urlLabel => 'URL';
	@override String get urlHint => 'https://...';
	@override String get selectSong => '选择歌曲';
	@override String get selectSongs => '选择歌曲';
	@override String get addSongs => '添加歌曲';
	@override String get artist => '艺术家';
	@override String get thumbnail => '缩略图';
	@override String get addImage => '添加图片';
	@override String get selectThumbnails => '选择 ({count})';
	@override String get selectThumbnailTitle => '选择缩略图';
	@override String get errorAddingCustomThumbnail => '添加自定义缩略图出错：{error}';
	@override String get audioExtracted => '从 {name} 提取的音频轨道';
	@override String get noAudioFound => '在 {name} 中未找到音频轨道';
	@override String get autoDiscovered => '自动发现：{types}';
	@override String get chooseMetadataValues => '为每个元数据字段选择值：';
	@override String get builtInTagsMetadata => '内置标签（元数据）';
	@override String get userTags => '用户标签';
	@override String get noUserTags => '暂无用户标签。请在标签管理中创建。';
	@override String get tagNameName => '名称';
	@override String get tagNameAlbum => '专辑';
	@override String get tagNameTime => '年份';
	@override String get aliasHintTitle => '标题';
	@override String get addImageOrExtract => '添加图片或从音频文件提取';
	@override String get thumbnailsAvailable => '有 {count} 个缩略图可用';
	@override String get removeFromCollection => '从集合中移除';
	@override String get metadataWriteNotImplemented => '元数据写入功能尚未实现，需要外部库支持。';
	@override String get linkedVideoFrom => '来自：{name}';
	@override String get offsetDisplay => '偏移：{value}';
	@override String get searchOnlineSources => '搜索在线源';
	@override String get providerLabel => '提供商';
	@override String get sourceTypeLabel => '源类型';
	@override String get searchQueryLabel => '搜索关键词';
	@override String get durationDisplay => '时长：{value}';
	@override String get addToSongUnit => '添加到曲目单元';
	@override String get cannotSaveInPlaceNoLocations => '就地模式下无法保存曲目单元，请先在设置中配置至少一个音乐库位置。';
	@override String get failedToLoadUrl => '无法从 URL 加载媒体，URL 可能无效或不可达。';
	@override String get urlNotDirectMedia => '警告：URL 似乎不是直接媒体文件。请使用音频/视频文件的直接链接（如 .mp3、.mp4），而非网页链接。';
	@override String get noAudioSourcesForMetadata => '没有可提取元数据的音频源';
	@override String get cannotExtractFromApi => '无法从 API 源提取元数据';
	@override String get metadataReloaded => '元数据已重新加载';
	@override String get addedSource => '已添加 {title}';
}

// Path: settings
class _TranslationsSettingsZhHans implements TranslationsSettingsEn {
	_TranslationsSettingsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '设置';
	@override String get user => '用户';
	@override String get username => '用户名';
	@override String get appearance => '外观';
	@override String get theme => '主题';
	@override String get themeSystem => '跟随系统';
	@override String get themeLight => '浅色';
	@override String get themeDark => '深色';
	@override String get accentColor => '主题色';
	@override String get accentColorHint => '自定义应用颜色';
	@override String get language => '语言';
	@override String get languageSystemDefault => '跟随系统';
	@override String get languageSelectorTitle => '选择语言';
	@override String get languageSelectorSubtitle => '选择您偏好的应用语言';
	@override String get languageSelectorHint => '您可以稍后在设置中更改语言';
	@override String get languageSelectorContinue => '继续';
	@override String get playback => '播放';
	@override String get lyricsMode => '歌词模式';
	@override String get ktvMode => 'KTV 模式';
	@override String get ktvModeHint => '强制屏幕歌词，禁用悬浮窗';
	@override String get hideDisplayPanel => '隐藏画面面板';
	@override String get hideDisplayPanelHint => '仅显示歌词和控制栏（纯音乐模式）';
	@override String get thumbnailBgLibrary => '曲库使用缩略图背景';
	@override String get thumbnailBgLibraryHint => '在曲库视图中将缩略图用作背景';
	@override String get thumbnailBgQueue => '队列使用缩略图背景';
	@override String get thumbnailBgQueueHint => '在队列中将缩略图用作背景';
	@override String get storage => '存储';
	@override String get configMode => '配置模式';
	@override String get configModeCentralized => '集中存储';
	@override String get configModeInPlace => '就地存储';
	@override String get libraryLocations => '曲库位置';
	@override String get libraryLocationsHint => '管理音乐文件的存储位置';
	@override String get metadataWriteback => '元数据回写';
	@override String get metadataWritebackHint => '将标签更改同步到源文件';
	@override String get autoDiscoverAudio => '自动发现音频文件';
	@override String get autoDiscoverAudioHint => '自动从曲库位置添加音频文件';
	@override String get debug => '调试';
	@override String get audioEntriesDebug => '音频条目调试';
	@override String get audioEntriesDebugHint => '查看已发现的音频条目';
	@override String get rescanAudio => '重新扫描音频文件';
	@override String get rescanAudioHint => '清除并重新发现所有音频文件（含更新的元数据）';
	@override String get about => '关于';
	@override String get version => '版本';
	@override String get license => '许可证';
	@override String get licenseValue => 'GNU Affero 通用公共许可证 v3.0 (AGPL-3.0)';
	@override String get resetFactory => '恢复出厂设置';
	@override String get resetFactoryHint => '将所有设置重置为默认值';
	@override String get system => '系统';
	@override String get resetFactoryTitle => '恢复出厂设置？';
	@override String get resetFactoryBody => '这将把应用完全重置为初始状态';
	@override String get resetFactoryItems => '所有设置和偏好\n歌曲单元库和标签\n播放列表、队列和分组\n播放状态';
	@override String get resetFactoryNote => '磁盘上的实际音乐文件不会被删除';
	@override String get resetFactoryRestart => '重置后应用将重启';
	@override String get resetEverything => '全部重置';
	@override String get rescanTitle => '重新扫描音频文件';
	@override String get rescanBody => '这将清除所有已发现的音频条目并重新扫描曲库位置';
	@override String get rescanNote => '大型曲库可能需要几分钟。是否继续？';
	@override String get rescan => '重新扫描';
	@override String get migratingConfig => '正在迁移配置';
	@override String get migratingEntryPoints => '正在迁移入口点文件...';
	@override String get scanningForSongUnits => '正在扫描歌曲单元...';
	@override String get storagePermissionTitle => '需要存储权限';
	@override String get storagePermissionBody => '珠链需要访问你的音乐文件以发现和播放音频';
	@override String get storagePermissionNote => '请在下一个对话框中授予存储权限，或前往系统设置手动开启';
	@override String get openSettings => '打开设置';
	@override String get foundAudioFiles => '找到 {count} 个音频文件';
	@override String get errorScanning => '扫描出错：{error}';
	@override String get audioEntriesCleared => '音频条目已清除';
	@override String get errorClearingAudio => '清除音频条目出错：{error}';
	@override String get audioRescanSuccess => '音频文件重新扫描成功';
	@override String get errorRescanning => '重新扫描出错：{error}';
	@override String get testingConnection => '正在测试连接...';
	@override String get connectionSuccess => '连接成功！';
	@override String get connectionFailed => '连接失败';
	@override String get onlineProviders => '在线源提供商';
}

// Path: libraryLocations
class _TranslationsLibraryLocationsZhHans implements TranslationsLibraryLocationsEn {
	_TranslationsLibraryLocationsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '曲库位置';
	@override String get selectLocation => '选择曲库位置';
	@override String get nameLocation => '为此位置命名';
	@override String get enterLocationName => '输入此位置的名称';
	@override String get locationAdded => '曲库位置已添加';
	@override String get discoveredImported => '已发现并导入 {count} 个歌曲单元';
	@override String get switchToInPlace => '切换到就地存储';
	@override String get switchToCentralized => '切换到集中存储';
	@override String get migrateToInPlaceBody => '这将把所有入口点文件从集中存储移动到 {path}，与音频源放在一起';
	@override String get migrateToCentralizedBody => '这将把所有入口点文件从 {path} 移动到集中存储';
	@override String get switchedToInPlace => '已切换到就地存储模式';
	@override String get switchedToCentralized => '已切换到集中存储模式';
	@override String get migrationFailed => '迁移失败';
	@override String get migrationError => '迁移出错：{error}';
	@override String get renameLocation => '重命名位置';
	@override String get nameLabel => '名称';
	@override String get removeLocation => '移除曲库位置';
	@override String get removeLocationConfirm => '确定要移除 "{name}"？';
	@override String get removeLocationNote => '从此位置发现的歌曲单元和音频条目将从曲库中移除。磁盘上的文件不会被删除。';
	@override String get removed => '已移除 "{name}"';
	@override String get failedToRemove => '移除失败：{error}';
	@override String get isNowDefault => '"{name}" 现在是默认位置';
	@override String get failedToSetDefault => '设置默认位置失败：{error}';
	@override String get accessible => '可访问';
	@override String get inaccessible => '不可访问';
	@override String get inPlace => '就地存储';
	@override String get centralized => '集中存储';
	@override String get setAsDefault => '设为默认';
}

// Path: locationSetup
class _TranslationsLocationSetupZhHans implements TranslationsLocationSetupEn {
	_TranslationsLocationSetupZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '设置曲库位置';
	@override String get description => '添加存储音乐文件的文件夹。珠链将自动扫描这些位置并监控变化。';
	@override String get storagePermissionRequired => '需要存储权限';
	@override String get selectedLocations => '已选位置';
	@override String get addLocation => '添加曲库位置';
	@override String get firstLocationNote => '第一个位置将作为新歌曲单元的默认位置';
}

// Path: configMode
class _TranslationsConfigModeZhHans implements TranslationsConfigModeEn {
	_TranslationsConfigModeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '欢迎使用珠链';
	@override String get subtitle => '选择曲库配置的存储方式';
	@override String get centralizedTitle => '集中存储';
	@override String get centralizedDesc => '将所有配置存储在应用数据目录中';
	@override String get centralizedPros => '数据集中管理\n易于备份和恢复\n标准应用行为';
	@override String get centralizedCons => '跨设备可移植性较差\n共享需手动导出';
	@override String get inPlaceTitle => '就地存储';
	@override String get inPlaceDesc => '将歌曲单元元数据与音乐文件存放在一起';
	@override String get inPlacePros => '跨设备可便携\n自动发现歌曲单元\n元数据与文件同在';
	@override String get inPlaceCons => '会在音乐文件夹中创建 beadline-*.json 文件\n需要设置存储位置';
	@override String get changeNote => '你可以稍后在 设置 > 存储 中更改此设置';
}

// Path: onlineProviders
class _TranslationsOnlineProvidersZhHans implements TranslationsOnlineProvidersEn {
	_TranslationsOnlineProvidersZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '在线源提供商';
	@override String get noProviders => '未配置提供商';
	@override String get noProvidersHint => '添加提供商以搜索在线源';
	@override String get addProvider => '添加提供商';
	@override String get editProvider => '编辑提供商';
	@override String get providerIdLabel => '提供商 ID';
	@override String get providerIdHint => 'bilibili、netease 等';
	@override String get displayNameLabel => '显示名称';
	@override String get displayNameHint => '哔哩哔哩、网易云音乐等';
	@override String get baseUrlLabel => '基础 URL';
	@override String get baseUrlHint => 'http://localhost:3000';
	@override String get apiKeyOptional => 'API 密钥（可选）';
	@override String get apiKeyHint => '不需要则留空';
	@override String get timeoutLabel => '超时（秒）';
	@override String get timeoutDefault => '10';
	@override String get timeoutError => '超时必须为正数';
}

// Path: display
class _TranslationsDisplayZhHans implements TranslationsDisplayEn {
	_TranslationsDisplayZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get noSource => '无画面源';
	@override String get loading => '加载中：{name}';
	@override String get failedToLoad => '加载失败：{name}';
}

// Path: lyrics
class _TranslationsLyricsZhHans implements TranslationsLyricsEn {
	_TranslationsLyricsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get noLyrics => '暂无歌词';
}

// Path: floatingLyrics
class _TranslationsFloatingLyricsZhHans implements TranslationsFloatingLyricsEn {
	_TranslationsFloatingLyricsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get noLyrics => '暂无歌词';
}

// Path: songPicker
class _TranslationsSongPickerZhHans implements TranslationsSongPickerEn {
	_TranslationsSongPickerZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get selectSongs => '选择歌曲';
	@override String get selectSong => '选择歌曲';
	@override String get searchHint => '搜索歌曲...';
	@override String get noSongsFound => '未找到歌曲';
	@override String get noSongsInLibrary => '曲库中没有歌曲';
	@override String get addSongs => '添加歌曲';
}

// Path: videoRemoval
class _TranslationsVideoRemovalZhHans implements TranslationsVideoRemovalEn {
	_TranslationsVideoRemovalZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '移除画面源';
	@override String get message => '画面源"{videoName}"包含已提取的音频源"{audioName}"。是否也要删除音频源？';
	@override String get cancel => '取消';
	@override String get keepAudio => '保留音频';
	@override String get removeBoth => '全部删除';
}

// Path: debug
class _TranslationsDebugZhHans implements TranslationsDebugEn {
	_TranslationsDebugZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get audioEntriesTitle => '音频条目调试';
	@override String get temporarySongUnitsFound => '找到临时歌曲单元：{count}';
	@override String get refresh => '刷新';
	@override String get temporarySongUnits => '临时歌曲单元';
	@override String get close => '关闭';
	@override String get showEntries => '显示条目';
}

// Path: dialogs
class _TranslationsDialogsZhHans implements TranslationsDialogsEn {
	_TranslationsDialogsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get confirmModeChange => '确认模式更改';
	@override String get changeMode => '更改模式';
	@override String get discoveringAudioFiles => '正在发现音频文件';
	@override String get rescanningAudioFiles => '正在重新扫描音频文件';
	@override String get noLibraryLocationsConfigured => '未配置曲库位置';
	@override String get errorLoadingLocations => '加载位置出错';
	@override String get kDefault => '默认';
	@override String get addLocationToStoreMusic => '添加位置以存储音乐库';
	@override String get noLocationsTitle => '未配置曲库位置';
	@override String get noLocationsMessage => '添加位置以存储音乐库';
	@override String get addNestedGroup => '添加嵌套分组';
	@override String get removeGroup => '移除分组';
	@override String get removeGroupQuestion => '如何移除 "{groupName}"？';
	@override String get ungroupKeepSongs => '取消分组（保留歌曲）';
	@override String get removeAll => '全部移除';
	@override String get renameGroup => '重命名分组';
	@override String get createNestedGroup => '创建嵌套分组';
	@override String get createGroup => '创建分组';
	@override String get selectThumbnail => '选择缩略图';
	@override String get errorAddingCustomThumbnail => '添加自定义缩略图出错：{error}';
	@override String get noResultsEnterSearch => '未找到结果。请输入搜索词并按搜索。';
	@override String get editProvider => '编辑';
	@override String get deleteProvider => '删除';
	@override String get providerId => 'ID: {providerId}';
	@override String get providerUrl => 'URL: {baseUrl}';
	@override String get providerApiKey => 'API 密钥：•••••••- ';
	@override String get deleteSongUnit => '删除歌曲单元';
	@override String get alsoDeleteConfigFile => '同时删除配置文件';
	@override String get configFileNote => '删除 beadline-*.json 文件。源文件不受影响。';
	@override String get deleteOriginalAfterMerge => '合并后删除原始歌曲单元';
	@override String get deleteItemsConfirm => '确定要删除 {count} 项吗？';
	@override String get deletedItems => '已删除 {count} 项';
	@override String get importComplete => '导入完成';
	@override String get imported => '已导入：{count}';
	@override String get skippedDuplicates => '已跳过（重复）：{count}';
	@override String get importMore => '... 还有 {count} 条';
	@override String get promotedToSongUnit => '已将 "{name}" 提升为歌曲单元';
	@override String get exportedTo => '已导出到 {path}';
	@override String get promoted => '已将 "{displayName}" 提升为歌曲单元';
	@override String get resetFailed => '重置失败：{error}';
	@override String get confirmTitle => '确认模式更改';
	@override String get changeModeButton => '更改模式';
	@override String get migratingConfig => '正在迁移配置';
	@override String get migratingEntryPoints => '正在迁移入口点文件...';
	@override String get scanningForSongUnits => '正在扫描歌曲单元...';
	@override String get errorScanning => '扫描出错：{error}';
	@override String get errorClearingAudio => '清除音频条目出错：{error}';
	@override String get errorRescanning => '重新扫描出错：{error}';
	@override String get failedToRename => '重命名失败：{error}';
	@override String get failedToRemove => '移除失败：{error}';
	@override String get failedToSetDefault => '设置默认失败：{error}';
	@override String get migrationError => '迁移出错：{error}';
	@override late final _TranslationsDialogsHomeZhHans home = _TranslationsDialogsHomeZhHans._(_root);
	@override late final _TranslationsDialogsProgressDialogsZhHans progressDialogs = _TranslationsDialogsProgressDialogsZhHans._(_root);
	@override late final _TranslationsDialogsLibraryLocationsErrorZhHans libraryLocationsError = _TranslationsDialogsLibraryLocationsErrorZhHans._(_root);
}

// Path: configModeChange
class _TranslationsConfigModeChangeZhHans implements TranslationsConfigModeChangeEn {
	_TranslationsConfigModeChangeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '确认模式更改';
	@override String get description => '更改配置模式将迁移入口点文件。这可能需要一些时间。';
	@override String get inPlaceDescription => '这将在音乐文件旁边创建 beadline-*.json 文件。你的曲库将可以在不同设备间携带。';
	@override String get centralizedDescription => '这将把入口点文件移动到应用数据目录。你的曲库将不再可携带。';
	@override String get changeMode => '更改模式';
}

// Path: app_routes
class _TranslationsAppRoutesZhHans implements TranslationsAppRoutesEn {
	_TranslationsAppRoutesZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get routeNotFound => '未找到路由：{name}';
}

// Path: loading_indicator
class _TranslationsLoadingIndicatorZhHans implements TranslationsLoadingIndicatorEn {
	_TranslationsLoadingIndicatorZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get percentage => '{percentage}%';
}

// Path: video_removal_prompt
class _TranslationsVideoRemovalPromptZhHans implements TranslationsVideoRemovalPromptEn {
	_TranslationsVideoRemovalPromptZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '移除画面源';
	@override String get message => '画面源"{videoName}"包含已提取的音频源"{audioName}"。是否也要删除音频源？';
	@override String get keepAudio => '保留音频';
	@override String get removeBoth => '全部删除';
}

// Path: library_location_setup_dialog
class _TranslationsLibraryLocationSetupDialogZhHans implements TranslationsLibraryLocationSetupDialogEn {
	_TranslationsLibraryLocationSetupDialogZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '选择音乐库位置';
}

// Path: home_page
class _TranslationsHomePageZhHans implements TranslationsHomePageEn {
	_TranslationsHomePageZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get renameGroup => '重命名分组';
}

// Path: song_unit_editor
class _TranslationsSongUnitEditorZhHans implements TranslationsSongUnitEditorEn {
	_TranslationsSongUnitEditorZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get addedToSources => '已将 {title} 添加到源';
	@override String get aliasHint => 'title';
}

// Path: library.actions
class _TranslationsLibraryActionsZhHans implements TranslationsLibraryActionsEn {
	_TranslationsLibraryActionsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get viewSongUnits => '查看歌曲单元';
	@override String get convertToSongUnit => '转换为歌曲单元';
	@override String get addToPlaylist => '添加到播放列表';
	@override String get addToQueue => '添加到队列';
	@override String get promoteToSongUnits => '升级为完整歌曲单元';
	@override String get mergeSelected => '合并所选';
	@override String get exportSelected => '导出所选';
	@override String get deleteSelected => '删除所选';
	@override String get selectAll => '全选';
	@override String get addTagsToSelected => '添加标签';
}

// Path: player.displayMode
class _TranslationsPlayerDisplayModeZhHans implements TranslationsPlayerDisplayModeEn {
	_TranslationsPlayerDisplayModeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get label => '画面模式';
	@override String get enabled => '启用';
	@override String get imageOnly => '仅图片';
	@override String get disabled => '禁用';
	@override String get hidden => '隐藏';
}

// Path: player.audioMode
class _TranslationsPlayerAudioModeZhHans implements TranslationsPlayerAudioModeEn {
	_TranslationsPlayerAudioModeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get label => '音频模式';
	@override String get original => '原声';
	@override String get accompaniment => '伴奏';
}

// Path: player.playbackMode
class _TranslationsPlayerPlaybackModeZhHans implements TranslationsPlayerPlaybackModeEn {
	_TranslationsPlayerPlaybackModeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get label => '播放模式';
	@override String get sequential => '顺序播放';
	@override String get repeatOne => '单曲循环';
	@override String get repeatAll => '列表循环';
	@override String get random => '随机播放';
}

// Path: player.lyricsMode
class _TranslationsPlayerLyricsModeZhHans implements TranslationsPlayerLyricsModeEn {
	_TranslationsPlayerLyricsModeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get label => '歌词模式';
	@override String get off => '关闭';
	@override String get screen => '屏幕显示';
	@override String get floating => '悬浮窗';
	@override String get rolling => '滚动显示';
}

// Path: dialogs.home
class _TranslationsDialogsHomeZhHans implements TranslationsDialogsHomeEn {
	_TranslationsDialogsHomeZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get shuffle => '随机排序';
	@override String get rename => '重命名';
	@override String get addNestedGroup => '添加嵌套分组';
	@override String get remove => '移除';
	@override String get removeGroup => '移除分组';
	@override String get removeGroupQuestion => '如何移除 "{groupName}"？';
	@override String get ungroupKeepSongs => '取消分组（保留歌曲）';
	@override String get removeAll => '全部移除';
	@override String get renameGroup => '重命名分组';
	@override String get createNestedGroup => '创建嵌套分组';
	@override String get create => '创建';
	@override String get createGroup => '创建分组';
}

// Path: dialogs.progressDialogs
class _TranslationsDialogsProgressDialogsZhHans implements TranslationsDialogsProgressDialogsEn {
	_TranslationsDialogsProgressDialogsZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get discovering => '正在发现音频文件';
	@override String get rescanning => '正在重新扫描音频文件';
}

// Path: dialogs.libraryLocationsError
class _TranslationsDialogsLibraryLocationsErrorZhHans implements TranslationsDialogsLibraryLocationsErrorEn {
	_TranslationsDialogsLibraryLocationsErrorZhHans._(this._root);

	final TranslationsZhHans _root; // ignore: unused_field

	// Translations
	@override String get noLocationsConfigured => '未配置曲库位置';
	@override String get errorLoading => '加载位置出错';
	@override String get retry => '重试';
}

/// The flat map containing all translations for locale <zh-Hans>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZhHans {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.cancel' => '取消',
			'common.save' => '保存',
			'common.delete' => '删除',
			'common.add' => '添加',
			'common.edit' => '编辑',
			'common.rename' => '重命名',
			'common.create' => '创建',
			'common.close' => '关闭',
			'common.retry' => '重试',
			'common.refresh' => '刷新',
			'common.search' => '搜索',
			'common.ok' => '确定',
			'common.yes' => '是',
			'common.no' => '否',
			'common.back' => '返回',
			'common.skip' => '暂时跳过',
			'common.apply' => '应用',
			'common.remove' => '移除',
			'common.duplicate' => '复制',
			'common.export' => '导出',
			'common.import' => '导入',
			'common.migrate' => '迁移',
			'common.reset' => '重置',
			'common.grant' => '授权',
			'common.enabled' => '已启用',
			'common.disabled' => '已禁用',
			'common.on' => '开',
			'common.off' => '关',
			'common.error' => '错误',
			'common.loading' => '加载中...',
			'common.songs' => '首歌曲',
			'common.selected' => '已选择',
			'common.items' => '项',
			'common.ms' => '毫秒',
			'common.dismiss' => '关闭',
			'common.extract' => '提取',
			'common.extractingThumbnails' => '正在提取缩略图...',
			'common.noThumbnailsAvailable' => '没有可用的缩略图',
			'common.displayVideoImage' => '显示（视频/图片）',
			'common.id' => 'ID',
			'common.url' => 'URL',
			'common.apiKey' => 'API 密钥',
			'common.openParen' => '(',
			'common.closeParen' => ')',
			'common.routeNotFound' => '未找到路由：{name}',
			'common.noResultsEnterSearch' => '未找到结果。请输入搜索词并按搜索。',
			'common.artistLabel' => '艺术家：',
			'common.albumLabel' => '专辑：',
			'common.platformLabel' => '平台：',
			'common.percentage' => '{percentage}%',
			'common.testConnection' => '测试连接',
			'common.disabledInKtvMode' => 'KTV 模式下禁用',
			'common.failedToRename' => '重命名失败：{error}',
			'common.continueText' => '继续',
			'common.artist' => '艺术家',
			'common.album' => '专辑',
			'common.platform' => '平台',
			'common.addImage' => '添加图片',
			'common.shuffle' => '随机排序',
			'common.alreadyInPlaylist' => '已在播放列表中',
			'common.createAndAdd' => '创建并添加',
			'nav.home' => '主页',
			'nav.library' => '曲库',
			'nav.playlists' => '播放列表',
			'nav.tags' => '标签',
			'nav.settings' => '设置',
			'app.name' => '珠链',
			'library.title' => '曲库',
			'library.loading' => '正在加载曲库...',
			'library.searchHint' => '搜索曲库...',
			'library.noLocations' => '未设置曲库位置',
			'library.allLocations' => '所有位置',
			'library.filterByLocation' => '按曲库位置筛选',
			'library.listView' => '列表视图',
			'library.gridView' => '网格视图',
			'library.noItems' => '曲库为空',
			'library.noResults' => '未找到歌曲',
			'library.tryDifferentSearch' => '请尝试其他搜索词',
			'library.audioOnly' => '仅音频',
			'library.noSong' => '无歌曲',
			'library.actions.viewSongUnits' => '查看歌曲单元',
			'library.actions.convertToSongUnit' => '转换为歌曲单元',
			'library.actions.addToPlaylist' => '添加到播放列表',
			'library.actions.addToQueue' => '添加到队列',
			'library.actions.promoteToSongUnits' => '升级为完整歌曲单元',
			'library.actions.mergeSelected' => '合并所选',
			'library.actions.exportSelected' => '导出所选',
			'library.actions.deleteSelected' => '删除所选',
			'library.actions.selectAll' => '全选',
			'library.actions.addTagsToSelected' => '添加标签',
			'library.processing' => '处理中...',
			'library.exportedTo' => '已导出到 {path}',
			'library.importComplete' => '导入完成',
			'library.imported' => '已导入：{count}',
			'library.skippedDuplicates' => '已跳过（重复）：{count}',
			'library.importMore' => '... 还有 {count} 条',
			'library.promotedToSongUnit' => '已将 "{name}" 提升为歌曲单元',
			'library.deleteItemsConfirm' => '确定要删除 {count} 项吗？',
			'library.deletedItems' => '已删除 {count} 项',
			'library.addedItemsToQueue' => '已将 {count} 项加入队列',
			'library.noTemporaryEntriesSelected' => '未选择临时条目',
			'library.addSongsToPlaylistTitle' => '将 {count} 首歌曲添加到播放列表',
			'library.noPlaylistsCreateFirst' => '暂无播放列表。请先创建一个。',
			'library.sectionMetadata' => '元数据',
			'library.sectionSources' => '源',
			'library.sectionTags' => '标签',
			'library.errorLoadingLibrary' => '加载曲库出错',
			'library.deleteSongUnit' => '删除歌曲单元',
			'library.alsoDeleteConfigFile' => '同时删除配置文件',
			'library.configFileNote' => '删除 beadline-*.json 文件。源文件不受影响。',
			'library.deleteOriginalAfterMerge' => '合并后删除原始歌曲单元',
			'library.selectedCount' => '{count} 已选择',
			'library.alreadyInPlaylist' => '已在播放列表中',
			'library.createAndAdd' => '创建并添加',
			'library.promoted' => '已将 "{displayName}" 提升为歌曲单元',
			'player.noSongPlaying' => '未在播放',
			'player.source' => '源',
			'player.display' => '画面',
			'player.audio' => '音频',
			'player.playback' => '播放',
			'player.lyrics' => '歌词',
			'player.fullscreen' => '全屏',
			'player.exitFullscreen' => '退出全屏 (ESC)',
			'player.selectSources' => '选择源',
			'player.play' => '播放',
			'player.pause' => '暂停',
			'player.next' => '下一首',
			'player.displayMode.label' => '画面模式',
			'player.displayMode.enabled' => '启用',
			'player.displayMode.imageOnly' => '仅图片',
			'player.displayMode.disabled' => '禁用',
			'player.displayMode.hidden' => '隐藏',
			'player.audioMode.label' => '音频模式',
			'player.audioMode.original' => '原声',
			'player.audioMode.accompaniment' => '伴奏',
			'player.playbackMode.label' => '播放模式',
			'player.playbackMode.sequential' => '顺序播放',
			'player.playbackMode.repeatOne' => '单曲循环',
			'player.playbackMode.repeatAll' => '列表循环',
			'player.playbackMode.random' => '随机播放',
			'player.lyricsMode.label' => '歌词模式',
			'player.lyricsMode.off' => '关闭',
			'player.lyricsMode.screen' => '屏幕显示',
			'player.lyricsMode.floating' => '悬浮窗',
			'player.lyricsMode.rolling' => '滚动显示',
			'queue.title' => '队列',
			'queue.manage' => '管理队列',
			'queue.removeDuplicates' => '移除重复',
			'queue.shuffle' => '随机排序',
			'queue.removeAfterPlayOn' => '播完移除：开',
			'queue.removeAfterPlayOff' => '播完移除：关',
			'queue.clearQueue' => '清空队列',
			'queue.removedDuplicates' => '已移除 {count} 个重复项',
			'queue.noDuplicates' => '未发现重复项',
			'queue.manageQueues' => '管理队列',
			'queue.queueContent' => '队列内容',
			'queue.backToQueues' => '返回队列列表',
			'queue.createQueue' => '新建队列',
			'queue.queueName' => '队列名称',
			'queue.enterQueueName' => '输入队列名称',
			'queue.renameQueue' => '重命名队列',
			'queue.enterNewName' => '输入新名称',
			'queue.deleteQueue' => '删除队列',
			'queue.deleteQueueConfirm' => '确定要删除',
			'queue.deleteQueueWillRemove' => '这将从此队列中移除',
			'queue.deleteQueueFromQueue' => '首歌曲',
			'queue.switchToQueue' => '切换到此队列',
			'queue.empty' => '队列为空',
			'queue.songs' => '{count} 首歌曲',
			'queue.actions' => '队列操作',
			'queue.collapse' => '折叠',
			'queue.expand' => '展开',
			'queue.groupActions' => '分组操作',
			'search.title' => '搜索',
			'search.songUnits' => '歌曲单元',
			'search.sources' => '源',
			'search.hint' => '搜索...',
			'search.textMode' => '文本模式',
			'search.queryBuilder' => '条件构建器',
			'search.tag' => '标签',
			'search.tagExample' => '例：artist:value',
			'search.range' => '范围',
			'search.rangeExample' => '例：time:[2020-2024]',
			'search.searching' => '搜索中...',
			'search.searchError' => '搜索出错',
			'search.noSongUnitsFound' => '未找到歌曲单元',
			'search.loadMore' => '加载更多',
			'search.play' => '播放',
			'search.addToQueue' => '添加到队列',
			'search.all' => '全部',
			'search.local' => '本地',
			'search.online' => '在线',
			'search.searchingSources' => '正在搜索源...',
			'search.noOnlineSources' => '未找到在线源',
			'search.noLocalSources' => '未找到本地源',
			'search.noSources' => '未找到源',
			'search.addToSongUnit' => '添加到歌曲单元',
			'search.or' => '或',
			'search.not' => '非',
			'search.addedToQueue' => '已将"{title}"添加到队列',
			'search.addSource' => '添加源：{title}',
			'tags.title' => '标签',
			'tags.noTags' => '暂无标签',
			'tags.noTagsHint' => '创建标签来整理你的音乐',
			'tags.loadError' => '加载标签失败',
			'tags.createTag' => '创建标签',
			'tags.createChildTag' => '创建子标签',
			'tags.tagName' => '标签名称',
			'tags.addAlias' => '添加别名',
			'tags.addAliasFor' => '为以下标签添加别名',
			'tags.aliasName' => '别名',
			'tags.enterAlias' => '输入别名',
			'tags.addChildTag' => '添加子标签',
			'tags.deleteTag' => '删除标签',
			'tags.deleteTagTitle' => '删除标签？',
			'tags.deleteTagConfirm' => '此操作无法撤销',
			'tags.deleteTagHasChildren' => '此标签有子标签，它们将成为根标签。',
			'tags.deleteTagAliases' => '别名也将被删除。',
			'tags.deletedTag' => '已删除标签',
			'tags.removeFromSong' => '从此歌曲移除标签',
			'tags.removeAll' => '全部移除',
			'tags.viewSongUnits' => '查看歌曲单元',
			'tags.item' => '项',
			'tags.items' => '项',
			'tags.songUnit' => '个歌曲单元',
			'tags.songUnits' => '个歌曲单元',
			'tags.lockedCollection' => '已锁定的集合',
			'tags.collection' => '集合',
			'tags.locked' => '已锁定',
			'playlists.title' => '播放列表',
			'playlists.noPlaylists' => '暂无播放列表',
			'playlists.noPlaylistsHint' => '右键或长按以创建播放列表',
			'playlists.selectPlaylist' => '选择播放列表以查看内容',
			'playlists.createPlaylist' => '创建播放列表',
			'playlists.addSongs' => '添加歌曲',
			'playlists.createGroup' => '创建分组',
			'playlists.moveToGroup' => '移动到分组',
			'playlists.addCollectionRef' => '添加合集引用',
			'playlists.renamePlaylist' => '重命名播放列表',
			'playlists.deletePlaylist' => '删除播放列表',
			'playlists.deletePlaylistConfirm' => '确定要删除',
			'playlists.deletePlaylistNote' => '歌曲不会被删除，仅删除此播放列表',
			'playlists.createGroupTitle' => '创建分组',
			'playlists.createGroupHint' => '创建一个分组',
			'playlists.groupName' => '分组名称',
			'playlists.enterGroupName' => '输入分组名称',
			'playlists.addCollectionRefTitle' => '添加合集引用',
			'playlists.noOtherCollections' => '没有其他可用合集',
			'playlists.addReferenceTo' => '添加引用到',
			'playlists.lock' => '锁定',
			'playlists.unlock' => '解锁',
			'playlists.viewContent' => '查看内容',
			'playlists.toggleSelectionMode' => '切换选择模式',
			'playlists.noGroupsAvailable' => '没有可用的分组。请先创建一个分组。',
			'playlists.song' => '首歌曲',
			'playlists.songs' => '首歌曲',
			'playlists.locked' => '已锁定',
			'playlists.clearSelection' => '清除选择',
			'playlists.selected' => '已选择',
			'playlists.removeFromGroup' => '从分组中移除',
			'playlists.alreadyInPlaylist' => '已在播放列表中',
			'playlists.addedToPlaylist' => '已添加到 "{name}"',
			'playlists.createdPlaylistAndAdded' => '已创建播放列表 "{name}" 并添加了歌曲',
			'playlists.createAndAdd' => '创建并添加',
			'playlists.songCount' => '{count} 首歌曲',
			'playlists.noSongsInGroup' => '此分组中没有歌曲',
			'playlists.dropHere' => '拖放到此处',
			'playlists.groupCreated' => '已创建分组 "{name}"',
			'playlists.failedToCreateGroup' => '创建分组失败：{error}',
			'songEditor.titleEdit' => '编辑歌曲单元',
			'songEditor.titleNew' => '新建歌曲单元',
			'songEditor.reloadMetadata' => '从源重新加载元数据',
			'songEditor.writeMetadata' => '将元数据写入源',
			'songEditor.sources' => '源',
			'songEditor.display' => '画面',
			'songEditor.audio' => '音频',
			'songEditor.accompaniment' => '伴奏',
			'songEditor.lyricsLabel' => '歌词',
			'songEditor.noDisplaySources' => '无画面源',
			'songEditor.noAudioSources' => '无音频源',
			'songEditor.noAccompanimentSources' => '无伴奏源',
			'songEditor.noLyricsSources' => '无歌词源',
			'songEditor.addDisplaySource' => '添加画面源',
			'songEditor.addAudioSource' => '添加音频源',
			'songEditor.addAccompanimentSource' => '添加伴奏源',
			'songEditor.addLyricsSource' => '添加歌词源',
			'songEditor.editDisplayName' => '编辑显示名称',
			'songEditor.setOffset' => '设置偏移',
			'songEditor.setOffsetTitle' => '设置偏移量',
			'songEditor.offsetHint' => '与音频对齐的毫秒偏移量',
			'songEditor.offsetNote' => '正值 = 延迟，负值 = 提前',
			'songEditor.offsetLabel' => '偏移量（毫秒）',
			'songEditor.editDisplayNameTitle' => '编辑显示名称',
			'songEditor.originalName' => '原始',
			'songEditor.displayNameLabel' => '显示名称',
			'songEditor.displayNameHint' => '留空则使用原始名称',
			'songEditor.addSource' => '添加源',
			'songEditor.localFile' => '本地文件',
			'songEditor.enterUrl' => '输入 URL',
			'songEditor.urlLabel' => 'URL',
			'songEditor.urlHint' => 'https://...',
			'songEditor.selectSong' => '选择歌曲',
			'songEditor.selectSongs' => '选择歌曲',
			'songEditor.addSongs' => '添加歌曲',
			'songEditor.artist' => '艺术家',
			'songEditor.thumbnail' => '缩略图',
			'songEditor.addImage' => '添加图片',
			'songEditor.selectThumbnails' => '选择 ({count})',
			'songEditor.selectThumbnailTitle' => '选择缩略图',
			'songEditor.errorAddingCustomThumbnail' => '添加自定义缩略图出错：{error}',
			'songEditor.audioExtracted' => '从 {name} 提取的音频轨道',
			'songEditor.noAudioFound' => '在 {name} 中未找到音频轨道',
			'songEditor.autoDiscovered' => '自动发现：{types}',
			'songEditor.chooseMetadataValues' => '为每个元数据字段选择值：',
			'songEditor.builtInTagsMetadata' => '内置标签（元数据）',
			'songEditor.userTags' => '用户标签',
			'songEditor.noUserTags' => '暂无用户标签。请在标签管理中创建。',
			'songEditor.tagNameName' => '名称',
			'songEditor.tagNameAlbum' => '专辑',
			'songEditor.tagNameTime' => '年份',
			'songEditor.aliasHintTitle' => '标题',
			'songEditor.addImageOrExtract' => '添加图片或从音频文件提取',
			'songEditor.thumbnailsAvailable' => '有 {count} 个缩略图可用',
			'songEditor.removeFromCollection' => '从集合中移除',
			'songEditor.metadataWriteNotImplemented' => '元数据写入功能尚未实现，需要外部库支持。',
			'songEditor.linkedVideoFrom' => '来自：{name}',
			'songEditor.offsetDisplay' => '偏移：{value}',
			'songEditor.searchOnlineSources' => '搜索在线源',
			'songEditor.providerLabel' => '提供商',
			'songEditor.sourceTypeLabel' => '源类型',
			'songEditor.searchQueryLabel' => '搜索关键词',
			'songEditor.durationDisplay' => '时长：{value}',
			'songEditor.addToSongUnit' => '添加到曲目单元',
			'songEditor.cannotSaveInPlaceNoLocations' => '就地模式下无法保存曲目单元，请先在设置中配置至少一个音乐库位置。',
			'songEditor.failedToLoadUrl' => '无法从 URL 加载媒体，URL 可能无效或不可达。',
			'songEditor.urlNotDirectMedia' => '警告：URL 似乎不是直接媒体文件。请使用音频/视频文件的直接链接（如 .mp3、.mp4），而非网页链接。',
			'songEditor.noAudioSourcesForMetadata' => '没有可提取元数据的音频源',
			'songEditor.cannotExtractFromApi' => '无法从 API 源提取元数据',
			'songEditor.metadataReloaded' => '元数据已重新加载',
			'songEditor.addedSource' => '已添加 {title}',
			'settings.title' => '设置',
			'settings.user' => '用户',
			'settings.username' => '用户名',
			'settings.appearance' => '外观',
			'settings.theme' => '主题',
			'settings.themeSystem' => '跟随系统',
			'settings.themeLight' => '浅色',
			'settings.themeDark' => '深色',
			'settings.accentColor' => '主题色',
			'settings.accentColorHint' => '自定义应用颜色',
			'settings.language' => '语言',
			'settings.languageSystemDefault' => '跟随系统',
			'settings.languageSelectorTitle' => '选择语言',
			'settings.languageSelectorSubtitle' => '选择您偏好的应用语言',
			'settings.languageSelectorHint' => '您可以稍后在设置中更改语言',
			'settings.languageSelectorContinue' => '继续',
			'settings.playback' => '播放',
			'settings.lyricsMode' => '歌词模式',
			'settings.ktvMode' => 'KTV 模式',
			'settings.ktvModeHint' => '强制屏幕歌词，禁用悬浮窗',
			'settings.hideDisplayPanel' => '隐藏画面面板',
			'settings.hideDisplayPanelHint' => '仅显示歌词和控制栏（纯音乐模式）',
			'settings.thumbnailBgLibrary' => '曲库使用缩略图背景',
			'settings.thumbnailBgLibraryHint' => '在曲库视图中将缩略图用作背景',
			'settings.thumbnailBgQueue' => '队列使用缩略图背景',
			'settings.thumbnailBgQueueHint' => '在队列中将缩略图用作背景',
			'settings.storage' => '存储',
			'settings.configMode' => '配置模式',
			'settings.configModeCentralized' => '集中存储',
			'settings.configModeInPlace' => '就地存储',
			'settings.libraryLocations' => '曲库位置',
			'settings.libraryLocationsHint' => '管理音乐文件的存储位置',
			'settings.metadataWriteback' => '元数据回写',
			'settings.metadataWritebackHint' => '将标签更改同步到源文件',
			'settings.autoDiscoverAudio' => '自动发现音频文件',
			'settings.autoDiscoverAudioHint' => '自动从曲库位置添加音频文件',
			'settings.debug' => '调试',
			'settings.audioEntriesDebug' => '音频条目调试',
			'settings.audioEntriesDebugHint' => '查看已发现的音频条目',
			'settings.rescanAudio' => '重新扫描音频文件',
			'settings.rescanAudioHint' => '清除并重新发现所有音频文件（含更新的元数据）',
			'settings.about' => '关于',
			'settings.version' => '版本',
			'settings.license' => '许可证',
			'settings.licenseValue' => 'GNU Affero 通用公共许可证 v3.0 (AGPL-3.0)',
			'settings.resetFactory' => '恢复出厂设置',
			'settings.resetFactoryHint' => '将所有设置重置为默认值',
			'settings.system' => '系统',
			'settings.resetFactoryTitle' => '恢复出厂设置？',
			'settings.resetFactoryBody' => '这将把应用完全重置为初始状态',
			'settings.resetFactoryItems' => '所有设置和偏好\n歌曲单元库和标签\n播放列表、队列和分组\n播放状态',
			'settings.resetFactoryNote' => '磁盘上的实际音乐文件不会被删除',
			'settings.resetFactoryRestart' => '重置后应用将重启',
			'settings.resetEverything' => '全部重置',
			'settings.rescanTitle' => '重新扫描音频文件',
			'settings.rescanBody' => '这将清除所有已发现的音频条目并重新扫描曲库位置',
			'settings.rescanNote' => '大型曲库可能需要几分钟。是否继续？',
			'settings.rescan' => '重新扫描',
			'settings.migratingConfig' => '正在迁移配置',
			'settings.migratingEntryPoints' => '正在迁移入口点文件...',
			'settings.scanningForSongUnits' => '正在扫描歌曲单元...',
			'settings.storagePermissionTitle' => '需要存储权限',
			'settings.storagePermissionBody' => '珠链需要访问你的音乐文件以发现和播放音频',
			'settings.storagePermissionNote' => '请在下一个对话框中授予存储权限，或前往系统设置手动开启',
			'settings.openSettings' => '打开设置',
			'settings.foundAudioFiles' => '找到 {count} 个音频文件',
			'settings.errorScanning' => '扫描出错：{error}',
			'settings.audioEntriesCleared' => '音频条目已清除',
			'settings.errorClearingAudio' => '清除音频条目出错：{error}',
			'settings.audioRescanSuccess' => '音频文件重新扫描成功',
			'settings.errorRescanning' => '重新扫描出错：{error}',
			'settings.testingConnection' => '正在测试连接...',
			'settings.connectionSuccess' => '连接成功！',
			'settings.connectionFailed' => '连接失败',
			'settings.onlineProviders' => '在线源提供商',
			'libraryLocations.title' => '曲库位置',
			'libraryLocations.selectLocation' => '选择曲库位置',
			'libraryLocations.nameLocation' => '为此位置命名',
			'libraryLocations.enterLocationName' => '输入此位置的名称',
			'libraryLocations.locationAdded' => '曲库位置已添加',
			'libraryLocations.discoveredImported' => '已发现并导入 {count} 个歌曲单元',
			'libraryLocations.switchToInPlace' => '切换到就地存储',
			'libraryLocations.switchToCentralized' => '切换到集中存储',
			'libraryLocations.migrateToInPlaceBody' => '这将把所有入口点文件从集中存储移动到 {path}，与音频源放在一起',
			'libraryLocations.migrateToCentralizedBody' => '这将把所有入口点文件从 {path} 移动到集中存储',
			'libraryLocations.switchedToInPlace' => '已切换到就地存储模式',
			'libraryLocations.switchedToCentralized' => '已切换到集中存储模式',
			'libraryLocations.migrationFailed' => '迁移失败',
			'libraryLocations.migrationError' => '迁移出错：{error}',
			'libraryLocations.renameLocation' => '重命名位置',
			'libraryLocations.nameLabel' => '名称',
			'libraryLocations.removeLocation' => '移除曲库位置',
			'libraryLocations.removeLocationConfirm' => '确定要移除 "{name}"？',
			'libraryLocations.removeLocationNote' => '从此位置发现的歌曲单元和音频条目将从曲库中移除。磁盘上的文件不会被删除。',
			'libraryLocations.removed' => '已移除 "{name}"',
			'libraryLocations.failedToRemove' => '移除失败：{error}',
			'libraryLocations.isNowDefault' => '"{name}" 现在是默认位置',
			'libraryLocations.failedToSetDefault' => '设置默认位置失败：{error}',
			'libraryLocations.accessible' => '可访问',
			'libraryLocations.inaccessible' => '不可访问',
			'libraryLocations.inPlace' => '就地存储',
			'libraryLocations.centralized' => '集中存储',
			'libraryLocations.setAsDefault' => '设为默认',
			'locationSetup.title' => '设置曲库位置',
			'locationSetup.description' => '添加存储音乐文件的文件夹。珠链将自动扫描这些位置并监控变化。',
			'locationSetup.storagePermissionRequired' => '需要存储权限',
			'locationSetup.selectedLocations' => '已选位置',
			'locationSetup.addLocation' => '添加曲库位置',
			'locationSetup.firstLocationNote' => '第一个位置将作为新歌曲单元的默认位置',
			'configMode.title' => '欢迎使用珠链',
			'configMode.subtitle' => '选择曲库配置的存储方式',
			'configMode.centralizedTitle' => '集中存储',
			'configMode.centralizedDesc' => '将所有配置存储在应用数据目录中',
			'configMode.centralizedPros' => '数据集中管理\n易于备份和恢复\n标准应用行为',
			'configMode.centralizedCons' => '跨设备可移植性较差\n共享需手动导出',
			'configMode.inPlaceTitle' => '就地存储',
			'configMode.inPlaceDesc' => '将歌曲单元元数据与音乐文件存放在一起',
			'configMode.inPlacePros' => '跨设备可便携\n自动发现歌曲单元\n元数据与文件同在',
			'configMode.inPlaceCons' => '会在音乐文件夹中创建 beadline-*.json 文件\n需要设置存储位置',
			'configMode.changeNote' => '你可以稍后在 设置 > 存储 中更改此设置',
			'onlineProviders.title' => '在线源提供商',
			'onlineProviders.noProviders' => '未配置提供商',
			'onlineProviders.noProvidersHint' => '添加提供商以搜索在线源',
			'onlineProviders.addProvider' => '添加提供商',
			'onlineProviders.editProvider' => '编辑提供商',
			'onlineProviders.providerIdLabel' => '提供商 ID',
			'onlineProviders.providerIdHint' => 'bilibili、netease 等',
			'onlineProviders.displayNameLabel' => '显示名称',
			'onlineProviders.displayNameHint' => '哔哩哔哩、网易云音乐等',
			'onlineProviders.baseUrlLabel' => '基础 URL',
			'onlineProviders.baseUrlHint' => 'http://localhost:3000',
			'onlineProviders.apiKeyOptional' => 'API 密钥（可选）',
			'onlineProviders.apiKeyHint' => '不需要则留空',
			'onlineProviders.timeoutLabel' => '超时（秒）',
			'onlineProviders.timeoutDefault' => '10',
			'onlineProviders.timeoutError' => '超时必须为正数',
			'display.noSource' => '无画面源',
			'display.loading' => '加载中：{name}',
			'display.failedToLoad' => '加载失败：{name}',
			'lyrics.noLyrics' => '暂无歌词',
			'floatingLyrics.noLyrics' => '暂无歌词',
			'songPicker.selectSongs' => '选择歌曲',
			'songPicker.selectSong' => '选择歌曲',
			'songPicker.searchHint' => '搜索歌曲...',
			'songPicker.noSongsFound' => '未找到歌曲',
			'songPicker.noSongsInLibrary' => '曲库中没有歌曲',
			'songPicker.addSongs' => '添加歌曲',
			'videoRemoval.title' => '移除画面源',
			'videoRemoval.message' => '画面源"{videoName}"包含已提取的音频源"{audioName}"。是否也要删除音频源？',
			'videoRemoval.cancel' => '取消',
			'videoRemoval.keepAudio' => '保留音频',
			'videoRemoval.removeBoth' => '全部删除',
			'debug.audioEntriesTitle' => '音频条目调试',
			'debug.temporarySongUnitsFound' => '找到临时歌曲单元：{count}',
			'debug.refresh' => '刷新',
			'debug.temporarySongUnits' => '临时歌曲单元',
			'debug.close' => '关闭',
			'debug.showEntries' => '显示条目',
			'dialogs.confirmModeChange' => '确认模式更改',
			'dialogs.changeMode' => '更改模式',
			'dialogs.discoveringAudioFiles' => '正在发现音频文件',
			'dialogs.rescanningAudioFiles' => '正在重新扫描音频文件',
			'dialogs.noLibraryLocationsConfigured' => '未配置曲库位置',
			'dialogs.errorLoadingLocations' => '加载位置出错',
			'dialogs.kDefault' => '默认',
			'dialogs.addLocationToStoreMusic' => '添加位置以存储音乐库',
			'dialogs.noLocationsTitle' => '未配置曲库位置',
			'dialogs.noLocationsMessage' => '添加位置以存储音乐库',
			'dialogs.addNestedGroup' => '添加嵌套分组',
			'dialogs.removeGroup' => '移除分组',
			'dialogs.removeGroupQuestion' => '如何移除 "{groupName}"？',
			'dialogs.ungroupKeepSongs' => '取消分组（保留歌曲）',
			_ => null,
		} ?? switch (path) {
			'dialogs.removeAll' => '全部移除',
			'dialogs.renameGroup' => '重命名分组',
			'dialogs.createNestedGroup' => '创建嵌套分组',
			'dialogs.createGroup' => '创建分组',
			'dialogs.selectThumbnail' => '选择缩略图',
			'dialogs.errorAddingCustomThumbnail' => '添加自定义缩略图出错：{error}',
			'dialogs.noResultsEnterSearch' => '未找到结果。请输入搜索词并按搜索。',
			'dialogs.editProvider' => '编辑',
			'dialogs.deleteProvider' => '删除',
			'dialogs.providerId' => 'ID: {providerId}',
			'dialogs.providerUrl' => 'URL: {baseUrl}',
			'dialogs.providerApiKey' => 'API 密钥：•••••••- ',
			'dialogs.deleteSongUnit' => '删除歌曲单元',
			'dialogs.alsoDeleteConfigFile' => '同时删除配置文件',
			'dialogs.configFileNote' => '删除 beadline-*.json 文件。源文件不受影响。',
			'dialogs.deleteOriginalAfterMerge' => '合并后删除原始歌曲单元',
			'dialogs.deleteItemsConfirm' => '确定要删除 {count} 项吗？',
			'dialogs.deletedItems' => '已删除 {count} 项',
			'dialogs.importComplete' => '导入完成',
			'dialogs.imported' => '已导入：{count}',
			'dialogs.skippedDuplicates' => '已跳过（重复）：{count}',
			'dialogs.importMore' => '... 还有 {count} 条',
			'dialogs.promotedToSongUnit' => '已将 "{name}" 提升为歌曲单元',
			'dialogs.exportedTo' => '已导出到 {path}',
			'dialogs.promoted' => '已将 "{displayName}" 提升为歌曲单元',
			'dialogs.resetFailed' => '重置失败：{error}',
			'dialogs.confirmTitle' => '确认模式更改',
			'dialogs.changeModeButton' => '更改模式',
			'dialogs.migratingConfig' => '正在迁移配置',
			'dialogs.migratingEntryPoints' => '正在迁移入口点文件...',
			'dialogs.scanningForSongUnits' => '正在扫描歌曲单元...',
			'dialogs.errorScanning' => '扫描出错：{error}',
			'dialogs.errorClearingAudio' => '清除音频条目出错：{error}',
			'dialogs.errorRescanning' => '重新扫描出错：{error}',
			'dialogs.failedToRename' => '重命名失败：{error}',
			'dialogs.failedToRemove' => '移除失败：{error}',
			'dialogs.failedToSetDefault' => '设置默认失败：{error}',
			'dialogs.migrationError' => '迁移出错：{error}',
			'dialogs.home.shuffle' => '随机排序',
			'dialogs.home.rename' => '重命名',
			'dialogs.home.addNestedGroup' => '添加嵌套分组',
			'dialogs.home.remove' => '移除',
			'dialogs.home.removeGroup' => '移除分组',
			'dialogs.home.removeGroupQuestion' => '如何移除 "{groupName}"？',
			'dialogs.home.ungroupKeepSongs' => '取消分组（保留歌曲）',
			'dialogs.home.removeAll' => '全部移除',
			'dialogs.home.renameGroup' => '重命名分组',
			'dialogs.home.createNestedGroup' => '创建嵌套分组',
			'dialogs.home.create' => '创建',
			'dialogs.home.createGroup' => '创建分组',
			'dialogs.progressDialogs.discovering' => '正在发现音频文件',
			'dialogs.progressDialogs.rescanning' => '正在重新扫描音频文件',
			'dialogs.libraryLocationsError.noLocationsConfigured' => '未配置曲库位置',
			'dialogs.libraryLocationsError.errorLoading' => '加载位置出错',
			'dialogs.libraryLocationsError.retry' => '重试',
			'configModeChange.title' => '确认模式更改',
			'configModeChange.description' => '更改配置模式将迁移入口点文件。这可能需要一些时间。',
			'configModeChange.inPlaceDescription' => '这将在音乐文件旁边创建 beadline-*.json 文件。你的曲库将可以在不同设备间携带。',
			'configModeChange.centralizedDescription' => '这将把入口点文件移动到应用数据目录。你的曲库将不再可携带。',
			'configModeChange.changeMode' => '更改模式',
			'app_routes.routeNotFound' => '未找到路由：{name}',
			'loading_indicator.percentage' => '{percentage}%',
			'video_removal_prompt.title' => '移除画面源',
			'video_removal_prompt.message' => '画面源"{videoName}"包含已提取的音频源"{audioName}"。是否也要删除音频源？',
			'video_removal_prompt.keepAudio' => '保留音频',
			'video_removal_prompt.removeBoth' => '全部删除',
			'library_location_setup_dialog.title' => '选择音乐库位置',
			'home_page.renameGroup' => '重命名分组',
			'song_unit_editor.addedToSources' => '已将 {title} 添加到源',
			'song_unit_editor.aliasHint' => 'title',
			_ => null,
		};
	}
}
