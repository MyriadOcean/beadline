use sea_orm::*;

use crate::entity::{song_unit, song_unit_tag};
use crate::error::CoreError;
use crate::model::song_unit::SongUnit as DomainSongUnit;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convert a DB entity model + tag IDs into a domain SongUnit.
fn to_domain(model: song_unit::Model, tag_ids: Vec<String>) -> Result<DomainSongUnit, CoreError> {
    Ok(DomainSongUnit {
        id: model.id,
        metadata: serde_json::from_str(&model.metadata_json)?,
        sources: serde_json::from_str(&model.sources_json)?,
        preferences: serde_json::from_str(&model.preferences_json)?,
        tag_ids,
        library_location_id: model.library_location_id,
        is_temporary: model.is_temporary != 0,
        discovered_at: model.discovered_at,
        original_file_path: model.original_file_path,
    })
}

/// Load tag IDs for a song unit from the junction table.
async fn load_tag_ids(
    conn: &DatabaseConnection,
    song_unit_id: &str,
) -> Result<Vec<String>, CoreError> {
    let tags = song_unit_tag::Entity::find()
        .filter(song_unit_tag::Column::SongUnitId.eq(song_unit_id))
        .all(conn)
        .await?;
    Ok(tags.into_iter().map(|t| t.tag_id).collect())
}

/// Sync tag associations: delete existing, insert new.
async fn sync_tag_associations(
    conn: &DatabaseConnection,
    song_unit_id: &str,
    tag_ids: &[String],
) -> Result<(), CoreError> {
    delete_tag_associations(conn, song_unit_id).await?;
    for tag_id in tag_ids {
        let model = song_unit_tag::ActiveModel {
            song_unit_id: Set(song_unit_id.to_string()),
            tag_id: Set(tag_id.clone()),
            value: Set(None),
        };
        song_unit_tag::Entity::insert(model).exec(conn).await?;
    }
    Ok(())
}

/// Delete all tag associations for a song unit.
async fn delete_tag_associations(
    conn: &DatabaseConnection,
    song_unit_id: &str,
) -> Result<(), CoreError> {
    song_unit_tag::Entity::delete_many()
        .filter(song_unit_tag::Column::SongUnitId.eq(song_unit_id))
        .exec(conn)
        .await?;
    Ok(())
}

/// Current time in milliseconds since UNIX epoch.
fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}


// ---------------------------------------------------------------------------
// CRUD operations
// ---------------------------------------------------------------------------

/// Insert a new Song Unit into the database, storing metadata, sources, and
/// preferences as JSON columns. Automatically computes hash and timestamps.
pub async fn insert_song_unit(
    conn: &DatabaseConnection,
    su: &DomainSongUnit,
) -> Result<(), CoreError> {
    let hash = crate::hash::calculate_hash(su);
    let now = now_millis();
    let model = song_unit::ActiveModel {
        id: Set(su.id.clone()),
        metadata_json: Set(serde_json::to_string(&su.metadata)?),
        sources_json: Set(serde_json::to_string(&su.sources)?),
        preferences_json: Set(serde_json::to_string(&su.preferences)?),
        hash: Set(hash),
        library_location_id: Set(su.library_location_id.clone()),
        is_temporary: Set(if su.is_temporary { 1 } else { 0 }),
        discovered_at: Set(su.discovered_at),
        original_file_path: Set(su.original_file_path.clone()),
        created_at: Set(now),
        updated_at: Set(now),
    };
    song_unit::Entity::insert(model).exec(conn).await?;
    sync_tag_associations(conn, &su.id, &su.tag_ids).await?;
    Ok(())
}

/// Update an existing Song Unit in the database, recalculating hash and
/// updating the timestamp. Does NOT modify `created_at`.
pub async fn update_song_unit(
    conn: &DatabaseConnection,
    su: &DomainSongUnit,
) -> Result<(), CoreError> {
    let hash = crate::hash::calculate_hash(su);
    let now = now_millis();
    let model = song_unit::ActiveModel {
        id: Set(su.id.clone()),
        metadata_json: Set(serde_json::to_string(&su.metadata)?),
        sources_json: Set(serde_json::to_string(&su.sources)?),
        preferences_json: Set(serde_json::to_string(&su.preferences)?),
        hash: Set(hash),
        library_location_id: Set(su.library_location_id.clone()),
        is_temporary: Set(if su.is_temporary { 1 } else { 0 }),
        discovered_at: Set(su.discovered_at),
        original_file_path: Set(su.original_file_path.clone()),
        created_at: NotSet,
        updated_at: Set(now),
    };
    song_unit::Entity::update(model).exec(conn).await?;
    sync_tag_associations(conn, &su.id, &su.tag_ids).await?;
    Ok(())
}

/// Delete a Song Unit by ID, including removing associated tag associations.
pub async fn delete_song_unit(
    conn: &DatabaseConnection,
    id: &str,
) -> Result<(), CoreError> {
    delete_tag_associations(conn, id).await?;
    song_unit::Entity::delete_by_id(id).exec(conn).await?;
    Ok(())
}

/// Retrieve a Song Unit by ID, reconstructing the full model from database
/// columns and JSON fields. Returns `None` if not found.
pub async fn get_song_unit(
    conn: &DatabaseConnection,
    id: &str,
) -> Result<Option<DomainSongUnit>, CoreError> {
    let model = song_unit::Entity::find_by_id(id).one(conn).await?;
    match model {
        Some(m) => {
            let tag_ids = load_tag_ids(conn, &m.id).await?;
            Ok(Some(to_domain(m, tag_ids)?))
        }
        None => Ok(None),
    }
}


