// Suggestion engine: get_suggestions

use crate::model::tag::Tag;

/// The type of a suggestion, used for UI display (icons, grouping).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SuggestionType {
    /// A named tag key (e.g. "artist", "album").
    NamedTagKey,
    /// A value for a specific named tag key (e.g. "luotianyi" for key "artist").
    NamedTagValue,
    /// A nameless tag value (e.g. "rock", "v4").
    NamelessTag,
    /// A hierarchical child tag (e.g. "luotianyi/v4").
    HierarchicalTag,
}

/// A single suggestion returned by the suggestion engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Suggestion {
    /// Text shown to the user in the dropdown.
    pub display_text: String,
    /// Text inserted into the query when the user selects this suggestion.
    pub insert_text: String,
    /// Classification for UI rendering (icon, color).
    pub suggestion_type: SuggestionType,
}

/// Format `key:value` for insertion, quoting the value if it contains spaces.
fn format_kv(key: &str, value: &str) -> String {
    if value.contains(' ') {
        format!("{}:\"{}\"", key, value)
    } else {
        format!("{}:{}", key, value)
    }
}

/// Get suggestions for the current input fragment.
///
/// Behavior:
/// - Empty fragment: return all unique values (named tag values + nameless tags).
/// - Fragment with colon (e.g. `artist:luo`): suggest values for that key.
/// - Fragment without colon: suggest all values that match via prefix, contains,
///   or fuzzy matching. Each suggestion's insert_text includes the proper query
///   syntax (e.g. `artist:luotianyi` for named, `tag:rock` for nameless).
///
/// Matching priority: exact > prefix > contains > fuzzy (edit distance ≤ 2).
pub fn get_suggestions(
    fragment: &str,
    tags: &[Tag],
    max_results: usize,
) -> Vec<Suggestion> {
    if fragment.is_empty() {
        return suggest_all_values(tags, max_results);
    }

    if let Some(colon_pos) = fragment.find(':') {
        let key = &fragment[..colon_pos];
        let partial_value = &fragment[colon_pos + 1..];
        suggest_values_for_key(key, partial_value, tags, max_results)
    } else {
        suggest_without_colon(fragment, tags, max_results)
    }
}

// ---------------------------------------------------------------------------
// Fuzzy matching
// ---------------------------------------------------------------------------

/// Compute Levenshtein edit distance between two strings.
fn levenshtein(a: &str, b: &str) -> usize {
    let a_chars: Vec<char> = a.chars().collect();
    let b_chars: Vec<char> = b.chars().collect();
    let m = a_chars.len();
    let n = b_chars.len();

    if m == 0 { return n; }
    if n == 0 { return m; }

    let mut prev = (0..=n).collect::<Vec<_>>();
    let mut curr = vec![0; n + 1];

    for i in 1..=m {
        curr[0] = i;
        for j in 1..=n {
            let cost = if a_chars[i - 1] == b_chars[j - 1] { 0 } else { 1 };
            curr[j] = (prev[j] + 1)
                .min(curr[j - 1] + 1)
                .min(prev[j - 1] + cost);
        }
        std::mem::swap(&mut prev, &mut curr);
    }
    prev[n]
}

/// Match score for ranking. Lower is better. None means no match.
/// Priority: exact(0) > prefix(1) > contains(2) > fuzzy(3+).
fn match_score(pattern: &str, candidate: &str) -> Option<usize> {
    let p = pattern.to_lowercase();
    let c = candidate.to_lowercase();

    if c == p {
        return Some(0); // exact
    }
    if c.starts_with(&p) {
        return Some(1); // prefix
    }
    if c.contains(&p) {
        return Some(2); // contains
    }
    // Fuzzy: only if pattern is at least 2 chars and edit distance ≤ 2
    if p.len() >= 2 {
        let dist = levenshtein(&p, &c);
        // Scale threshold: allow up to min(2, pattern_len/2)
        let threshold = 2.min(p.len() / 2).max(1);
        if dist <= threshold {
            return Some(3 + dist);
        }
        // Also try fuzzy against substrings of candidate (for partial fuzzy)
        if c.len() > p.len() {
            let c_chars: Vec<char> = c.chars().collect();
            for start in 0..=(c_chars.len().saturating_sub(p.len())) {
                let end = (start + p.len() + 1).min(c_chars.len());
                let sub: String = c_chars[start..end].iter().collect();
                let d = levenshtein(&p, &sub);
                if d <= threshold {
                    return Some(3 + d);
                }
            }
        }
    }
    None
}


