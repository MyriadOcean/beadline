// Collection repository: CRUD, metadata persistence, and query operations
//
// Collections are tags with `playlist_metadata_json` — this module provides
// higher-level operations that compose tag CRUD with JSON metadata management.

use std::collections::HashSet;

use sea_orm::{
    ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, QueryOrder, Set,
};

use beadline_core::entity::song_unit_tag;
use crate::entity::tag;
use crate::error::TagError;
use crate::model::collection::*;
use crate::model::tag::{Tag, TagType};
use crate::repository::get_tag;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn tag_type_to_str(tt: &TagType) -> &'static str {
    match tt {
        TagType::BuiltIn => "builtin",
        TagType::User => "user",
        TagType::Automatic => "automatic",
    }
}

/// Parse `playlist_metadata_json` into `CollectionMetadata`.
/// Returns `None` if the JSON is `None` or empty.
pub fn load_collection_metadata(json: Option<&str>) -> Result<Option<CollectionMetadata>, TagError> {
    match json {
        None => Ok(None),
        Some(s) if s.trim().is_empty() => Ok(None),
        Some(s) => {
            let mut metadata: CollectionMetadata =
                serde_json::from_str(s).map_err(|e| TagError::Database(
                    crate::error::DbError::QueryFailed(format!(
                        "failed to parse collection metadata JSON: {}",
                        e
                    )),
                ))?;
            metadata.items.sort_by_key(|item| item.order);
            Ok(Some(metadata))
        }
    }
}

/// Serialize `CollectionMetadata` to JSON and persist it to the tag row.
/// Also updates `is_locked`, `display_order`, and `is_group` columns.
pub async fn save_collection_metadata(
    conn: &DatabaseConnection,
    tag_id: &str,
    metadata: &CollectionMetadata,
    is_group: bool,
) -> Result<(), TagError> {
    let json = serde_json::to_string(metadata).map_err(|e| {
        TagError::Database(crate::error::DbError::QueryFailed(format!(
            "failed to serialize collection metadata: {}",
            e
        )))
    })?;

    // Load the existing model to preserve fields we don't touch.
    let existing = tag::Entity::find_by_id(tag_id.to_owned())
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?
        .ok_or_else(|| TagError::NotFound(tag_id.to_owned()))?;

    let model = tag::ActiveModel {
        id: Set(existing.id),
        key: Set(existing.key),
        name: Set(existing.name),
        tag_type: Set(existing.tag_type),
        parent_id: Set(existing.parent_id),
        include_children: Set(existing.include_children),
        is_locked: Set(metadata.is_locked),
        display_order: Set(metadata.display_order),
        playlist_metadata_json: Set(Some(json)),
        is_group: Set(is_group),
    };
    tag::Entity::update(model)
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    Ok(())
}

/// Build a `Tag` (with collection metadata) from a tag model row.
/// Returns `None` if the tag has no collection metadata.
async fn model_to_collection_tag(
    conn: &DatabaseConnection,
    model: tag::Model,
) -> Result<Option<Tag>, TagError> {
    // Only proceed if the tag has collection metadata
    if model.playlist_metadata_json.is_none() {
        return Ok(None);
    }

    let tag = get_tag(conn, &model.id)
        .await?
        .ok_or_else(|| TagError::NotFound(model.id.clone()))?;

    if tag.collection_metadata.is_some() {
        Ok(Some(tag))
    } else {
        Ok(None)
    }
}

// ---------------------------------------------------------------------------
// CRUD operations
// ---------------------------------------------------------------------------

/// Create a new collection (tag + empty metadata).
///
/// Creates a tag row with `tag_type = "automatic"`, `key = "playlist"`,
/// and serialized empty `CollectionMetadata` in `playlist_metadata_json`.
pub async fn create_collection(
    conn: &DatabaseConnection,
    name: String,
    parent_id: Option<String>,
    collection_type: CollectionType,
) -> Result<Tag, TagError> {
    if name.trim().is_empty() {
        return Err(TagError::Invalid("collection name must not be empty".into()));
    }

    let id = uuid::Uuid::new_v4().to_string();
    let is_group = matches!(collection_type, CollectionType::Group);
    let metadata = CollectionMetadata::empty(collection_type);

    let json = serde_json::to_string(&metadata).map_err(|e| {
        TagError::Database(crate::error::DbError::QueryFailed(format!(
            "failed to serialize collection metadata: {}",
            e
        )))
    })?;

    let model = tag::ActiveModel {
        id: Set(id.clone()),
        key: Set(Some("playlist".to_owned())),
        name: Set(name),
        tag_type: Set(tag_type_to_str(&TagType::Automatic).to_owned()),
        parent_id: Set(parent_id),
        include_children: Set(true),
        is_locked: Set(false),
        display_order: Set(0),
        playlist_metadata_json: Set(Some(json)),
        is_group: Set(is_group),
    };
    tag::Entity::insert(model)
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    get_collection(conn, &id)
        .await?
        .ok_or_else(|| TagError::NotFound(id))
}

