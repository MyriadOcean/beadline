// FRB-exposed collection repository functions
//
// Thin wrappers that read the global DB connection and delegate
// to beadline_tags::collection_repository.

use beadline_tags::model::collection::{
    Collection, CollectionItem, CollectionItemType, CollectionType,
};
use super::database_api::lock_db;

// ── FRB-transparent structs ────────────────────────────────────────────

/// FRB-transparent collection representation.
/// All fields are simple types so FRB generates a non-opaque Dart class.
#[derive(Debug)]
pub struct DartCollection {
    pub id: String,
    pub name: String,
    pub collection_type: String, // "playlist", "queue", "group"
    pub is_locked: bool,
    pub display_order: i32,
    pub items: Vec<DartCollectionItem>,
    pub current_index: i32,
    pub playback_position_ms: i64,
    pub was_playing: bool,
    pub remove_after_play: bool,
    pub is_queue: bool,
    pub created_at: String,
    pub updated_at: String,
    // Tag fields
    pub parent_id: Option<String>,
    pub alias_names: Vec<String>,
    pub include_children: bool,
    pub is_group: bool,
}

/// FRB-transparent collection item representation.
#[derive(Debug)]
pub struct DartCollectionItem {
    pub id: String,
    pub item_type: String, // "songUnit", "collectionReference"
    pub target_id: String,
    pub order: i32,
    pub inherit_lock: bool,
}

// ── Conversion functions ───────────────────────────────────────────────

fn collection_type_to_string(ct: &CollectionType) -> &'static str {
    match ct {
        CollectionType::Playlist => "playlist",
        CollectionType::Queue => "queue",
        CollectionType::Group => "group",
    }
}

fn string_to_collection_type(s: &str) -> CollectionType {
    match s {
        "queue" => CollectionType::Queue,
        "group" => CollectionType::Group,
        _ => CollectionType::Playlist,
    }
}

fn item_type_to_string(it: &CollectionItemType) -> &'static str {
    match it {
        CollectionItemType::SongUnit => "songUnit",
        CollectionItemType::CollectionReference => "collectionReference",
    }
}

fn string_to_item_type(s: &str) -> CollectionItemType {
    match s {
        "collectionReference" => CollectionItemType::CollectionReference,
        _ => CollectionItemType::SongUnit,
    }
}

fn to_dart_collection_item(item: &CollectionItem) -> DartCollectionItem {
    DartCollectionItem {
        id: item.id.clone(),
        item_type: item_type_to_string(&item.item_type).to_string(),
        target_id: item.target_id.clone(),
        order: item.order,
        inherit_lock: item.inherit_lock,
    }
}

fn to_dart_collection(c: Collection) -> DartCollection {
    let ct_str = collection_type_to_string(&c.collection_type);
    let dart_items: Vec<DartCollectionItem> = c.metadata.items.iter().map(to_dart_collection_item).collect();
    DartCollection {
        id: c.tag.id,
        name: c.tag.value,
        collection_type: ct_str.to_string(),
        is_locked: c.metadata.is_locked,
        display_order: c.metadata.display_order,
        items: dart_items,
        current_index: c.metadata.current_index,
        playback_position_ms: c.metadata.playback_position_ms,
        was_playing: c.metadata.was_playing,
        remove_after_play: c.metadata.remove_after_play,
        is_queue: c.metadata.is_queue,
        created_at: c.metadata.created_at,
        updated_at: c.metadata.updated_at,
        parent_id: c.tag.parent_id,
        alias_names: c.tag.alias_names,
        include_children: c.tag.include_children,
        is_group: c.tag.is_group,
    }
}


// ── API functions ──────────────────────────────────────────────────────

pub async fn create_collection(
    name: String,
    parent_id: Option<String>,
    collection_type: String,
) -> Result<DartCollection, String> {
    let ct = string_to_collection_type(&collection_type);
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::create_collection(conn, name, parent_id, ct)
        .await
        .map(to_dart_collection)
        .map_err(|e| e.to_string())
}

pub async fn get_collection(id: String) -> Result<Option<DartCollection>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::get_collection(conn, &id)
        .await
        .map(|opt| opt.map(to_dart_collection))
        .map_err(|e| e.to_string())
}

pub async fn get_collections(
    filter_type: Option<String>,
) -> Result<Vec<DartCollection>, String> {
    let ft = filter_type.as_deref().map(string_to_collection_type);
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::get_collections(conn, ft)
        .await
        .map(|cols| cols.into_iter().map(to_dart_collection).collect())
        .map_err(|e| e.to_string())
}

