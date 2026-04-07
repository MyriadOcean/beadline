// FRB-exposed evaluator functions
//
// Fetches all tags from DB via repository, then delegates to
// beadline_tags::evaluator for pure evaluation.

pub use beadline_tags::evaluator::SongUnitView;
pub use beadline_tags::model::query::QueryExpression;
use super::database_api::lock_db;

pub async fn filter_song_units(
    expr: QueryExpression,
    units: Vec<SongUnitView>,
) -> Result<Vec<String>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let tags = beadline_tags::repository::get_all_tags(conn)
        .await
        .map_err(|e| e.to_string())?;
    Ok(beadline_tags::evaluator::filter_song_units(&expr, &units, &tags))
}

/// High-level search: parse query, fetch song units + tags from DB, evaluate,
/// return matching IDs.
///
/// The API is intentionally simple — just query text in, matching IDs out.
/// The Rust side fetches everything from the database itself.
///
/// Metadata fields (name, artist, album) are injected as synthetic named tags
/// so the evaluator treats them identically to real tags. This aligns with the
/// design philosophy that metadata IS built-in tags — they're just convenient
/// defaults that are always present.
pub async fn search_song_units(
    query_text: String,
    name_auto_search: bool,
) -> Result<Vec<String>, String> {
    // Parse the query
    let expr = beadline_tags::parser::parse_query(&query_text, name_auto_search)
        .map_err(|e| e.to_string())?;

    // Get DB connection
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();

    // Fetch all tags from DB
    let mut tags = beadline_tags::repository::get_all_tags(conn)
        .await
        .map_err(|e| e.to_string())?;

    // Fetch all song units from DB
    let song_units = beadline_core::repository::get_all_song_units(conn)
        .await
        .map_err(|e| e.to_string())?;

    // Build SongUnitViews and inject synthetic named tags from metadata
    let mut units: Vec<SongUnitView> = Vec::with_capacity(song_units.len());

    for (i, su) in song_units.iter().enumerate() {
        let mut tag_ids = su.tag_ids.clone();

        // Inject synthetic tags for metadata fields so the evaluator
        // can match name:, artist:, album: queries naturally.
        let metadata_fields: Vec<(&str, String)> = vec![
            ("name", su.metadata.title.clone()),
            ("artist", su.metadata.artists.join(", ")),
            ("album", su.metadata.album.clone()),
        ];

        for (key, value) in metadata_fields {
            if value.is_empty() {
                continue;
            }
            let syn_id = format!("__syn_{}_{}", key, i);
            tags.push(beadline_tags::model::tag::Tag {
                id: syn_id.clone(),
                key: Some(key.to_string()),
                value,
                tag_type: beadline_tags::model::tag::TagType::BuiltIn,
                parent_id: None,
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            });
            tag_ids.push(syn_id);
        }

        units.push(SongUnitView {
            id: su.id.clone(),
            tag_ids,
        });
    }

    Ok(beadline_tags::evaluator::filter_song_units(&expr, &units, &tags))
}
