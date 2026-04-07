// FRB-exposed collection repository functions.
// All APIs use Tag/TagItem/TagMetadata from tag_api.

use beadline_tags::model::collection::{CollectionItemType, CollectionType, CollectionMetadata, CollectionItem};
use super::database_api::lock_db;
use super::tag_api::{Tag, TagItem, TagItemType, TagMetadata, domain_to_ffi};

fn str_to_ct(s: &str) -> CollectionType {
    match s { "queue" => CollectionType::Queue, "group" => CollectionType::Group, _ => CollectionType::Playlist }
}

fn ffi_item_to_domain(i: &TagItem) -> CollectionItem {
    CollectionItem {
        id: i.id.clone(),
        item_type: match i.item_type { TagItemType::SongUnit => CollectionItemType::SongUnit, TagItemType::TagReference => CollectionItemType::CollectionReference },
        target_id: i.target_id.clone(), order: i.order, inherit_lock: i.inherit_lock,
    }
}

fn domain_item_to_ffi(i: CollectionItem) -> TagItem {
    TagItem {
        id: i.id,
        item_type: match i.item_type { CollectionItemType::SongUnit => TagItemType::SongUnit, CollectionItemType::CollectionReference => TagItemType::TagReference },
        target_id: i.target_id, order: i.order, inherit_lock: i.inherit_lock,
    }
}

pub async fn create_collection(name: String, parent_id: Option<String>, collection_type: String) -> Result<Tag, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::create_collection(conn, name, parent_id, str_to_ct(&collection_type))
        .await.map(domain_to_ffi).map_err(|e| e.to_string())
}

pub async fn get_collection(id: String) -> Result<Option<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::get_collection(conn, &id)
        .await.map(|o| o.map(domain_to_ffi)).map_err(|e| e.to_string())
}

pub async fn get_collections(filter_type: Option<String>) -> Result<Vec<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let ft = filter_type.as_deref().map(str_to_ct);
    beadline_tags::collection_repository::get_collections(conn, ft)
        .await.map(|v| v.into_iter().map(domain_to_ffi).collect()).map_err(|e| e.to_string())
}

pub async fn get_collection_items(collection_id: String) -> Result<Vec<TagItem>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::get_collection_items(conn, &collection_id)
        .await.map(|v| v.into_iter().map(domain_item_to_ffi).collect()).map_err(|e| e.to_string())
}

pub async fn add_item_to_collection(collection_id: String, item_type: TagItemType, target_id: String, inherit_lock: bool) -> Result<TagItem, String> {
    let it = match item_type { TagItemType::SongUnit => CollectionItemType::SongUnit, TagItemType::TagReference => CollectionItemType::CollectionReference };
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::add_item_to_collection(conn, &collection_id, it, &target_id, inherit_lock)
        .await.map(domain_item_to_ffi).map_err(|e| e.to_string())
}

pub async fn remove_item_from_collection(collection_id: String, item_id: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::remove_item_from_collection(conn, &collection_id, &item_id)
        .await.map_err(|e| e.to_string())
}

pub async fn reorder_collection_items(collection_id: String, item_ids: Vec<String>) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::reorder_collection_items(conn, &collection_id, &item_ids)
        .await.map_err(|e| e.to_string())
}

pub async fn set_collection_lock(collection_id: String, is_locked: bool) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::set_collection_lock(conn, &collection_id, is_locked)
        .await.map_err(|e| e.to_string())
}

pub async fn start_playing(collection_id: String, start_index: i32, playback_position_ms: i64) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::start_playing(conn, &collection_id, start_index, playback_position_ms)
        .await.map_err(|e| e.to_string())
}

pub async fn stop_playing(collection_id: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::stop_playing(conn, &collection_id)
        .await.map_err(|e| e.to_string())
}

pub async fn update_playback_state(collection_id: String, current_index: i32, playback_position_ms: i64, was_playing: bool) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::update_playback_state(conn, &collection_id, current_index, playback_position_ms, was_playing)
        .await.map_err(|e| e.to_string())
}

pub async fn update_collection_metadata(collection_id: String, metadata: TagMetadata) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();

    let existing = beadline_tags::collection_repository::get_collection(conn, &collection_id)
        .await.map_err(|e| e.to_string())?
        .ok_or_else(|| format!("collection not found: {}", collection_id))?;

    let items: Vec<CollectionItem> = metadata.items.iter().map(ffi_item_to_domain).collect();
    let cm = CollectionMetadata {
        is_locked: metadata.is_locked, display_order: metadata.display_order, items,
        current_index: metadata.current_index, playback_position_ms: metadata.playback_position_ms,
        was_playing: metadata.was_playing, remove_after_play: metadata.remove_after_play,
        is_queue: metadata.is_queue,
        created_at: existing.collection_metadata.map(|m| m.created_at).unwrap_or_default(),
        updated_at: beadline_tags::model::collection::now_iso8601(),
    };

    beadline_tags::collection_repository::save_collection_metadata(conn, &collection_id, &cm, existing.is_group)
        .await.map_err(|e| e.to_string())
}

pub async fn resolve_content(collection_id: String, max_depth: usize) -> Result<Vec<String>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::resolve_content(conn, &collection_id, max_depth)
        .await.map_err(|e| e.to_string())
}

pub async fn would_create_circular_reference(parent_id: String, target_id: String) -> Result<bool, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::would_create_circular_reference(conn, &parent_id, &target_id)
        .await.map_err(|e| e.to_string())
}

/// Deep-copy all items from source collection into target, recursively.
/// Returns the number of song units copied.
pub async fn deep_copy_collection(source_id: String, target_id: String, max_depth: usize) -> Result<u32, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::deep_copy_collection(conn, &source_id, &target_id, max_depth)
        .await.map_err(|e| e.to_string())
}

/// Remove duplicate song unit entries, keeping first occurrence. Returns removed count.
pub async fn deduplicate_collection(collection_id: String) -> Result<u32, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::deduplicate_collection(conn, &collection_id)
        .await.map_err(|e| e.to_string())
}

/// Shuffle a collection's items. Locked groups stay together as blocks.
/// If current_song_id is provided, that song is placed at index 0.
pub async fn shuffle_collection(collection_id: String, current_song_id: Option<String>) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::collection_repository::shuffle_collection(conn, &collection_id, current_song_id.as_deref())
        .await.map_err(|e| e.to_string())
}