/// Get a collection by tag ID.
/// Returns `None` if the tag exists but is not a collection (no metadata JSON).
/// Returns `Err(NotFound)` if the tag doesn't exist at all.
pub async fn get_collection(
    conn: &DatabaseConnection,
    id: &str,
) -> Result<Option<Tag>, TagError> {
    let result = tag::Entity::find_by_id(id.to_owned())
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    match result {
        Some(model) => model_to_collection_tag(conn, model).await,
        None => Ok(None),
    }
}

/// Get all collections, optionally filtered by type.
pub async fn get_collections(
    conn: &DatabaseConnection,
    filter_type: Option<CollectionType>,
) -> Result<Vec<Tag>, TagError> {
    let models = tag::Entity::find()
        .filter(tag::Column::PlaylistMetadataJson.is_not_null())
        .order_by_asc(tag::Column::DisplayOrder)
        .order_by_asc(tag::Column::Name)
        .all(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    let mut collections = Vec::new();
    for model in models {
        if let Some(tag) = model_to_collection_tag(conn, model).await? {
            if let Some(ref ft) = filter_type {
                if tag.collection_type().as_ref() != Some(ft) {
                    continue;
                }
            }
            collections.push(tag);
        }
    }
    Ok(collections)
}

/// Get the ordered items list for a collection.
/// Returns `Err(NotACollection)` if the tag is not a collection.
pub async fn get_collection_items(
    conn: &DatabaseConnection,
    collection_id: &str,
) -> Result<Vec<CollectionItem>, TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| {
            TagError::NotACollection(collection_id.to_owned())
        })?;

    let mut items = tag.collection_metadata.unwrap().items;
    items.sort_by_key(|item| item.order);
    Ok(items)
}

// ---------------------------------------------------------------------------
// Add / Remove item operations
// ---------------------------------------------------------------------------

/// Add an item to a collection.
///
/// Appends a new `CollectionItem` to the collection's metadata items list
/// and persists the updated JSON. If the item is a `SongUnit`, also creates
/// a `song_unit_tags` junction table entry so the Song Unit is searchable
/// by the collection's tag.
pub async fn add_item_to_collection(
    conn: &DatabaseConnection,
    collection_id: &str,
    item_type: CollectionItemType,
    target_id: &str,
    inherit_lock: bool,
) -> Result<CollectionItem, TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    let order = metadata.items.len() as i32;
    let item = CollectionItem {
        id: uuid::Uuid::new_v4().to_string(),
        item_type,
        target_id: target_id.to_owned(),
        order,
        inherit_lock,
    };

    metadata.items.push(item.clone());
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;

    if item_type == CollectionItemType::SongUnit {
        create_collection_tag_association(conn, collection_id, target_id).await?;
    }

    Ok(item)
}

/// Remove an item from a collection by item ID.
///
/// Removes the `CollectionItem` from the metadata items list and persists
/// the updated JSON. If the removed item was a `SongUnit`, also removes
/// the corresponding `song_unit_tags` junction table entry.
pub async fn remove_item_from_collection(
    conn: &DatabaseConnection,
    collection_id: &str,
    item_id: &str,
) -> Result<(), TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    let is_group = tag.is_group;

    let idx = metadata
        .items
        .iter()
        .position(|i| i.id == item_id)
        .ok_or_else(|| TagError::CollectionItemNotFound(item_id.to_owned()))?;

    let removed = metadata.items.remove(idx);
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, is_group).await?;

    if removed.item_type == CollectionItemType::SongUnit {
        remove_collection_tag_association(conn, collection_id, &removed.target_id).await?;
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Reorder / Lock operations
// ---------------------------------------------------------------------------

/// Reorder items in a collection by the provided ID list.
///
/// Each item's `order` field is set to its index position in `item_ids`.
/// All existing items must be present in the provided list (same set).
pub async fn reorder_collection_items(
    conn: &DatabaseConnection,
    collection_id: &str,
    item_ids: &[String],
) -> Result<(), TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    let is_group = tag.is_group;

    // Validate that item_ids contains exactly the same set of IDs as the collection.
    if item_ids.len() != metadata.items.len() {
        return Err(TagError::Invalid(format!(
            "expected {} item IDs, got {}",
            metadata.items.len(),
            item_ids.len()
        )));
    }

    // Build a lookup from item ID → index in the new order.
    let mut order_map = std::collections::HashMap::new();
    for (idx, id) in item_ids.iter().enumerate() {
        if order_map.insert(id.as_str(), idx as i32).is_some() {
            return Err(TagError::Invalid(format!(
                "duplicate item ID in reorder list: {}",
                id
            )));
        }
    }

    // Apply the new order to each item.
    for item in &mut metadata.items {
        let new_order = order_map.get(item.id.as_str()).ok_or_else(|| {
            TagError::CollectionItemNotFound(item.id.clone())
        })?;
        item.order = *new_order;
    }

    // Sort items by their new order so the persisted JSON matches the logical order.
    metadata.items.sort_by_key(|item| item.order);
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, is_group).await?;

    Ok(())
}