// ---------------------------------------------------------------------------
// Empty fragment: suggest all unique values
// ---------------------------------------------------------------------------

/// When the fragment is empty, return unique tag keys (e.g. `album:`, `artist:`)
/// plus all unique values (named tag values + nameless tags).
/// Keys come first (alphabetical), then values (alphabetical).
fn suggest_all_values(tags: &[Tag], max_results: usize) -> Vec<Suggestion> {
    let mut result: Vec<Suggestion> = Vec::new();

    // 1. Collect unique named tag keys (e.g. "artist:", "album:")
    let mut seen_keys = std::collections::HashSet::new();
    let mut key_suggestions: Vec<Suggestion> = Vec::new();
    for tag in tags.iter().filter(|t| t.is_named()) {
        if let Some(ref key) = tag.key {
            let key_lower = key.to_lowercase();
            if seen_keys.insert(key_lower) {
                key_suggestions.push(Suggestion {
                    display_text: format!("{}:", key),
                    insert_text: format!("{}:", key),
                    suggestion_type: SuggestionType::NamedTagKey,
                });
            }
        }
    }
    key_suggestions.sort_by(|a, b| a.display_text.to_lowercase().cmp(&b.display_text.to_lowercase()));

    // 2. Collect named tag values, skipping values that duplicate a key name
    //    (e.g. if key "album" exists, don't also show value "album")
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut value_suggestions: Vec<Suggestion> = Vec::new();
    for tag in tags.iter().filter(|t| t.is_named()) {
        if let Some(ref key) = tag.key {
            // Skip if the value is the same as any known key name
            if seen_keys.contains(&tag.value.to_lowercase()) {
                continue;
            }
            let dedup_key = format!("{}:{}", key.to_lowercase(), tag.value.to_lowercase());
            if seen.insert(dedup_key) {
                value_suggestions.push(Suggestion {
                    display_text: tag.value.clone(),
                    insert_text: format_kv(key, &tag.value),
                    suggestion_type: SuggestionType::NamedTagValue,
                });
            }
        }
    }

    // 3. Collect nameless tag values
    let mut seen_ids = std::collections::HashSet::new();
    for tag in tags.iter().filter(|t| t.is_nameless()) {
        if seen_ids.insert(tag.id.clone()) {
            let path = build_tag_path(&tag.id, tags);
            let is_hierarchical = path.contains('/');
            value_suggestions.push(Suggestion {
                display_text: path,
                insert_text: format!("tag:{}", tag.value),
                suggestion_type: if is_hierarchical {
                    SuggestionType::HierarchicalTag
                } else {
                    SuggestionType::NamelessTag
                },
            });
        }
    }

    value_suggestions.sort_by(|a, b| a.display_text.to_lowercase().cmp(&b.display_text.to_lowercase()));

    // Keys first, then values
    result.extend(key_suggestions);
    result.extend(value_suggestions);
    result.truncate(max_results);
    result
}


// ---------------------------------------------------------------------------
// Without colon: suggest values matching the fragment
// ---------------------------------------------------------------------------

