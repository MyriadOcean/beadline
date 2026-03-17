// FRB-exposed suggestion functions
//
// Fetches all tags from DB via repository, then delegates to
// beadline_tags::suggestion for pure computation.

pub use beadline_tags::suggestion::Suggestion;
use super::database_api::lock_db;

pub async fn get_suggestions(
    fragment: String,
    max_results: u32,
) -> Result<Vec<Suggestion>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let tags = beadline_tags::repository::get_all_tags(conn)
        .await
        .map_err(|e| e.to_string())?;
    Ok(beadline_tags::suggestion::get_suggestions(
        &fragment,
        &tags,
        max_results as usize,
    ))
}

/// A Dart-friendly suggestion representation with all fields as simple types.
/// FRB can serialize this directly (no opaque wrapper needed).
pub struct DartSuggestion {
    /// Text shown to the user in the dropdown.
    pub display_text: String,
    /// Text inserted into the query when the user selects this suggestion.
    pub insert_text: String,
    /// Suggestion type as a string: "named_tag_key", "named_tag_value", "nameless_tag", "hierarchical_tag"
    pub suggestion_type: String,
}

/// Get suggestions and return them as Dart-friendly structs.
pub async fn get_dart_suggestions(
    fragment: String,
    max_results: u32,
) -> Result<Vec<DartSuggestion>, String> {
    let guard = lock_db().await?;
    let conn = guard.as_ref().unwrap();
    let tags = beadline_tags::repository::get_all_tags(conn)
        .await
        .map_err(|e| e.to_string())?;
    let suggestions = beadline_tags::suggestion::get_suggestions(
        &fragment,
        &tags,
        max_results as usize,
    );
    Ok(suggestions
        .into_iter()
        .map(|s| {
            let stype = match s.suggestion_type {
                beadline_tags::suggestion::SuggestionType::NamedTagKey => "named_tag_key",
                beadline_tags::suggestion::SuggestionType::NamedTagValue => "named_tag_value",
                beadline_tags::suggestion::SuggestionType::NamelessTag => "nameless_tag",
                beadline_tags::suggestion::SuggestionType::HierarchicalTag => "hierarchical_tag",
            };
            DartSuggestion {
                display_text: s.display_text,
                insert_text: s.insert_text,
                suggestion_type: stype.to_string(),
            }
        })
        .collect())
}
