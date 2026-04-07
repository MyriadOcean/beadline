// Query evaluator: evaluate_query, filter_song_units

use crate::model::query::{BoolOp, QueryExpression, RangeItem};
use crate::model::tag::{Tag, TagType};

/// A lightweight view of a Song Unit for evaluation purposes.
/// Contains the Song Unit's ID and the IDs of tags attached to it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SongUnitView {
    pub id: String,
    pub tag_ids: Vec<String>,
}

/// Evaluate a query expression against a single Song Unit.
///
/// The evaluator is a pure function — `tags` is the full set of tags in the system,
/// passed in so there's no database dependency. The bridge crate fetches tags from
/// the DB and passes them here.
///
/// Matching rules:
/// - `NamedTagQuery`: matches only named tags with the specified key
/// - `NamelessTagQuery`: matches only nameless tags
/// - `BareKeyword`: matches nameless tags, and optionally the `name` built-in tag
///   if `name_auto_search` is true (OR logic)
/// - `RangeQuery`: matches named tags whose value falls within the specified ranges
/// - `BooleanQuery`: AND/OR combination of sub-expressions
///
/// Alias resolution: if a tag has aliases, queries matching any alias will match
/// the primary tag.
///
/// `includeChildren`: if a matched tag has `include_children=true`, all descendant
/// tags also count as matches.
pub fn evaluate_query(
    expr: &QueryExpression,
    unit: &SongUnitView,
    tags: &[Tag],
) -> bool {
    match expr {
        QueryExpression::NamedTagQuery {
            key,
            value,
            negated,
            wildcard,
        } => {
            let matched = match_named_tag(key, value, *wildcard, unit, tags);
            if *negated { !matched } else { matched }
        }

        QueryExpression::NamelessTagQuery {
            value,
            negated,
            wildcard,
        } => {
            let matched = match_nameless_tag(value, *wildcard, unit, tags);
            if *negated { !matched } else { matched }
        }

        QueryExpression::BareKeyword {
            value,
            negated,
            name_auto_search,
        } => {
            // Bare keywords match nameless tags using wildcard contains
            let nameless_match = match_nameless_tag_contains(value, unit, tags);

            // If name_auto_search is enabled, also match against the `name` built-in tag
            let name_match = if *name_auto_search {
                match_named_tag_contains("name", value, unit, tags)
            } else {
                false
            };

            let matched = nameless_match || name_match;
            if *negated { !matched } else { matched }
        }

        QueryExpression::RangeQuery { key, ranges } => {
            match_range(key, ranges, unit, tags)
        }

        QueryExpression::BooleanQuery { operator, operands } => {
            if operands.is_empty() {
                // Empty AND = match all, empty OR = match none
                return *operator == BoolOp::And;
            }
            match operator {
                BoolOp::And => operands.iter().all(|op| evaluate_query(op, unit, tags)),
                BoolOp::Or => operands.iter().any(|op| evaluate_query(op, unit, tags)),
            }
        }
    }
}

/// Batch evaluate: filter Song Units by a query. Returns matching IDs.
pub fn filter_song_units(
    expr: &QueryExpression,
    units: &[SongUnitView],
    tags: &[Tag],
) -> Vec<String> {
    units
        .iter()
        .filter(|unit| evaluate_query(expr, unit, tags))
        .map(|unit| unit.id.clone())
        .collect()
}


// ---------------------------------------------------------------------------
// Internal matching helpers
// ---------------------------------------------------------------------------

/// Collect all tag IDs that should be considered a match for a given tag,
/// including descendants if `include_children` is true.
fn collect_matching_tag_ids(tag: &Tag, all_tags: &[Tag]) -> Vec<String> {
    let mut ids = vec![tag.id.clone()];
    if tag.include_children {
        collect_descendants(&tag.id, all_tags, &mut ids);
    }
    ids
}

/// Recursively collect descendant tag IDs.
fn collect_descendants(parent_id: &str, all_tags: &[Tag], result: &mut Vec<String>) {
    for tag in all_tags {
        if tag.parent_id.as_deref() == Some(parent_id) {
            result.push(tag.id.clone());
            collect_descendants(&tag.id, all_tags, result);
        }
    }
}

