// FRB-exposed Song Unit repository functions
//
// Thin wrappers that read the global DB connection and delegate
// to beadline_core::repository, following the same pattern as tag_api.rs.

use beadline_core::model::metadata::Metadata;
use beadline_core::model::playback_preferences::PlaybackPreferences;
use beadline_core::model::source_collection::SourceCollection;
use beadline_core::model::song_unit::SongUnit as DomainSongUnit;

use super::database_api::lock_db;

/// Flat struct for FFI transport — avoids nested enums that FRB struggles with.
/// The Dart side reconstructs the full SongUnit from these JSON strings.
pub struct FfiSongUnit {
    pub id: String,
    pub metadata_json: String,
    pub sources_json: String,
    pub preferences_json: String,
    pub tag_ids: Vec<String>,
    pub library_location_id: Option<String>,
    pub is_temporary: bool,
    pub discovered_at: Option<i64>,
    pub original_file_path: Option<String>,
}

/// Convert a domain SongUnit to an FfiSongUnit by serializing nested structs to JSON.
fn to_ffi(su: DomainSongUnit) -> Result<FfiSongUnit, String> {
    Ok(FfiSongUnit {
        id: su.id,
        metadata_json: serde_json::to_string(&su.metadata).map_err(|e| e.to_string())?,
        sources_json: serde_json::to_string(&su.sources).map_err(|e| e.to_string())?,
        preferences_json: serde_json::to_string(&su.preferences).map_err(|e| e.to_string())?,
        tag_ids: su.tag_ids,
        library_location_id: su.library_location_id,
        is_temporary: su.is_temporary,
        discovered_at: su.discovered_at,
        original_file_path: su.original_file_path,
    })
}

/// Convert FFI parameters into a domain SongUnit by deserializing JSON strings.
fn to_domain(
    id: String,
    metadata_json: &str,
    sources_json: &str,
    preferences_json: &str,
    tag_ids: Vec<String>,
    library_location_id: Option<String>,
    is_temporary: bool,
    discovered_at: Option<i64>,
    original_file_path: Option<String>,
) -> Result<DomainSongUnit, String> {
    let metadata: Metadata =
        serde_json::from_str(metadata_json).map_err(|e| e.to_string())?;
    let sources: SourceCollection =
        serde_json::from_str(sources_json).map_err(|e| e.to_string())?;
    let preferences: PlaybackPreferences =
        serde_json::from_str(preferences_json).map_err(|e| e.to_string())?;
    Ok(DomainSongUnit {
        id,
        metadata,
        sources,
        tag_ids,
        preferences,
        library_location_id,
        is_temporary,
        discovered_at,
        original_file_path,
    })
}

// ---------------------------------------------------------------------------
// CRUD operations
// ---------------------------------------------------------------------------

pub async fn create_song_unit(
    id: String,
    metadata_json: String,
    sources_json: String,
    preferences_json: String,
    tag_ids: Vec<String>,
    library_location_id: Option<String>,
    is_temporary: bool,
    discovered_at: Option<i64>,
    original_file_path: Option<String>,
) -> Result<(), String> {
    let su = to_domain(
        id,
        &metadata_json,
        &sources_json,
        &preferences_json,
        tag_ids,
        library_location_id,
        is_temporary,
        discovered_at,
        original_file_path,
    )?;
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::insert_song_unit(conn, &su)
        .await
        .map_err(|e| e.to_string())
}

pub async fn get_song_unit(id: String) -> Result<Option<FfiSongUnit>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let result = beadline_core::repository::get_song_unit(conn, &id)
        .await
        .map_err(|e| e.to_string())?;
    match result {
        Some(su) => Ok(Some(to_ffi(su)?)),
        None => Ok(None),
    }
}

pub async fn update_song_unit(
    id: String,
    metadata_json: String,
    sources_json: String,
    preferences_json: String,
    tag_ids: Vec<String>,
    library_location_id: Option<String>,
    is_temporary: bool,
    discovered_at: Option<i64>,
    original_file_path: Option<String>,
) -> Result<(), String> {
    let su = to_domain(
        id,
        &metadata_json,
        &sources_json,
        &preferences_json,
        tag_ids,
        library_location_id,
        is_temporary,
        discovered_at,
        original_file_path,
    )?;
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::update_song_unit(conn, &su)
        .await
        .map_err(|e| e.to_string())
}

pub async fn delete_song_unit(id: String) -> Result<(), String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::delete_song_unit(conn, &id)
        .await
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Query operations
// ---------------------------------------------------------------------------

pub async fn get_song_units_paginated(
    offset: u64,
    limit: u64,
) -> Result<Vec<FfiSongUnit>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let units = beadline_core::repository::get_song_units_paginated(conn, offset, limit)
        .await
        .map_err(|e| e.to_string())?;
    units.into_iter().map(to_ffi).collect()
}

pub async fn get_all_song_units() -> Result<Vec<FfiSongUnit>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let units = beadline_core::repository::get_all_song_units(conn)
        .await
        .map_err(|e| e.to_string())?;
    units.into_iter().map(to_ffi).collect()
}

pub async fn get_song_units_by_library_location(
    location_id: String,
) -> Result<Vec<FfiSongUnit>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let units =
        beadline_core::repository::get_song_units_by_library_location(conn, &location_id)
            .await
            .map_err(|e| e.to_string())?;
    units.into_iter().map(to_ffi).collect()
}

pub async fn get_song_units_by_hash(hash: String) -> Result<Vec<FfiSongUnit>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let units = beadline_core::repository::get_song_units_by_hash(conn, &hash)
        .await
        .map_err(|e| e.to_string())?;
    units.into_iter().map(to_ffi).collect()
}

pub async fn get_temporary_song_units() -> Result<Vec<FfiSongUnit>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let units = beadline_core::repository::get_temporary_song_units(conn)
        .await
        .map_err(|e| e.to_string())?;
    units.into_iter().map(to_ffi).collect()
}

pub async fn has_temporary_song_unit_for_path(file_path: String) -> Result<bool, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::has_temporary_for_path(conn, &file_path)
        .await
        .map_err(|e| e.to_string())
}

pub async fn delete_all_temporary_song_units() -> Result<u64, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::delete_all_temporary(conn)
        .await
        .map_err(|e| e.to_string())
}

pub async fn delete_temporary_song_unit_by_path(file_path: String) -> Result<u64, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::delete_temporary_by_path(conn, &file_path)
        .await
        .map_err(|e| e.to_string())
}

pub async fn get_song_unit_count() -> Result<u64, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    beadline_core::repository::get_song_unit_count(conn)
        .await
        .map_err(|e| e.to_string())
}

pub async fn calculate_song_unit_hash(
    metadata_json: String,
    sources_json: String,
) -> Result<String, String> {
    let metadata: Metadata =
        serde_json::from_str(&metadata_json).map_err(|e| e.to_string())?;
    let sources: SourceCollection =
        serde_json::from_str(&sources_json).map_err(|e| e.to_string())?;
    // Construct a minimal SongUnit with defaults for fields not needed for hash.
    let su = DomainSongUnit {
        id: String::new(),
        metadata,
        sources,
        tag_ids: Vec::new(),
        preferences: PlaybackPreferences {
            prefer_instrumental: false,
            preferred_display_source_id: None,
            preferred_audio_source_id: None,
            preferred_instrumental_source_id: None,
            preferred_hover_source_id: None,
        },
        library_location_id: None,
        is_temporary: false,
        discovered_at: None,
        original_file_path: None,
    };
    Ok(beadline_core::hash::calculate_hash(&su))
}