/// Set the lock state of a collection.
pub async fn set_collection_lock(
    conn: &DatabaseConnection,
    collection_id: &str,
    is_locked: bool,
) -> Result<(), TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    metadata.is_locked = is_locked;
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;

    Ok(())
}

// ---------------------------------------------------------------------------
// Playback state operations
// ---------------------------------------------------------------------------

/// Start playing a collection.
///
/// Sets `current_index` to `start_index`, `playback_position_ms`, and
/// `was_playing = true`, then persists the updated metadata.
/// Returns `Err(NotACollection)` if the tag is not a collection.
pub async fn start_playing(
    conn: &DatabaseConnection,
    collection_id: &str,
    start_index: i32,
    playback_position_ms: i64,
) -> Result<(), TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    metadata.current_index = start_index;
    metadata.playback_position_ms = playback_position_ms;
    metadata.was_playing = true;
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;

    Ok(())
}

/// Stop playing a collection.
///
/// Resets `current_index` to -1, `playback_position_ms` to 0, and
/// `was_playing` to false, then persists the updated metadata.
/// Returns `Err(NotACollection)` if the tag is not a collection.
pub async fn stop_playing(
    conn: &DatabaseConnection,
    collection_id: &str,
) -> Result<(), TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    metadata.current_index = -1;
    metadata.playback_position_ms = 0;
    metadata.was_playing = false;
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;

    Ok(())
}

/// Update playback state for a collection.
///
/// Sets `current_index`, `playback_position_ms`, and `was_playing` to the
/// provided values, then persists the updated metadata.
/// Returns `Err(NotACollection)` if the tag is not a collection.
pub async fn update_playback_state(
    conn: &DatabaseConnection,
    collection_id: &str,
    current_index: i32,
    playback_position_ms: i64,
    was_playing: bool,
) -> Result<(), TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    metadata.current_index = current_index;
    metadata.playback_position_ms = playback_position_ms;
    metadata.was_playing = was_playing;
    metadata.updated_at = now_iso8601();

    save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;

    Ok(())
}

// ---------------------------------------------------------------------------
// song_unit_tags association helpers
// ---------------------------------------------------------------------------

/// Create a `song_unit_tags` entry linking a Song Unit to a collection's tag.
///
/// Uses `on_conflict_do_nothing()` to handle duplicates gracefully (e.g. if
/// the same Song Unit is added to the same collection twice via different items).
async fn create_collection_tag_association(
    conn: &DatabaseConnection,
    collection_tag_id: &str,
    song_unit_id: &str,
) -> Result<(), TagError> {
    let model = song_unit_tag::ActiveModel {
        song_unit_id: Set(song_unit_id.to_owned()),
        tag_id: Set(collection_tag_id.to_owned()),
        value: Set(None),
    };
    song_unit_tag::Entity::insert(model)
        .on_conflict(
            sea_orm::sea_query::OnConflict::columns([
                song_unit_tag::Column::SongUnitId,
                song_unit_tag::Column::TagId,
            ])
            .do_nothing()
            .to_owned(),
        )
        .do_nothing()
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(crate::error::DbError::SeaOrm(e)))?;
    Ok(())
}

/// Remove the `song_unit_tags` entry linking a Song Unit to a collection's tag.
async fn remove_collection_tag_association(
    conn: &DatabaseConnection,
    collection_tag_id: &str,
    song_unit_id: &str,
) -> Result<(), TagError> {
    song_unit_tag::Entity::delete_many()
        .filter(song_unit_tag::Column::SongUnitId.eq(song_unit_id))
        .filter(song_unit_tag::Column::TagId.eq(collection_tag_id))
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(crate::error::DbError::SeaOrm(e)))?;
    Ok(())
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Batch operations
// ---------------------------------------------------------------------------