// ---------------------------------------------------------------------------
// Query operations
// ---------------------------------------------------------------------------

/// Retrieve all Song Units.
pub async fn get_all_song_units(
    conn: &DatabaseConnection,
) -> Result<Vec<DomainSongUnit>, CoreError> {
    let models = song_unit::Entity::find()
        .order_by_desc(song_unit::Column::CreatedAt)
        .all(conn)
        .await?;
    let mut result = Vec::with_capacity(models.len());
    for m in models {
        let tag_ids = load_tag_ids(conn, &m.id).await?;
        result.push(to_domain(m, tag_ids)?);
    }
    Ok(result)
}

/// Retrieve Song Units with pagination (offset and limit).
pub async fn get_song_units_paginated(
    conn: &DatabaseConnection,
    offset: u64,
    limit: u64,
) -> Result<Vec<DomainSongUnit>, CoreError> {
    let models = song_unit::Entity::find()
        .order_by_desc(song_unit::Column::CreatedAt)
        .offset(Some(offset))
        .limit(Some(limit))
        .all(conn)
        .await?;
    let mut result = Vec::with_capacity(models.len());
    for m in models {
        let tag_ids = load_tag_ids(conn, &m.id).await?;
        result.push(to_domain(m, tag_ids)?);
    }
    Ok(result)
}

/// Get total count of Song Units.
pub async fn get_song_unit_count(
    conn: &DatabaseConnection,
) -> Result<u64, CoreError> {
    let count = song_unit::Entity::find().count(conn).await?;
    Ok(count)
}

/// Retrieve Song Units by library location ID.
pub async fn get_song_units_by_library_location(
    conn: &DatabaseConnection,
    location_id: &str,
) -> Result<Vec<DomainSongUnit>, CoreError> {
    let models = song_unit::Entity::find()
        .filter(song_unit::Column::LibraryLocationId.eq(location_id))
        .order_by_desc(song_unit::Column::CreatedAt)
        .all(conn)
        .await?;
    let mut result = Vec::with_capacity(models.len());
    for m in models {
        let tag_ids = load_tag_ids(conn, &m.id).await?;
        result.push(to_domain(m, tag_ids)?);
    }
    Ok(result)
}

/// Retrieve Song Units by hash for deduplication checks.
pub async fn get_song_units_by_hash(
    conn: &DatabaseConnection,
    hash: &str,
) -> Result<Vec<DomainSongUnit>, CoreError> {
    let models = song_unit::Entity::find()
        .filter(song_unit::Column::Hash.eq(hash))
        .all(conn)
        .await?;
    let mut result = Vec::with_capacity(models.len());
    for m in models {
        let tag_ids = load_tag_ids(conn, &m.id).await?;
        result.push(to_domain(m, tag_ids)?);
    }
    Ok(result)
}

/// Retrieve all temporary Song Units.
pub async fn get_temporary_song_units(
    conn: &DatabaseConnection,
) -> Result<Vec<DomainSongUnit>, CoreError> {
    let models = song_unit::Entity::find()
        .filter(song_unit::Column::IsTemporary.eq(1))
        .order_by_desc(song_unit::Column::DiscoveredAt)
        .all(conn)
        .await?;
    let mut result = Vec::with_capacity(models.len());
    for m in models {
        let tag_ids = load_tag_ids(conn, &m.id).await?;
        result.push(to_domain(m, tag_ids)?);
    }
    Ok(result)
}

/// Check if a temporary Song Unit exists for a given file path.
pub async fn has_temporary_for_path(
    conn: &DatabaseConnection,
    file_path: &str,
) -> Result<bool, CoreError> {
    let count = song_unit::Entity::find()
        .filter(song_unit::Column::IsTemporary.eq(1))
        .filter(song_unit::Column::OriginalFilePath.eq(file_path))
        .count(conn)
        .await?;
    Ok(count > 0)
}

/// Delete all temporary Song Units, returning the number deleted.
pub async fn delete_all_temporary(
    conn: &DatabaseConnection,
) -> Result<u64, CoreError> {
    // First delete tag associations for all temporary song units
    let temp_ids: Vec<String> = song_unit::Entity::find()
        .filter(song_unit::Column::IsTemporary.eq(1))
        .all(conn)
        .await?
        .into_iter()
        .map(|m| m.id)
        .collect();
    for id in &temp_ids {
        delete_tag_associations(conn, id).await?;
    }
    let result = song_unit::Entity::delete_many()
        .filter(song_unit::Column::IsTemporary.eq(1))
        .exec(conn)
        .await?;
    Ok(result.rows_affected)
}

/// Delete temporary Song Units for a specific file path, returning the number deleted.
pub async fn delete_temporary_by_path(
    conn: &DatabaseConnection,
    file_path: &str,
) -> Result<u64, CoreError> {
    let models = song_unit::Entity::find()
        .filter(song_unit::Column::IsTemporary.eq(1))
        .filter(song_unit::Column::OriginalFilePath.eq(file_path))
        .all(conn)
        .await?;
    for m in &models {
        delete_tag_associations(conn, &m.id).await?;
    }
    let result = song_unit::Entity::delete_many()
        .filter(song_unit::Column::IsTemporary.eq(1))
        .filter(song_unit::Column::OriginalFilePath.eq(file_path))
        .exec(conn)
        .await?;
    Ok(result.rows_affected)
}