/// Suggest tag keys and values (named + nameless) that match the fragment via
/// prefix, contains, or fuzzy matching. Each suggestion includes proper
/// query syntax in insert_text.
fn suggest_without_colon(
    fragment: &str,
    tags: &[Tag],
    max_results: usize,
) -> Vec<Suggestion> {
    let mut scored: Vec<(usize, Suggestion)> = Vec::new();
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();

    // Collect all known key names for dedup (so we don't show "album" value when "album:" key exists)
    let all_key_names: std::collections::HashSet<String> = tags.iter()
        .filter(|t| t.is_named())
        .filter_map(|t| t.key.as_ref().map(|k| k.to_lowercase()))
        .collect();

    // 1. Match against named tag keys (e.g. typing "alb" suggests "album:")
    let mut seen_keys = std::collections::HashSet::new();
    for tag in tags.iter().filter(|t| t.is_named()) {
        if let Some(ref key) = tag.key {
            let key_lower = key.to_lowercase();
            if seen_keys.contains(&key_lower) {
                continue;
            }
            if let Some(score) = match_score(fragment, key) {
                seen_keys.insert(key_lower);
                scored.push((score, Suggestion {
                    display_text: format!("{}:", key),
                    insert_text: format!("{}:", key),
                    suggestion_type: SuggestionType::NamedTagKey,
                }));
            }
        }
    }

    // 2. Named tag values (skip values that duplicate a key name)
    for tag in tags.iter().filter(|t| t.is_named()) {
        if let Some(ref key) = tag.key {
            // Skip if the value is the same as any known key name
            if all_key_names.contains(&tag.value.to_lowercase()) {
                continue;
            }
            let dedup_key = format!("{}:{}", key.to_lowercase(), tag.value.to_lowercase());
            if seen.contains(&dedup_key) {
                continue;
            }

            // Check value match
            let value_score = match_score(fragment, &tag.value);
            // Check alias match
            let alias_score = tag.alias_names.iter()
                .filter_map(|a| match_score(fragment, a))
                .min();
            let best = value_score.into_iter().chain(alias_score).min();

            if let Some(score) = best {
                seen.insert(dedup_key);
                scored.push((score, Suggestion {
                    display_text: tag.value.clone(),
                    insert_text: format_kv(key, &tag.value),
                    suggestion_type: SuggestionType::NamedTagValue,
                }));
            }
        }
    }

    // Nameless tag values
    let mut seen_ids = std::collections::HashSet::new();
    for tag in tags.iter().filter(|t| t.is_nameless()) {
        if seen_ids.contains(&tag.id) {
            continue;
        }

        let value_score = match_score(fragment, &tag.value);
        let alias_score = tag.alias_names.iter()
            .filter_map(|a| match_score(fragment, a))
            .min();
        let best = value_score.into_iter().chain(alias_score).min();

        if let Some(score) = best {
            seen_ids.insert(tag.id.clone());
            let path = build_tag_path(&tag.id, tags);
            let is_hierarchical = path.contains('/');

            scored.push((score, Suggestion {
                display_text: path.clone(),
                insert_text: format!("tag:{}", tag.value),
                suggestion_type: if is_hierarchical {
                    SuggestionType::HierarchicalTag
                } else {
                    SuggestionType::NamelessTag
                },
            }));

            // Also include children of matched nameless tags
            suggest_children_scored(tag, tags, fragment, &mut scored, &mut seen_ids);
        }
    }

    // Sort by score (lower = better), then alphabetically
    scored.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.display_text.cmp(&b.1.display_text)));
    scored.into_iter().map(|(_, s)| s).take(max_results).collect()
}

/// Recursively add children of a matched nameless tag with scores.
fn suggest_children_scored(
    parent: &Tag,
    all_tags: &[Tag],
    fragment: &str,
    scored: &mut Vec<(usize, Suggestion)>,
    seen_ids: &mut std::collections::HashSet<String>,
) {
    for child in all_tags.iter().filter(|t| {
        t.is_nameless() && t.parent_id.as_deref() == Some(&parent.id)
    }) {
        if seen_ids.contains(&child.id) {
            continue;
        }
        seen_ids.insert(child.id.clone());

        let path = build_tag_path(&child.id, all_tags);
        // Children of a matched parent get a slightly worse score
        let child_score = match_score(fragment, &child.value).unwrap_or(5);
        scored.push((child_score.max(2), Suggestion {
            display_text: path,
            insert_text: format!("tag:{}", child.value),
            suggestion_type: SuggestionType::HierarchicalTag,
        }));

        suggest_children_scored(child, all_tags, fragment, scored, seen_ids);
    }
}


// ---------------------------------------------------------------------------
// With colon: suggest values for a specific key
// ---------------------------------------------------------------------------