/// Resolve a value to matching tags, considering aliases.
/// Returns all tags where the value matches the tag's value or any of its aliases.
fn resolve_by_value<'a>(value: &str, tags: &'a [Tag]) -> Vec<&'a Tag> {
    let lower = value.to_lowercase();
    tags.iter()
        .filter(|t| {
            t.value.to_lowercase() == lower
                || t.alias_names.iter().any(|a| a.to_lowercase() == lower)
        })
        .collect()
}

/// Check if a value matches a pattern, supporting wildcard `*`.
/// - No `*`: exact case-insensitive match
/// - `*text*`: contains
/// - `text*`: starts with
/// - `*text`: ends with
fn wildcard_match(pattern: &str, value: &str) -> bool {
    let p = pattern.to_lowercase();
    let v = value.to_lowercase();

    if !p.contains('*') {
        return p == v;
    }

    let starts_wild = p.starts_with('*');
    let ends_wild = p.ends_with('*');
    let core = p.trim_matches('*');

    if core.is_empty() {
        // Pattern is just "*" or "**" — matches everything
        return true;
    }

    match (starts_wild, ends_wild) {
        (true, true) => v.contains(core),
        (true, false) => v.ends_with(core),
        (false, true) => v.starts_with(core),
        (false, false) => {
            // Pattern like "a*b" — split on first * and check prefix/suffix
            // For simplicity, split on first * only
            if let Some(star_pos) = p.find('*') {
                let prefix = &p[..star_pos];
                let suffix = &p[star_pos + 1..];
                v.starts_with(prefix) && v.ends_with(suffix) && v.len() >= prefix.len() + suffix.len()
            } else {
                p == v
            }
        }
    }
}

/// Match a `NamedTagQuery` against a Song Unit.
/// Only considers named tags with the specified key.
fn match_named_tag(
    key: &str,
    value: &str,
    wildcard: bool,
    unit: &SongUnitView,
    tags: &[Tag],
) -> bool {
    let key_lower = key.to_lowercase();

    // Find all named tags with this key
    let candidate_tags: Vec<&Tag> = tags
        .iter()
        .filter(|t| {
            t.is_named()
                && t.key.as_ref().map_or(false, |k| k.to_lowercase() == key_lower)
        })
        .collect();

    for candidate in &candidate_tags {
        // Check if the value matches (direct or via alias)
        let value_matches = if wildcard {
            wildcard_match(value, &candidate.value)
                || candidate.alias_names.iter().any(|a| wildcard_match(value, a))
        } else if candidate.tag_type == TagType::BuiltIn {
            // Built-in tags (metadata like name, artist, album) use contains-matching
            // so that e.g. name:飞 finds songs with "飞" anywhere in the title
            let val_lower = value.to_lowercase();
            candidate.value.to_lowercase().contains(&val_lower)
                || candidate.alias_names.iter().any(|a| a.to_lowercase().contains(&val_lower))
        } else {
            let resolved = resolve_by_value(value, tags);
            // Check if any resolved tag matches this candidate (by ID)
            if resolved.iter().any(|r| r.id == candidate.id) {
                true
            } else {
                // Direct case-insensitive comparison
                candidate.value.to_lowercase() == value.to_lowercase()
                    || candidate.alias_names.iter().any(|a| a.to_lowercase() == value.to_lowercase())
            }
        };

        if value_matches {
            // Collect IDs including descendants if include_children is set
            let matching_ids = collect_matching_tag_ids(candidate, tags);
            if unit.tag_ids.iter().any(|tid| matching_ids.contains(tid)) {
                return true;
            }
        }
    }

    false
}

/// Match a `NamelessTagQuery` against a Song Unit.
/// Only considers nameless tags.
fn match_nameless_tag(
    value: &str,
    wildcard: bool,
    unit: &SongUnitView,
    tags: &[Tag],
) -> bool {
    // Find all nameless tags
    let nameless_tags: Vec<&Tag> = tags.iter().filter(|t| t.is_nameless()).collect();

    for candidate in &nameless_tags {
        let value_matches = if wildcard {
            wildcard_match(value, &candidate.value)
                || candidate.alias_names.iter().any(|a| wildcard_match(value, a))
        } else {
            candidate.value.to_lowercase() == value.to_lowercase()
                || candidate.alias_names.iter().any(|a| a.to_lowercase() == value.to_lowercase())
        };

        if value_matches {
            let matching_ids = collect_matching_tag_ids(candidate, tags);
            if unit.tag_ids.iter().any(|tid| matching_ids.contains(tid)) {
                return true;
            }
        }
    }

    false
}