/// Deep-copy all items from `source_id` into `target_id`, recursively copying
/// nested group references. Returns the number of song units copied.
pub async fn deep_copy_collection(
    conn: &DatabaseConnection,
    source_id: &str,
    target_id: &str,
    max_depth: usize,
) -> Result<u32, TagError> {
    deep_copy_inner(conn, source_id, target_id, max_depth, &mut HashSet::new()).await
}

fn deep_copy_inner<'a>(
    conn: &'a DatabaseConnection,
    source_id: &'a str,
    target_id: &'a str,
    max_depth: usize,
    visited: &'a mut HashSet<String>,
) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<u32, TagError>> + Send + 'a>> {
    Box::pin(async move {
        if max_depth == 0 || visited.contains(source_id) {
            return Ok(0);
        }
        visited.insert(source_id.to_owned());

        let items = get_collection_items(conn, source_id).await?;
        let mut count = 0u32;

        for item in &items {
            match item.item_type {
                CollectionItemType::SongUnit => {
                    add_item_to_collection(
                        conn, target_id, CollectionItemType::SongUnit,
                        &item.target_id, item.inherit_lock,
                    ).await?;
                    count += 1;
                }
                CollectionItemType::CollectionReference => {
                    let ref_tag = get_collection(conn, &item.target_id).await?;
                    if let Some(ref_tag) = ref_tag {
                        let sub = create_collection(
                            conn, ref_tag.value.clone(),
                            Some(target_id.to_owned()),
                            CollectionType::Group,
                        ).await?;
                        if ref_tag.is_locked {
                            set_collection_lock(conn, &sub.id, true).await?;
                        }
                        let sub_count = deep_copy_inner(
                            conn, &item.target_id, &sub.id, max_depth - 1, visited,
                        ).await?;
                        if sub_count == 0 {
                            // Empty group — clean up
                            use crate::repository::delete_tag;
                            delete_tag(conn, &sub.id).await?;
                        } else {
                            count += sub_count;
                        }
                    }
                }
            }
        }
        Ok(count)
    })
}

/// Remove duplicate song unit entries from a collection, keeping the first
/// occurrence of each target_id. Returns the number of duplicates removed.
pub async fn deduplicate_collection(
    conn: &DatabaseConnection,
    collection_id: &str,
) -> Result<u32, TagError> {
    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    let original_len = metadata.items.len();

    let mut seen = HashSet::new();
    metadata.items.retain(|item| {
        if item.item_type == CollectionItemType::SongUnit {
            seen.insert(item.target_id.clone())
        } else {
            true // keep all references
        }
    });

    let removed = (original_len - metadata.items.len()) as u32;
    if removed > 0 {
        // Re-number orders
        for (i, item) in metadata.items.iter_mut().enumerate() {
            item.order = i as i32;
        }
        metadata.updated_at = now_iso8601();
        save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;
    }
    Ok(removed)
}