/// Suggest values for a specific named tag key with fuzzy matching.
fn suggest_values_for_key(
    key: &str,
    partial_value: &str,
    tags: &[Tag],
    max_results: usize,
) -> Vec<Suggestion> {
    let key_lower = key.to_lowercase();

    // Special case: `tag:partial` suggests nameless tag values
    if key_lower == "tag" {
        return suggest_nameless_values(partial_value, tags, max_results);
    }

    let mut scored: Vec<(usize, Suggestion)> = Vec::new();
    let mut seen_values = std::collections::HashSet::new();

    for tag in tags.iter().filter(|t| {
        t.is_named() && t.key.as_ref().map_or(false, |k| k.to_lowercase() == key_lower)
    }) {
        let value_lower = tag.value.to_lowercase();
        if seen_values.contains(&value_lower) {
            continue;
        }

        if partial_value.is_empty() {
            // No partial: show all values for this key
            seen_values.insert(value_lower);
            scored.push((0, Suggestion {
                display_text: tag.value.clone(),
                insert_text: format_kv(key, &tag.value),
                suggestion_type: SuggestionType::NamedTagValue,
            }));
        } else {
            let value_score = match_score(partial_value, &tag.value);
            let alias_score = tag.alias_names.iter()
                .filter_map(|a| match_score(partial_value, a))
                .min();
            let best = value_score.into_iter().chain(alias_score).min();

            if let Some(score) = best {
                seen_values.insert(value_lower);
                scored.push((score, Suggestion {
                    display_text: tag.value.clone(),
                    insert_text: format_kv(key, &tag.value),
                    suggestion_type: SuggestionType::NamedTagValue,
                }));
            }
        }
    }

    scored.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.display_text.cmp(&b.1.display_text)));
    scored.into_iter().map(|(_, s)| s).take(max_results).collect()
}

/// Suggest nameless tag values for `tag:partial` syntax with fuzzy matching.
fn suggest_nameless_values(
    partial_value: &str,
    tags: &[Tag],
    max_results: usize,
) -> Vec<Suggestion> {
    let mut scored: Vec<(usize, Suggestion)> = Vec::new();
    let mut seen_ids = std::collections::HashSet::new();

    for tag in tags.iter().filter(|t| t.is_nameless()) {
        if seen_ids.contains(&tag.id) {
            continue;
        }

        if partial_value.is_empty() {
            seen_ids.insert(tag.id.clone());
            let path = build_tag_path(&tag.id, tags);
            let is_hierarchical = path.contains('/');
            scored.push((0, Suggestion {
                display_text: path,
                insert_text: format!("tag:{}", tag.value),
                suggestion_type: if is_hierarchical {
                    SuggestionType::HierarchicalTag
                } else {
                    SuggestionType::NamelessTag
                },
            }));
        } else {
            let value_score = match_score(partial_value, &tag.value);
            let alias_score = tag.alias_names.iter()
                .filter_map(|a| match_score(partial_value, a))
                .min();
            let best = value_score.into_iter().chain(alias_score).min();

            if let Some(score) = best {
                seen_ids.insert(tag.id.clone());
                let path = build_tag_path(&tag.id, tags);
                let is_hierarchical = path.contains('/');
                scored.push((score, Suggestion {
                    display_text: path,
                    insert_text: format!("tag:{}", tag.value),
                    suggestion_type: if is_hierarchical {
                        SuggestionType::HierarchicalTag
                    } else {
                        SuggestionType::NamelessTag
                    },
                }));
            }
        }
    }

    scored.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.display_text.cmp(&b.1.display_text)));
    scored.into_iter().map(|(_, s)| s).take(max_results).collect()
}


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build the full hierarchical path for a tag by walking up the parent chain.
fn build_tag_path(tag_id: &str, all_tags: &[Tag]) -> String {
    let mut segments = Vec::new();
    let mut current_id = Some(tag_id.to_string());
    let mut depth = 0;
    const MAX_DEPTH: usize = 100;

    while let Some(ref id) = current_id {
        if depth >= MAX_DEPTH {
            break;
        }
        if let Some(tag) = all_tags.iter().find(|t| t.id == *id) {
            segments.push(tag.value.clone());
            current_id = tag.parent_id.clone();
        } else {
            break;
        }
        depth += 1;
    }

    segments.reverse();
    segments.join("/")
}


// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::tag::TagType;

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

    // -- Empty fragment: all values --

    #[test]
    fn empty_fragment_returns_keys_and_values() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            nameless_tag("t2", "rock"),
        ];
        let result = get_suggestions("", &tags, 20);
        assert!(!result.is_empty());
        // Should show tag keys like "artist:"
        assert!(result.iter().any(|s| s.display_text == "artist:" && s.suggestion_type == SuggestionType::NamedTagKey));
        // Should show values
        assert!(result.iter().any(|s| s.display_text == "luotianyi"));
        assert!(result.iter().any(|s| s.display_text == "rock"));
        // Keys should come before values
        let key_pos = result.iter().position(|s| s.display_text == "artist:").unwrap();
        let val_pos = result.iter().position(|s| s.display_text == "luotianyi").unwrap();
        assert!(key_pos < val_pos, "Keys should appear before values");
    }

    #[test]
    fn empty_fragment_key_insert_text_ends_with_colon() {
        let tags = vec![
            named_tag("t1", "album", "best"),
        ];
        let result = get_suggestions("", &tags, 20);
        let key_suggestion = result.iter().find(|s| s.suggestion_type == SuggestionType::NamedTagKey).unwrap();
        assert_eq!(key_suggestion.display_text, "album:");
        assert_eq!(key_suggestion.insert_text, "album:");
    }

    // -- Without colon: value suggestions --

    #[test]
    fn suggests_named_tag_values_by_prefix() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "album", "best"),
            named_tag("t3", "artist", "yanhe"),
        ];
        let result = get_suggestions("luo", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "luotianyi" && s.insert_text == "artist:luotianyi"));
        assert!(!result.iter().any(|s| s.display_text == "best"));
    }

    #[test]
    fn typing_key_prefix_suggests_key() {
        let tags = vec![
            named_tag("t1", "album", "best"),
            named_tag("t2", "artist", "luotianyi"),
        ];
        let result = get_suggestions("alb", &tags, 10);
        // Should suggest "album:" as a key
        assert!(result.iter().any(|s| s.display_text == "album:" && s.insert_text == "album:"),
            "Expected 'album:' key suggestion, got: {:?}", result);
    }

    #[test]
    fn suggests_nameless_tag_values_by_contains() {
        let tags = vec![
            nameless_tag("t1", "rock"),
            nameless_tag("t2", "electronic"),
            nameless_tag("t3", "baroque"),
        ];
        let result = get_suggestions("rock", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "rock"));
        assert!(!result.iter().any(|s| s.display_text == "baroque"));
    }

    #[test]
    fn suggests_both_named_and_nameless_values() {
        let tags = vec![
            named_tag("t1", "name", "naming_song"),
            nameless_tag("t2", "naming"),
        ];
        let result = get_suggestions("na", &tags, 10);
        // Should suggest "name:" key
        assert!(result.iter().any(|s| s.display_text == "name:" && s.suggestion_type == SuggestionType::NamedTagKey));
        // Should suggest values
        assert!(result.iter().any(|s| s.display_text == "naming_song"));
        assert!(result.iter().any(|s| s.display_text == "naming"));
    }

    #[test]
    fn suggests_hierarchical_children() {
        let parent = nameless_tag("p1", "luotianyi");
        let mut child = nameless_tag("c1", "v4");
        child.parent_id = Some("p1".to_string());

        let tags = vec![parent, child];
        let result = get_suggestions("luotianyi", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "luotianyi"));
        assert!(result.iter().any(|s| s.display_text == "luotianyi/v4" && s.suggestion_type == SuggestionType::HierarchicalTag));
    }

    #[test]
    fn alias_surfaces_primary_tag() {
        let mut tag = nameless_tag("t1", "rock");
        tag.alias_names = vec!["ロック".to_string()];

        let tags = vec![tag];
        let result = get_suggestions("ロック", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "rock"));
    }

    // -- Fuzzy matching --

    #[test]
    fn fuzzy_match_typo() {
        let tags = vec![
            nameless_tag("t1", "world"),
        ];
        // "wolrd" is a typo for "world" (transposition, edit distance 2)
        let result = get_suggestions("wolrd", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "world"),
            "Expected fuzzy match for 'wolrd' -> 'world', got: {:?}", result);
    }

    #[test]
    fn prefix_match() {
        let tags = vec![
            nameless_tag("t1", "world"),
        ];
        let result = get_suggestions("worl", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "world"));
    }

    #[test]
    fn exact_match_ranked_first() {
        let tags = vec![
            nameless_tag("t1", "electronic"),
            nameless_tag("t2", "electro"),
        ];
        let result = get_suggestions("electro", &tags, 10);
        assert!(result.len() == 2);
        assert_eq!(result[0].display_text, "electro"); // exact match first
    }

    // -- With colon: values for specific key --

    #[test]
    fn suggests_values_for_key() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "artist", "yanhe"),
            named_tag("t3", "album", "best"),
        ];
        let result = get_suggestions("artist:", &tags, 10);
        assert_eq!(result.len(), 2);
        assert!(result.iter().all(|s| s.suggestion_type == SuggestionType::NamedTagValue));
        // Display text is now just the value, not "artist:value"
        assert!(result.iter().any(|s| s.display_text == "luotianyi"));
        assert!(result.iter().any(|s| s.display_text == "yanhe"));
    }

    #[test]
    fn suggests_values_for_key_with_partial() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "artist", "yanhe"),
        ];
        let result = get_suggestions("artist:luo", &tags, 10);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].display_text, "luotianyi");
        assert_eq!(result[0].insert_text, "artist:luotianyi");
    }

    #[test]
    fn suggests_values_only_for_matching_key() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
            named_tag("t2", "album", "luotianyi"),
        ];
        let result = get_suggestions("artist:luo", &tags, 10);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].insert_text, "artist:luotianyi");
    }

    #[test]
    fn tag_colon_suggests_nameless_values() {
        let tags = vec![
            nameless_tag("t1", "rock"),
            nameless_tag("t2", "electronic"),
            named_tag("t3", "genre", "rock"),
        ];
        let result = get_suggestions("tag:ro", &tags, 10);
        assert!(result.iter().any(|s| s.insert_text == "tag:rock"));
        assert!(!result.iter().any(|s| s.insert_text.contains("genre")));
    }

    #[test]
    fn fuzzy_match_in_key_values() {
        let tags = vec![
            named_tag("t1", "artist", "luotianyi"),
        ];
        // "luotinyi" is a typo (missing 'a'), edit distance ~1
        let result = get_suggestions("artist:luotinyi", &tags, 10);
        assert!(!result.is_empty(), "Expected fuzzy match for artist:luotinyi");
    }

    // -- max_results bound --

    #[test]
    fn respects_max_results() {
        let tags: Vec<Tag> = (0..20)
            .map(|i| nameless_tag(&format!("t{}", i), &format!("tag{}", i)))
            .collect();
        let result = get_suggestions("tag", &tags, 5);
        assert!(result.len() <= 5);
    }

    // -- Alias resolution for named tag values --

    #[test]
    fn alias_in_named_tag_value_suggestion() {
        let mut tag = named_tag("t1", "artist", "luotianyi");
        tag.alias_names = vec!["洛天依".to_string()];

        let tags = vec![tag];
        let result = get_suggestions("artist:洛天依", &tags, 10);
        assert!(result.iter().any(|s| s.display_text == "luotianyi"));
    }

    // -- build_tag_path helper --

    #[test]
    fn build_path_single_tag() {
        let tag = nameless_tag("t1", "rock");
        let path = build_tag_path("t1", &[tag]);
        assert_eq!(path, "rock");
    }

    #[test]
    fn build_path_hierarchical() {
        let parent = nameless_tag("p1", "vocaloid");
        let mut child = nameless_tag("c1", "luotianyi");
        child.parent_id = Some("p1".to_string());
        let mut grandchild = nameless_tag("g1", "v4");
        grandchild.parent_id = Some("c1".to_string());

        let tags = vec![parent, child, grandchild];
        let path = build_tag_path("g1", &tags);
        assert_eq!(path, "vocaloid/luotianyi/v4");
    }

    // -- Levenshtein --

    #[test]
    fn levenshtein_basic() {
        assert_eq!(levenshtein("kitten", "sitting"), 3);
        assert_eq!(levenshtein("world", "wolrd"), 2);
        assert_eq!(levenshtein("", "abc"), 3);
        assert_eq!(levenshtein("abc", "abc"), 0);
    }

    // -- match_score --

    #[test]
    fn match_score_exact() {
        assert_eq!(match_score("rock", "rock"), Some(0));
    }

    #[test]
    fn match_score_prefix() {
        assert_eq!(match_score("roc", "rock"), Some(1));
    }

    #[test]
    fn match_score_contains() {
        assert_eq!(match_score("ock", "rock"), Some(2));
    }

    #[test]
    fn match_score_no_match() {
        assert_eq!(match_score("xyz", "rock"), None);
    }

    #[test]
    fn match_score_cjk_contains() {
        // 飞 is contained in 乐正绫 飞跃乌托邦
        assert_eq!(match_score("飞", "乐正绫 飞跃乌托邦"), Some(2));
    }

    #[test]
    fn cjk_value_with_space_found_by_key_search() {
        let tags = vec![
            named_tag("t1", "name", "乐正绫 飞跃乌托邦"),
        ];
        let result = get_suggestions("name:飞", &tags, 10);
        assert!(!result.is_empty(), "Expected to find '乐正绫 飞跃乌托邦' with name:飞, got: {:?}", result);
        assert!(result.iter().any(|s| s.display_text == "乐正绫 飞跃乌托邦"));
    }


    // -----------------------------------------------------------------------
    // Property-based tests
    // -----------------------------------------------------------------------

    mod prop_tests {
        use super::*;
        use proptest::prelude::*;
        use proptest::collection::vec as arb_vec;

        // Feature: tag-search-system, Property 16: Suggestions without colon include values
        // Validates: Requirements 9.2, 9.4
        proptest! {
            #![proptest_config(ProptestConfig::with_cases(100))]

            #[test]
            fn suggestions_without_colon_include_values(
                prefix in "[a-z]{1,3}",
                key_suffixes in arb_vec("[a-z]{0,5}", 1..=3),
                nameless_values in arb_vec("[a-z]{1,8}", 1..=3),
            ) {
                let mut tags: Vec<Tag> = Vec::new();
                // Named tags with values starting with prefix
                for (i, suffix) in key_suffixes.iter().enumerate() {
                    let value = format!("{}{}", prefix, suffix);
                    tags.push(Tag {
                        id: format!("named_{}", i),
                        key: Some("artist".to_string()),
                        value,
                        tag_type: TagType::User,
                        parent_id: None,
                        alias_names: vec![],
                        include_children: false,
                        is_group: false,
                        is_locked: false,
                        display_order: 0,
                        collection_metadata: None,
                    });
                }

                // Nameless tags with values containing prefix
                for (i, val) in nameless_values.iter().enumerate() {
                    let value = format!("{}{}", prefix, val);
                    tags.push(Tag {
                        id: format!("nameless_{}", i),
                        key: None,
                        value,
                        tag_type: TagType::User,
                        parent_id: None,
                        alias_names: vec![],
                        include_children: false,
                        is_group: false,
                        is_locked: false,
                        display_order: 0,
                        collection_metadata: None,
                    });
                }

                let result = get_suggestions(&prefix, &tags, 50);

                // Must include at least one NamedTagValue suggestion
                let has_value = result.iter().any(|s| s.suggestion_type == SuggestionType::NamedTagValue);
                prop_assert!(has_value, "Expected at least one NamedTagValue suggestion for prefix {:?}", prefix);

                // Must include at least one NamelessTag suggestion
                let has_nameless = result.iter().any(|s|
                    s.suggestion_type == SuggestionType::NamelessTag
                    || s.suggestion_type == SuggestionType::HierarchicalTag
                );
                prop_assert!(has_nameless, "Expected at least one NamelessTag suggestion for prefix {:?}", prefix);

                // NamedTagKey suggestions should have display_text ending with ':'
                for s in result.iter().filter(|s| s.suggestion_type == SuggestionType::NamedTagKey) {
                    prop_assert!(
                        s.display_text.ends_with(':'),
                        "NamedTagKey suggestion {:?} should end with ':'",
                        s.display_text
                    );
                    prop_assert!(
                        s.insert_text.ends_with(':'),
                        "NamedTagKey insert_text {:?} should end with ':'",
                        s.insert_text
                    );
                }
            }
        }

        // Feature: tag-search-system, Property 17: Suggestions with colon return values for that key only
        // Validates: Requirements 9.3
        proptest! {
            #![proptest_config(ProptestConfig::with_cases(100))]

            #[test]
            fn suggestions_with_colon_return_values_for_key_only(
                key in "[a-z]{2,6}",
                partial in "[a-z]{0,3}",
                matching_values in arb_vec("[a-z]{1,8}", 1..=4),
                other_key in "[a-z]{2,6}",
                other_values in arb_vec("[a-z]{1,8}", 1..=3),
            ) {
                prop_assume!(key != other_key);
                prop_assume!(key != "tag");

                let mut tags: Vec<Tag> = Vec::new();

                for (i, val) in matching_values.iter().enumerate() {
                    let value = format!("{}{}", partial, val);
                    tags.push(Tag {
                        id: format!("target_{}", i),
                        key: Some(key.clone()),
                        value,
                        tag_type: TagType::User,
                        parent_id: None,
                        alias_names: vec![],
                        include_children: false,
                        is_group: false,
                        is_locked: false,
                        display_order: 0,
                        collection_metadata: None,
                    });
                }

                for (i, val) in other_values.iter().enumerate() {
                    tags.push(Tag {
                        id: format!("other_{}", i),
                        key: Some(other_key.clone()),
                        value: val.clone(),
                        tag_type: TagType::User,
                        parent_id: None,
                        alias_names: vec![],
                        include_children: false,
                        is_group: false,
                        is_locked: false,
                        display_order: 0,
                        collection_metadata: None,
                    });
                }

                let fragment = format!("{}:{}", key, partial);
                let result = get_suggestions(&fragment, &tags, 50);

                for s in &result {
                    prop_assert!(
                        s.suggestion_type == SuggestionType::NamedTagValue,
                        "Expected NamedTagValue, got {:?} for suggestion {:?}",
                        s.suggestion_type, s.display_text
                    );
                    prop_assert!(
                        s.insert_text.starts_with(&format!("{}:", key)),
                        "Suggestion {:?} does not reference key {:?}",
                        s.insert_text, key
                    );
                }
            }
        }

        // Feature: tag-search-system, Property 18: Suggestion count is bounded
        // Validates: Requirements 9.5
        proptest! {
            #![proptest_config(ProptestConfig::with_cases(100))]

            #[test]
            fn suggestion_count_is_bounded(
                max_results in 1usize..=20,
                num_tags in 5usize..=40,
            ) {
                let tags: Vec<Tag> = (0..num_tags)
                    .map(|i| Tag {
                        id: format!("t{}", i),
                        key: None,
                        value: format!("a{}", i),
                        tag_type: TagType::User,
                        parent_id: None,
                        alias_names: vec![],
                        include_children: false,
                        is_group: false,
                        is_locked: false,
                        display_order: 0,
                        collection_metadata: None,
                    })
                    .collect();

                let result = get_suggestions("a", &tags, max_results);
                prop_assert!(
                    result.len() <= max_results,
                    "Got {} suggestions but max_results is {}",
                    result.len(), max_results
                );
            }
        }

        // Feature: tag-search-system, Property 19: Alias resolution in suggestions
        // Validates: Requirements 9.6
        proptest! {
            #![proptest_config(ProptestConfig::with_cases(100))]

            #[test]
            fn alias_resolution_surfaces_primary_tag(
                primary_value in "[a-z]{2,8}",
                alias in "[a-z]{2,8}",
            ) {
                prop_assume!(alias != primary_value);
                prop_assume!(!primary_value.to_lowercase().contains(&alias.to_lowercase()));

                let tag = Tag {
                    id: "alias_tag".to_string(),
                    key: None,
                    value: primary_value.clone(),
                    tag_type: TagType::User,
                    parent_id: None,
                    alias_names: vec![alias.clone()],
                    include_children: false,
                    is_group: false,
                    is_locked: false,
                    display_order: 0,
                    collection_metadata: None,
                };

                let tags = vec![tag];
                let result = get_suggestions(&alias, &tags, 10);

                let found = result.iter().any(|s| {
                    s.insert_text == format!("tag:{}", primary_value)
                    || s.display_text == primary_value
                });
                prop_assert!(
                    found,
                    "Primary tag {:?} not found in suggestions when searching by alias {:?}. Got: {:?}",
                    primary_value, alias, result
                );
            }
        }
    }
}
