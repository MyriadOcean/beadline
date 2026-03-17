// FRB-exposed parser functions
//
// Direct delegation to beadline_tags::parser — no DB access needed.

pub use beadline_tags::model::query::{QueryChip, QueryExpression};

pub fn parse_query(input: String, name_auto_search: bool) -> Result<QueryExpression, String> {
    beadline_tags::parser::parse_query(&input, name_auto_search).map_err(|e| e.to_string())
}

pub fn serialize_query(expr: QueryExpression) -> String {
    beadline_tags::parser::serialize_query(&expr)
}

pub fn parse_to_chips(input: String, name_auto_search: bool) -> Result<Vec<QueryChip>, String> {
    beadline_tags::parser::parse_to_chips(&input, name_auto_search).map_err(|e| e.to_string())
}

/// A Dart-friendly chip representation with all fields as simple types.
/// FRB can serialize this directly (no opaque wrapper needed).
pub struct DartQueryChip {
    /// Chip type as a string: "named_tag", "nameless_tag", "bare_keyword", "range", "negation", "or_operator"
    pub chip_type: String,
    /// The display text for this chip
    pub text: String,
    /// Byte offset of the chip's start in the original query string
    pub start: usize,
    /// Byte offset of the chip's end in the original query string
    pub end: usize,
}

/// Parse a query string and return chips as Dart-friendly structs.
pub fn parse_to_dart_chips(
    input: String,
    name_auto_search: bool,
) -> Result<Vec<DartQueryChip>, String> {
    let chips = beadline_tags::parser::parse_to_chips(&input, name_auto_search)
        .map_err(|e| e.to_string())?;
    Ok(chips
        .into_iter()
        .map(|c| {
            let chip_type = match c.chip_type {
                beadline_tags::model::query::ChipType::NamedTag => "named_tag",
                beadline_tags::model::query::ChipType::NamelessTag => "nameless_tag",
                beadline_tags::model::query::ChipType::BareKeyword => "bare_keyword",
                beadline_tags::model::query::ChipType::Range => "range",
                beadline_tags::model::query::ChipType::Negation => "negation",
                beadline_tags::model::query::ChipType::OrOperator => "or_operator",
            };
            DartQueryChip {
                chip_type: chip_type.to_string(),
                text: c.text,
                start: c.start,
                end: c.end,
            }
        })
        .collect())
}