/// Match a bare keyword against nameless tags using contains matching.
/// This is the default behavior for bare keywords — `*value*` style matching.
fn match_nameless_tag_contains(
    value: &str,
    unit: &SongUnitView,
    tags: &[Tag],
) -> bool {
    let lower = value.to_lowercase();
    let nameless_tags: Vec<&Tag> = tags.iter().filter(|t| t.is_nameless()).collect();

    for candidate in &nameless_tags {
        let contains_match = candidate.value.to_lowercase().contains(&lower)
            || candidate.alias_names.iter().any(|a| a.to_lowercase().contains(&lower));

        if contains_match {
            let matching_ids = collect_matching_tag_ids(candidate, tags);
            if unit.tag_ids.iter().any(|tid| matching_ids.contains(tid)) {
                return true;
            }
        }
    }

    false
}

/// Match a bare keyword against a specific named tag key using contains matching.
/// Used for `name_auto_search` — matches `name:*value*`.
fn match_named_tag_contains(
    key: &str,
    value: &str,
    unit: &SongUnitView,
    tags: &[Tag],
) -> bool {
    let key_lower = key.to_lowercase();
    let val_lower = value.to_lowercase();

    let candidate_tags: Vec<&Tag> = tags
        .iter()
        .filter(|t| {
            t.is_named()
                && t.key.as_ref().map_or(false, |k| k.to_lowercase() == key_lower)
        })
        .collect();

    for candidate in &candidate_tags {
        let contains_match = candidate.value.to_lowercase().contains(&val_lower)
            || candidate.alias_names.iter().any(|a| a.to_lowercase().contains(&val_lower));

        if contains_match {
            let matching_ids = collect_matching_tag_ids(candidate, tags);
            if unit.tag_ids.iter().any(|tid| matching_ids.contains(tid)) {
                return true;
            }
        }
    }

    false
}

/// Match a `RangeQuery` against a Song Unit.
/// Checks named tags with the specified key and sees if their value falls
/// within any of the specified ranges.
fn match_range(
    key: &str,
    ranges: &[RangeItem],
    unit: &SongUnitView,
    tags: &[Tag],
) -> bool {
    let key_lower = key.to_lowercase();

    // Find named tags with this key that are attached to the unit
    for tag in tags.iter().filter(|t| {
        t.is_named()
            && t.key.as_ref().map_or(false, |k| k.to_lowercase() == key_lower)
    }) {
        let matching_ids = collect_matching_tag_ids(tag, tags);
        if !unit.tag_ids.iter().any(|tid| matching_ids.contains(tid)) {
            continue;
        }

        // Check if the tag's value falls within any range
        for range in ranges {
            if value_in_range(&tag.value, &range.start, &range.end) {
                return true;
            }
        }
    }

    false
}

/// Check if a value falls within a range [start, end].
/// Tries numeric comparison first, falls back to lexicographic.
fn value_in_range(value: &str, start: &str, end: &str) -> bool {
    // Try numeric comparison
    if let (Ok(v), Ok(s), Ok(e)) = (
        value.parse::<f64>(),
        start.parse::<f64>(),
        end.parse::<f64>(),
    ) {
        return v >= s && v <= e;
    }

    // Fallback to lexicographic comparison
    value >= start && value <= end
}


// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::tag::TagType;

    /// Helper to create a named tag.
    fn named_tag(id: &str, key: &str, value: &str) -> Tag {
        Tag {
            id: id.to_string(),
            key: Some(key.to_string()),
            value: value.to_string(),
            tag_type: TagType::User,
            parent_id: None,
            alias_names: vec![],
            include_children: false,
            is_group: false,
            is_locked: false,
            display_order: 0,
            collection_metadata: None,
        }
    }

    /// Helper to create a nameless tag.
    fn nameless_tag(id: &str, value: &str) -> Tag {
        Tag {
            id: id.to_string(),
            key: None,
            value: value.to_string(),
            tag_type: TagType::User,
            parent_id: None,
            alias_names: vec![],
            include_children: false,
            is_group: false,
            is_locked: false,
            display_order: 0,
            collection_metadata: None,
        }
    }

    /// Helper to create a Song Unit view.
    fn unit(id: &str, tag_ids: &[&str]) -> SongUnitView {
        SongUnitView {
            id: id.to_string(),
            tag_ids: tag_ids.iter().map(|s| s.to_string()).collect(),
        }
    }

    // -- NamedTagQuery tests --

    #[test]
    fn named_tag_query_matches_correct_key() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "album", "luotianyi"),
        ];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "luotianyi".into(),
            negated: false,
            wildcard: false,
        };
        assert!(evaluate_query(&expr, &su, &tags));

        // Should NOT match album key
        let expr2 = QueryExpression::NamedTagQuery {
            key: "album".into(),
            value: "luotianyi".into(),
            negated: false,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr2, &su, &tags));
    }

    #[test]
    fn named_tag_query_negation() {
        let tags = vec![named_tag("t1", "artist", "luotianyi")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "luotianyi".into(),
            negated: true,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn named_tag_query_wildcard() {
        let tags = vec![named_tag("t1", "artist", "luotianyi")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "luo*".into(),
            negated: false,
            wildcard: true,
        };
        assert!(evaluate_query(&expr, &su, &tags));

        let expr2 = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "*tianyi".into(),
            negated: false,
            wildcard: true,
        };
        assert!(evaluate_query(&expr2, &su, &tags));
    }

    // -- NamelessTagQuery tests --

    #[test]
    fn nameless_tag_query_matches_only_nameless() {
        let tags = vec![
            nameless_tag("t1", "rock"),
            named_tag("t2", "genre", "rock"),
        ];
        let su = unit("u1", &["t2"]); // only has the named tag

        let expr = QueryExpression::NamelessTagQuery {
            value: "rock".into(),
            negated: false,
            wildcard: false,
        };
        // Should NOT match — unit only has the named "genre:rock", not nameless "rock"
        assert!(!evaluate_query(&expr, &su, &tags));

        // Now with the nameless tag
        let su2 = unit("u2", &["t1"]);
        assert!(evaluate_query(&expr, &su2, &tags));
    }

    #[test]
    fn nameless_tag_query_negation() {
        let tags = vec![nameless_tag("t1", "rock")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamelessTagQuery {
            value: "rock".into(),
            negated: true,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr, &su, &tags));

        // Unit without the tag — negation should match
        let su2 = unit("u2", &[]);
        assert!(evaluate_query(&expr, &su2, &tags));
    }

    // -- BareKeyword tests --

    #[test]
    fn bare_keyword_matches_nameless_contains() {
        let tags = vec![nameless_tag("t1", "electronic")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::BareKeyword {
            value: "electro".into(),
            negated: false,
            name_auto_search: false,
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn bare_keyword_with_name_auto_search() {
        let tags = vec![
            named_tag("t1", "name", "hello world"),
        ];
        let su = unit("u1", &["t1"]);

        // With name_auto_search=true, should match name tag
        let expr = QueryExpression::BareKeyword {
            value: "hello".into(),
            negated: false,
            name_auto_search: true,
        };
        assert!(evaluate_query(&expr, &su, &tags));

        // With name_auto_search=false, should NOT match (no nameless tags)
        let expr2 = QueryExpression::BareKeyword {
            value: "hello".into(),
            negated: false,
            name_auto_search: false,
        };
        assert!(!evaluate_query(&expr2, &su, &tags));
    }

    // -- BooleanQuery tests --

    #[test]
    fn boolean_and() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "album", "best"),
        ];
        let su = unit("u1", &["t1", "t2"]);

        let expr = QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![
                QueryExpression::NamedTagQuery {
                    key: "artist".into(),
                    value: "luotianyi".into(),
                    negated: false,
                    wildcard: false,
                },
                QueryExpression::NamedTagQuery {
                    key: "album".into(),
                    value: "best".into(),
                    negated: false,
                    wildcard: false,
                },
            ],
        };
        assert!(evaluate_query(&expr, &su, &tags));

        // Missing one tag
        let su2 = unit("u2", &["t1"]);
        assert!(!evaluate_query(&expr, &su2, &tags));
    }

    #[test]
    fn boolean_or() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "artist", "yanhe"),
        ];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::BooleanQuery {
            operator: BoolOp::Or,
            operands: vec![
                QueryExpression::NamedTagQuery {
                    key: "artist".into(),
                    value: "luotianyi".into(),
                    negated: false,
                    wildcard: false,
                },
                QueryExpression::NamedTagQuery {
                    key: "artist".into(),
                    value: "yanhe".into(),
                    negated: false,
                    wildcard: false,
                },
            ],
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn empty_and_matches_all() {
        let tags = vec![];
        let su = unit("u1", &[]);

        let expr = QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![],
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn empty_or_matches_none() {
        let tags = vec![];
        let su = unit("u1", &[]);

        let expr = QueryExpression::BooleanQuery {
            operator: BoolOp::Or,
            operands: vec![],
        };
        assert!(!evaluate_query(&expr, &su, &tags));
    }

    // -- RangeQuery tests --

    #[test]
    fn range_query_numeric() {
        let tags = vec![named_tag("t1", "year", "2020")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::RangeQuery {
            key: "year".into(),
            ranges: vec![RangeItem {
                start: "2017".into(),
                end: "2024".into(),
            }],
        };
        assert!(evaluate_query(&expr, &su, &tags));

        // Out of range
        let tags2 = vec![named_tag("t2", "year", "2015")];
        let su2 = unit("u2", &["t2"]);
        assert!(!evaluate_query(&expr, &su2, &tags2));
    }

    #[test]
    fn range_query_multi_range() {
        let tags = vec![named_tag("t1", "year", "2019")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::RangeQuery {
            key: "year".into(),
            ranges: vec![
                RangeItem { start: "2017".into(), end: "2017".into() },
                RangeItem { start: "2019".into(), end: "2021".into() },
            ],
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    // -- Hierarchy (includeChildren) tests --

    #[test]
    fn include_children_matches_descendants() {
        let mut parent = nameless_tag("p1", "vocaloid");
        parent.include_children = true;

        let mut child = nameless_tag("c1", "luotianyi");
        child.parent_id = Some("p1".into());

        let mut grandchild = nameless_tag("g1", "v4");
        grandchild.parent_id = Some("c1".into());

        let tags = vec![parent, child, grandchild];

        // Unit tagged with grandchild only
        let su = unit("u1", &["g1"]);

        // Query for parent with includeChildren=true should match
        let expr = QueryExpression::NamelessTagQuery {
            value: "vocaloid".into(),
            negated: false,
            wildcard: false,
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn include_children_false_no_descendant_match() {
        let mut parent = nameless_tag("p1", "vocaloid");
        parent.include_children = false;

        let mut child = nameless_tag("c1", "luotianyi");
        child.parent_id = Some("p1".into());

        let tags = vec![parent, child];

        // Unit tagged with child only
        let su = unit("u1", &["c1"]);

        // Query for parent with includeChildren=false should NOT match
        let expr = QueryExpression::NamelessTagQuery {
            value: "vocaloid".into(),
            negated: false,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr, &su, &tags));
    }

    // -- Alias resolution tests --

    #[test]
    fn alias_resolution_in_named_tag() {
        let mut tag = named_tag("t1", "artist", "luotianyi");
        tag.alias_names = vec!["洛天依".into()];

        let tags = vec![tag];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "洛天依".into(),
            negated: false,
            wildcard: false,
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn alias_resolution_in_nameless_tag() {
        let mut tag = nameless_tag("t1", "rock");
        tag.alias_names = vec!["ロック".into()];

        let tags = vec![tag];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamelessTagQuery {
            value: "ロック".into(),
            negated: false,
            wildcard: false,
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    // -- Built-in tag matching tests --

    /// Helper to create a built-in named tag.
    fn builtin_tag(id: &str, key: &str, value: &str) -> Tag {
        Tag {
            id: id.to_string(),
            key: Some(key.to_string()),
            value: value.to_string(),
            tag_type: TagType::BuiltIn,
            parent_id: None,
            alias_names: vec![],
            include_children: false,
            is_group: false,
            is_locked: false,
            display_order: 0,
            collection_metadata: None,
        }
    }

    #[test]
    fn builtin_tag_contains_match_without_wildcard() {
        let tags = vec![builtin_tag("t1", "name", "飞鸟和蝉")];
        let su = unit("u1", &["t1"]);

        // name:飞 (no wildcard) should match via contains for BuiltIn tags
        let expr = QueryExpression::NamedTagQuery {
            key: "name".into(),
            value: "飞".into(),
            negated: false,
            wildcard: false,
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn builtin_tag_explicit_wildcard() {
        let tags = vec![builtin_tag("t1", "name", "飞鸟和蝉")];
        let su = unit("u1", &["t1"]);

        // name:*飞* (explicit wildcard) should also match
        let expr = QueryExpression::NamedTagQuery {
            key: "name".into(),
            value: "*飞*".into(),
            negated: false,
            wildcard: true,
        };
        assert!(evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn builtin_tag_starts_with_wildcard() {
        let tags = vec![builtin_tag("t1", "name", "飞鸟和蝉")];
        let su = unit("u1", &["t1"]);

        // name:飞* (starts-with wildcard) should match
        let expr = QueryExpression::NamedTagQuery {
            key: "name".into(),
            value: "飞*".into(),
            negated: false,
            wildcard: true,
        };
        assert!(evaluate_query(&expr, &su, &tags), "name:飞* should match 飞鸟和蝉");
    }

    #[test]
    fn builtin_tag_ends_with_wildcard() {
        let tags = vec![builtin_tag("t1", "name", "飞鸟和蝉")];
        let su = unit("u1", &["t1"]);

        // name:*蝉 (ends-with wildcard) should match
        let expr = QueryExpression::NamedTagQuery {
            key: "name".into(),
            value: "*蝉".into(),
            negated: false,
            wildcard: true,
        };
        assert!(evaluate_query(&expr, &su, &tags), "name:*蝉 should match 飞鸟和蝉");
    }

    #[test]
    fn user_tag_exact_match_only() {
        // User tags should NOT use contains-matching
        let tags = vec![named_tag("t1", "genre", "electronic")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamedTagQuery {
            key: "genre".into(),
            value: "electro".into(),
            negated: false,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr, &su, &tags));
    }

    // -- Named vs nameless scope isolation --

    #[test]
    fn named_query_does_not_match_nameless_tag() {
        let tags = vec![nameless_tag("t1", "rock")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamedTagQuery {
            key: "genre".into(),
            value: "rock".into(),
            negated: false,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr, &su, &tags));
    }

    #[test]
    fn nameless_query_does_not_match_named_tag() {
        let tags = vec![named_tag("t1", "genre", "rock")];
        let su = unit("u1", &["t1"]);

        let expr = QueryExpression::NamelessTagQuery {
            value: "rock".into(),
            negated: false,
            wildcard: false,
        };
        assert!(!evaluate_query(&expr, &su, &tags));
    }

    // -- filter_song_units tests --

    #[test]
    fn filter_returns_matching_ids() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "artist", "yanhe"),
        ];
        let units = vec![
            unit("u1", &["t1"]),
            unit("u2", &["t2"]),
            unit("u3", &["t1", "t2"]),
        ];

        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "luotianyi".into(),
            negated: false,
            wildcard: false,
        };

        let result = filter_song_units(&expr, &units, &tags);
        assert_eq!(result, vec!["u1".to_string(), "u3".to_string()]);
    }

    // -- Wildcard matching unit tests --

    #[test]
    fn wildcard_contains() {
        assert!(wildcard_match("*hello*", "say hello world"));
        assert!(wildcard_match("*hello*", "hello"));
        assert!(!wildcard_match("*hello*", "helo"));
    }

    #[test]
    fn wildcard_starts_with() {
        assert!(wildcard_match("hello*", "hello world"));
        assert!(!wildcard_match("hello*", "say hello"));
    }

    #[test]
    fn wildcard_ends_with() {
        assert!(wildcard_match("*world", "hello world"));
        assert!(!wildcard_match("*world", "world hello"));
    }

    #[test]
    fn wildcard_star_matches_all() {
        assert!(wildcard_match("*", "anything"));
        assert!(wildcard_match("*", ""));
    }

    #[test]
    fn wildcard_middle() {
        assert!(wildcard_match("hel*rld", "hello world"));
        assert!(!wildcard_match("hel*rld", "help"));
    }

    // -----------------------------------------------------------------------
    // Property-based tests (proptest)
    // -----------------------------------------------------------------------

    use proptest::prelude::*;

    /// Strategy for generating a valid identifier string (used for tag IDs, keys, values).
    fn arb_identifier() -> impl Strategy<Value = String> {
        "[a-z][a-z0-9]{0,9}".prop_map(|s| s)
    }

    /// Strategy for generating a unique ID.
    fn arb_id() -> impl Strategy<Value = String> {
        "[a-f0-9]{16}"
    }

    proptest! {
        #![proptest_config(proptest::test_runner::Config::with_cases(100))]

        // Feature: tag-search-system, Property 5: includeChildren=true matches descendants
        // Validates: Requirements 4.3, 11.3
        #[test]
        fn include_children_true_matches_descendants(
            parent_id in arb_id(),
            child_id in arb_id(),
            parent_value in arb_identifier(),
            child_value in arb_identifier(),
            unit_id in arb_id(),
            use_named in proptest::bool::ANY,
            key in arb_identifier(),
        ) {
            // Skip if IDs collide
            prop_assume!(parent_id != child_id);

            let (parent_key, child_key) = if use_named {
                (Some(key.clone()), Some(key.clone()))
            } else {
                (None, None)
            };

            let parent = Tag {
                id: parent_id.clone(),
                key: parent_key.clone(),
                value: parent_value.clone(),
                tag_type: TagType::User,
                parent_id: None,
                alias_names: vec![],
                include_children: true, // KEY: include_children is true
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            let child = Tag {
                id: child_id.clone(),
                key: child_key.clone(),
                value: child_value.clone(),
                tag_type: TagType::User,
                parent_id: Some(parent_id.clone()), // child of parent
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            let tags = vec![parent, child];

            // Song unit tagged with the CHILD only
            let su = SongUnitView {
                id: unit_id,
                tag_ids: vec![child_id],
            };

            // Query for the parent tag's value
            let expr = if use_named {
                QueryExpression::NamedTagQuery {
                    key: parent_key.unwrap(),
                    value: parent_value,
                    negated: false,
                    wildcard: false,
                }
            } else {
                QueryExpression::NamelessTagQuery {
                    value: parent_value,
                    negated: false,
                    wildcard: false,
                }
            };

            // With includeChildren=true on parent, querying for parent should match
            // a unit tagged with the child
            prop_assert!(
                evaluate_query(&expr, &su, &tags),
                "includeChildren=true on parent should match unit tagged with child"
            );
        }

        // Feature: tag-search-system, Property 6: includeChildren=false matches only exact tag
        // Validates: Requirements 4.4
        #[test]
        fn include_children_false_matches_only_exact(
            parent_id in arb_id(),
            child_id in arb_id(),
            parent_value in arb_identifier(),
            child_value in arb_identifier(),
            unit_id in arb_id(),
            use_named in proptest::bool::ANY,
            key in arb_identifier(),
        ) {
            // Skip if IDs collide or values are the same (we need distinct tags)
            prop_assume!(parent_id != child_id);
            prop_assume!(parent_value != child_value);

            let (parent_key, child_key) = if use_named {
                (Some(key.clone()), Some(key.clone()))
            } else {
                (None, None)
            };

            let parent = Tag {
                id: parent_id.clone(),
                key: parent_key.clone(),
                value: parent_value.clone(),
                tag_type: TagType::User,
                parent_id: None,
                alias_names: vec![],
                include_children: false, // KEY: include_children is false
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            let child = Tag {
                id: child_id.clone(),
                key: child_key.clone(),
                value: child_value.clone(),
                tag_type: TagType::User,
                parent_id: Some(parent_id.clone()),
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            let tags = vec![parent, child];

            // Song unit tagged with the CHILD only (NOT the parent)
            let su = SongUnitView {
                id: unit_id,
                tag_ids: vec![child_id],
            };

            // Query for the parent tag's value
            let expr = if use_named {
                QueryExpression::NamedTagQuery {
                    key: parent_key.unwrap(),
                    value: parent_value,
                    negated: false,
                    wildcard: false,
                }
            } else {
                QueryExpression::NamelessTagQuery {
                    value: parent_value,
                    negated: false,
                    wildcard: false,
                }
            };

            // With includeChildren=false, querying for parent should NOT match
            // a unit tagged only with the child
            prop_assert!(
                !evaluate_query(&expr, &su, &tags),
                "includeChildren=false on parent should NOT match unit tagged only with child"
            );
        }

        // Feature: tag-search-system, Property 23: Evaluator respects named vs nameless scope
        // Validates: Requirements 11.1, 11.2
        #[test]
        fn evaluator_respects_named_vs_nameless_scope(
            named_tag_id in arb_id(),
            nameless_tag_id in arb_id(),
            key in arb_identifier(),
            value in arb_identifier(),
            unit_id_a in arb_id(),
            unit_id_b in arb_id(),
        ) {
            prop_assume!(named_tag_id != nameless_tag_id);
            prop_assume!(unit_id_a != unit_id_b);

            // A named tag with key:value
            let named = Tag {
                id: named_tag_id.clone(),
                key: Some(key.clone()),
                value: value.clone(),
                tag_type: TagType::User,
                parent_id: None,
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            // A nameless tag with the same value
            let nameless = Tag {
                id: nameless_tag_id.clone(),
                key: None,
                value: value.clone(),
                tag_type: TagType::User,
                parent_id: None,
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            let tags = vec![named.clone(), nameless.clone()];

            // Unit A has ONLY the named tag
            let unit_a = SongUnitView {
                id: unit_id_a,
                tag_ids: vec![named_tag_id.clone()],
            };

            // Unit B has ONLY the nameless tag
            let unit_b = SongUnitView {
                id: unit_id_b,
                tag_ids: vec![nameless_tag_id.clone()],
            };

            // A NamelessTagQuery for `value` should NOT match unit_a (which only has named tag)
            let nameless_query = QueryExpression::NamelessTagQuery {
                value: value.clone(),
                negated: false,
                wildcard: false,
            };
            prop_assert!(
                !evaluate_query(&nameless_query, &unit_a, &tags),
                "NamelessTagQuery should NOT match a unit with only a named tag of the same value"
            );

            // A NamedTagQuery for `key:value` should NOT match unit_b (which only has nameless tag)
            let named_query = QueryExpression::NamedTagQuery {
                key: key.clone(),
                value: value.clone(),
                negated: false,
                wildcard: false,
            };
            prop_assert!(
                !evaluate_query(&named_query, &unit_b, &tags),
                "NamedTagQuery should NOT match a unit with only a nameless tag of the same value"
            );

            // Positive checks: each query SHOULD match the correct unit
            prop_assert!(
                evaluate_query(&nameless_query, &unit_b, &tags),
                "NamelessTagQuery should match a unit with the nameless tag"
            );
            prop_assert!(
                evaluate_query(&named_query, &unit_a, &tags),
                "NamedTagQuery should match a unit with the named tag"
            );
        }

        // Feature: tag-search-system, Property 24: Alias resolution in evaluation
        // Validates: Requirements 11.4
        #[test]
        fn alias_resolution_in_evaluation(
            tag_id in arb_id(),
            primary_value in arb_identifier(),
            alias_value in arb_identifier(),
            unit_id in arb_id(),
            use_named in proptest::bool::ANY,
            key in arb_identifier(),
        ) {
            // Alias must differ from primary value to be a meaningful test
            prop_assume!(primary_value.to_lowercase() != alias_value.to_lowercase());

            let tag_key = if use_named { Some(key.clone()) } else { None };

            let tag = Tag {
                id: tag_id.clone(),
                key: tag_key.clone(),
                value: primary_value.clone(),
                tag_type: TagType::User,
                parent_id: None,
                alias_names: vec![alias_value.clone()], // tag has an alias
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            };

            let tags = vec![tag];

            // Song unit tagged with the primary tag
            let su = SongUnitView {
                id: unit_id,
                tag_ids: vec![tag_id],
            };

            // Query using the ALIAS value — should still match
            let expr = if use_named {
                QueryExpression::NamedTagQuery {
                    key: tag_key.unwrap(),
                    value: alias_value.clone(),
                    negated: false,
                    wildcard: false,
                }
            } else {
                QueryExpression::NamelessTagQuery {
                    value: alias_value.clone(),
                    negated: false,
                    wildcard: false,
                }
            };

            prop_assert!(
                evaluate_query(&expr, &su, &tags),
                "Querying by alias '{}' should match unit tagged with primary tag '{}'",
                alias_value,
                primary_value
            );

            // Also verify querying by primary value still works
            let expr_primary = if use_named {
                QueryExpression::NamedTagQuery {
                    key: key.clone(),
                    value: primary_value.clone(),
                    negated: false,
                    wildcard: false,
                }
            } else {
                QueryExpression::NamelessTagQuery {
                    value: primary_value.clone(),
                    negated: false,
                    wildcard: false,
                }
            };

            prop_assert!(
                evaluate_query(&expr_primary, &su, &tags),
                "Querying by primary value '{}' should also match",
                primary_value
            );
        }
    }
}
