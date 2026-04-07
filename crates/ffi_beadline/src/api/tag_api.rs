// FRB-exposed tag types and repository functions.
//
// These structs use proper enums and nested types so FRB generates
// rich Dart classes directly — no manual Dart model needed.

use super::database_api::lock_db;

// Re-export for stale frb_generated.rs compatibility.
pub use beadline_tags::model::tag::Tag as _InternalTag;

// ── FRB-translatable types ─────────────────────────────────────────────

/// Tag type classification.
pub enum TagType {
    BuiltIn,
    User,
    Automatic,
}

/// Item type within a tag's metadata.
pub enum TagItemType {
    SongUnit,
    TagReference,
}

/// A single item entry in a tag's metadata.
pub struct TagItem {
    pub id: String,
    pub item_type: TagItemType,
    pub target_id: String,
    pub order: i32,
    pub inherit_lock: bool,
}

/// Metadata for tags that contain songs (playlists/queues/groups).
pub struct TagMetadata {
    pub is_locked: bool,
    pub display_order: i32,
    pub items: Vec<TagItem>,
    pub current_index: i32,
    pub playback_position_ms: i64,
    pub was_playing: bool,
    pub remove_after_play: bool,
    pub is_queue: bool,
    pub created_at: String,
    pub updated_at: String,
}

/// A tag — the unified model for tags, playlists, queues, and groups.
/// When `metadata` is `Some`, this tag contains songs.
pub struct Tag {
    pub id: String,
    pub name: String,
    pub key: Option<String>,
    pub tag_type: TagType,
    pub parent_id: Option<String>,
    pub alias_names: Vec<String>,
    pub include_children: bool,
    pub is_group: bool,
    pub is_locked: bool,
    pub display_order: i32,
    pub metadata: Option<TagMetadata>,
}

// ── Conversion: domain Tag ↔ FFI Tag ───────────────────────────────────

pub(crate) fn domain_to_ffi(t: beadline_tags::model::tag::Tag) -> Tag {
    use beadline_tags::model::collection::CollectionItemType;

    let tag_type = match t.tag_type {
        beadline_tags::model::tag::TagType::BuiltIn => TagType::BuiltIn,
        beadline_tags::model::tag::TagType::User => TagType::User,
        beadline_tags::model::tag::TagType::Automatic => TagType::Automatic,
    };

    let metadata = t.collection_metadata.map(|m| {
        let items = m.items.into_iter().map(|i| TagItem {
            id: i.id,
            item_type: match i.item_type {
                CollectionItemType::SongUnit => TagItemType::SongUnit,
                CollectionItemType::CollectionReference => TagItemType::TagReference,
            },
            target_id: i.target_id,
            order: i.order,
            inherit_lock: i.inherit_lock,
        }).collect();
        TagMetadata {
            is_locked: m.is_locked,
            display_order: m.display_order,
            items,
            current_index: m.current_index,
            playback_position_ms: m.playback_position_ms,
            was_playing: m.was_playing,
            remove_after_play: m.remove_after_play,
            is_queue: m.is_queue,
            created_at: m.created_at,
            updated_at: m.updated_at,
        }
    });

    Tag {
        id: t.id,
        name: t.value,
        key: t.key,
        tag_type,
        parent_id: t.parent_id,
        alias_names: t.alias_names,
        include_children: t.include_children,
        is_group: t.is_group,
        is_locked: t.is_locked,
        display_order: t.display_order,
        metadata,
    }
}

fn ffi_to_domain(t: Tag) -> beadline_tags::model::tag::Tag {
    use beadline_tags::model::collection::{CollectionMetadata, CollectionItem, CollectionItemType};

    let tag_type = match t.tag_type {
        TagType::BuiltIn => beadline_tags::model::tag::TagType::BuiltIn,
        TagType::User => beadline_tags::model::tag::TagType::User,
        TagType::Automatic => beadline_tags::model::tag::TagType::Automatic,
    };

    let collection_metadata = t.metadata.map(|m| {
        let items = m.items.into_iter().map(|i| CollectionItem {
            id: i.id,
            item_type: match i.item_type {
                TagItemType::SongUnit => CollectionItemType::SongUnit,
                TagItemType::TagReference => CollectionItemType::CollectionReference,
            },
            target_id: i.target_id,
            order: i.order,
            inherit_lock: i.inherit_lock,
        }).collect();
        CollectionMetadata {
            is_locked: m.is_locked,
            display_order: m.display_order,
            items,
            current_index: m.current_index,
            playback_position_ms: m.playback_position_ms,
            was_playing: m.was_playing,
            remove_after_play: m.remove_after_play,
            is_queue: m.is_queue,
            created_at: m.created_at,
            updated_at: m.updated_at,
        }
    });

    beadline_tags::model::tag::Tag {
        id: t.id,
        key: t.key,
        value: t.name,
        tag_type,
        parent_id: t.parent_id,
        alias_names: t.alias_names,
        include_children: t.include_children,
        is_group: t.is_group,
        is_locked: t.is_locked,
        display_order: t.display_order,
        collection_metadata,
    }
}

// ── API functions ──────────────────────────────────────────────────────

pub async fn create_tag(
    key: Option<String>,
    value: String,
    parent_id: Option<String>,
) -> Result<Tag, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::create_tag(conn, key, value, parent_id)
        .await.map(domain_to_ffi).map_err(|e| e.to_string())
}

pub async fn delete_tag(id: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::delete_tag(conn, &id)
        .await.map_err(|e| e.to_string())
}

pub async fn update_tag(tag: Tag) -> Result<Tag, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let rust_tag = ffi_to_domain(tag);
    beadline_tags::repository::update_tag(conn, &rust_tag)
        .await.map(domain_to_ffi).map_err(|e| e.to_string())
}

pub async fn get_tag(id: String) -> Result<Option<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_tag(conn, &id)
        .await.map(|opt| opt.map(domain_to_ffi)).map_err(|e| e.to_string())
}

pub async fn get_all_tags() -> Result<Vec<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_all_tags(conn)
        .await.map(|v| v.into_iter().map(domain_to_ffi).collect()).map_err(|e| e.to_string())
}

pub async fn get_children(parent_id: String) -> Result<Vec<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_children(conn, &parent_id)
        .await.map(|v| v.into_iter().map(domain_to_ffi).collect()).map_err(|e| e.to_string())
}

pub async fn get_descendants(tag_id: String) -> Result<Vec<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_descendants(conn, &tag_id)
        .await.map(|v| v.into_iter().map(domain_to_ffi).collect()).map_err(|e| e.to_string())
}

pub async fn add_alias(tag_id: String, alias: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::add_alias(conn, &tag_id, &alias)
        .await.map_err(|e| e.to_string())
}

pub async fn remove_alias(alias: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::remove_alias(conn, &alias)
        .await.map_err(|e| e.to_string())
}

pub async fn resolve_tag(name_or_alias: String) -> Result<Option<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::resolve_tag(conn, &name_or_alias)
        .await.map(|opt| opt.map(domain_to_ffi)).map_err(|e| e.to_string())
}

pub async fn get_tag_path(tag_id: String) -> Result<String, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_tag_path(conn, &tag_id)
        .await.map_err(|e| e.to_string())
}

pub async fn get_tags_by_type(tag_type: String) -> Result<Vec<Tag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_tags_by_type(conn, &tag_type)
        .await.map(|v| v.into_iter().map(domain_to_ffi).collect()).map_err(|e| e.to_string())
}