/// Shuffle a collection's items. Locked sub-groups stay together as blocks.
/// The `current_song_id` (if provided) will be placed at index 0 after shuffle.
pub async fn shuffle_collection(
    conn: &DatabaseConnection,
    collection_id: &str,
    current_song_id: Option<&str>,
) -> Result<(), TagError> {
    use rand::seq::SliceRandom;

    let tag = get_collection(conn, collection_id)
        .await?
        .ok_or_else(|| TagError::NotACollection(collection_id.to_owned()))?;

    let mut metadata = tag.collection_metadata.unwrap();
    if metadata.items.len() <= 1 {
        return Ok(());
    }

    // Separate locked groups from unlocked items
    let mut locked_blocks: Vec<Vec<CollectionItem>> = Vec::new();
    let mut unlocked: Vec<CollectionItem> = Vec::new();

    for item in &metadata.items {
        if item.item_type == CollectionItemType::CollectionReference {
            if let Some(ref_tag) = get_collection(conn, &item.target_id).await? {
                if ref_tag.is_locked {
                    // This reference + its contents stay as a block
                    locked_blocks.push(vec![item.clone()]);
                    continue;
                }
            }
        }
        unlocked.push(item.clone());
    }

    use rand::Rng;
    use rand::SeedableRng;

    let mut rng = rand::rngs::StdRng::from_os_rng();
    unlocked.shuffle(&mut rng);
    locked_blocks.shuffle(&mut rng);

    // Interleave: unlocked items with locked blocks inserted at random positions
    let mut result = unlocked;
    for block in locked_blocks {
        let pos = if result.is_empty() { 0 } else { rng.random_range(0..=result.len()) };
        for (i, item) in block.into_iter().enumerate() {
            result.insert(pos + i, item);
        }
    }

    // Move current song to front if specified
    if let Some(song_id) = current_song_id {
        if let Some(idx) = result.iter().position(|i| {
            i.item_type == CollectionItemType::SongUnit && i.target_id == song_id
        }) {
            let item = result.remove(idx);
            result.insert(0, item);
        }
    }

    // Re-number orders
    for (i, item) in result.iter_mut().enumerate() {
        item.order = i as i32;
    }

    metadata.items = result;
    metadata.updated_at = now_iso8601();
    save_collection_metadata(conn, collection_id, &metadata, tag.is_group).await?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Content resolution & circular reference detection
// ---------------------------------------------------------------------------

/// Resolve collection content recursively into a flat list of Song Unit IDs.
///
/// Follows `CollectionReference` items to their target collections, expanding
/// them depth-first. Uses a visited set to detect and skip circular references.
/// Stops expanding when `max_depth` is reached.
pub async fn resolve_content(
    conn: &DatabaseConnection,
    collection_id: &str,
    max_depth: usize,
) -> Result<Vec<String>, TagError> {
    let mut visited = HashSet::new();
    resolve_content_inner(conn, collection_id, max_depth, &mut visited).await
}

/// Recursive helper for `resolve_content`.
///
/// Walks the collection's items list depth-first:
/// - `SongUnit` items have their `target_id` appended to the result.
/// - `CollectionReference` items are recursively expanded (with decremented depth).
/// - Already-visited collections are skipped (cycle detection).
/// - When `max_depth` reaches 0, no further expansion occurs.
fn resolve_content_inner<'a>(
    conn: &'a DatabaseConnection,
    collection_id: &'a str,
    max_depth: usize,
    visited: &'a mut HashSet<String>,
) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Vec<String>, TagError>> + Send + 'a>> {
    Box::pin(async move {
        if max_depth == 0 || visited.contains(collection_id) {
            return Ok(vec![]);
        }
        visited.insert(collection_id.to_owned());

        let tag = get_collection(conn, collection_id).await?;
        let Some(tag) = tag else {
            return Ok(vec![]);
        };
        let metadata = match tag.collection_metadata {
            Some(m) => m,
            None => return Ok(vec![]),
        };

        let mut result = Vec::new();
        for item in &metadata.items {
            match item.item_type {
                CollectionItemType::SongUnit => {
                    result.push(item.target_id.clone());
                }
                CollectionItemType::CollectionReference => {
                    let nested = resolve_content_inner(
                        conn,
                        &item.target_id,
                        max_depth - 1,
                        visited,
                    )
                    .await?;
                    result.extend(nested);
                }
            }
        }
        Ok(result)
    })
}

/// Check whether adding a reference from `parent_id` to `target_id` would
/// create a circular reference.
///
/// Returns `true` if:
/// - `parent_id == target_id` (self-reference), or
/// - `target_id`'s collection graph eventually references `parent_id`.
pub async fn would_create_circular_reference(
    conn: &DatabaseConnection,
    parent_id: &str,
    target_id: &str,
) -> Result<bool, TagError> {
    // Self-reference is always circular.
    if parent_id == target_id {
        return Ok(true);
    }

    let mut visited = HashSet::new();
    check_circular(conn, target_id, parent_id, &mut visited).await
}

/// Recursive helper for `would_create_circular_reference`.
///
/// Walks `current_id`'s collection references looking for `search_for_id`.
/// Returns `true` as soon as a reference to `search_for_id` is found.
/// Uses a visited set to avoid infinite loops in already-circular graphs.
fn check_circular<'a>(
    conn: &'a DatabaseConnection,
    current_id: &'a str,
    search_for_id: &'a str,
    visited: &'a mut HashSet<String>,
) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<bool, TagError>> + Send + 'a>> {
    Box::pin(async move {
        if visited.contains(current_id) {
            return Ok(false);
        }
        visited.insert(current_id.to_owned());

        let tag = get_collection(conn, current_id).await?;
        let Some(tag) = tag else {
            return Ok(false);
        };
        let metadata = match tag.collection_metadata {
            Some(m) => m,
            None => return Ok(false),
        };

        for item in &metadata.items {
            if item.item_type == CollectionItemType::CollectionReference {
                if item.target_id == search_for_id {
                    return Ok(true);
                }
                if check_circular(conn, &item.target_id, search_for_id, visited).await? {
                    return Ok(true);
                }
            }
        }
        Ok(false)
    })
}