pub async fn get_collection_items(
    collection_id: String,
) -> Result<Vec<DartCollectionItem>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::get_collection_items(conn, &collection_id)
        .await
        .map(|items| items.iter().map(to_dart_collection_item).collect())
        .map_err(|e| e.to_string())
}

pub async fn add_item_to_collection(
    collection_id: String,
    item_type: String,
    target_id: String,
    inherit_lock: bool,
) -> Result<DartCollectionItem, String> {
    let it = string_to_item_type(&item_type);
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::add_item_to_collection(
        conn,
        &collection_id,
        it,
        &target_id,
        inherit_lock,
    )
    .await
    .map(|item| to_dart_collection_item(&item))
    .map_err(|e| e.to_string())
}

pub async fn remove_item_from_collection(
    collection_id: String,
    item_id: String,
) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::remove_item_from_collection(conn, &collection_id, &item_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn reorder_collection_items(
    collection_id: String,
    item_ids: Vec<String>,
) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::reorder_collection_items(conn, &collection_id, &item_ids)
        .await
        .map_err(|e| e.to_string())
}

pub async fn set_collection_lock(
    collection_id: String,
    is_locked: bool,
) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::set_collection_lock(conn, &collection_id, is_locked)
        .await
        .map_err(|e| e.to_string())
}

pub async fn start_playing(
    collection_id: String,
    start_index: i32,
    playback_position_ms: i64,
) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::start_playing(
        conn,
        &collection_id,
        start_index,
        playback_position_ms,
    )
    .await
    .map_err(|e| e.to_string())
}

pub async fn stop_playing(collection_id: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::stop_playing(conn, &collection_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn update_playback_state(
    collection_id: String,
    current_index: i32,
    playback_position_ms: i64,
    was_playing: bool,
) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::update_playback_state(
        conn,
        &collection_id,
        current_index,
        playback_position_ms,
        was_playing,
    )
    .await
    .map_err(|e| e.to_string())
}

/// Update the full collection metadata (items, playback state, flags).
///
/// This is the "bulk update" path used by the Dart `_updateActiveQueue()`
/// method so that all metadata fields are persisted in a single write.
pub async fn update_collection_metadata(
    collection_id: String,
    items: Vec<DartCollectionItem>,
    current_index: i32,
    playback_position_ms: i64,
    was_playing: bool,
    remove_after_play: bool,
    is_locked: bool,
    display_order: i32,
    is_queue: bool,
) -> Result<(), String> {
    use beadline_tags::model::collection::{CollectionMetadata, CollectionItem as CItem};

    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();

    // Fetch existing metadata to preserve created_at and temporary_song_units
    let existing = beadline_tags::collection_repository::get_collection(conn, &collection_id)
        .await
        .map_err(|e| e.to_string())?
        .ok_or_else(|| format!("collection not found: {}", collection_id))?;

    let rust_items: Vec<CItem> = items
        .iter()
        .map(|di| CItem {
            id: di.id.clone(),
            item_type: string_to_item_type(&di.item_type),
            target_id: di.target_id.clone(),
            order: di.order,
            inherit_lock: di.inherit_lock,
        })
        .collect();

    let metadata = CollectionMetadata {
        is_locked,
        display_order,
        items: rust_items,
        current_index,
        playback_position_ms,
        was_playing,
        remove_after_play,
        temporary_song_units: existing.metadata.temporary_song_units,
        is_queue,
        created_at: existing.metadata.created_at,
        updated_at: beadline_tags::model::collection::now_iso8601(),
    };

    let is_group = existing.tag.is_group;
    beadline_tags::collection_repository::save_collection_metadata(
        conn,
        &collection_id,
        &metadata,
        is_group,
    )
    .await
    .map_err(|e| e.to_string())
}

pub async fn resolve_content(
    collection_id: String,
    max_depth: usize,
) -> Result<Vec<String>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::resolve_content(conn, &collection_id, max_depth)
        .await
        .map_err(|e| e.to_string())
}

pub async fn would_create_circular_reference(
    parent_id: String,
    target_id: String,
) -> Result<bool, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::would_create_circular_reference(
        conn,
        &parent_id,
        &target_id,
    )
    .await
    .map_err(|e| e.to_string())
}
