// FRB-exposed tag repository functions
//
// Thin wrappers that read the global DB connection and delegate
// to beadline_tags::repository.

use beadline_tags::model::tag::TagType;
use super::database_api::lock_db;

// TODO(task-2): Remove this pub re-export after FRB codegen regenerates frb_generated.rs.
// The stale frb_generated.rs references `Tag` via `use crate::api::tag_api::*`.
pub use beadline_tags::model::tag::Tag;

/// FRB-transparent tag representation.
/// All fields are simple types so FRB generates a non-opaque Dart class.
#[derive(Debug)]
pub struct DartTag {
    pub id: String,
    pub name: String,
    pub key: Option<String>,
    pub tag_type: String,
    pub parent_id: Option<String>,
    pub alias_names: Vec<String>,
    pub include_children: bool,
    pub is_group: bool,
    pub is_locked: bool,
    pub display_order: i32,
    pub has_collection_metadata: bool,
}

/// Convert a Rust Tag to a DartTag for FFI transport.
pub fn to_dart_tag(tag: Tag) -> DartTag {
    let tag_type = match tag.tag_type {
        TagType::BuiltIn => "builtIn",
        TagType::User => "user",
        TagType::Automatic => "automatic",
    };
    DartTag {
        id: tag.id,
        name: tag.value,
        key: tag.key,
        tag_type: tag_type.to_string(),
        parent_id: tag.parent_id,
        alias_names: tag.alias_names,
        include_children: tag.include_children,
        is_group: tag.is_group,
        is_locked: tag.is_locked,
        display_order: tag.display_order,
        has_collection_metadata: tag.has_collection_metadata,
    }
}

/// Convert a DartTag back to a Rust Tag (used by update_tag).
pub fn from_dart_tag(dt: DartTag) -> Tag {
    let tag_type = match dt.tag_type.as_str() {
        "builtIn" => TagType::BuiltIn,
        "user" => TagType::User,
        "automatic" => TagType::Automatic,
        _ => TagType::User, // fallback
    };
    Tag {
        id: dt.id,
        key: dt.key,
        value: dt.name,
        tag_type,
        parent_id: dt.parent_id,
        alias_names: dt.alias_names,
        include_children: dt.include_children,
        is_group: dt.is_group,
        is_locked: dt.is_locked,
        display_order: dt.display_order,
        has_collection_metadata: dt.has_collection_metadata,
    }
}

pub async fn create_tag(
    key: Option<String>,
    value: String,
    parent_id: Option<String>,
) -> Result<DartTag, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::create_tag(conn, key, value, parent_id)
        .await
        .map(to_dart_tag)
        .map_err(|e| e.to_string())
}

pub async fn delete_tag(id: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::delete_tag(conn, &id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn update_tag(tag: DartTag) -> Result<DartTag, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let rust_tag = from_dart_tag(tag);
    beadline_tags::repository::update_tag(conn, &rust_tag)
        .await
        .map(to_dart_tag)
        .map_err(|e| e.to_string())
}

pub async fn get_tag(id: String) -> Result<Option<DartTag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_tag(conn, &id)
        .await
        .map(|opt| opt.map(to_dart_tag))
        .map_err(|e| e.to_string())
}

pub async fn get_all_tags() -> Result<Vec<DartTag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_all_tags(conn)
        .await
        .map(|tags| tags.into_iter().map(to_dart_tag).collect())
        .map_err(|e| e.to_string())
}

pub async fn get_children(parent_id: String) -> Result<Vec<DartTag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_children(conn, &parent_id)
        .await
        .map(|tags| tags.into_iter().map(to_dart_tag).collect())
        .map_err(|e| e.to_string())
}

pub async fn get_descendants(tag_id: String) -> Result<Vec<DartTag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_descendants(conn, &tag_id)
        .await
        .map(|tags| tags.into_iter().map(to_dart_tag).collect())
        .map_err(|e| e.to_string())
}

pub async fn add_alias(tag_id: String, alias: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::add_alias(conn, &tag_id, &alias)
        .await
        .map_err(|e| e.to_string())
}

pub async fn remove_alias(alias: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::remove_alias(conn, &alias)
        .await
        .map_err(|e| e.to_string())
}

pub async fn resolve_tag(name_or_alias: String) -> Result<Option<DartTag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::resolve_tag(conn, &name_or_alias)
        .await
        .map(|opt| opt.map(to_dart_tag))
        .map_err(|e| e.to_string())
}

pub async fn get_tag_path(tag_id: String) -> Result<String, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_tag_path(conn, &tag_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn get_tags_by_type(tag_type: String) -> Result<Vec<DartTag>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_tags::repository::get_tags_by_type(conn, &tag_type)
        .await
        .map(|tags| tags.into_iter().map(to_dart_tag).collect())
        .map_err(|e| e.to_string())
}
