use serde::{Deserialize, Deserializer, Serialize};

/// Metadata for a Song Unit — title, artists, album, year, duration, thumbnail.
///
/// Supports legacy deserialization: if the JSON contains `"artist"` (singular string)
/// instead of `"artists"` (array), the string is parsed using common artist separators.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Metadata {
    #[serde(default)]
    pub title: String,
    #[serde(
        default,
        alias = "artist",
        deserialize_with = "deserialize_artists"
    )]
    pub artists: Vec<String>,
    #[serde(default)]
    pub album: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year: Option<i32>,
    /// Duration in microseconds, matching Dart `Duration.inMicroseconds`.
    #[serde(default)]
    pub duration: i64,
    #[serde(skip_serializing_if = "Option::is_none", rename = "thumbnailPath")]
    pub thumbnail_path: Option<String>,
    #[serde(
        skip_serializing_if = "Option::is_none",
        rename = "thumbnailSourceId"
    )]
    pub thumbnail_source_id: Option<String>,
}

/// Custom deserializer that accepts either a JSON array of strings or a single
/// string (legacy format). When a string is encountered, it is split on common
/// artist separators to produce the list.
fn deserialize_artists<'de, D>(deserializer: D) -> Result<Vec<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let value: Option<serde_json::Value> = Option::deserialize(deserializer)?;

    match value {
        None | Some(serde_json::Value::Null) => Ok(Vec::new()),
        Some(serde_json::Value::Array(arr)) => {
            let mut artists = Vec::with_capacity(arr.len());
            for item in arr {
                match item {
                    serde_json::Value::String(s) => artists.push(s),
                    other => {
                        return Err(serde::de::Error::custom(format!(
                            "expected string in artists array, got {other}"
                        )));
                    }
                }
            }
            Ok(artists)
        }
        Some(serde_json::Value::String(s)) => Ok(parse_artist_string(&s)),
        Some(other) => Err(serde::de::Error::custom(format!(
            "expected array or string for artists, got {other}"
        ))),
    }
}

/// Parse an artist string using common separators, matching the Dart
/// `_parseArtistString` implementation.
///
/// Separators (in order of replacement):
/// - `,` `;` `/` `&` (with optional surrounding whitespace)
/// - `feat.` / `feat` (case-insensitive, whitespace-bounded)
/// - `ft.` / `ft` (case-insensitive, whitespace-bounded)
/// - `featuring` (case-insensitive, whitespace-bounded)
/// - `×` (whitespace-bounded)
/// - `x` (case-insensitive, whitespace-bounded — requires surrounding whitespace
///   to avoid splitting words containing 'x')
pub fn parse_artist_string(s: &str) -> Vec<String> {
    if s.is_empty() {
        return Vec::new();
    }

    // Multi-pass approach like Dart: normalize separators to '|' then split.
    let mut normalized = s.to_string();

    // Pass 1: \s*[,;/&]\s* → |
    normalized = replace_pattern_punct(&normalized);

    // Pass 2: \s+feat\.?\s+ (case-insensitive) → |
    normalized = replace_keyword(&normalized, &["feat.", "feat"]);

    // Pass 3: \s+ft\.?\s+ (case-insensitive) → |
    normalized = replace_keyword(&normalized, &["ft.", "ft"]);

    // Pass 4: \s+featuring\s+ (case-insensitive) → |
    normalized = replace_keyword(&normalized, &["featuring"]);

    // Pass 5: \s+×\s+ → |  (× is case-sensitive in Dart, but it's a single char)
    normalized = replace_keyword_exact(&normalized, "×");

    // Pass 6: \s+x\s+ (case-insensitive) → |
    normalized = replace_keyword(&normalized, &["x"]);

    normalized
        .split('|')
        .map(|seg| seg.trim())
        .filter(|seg| !seg.is_empty())
        .map(|seg| seg.to_string())
        .collect()
}

/// Replace `\s*[,;/&]\s*` with `|`.
fn replace_pattern_punct(s: &str) -> String {
    let chars: Vec<char> = s.chars().collect();
    let len = chars.len();
    let mut out = String::with_capacity(len);
    let mut i = 0;

    while i < len {
        // Try to match optional whitespace, then a separator, then optional whitespace
        let mut j = i;
        // Consume leading whitespace
        while j < len && chars[j].is_whitespace() {
            j += 1;
        }
        if j < len && matches!(chars[j], ',' | ';' | '/' | '&') {
            j += 1;
            // Consume trailing whitespace
            while j < len && chars[j].is_whitespace() {
                j += 1;
            }
            out.push('|');
            i = j;
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }

    out
}

/// Replace `\s+keyword\s+` with `|` (case-insensitive for the keywords).
/// `keywords` should be ordered longest-first so "feat." matches before "feat".
fn replace_keyword(s: &str, keywords: &[&str]) -> String {
    let lower = s.to_lowercase();
    let chars: Vec<char> = s.chars().collect();
    let lower_chars: Vec<char> = lower.chars().collect();
    let len = chars.len();
    let mut out = String::with_capacity(len);
    let mut i = 0;

    while i < len {
        let mut matched = false;
        // We need at least one whitespace before the keyword
        if i > 0 && chars[i].is_whitespace() {
            // Consume whitespace
            let ws_start = i;
            let mut j = i;
            while j < len && chars[j].is_whitespace() {
                j += 1;
            }
            let ws_count = j - ws_start;
            if ws_count > 0 {
                for kw in keywords {
                    let kw_lower: Vec<char> = kw.to_lowercase().chars().collect();
                    let kw_len = kw_lower.len();
                    if j + kw_len <= len {
                        let slice: String = lower_chars[j..j + kw_len].iter().collect();
                        let kw_str: String = kw_lower.iter().collect();
                        if slice == kw_str {
                            // Check trailing whitespace
                            let after = j + kw_len;
                            if after < len && chars[after].is_whitespace() {
                                let mut k = after;
                                while k < len && chars[k].is_whitespace() {
                                    k += 1;
                                }
                                out.push('|');
                                i = k;
                                matched = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
        if !matched {
            out.push(chars[i]);
            i += 1;
        }
    }

    out
}

/// Replace `\s+keyword\s+` with `|` (case-sensitive, for `×`).
fn replace_keyword_exact(s: &str, keyword: &str) -> String {
    let chars: Vec<char> = s.chars().collect();
    let kw_chars: Vec<char> = keyword.chars().collect();
    let len = chars.len();
    let kw_len = kw_chars.len();
    let mut out = String::with_capacity(len);
    let mut i = 0;

    while i < len {
        let mut matched = false;
        if i > 0 && chars[i].is_whitespace() {
            let ws_start = i;
            let mut j = i;
            while j < len && chars[j].is_whitespace() {
                j += 1;
            }
            let ws_count = j - ws_start;
            if ws_count > 0 && j + kw_len <= len {
                let slice: Vec<char> = chars[j..j + kw_len].to_vec();
                if slice == kw_chars {
                    let after = j + kw_len;
                    if after < len && chars[after].is_whitespace() {
                        let mut k = after;
                        while k < len && chars[k].is_whitespace() {
                            k += 1;
                        }
                        out.push('|');
                        i = k;
                        matched = true;
                    }
                }
            }
        }
        if !matched {
            out.push(chars[i]);
            i += 1;
        }
    }

    out
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // -- parse_artist_string tests --

    #[test]
    fn parse_empty_string() {
        assert_eq!(parse_artist_string(""), Vec::<String>::new());
    }

    #[test]
    fn parse_single_artist() {
        assert_eq!(parse_artist_string("Artist1"), vec!["Artist1"]);
    }

    #[test]
    fn parse_comma_separated() {
        assert_eq!(
            parse_artist_string("Artist1, Artist2, Artist3"),
            vec!["Artist1", "Artist2", "Artist3"]
        );
    }

    #[test]
    fn parse_semicolon_separated() {
        assert_eq!(
            parse_artist_string("Artist1; Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_slash_separated() {
        assert_eq!(
            parse_artist_string("Artist1 / Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_ampersand_separated() {
        assert_eq!(
            parse_artist_string("Artist1 & Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_feat_separator() {
        assert_eq!(
            parse_artist_string("Artist1 feat. Artist2"),
            vec!["Artist1", "Artist2"]
        );
        assert_eq!(
            parse_artist_string("Artist1 feat Artist2"),
            vec!["Artist1", "Artist2"]
        );
        assert_eq!(
            parse_artist_string("Artist1 FEAT. Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_ft_separator() {
        assert_eq!(
            parse_artist_string("Artist1 ft. Artist2"),
            vec!["Artist1", "Artist2"]
        );
        assert_eq!(
            parse_artist_string("Artist1 ft Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_featuring_separator() {
        assert_eq!(
            parse_artist_string("Artist1 featuring Artist2"),
            vec!["Artist1", "Artist2"]
        );
        assert_eq!(
            parse_artist_string("Artist1 FEATURING Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_times_separator() {
        // × (multiplication sign)
        assert_eq!(
            parse_artist_string("Artist1 × Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_x_separator() {
        // x requires whitespace on both sides
        assert_eq!(
            parse_artist_string("Artist1 x Artist2"),
            vec!["Artist1", "Artist2"]
        );
        assert_eq!(
            parse_artist_string("Artist1 X Artist2"),
            vec!["Artist1", "Artist2"]
        );
    }

    #[test]
    fn parse_x_does_not_split_words() {
        // "Foxes" should NOT be split on the 'x'
        assert_eq!(parse_artist_string("Foxes"), vec!["Foxes"]);
        assert_eq!(
            parse_artist_string("MaxWell, Foxes"),
            vec!["MaxWell", "Foxes"]
        );
    }

    #[test]
    fn parse_mixed_separators() {
        assert_eq!(
            parse_artist_string("A, B & C feat. D"),
            vec!["A", "B", "C", "D"]
        );
    }

    #[test]
    fn parse_trims_whitespace() {
        assert_eq!(
            parse_artist_string("  Artist1  ,  Artist2  "),
            vec!["Artist1", "Artist2"]
        );
    }

    // -- Metadata deserialization tests --

    #[test]
    fn metadata_deserialize_new_format() {
        let json = json!({
            "title": "Test Song",
            "artists": ["Artist1", "Artist2"],
            "album": "Test Album",
            "year": 2024,
            "duration": 240000000,
            "thumbnailPath": "/path/to/thumb.jpg",
            "thumbnailSourceId": "src-1"
        });
        let meta: Metadata = serde_json::from_value(json).unwrap();
        assert_eq!(meta.title, "Test Song");
        assert_eq!(meta.artists, vec!["Artist1", "Artist2"]);
        assert_eq!(meta.album, "Test Album");
        assert_eq!(meta.year, Some(2024));
        assert_eq!(meta.duration, 240_000_000);
        assert_eq!(meta.thumbnail_path, Some("/path/to/thumb.jpg".to_string()));
        assert_eq!(meta.thumbnail_source_id, Some("src-1".to_string()));
    }

    #[test]
    fn metadata_deserialize_legacy_artist_string() {
        let json = json!({
            "title": "Old Song",
            "artist": "Artist1, Artist2 & Artist3",
            "album": "Old Album",
            "duration": 180000000
        });
        let meta: Metadata = serde_json::from_value(json).unwrap();
        assert_eq!(meta.artists, vec!["Artist1", "Artist2", "Artist3"]);
    }

    #[test]
    fn metadata_deserialize_legacy_empty_artist() {
        let json = json!({
            "title": "No Artist",
            "artist": "",
            "album": "",
            "duration": 0
        });
        let meta: Metadata = serde_json::from_value(json).unwrap();
        assert_eq!(meta.artists, Vec::<String>::new());
    }

    #[test]
    fn metadata_deserialize_missing_artists() {
        let json = json!({
            "title": "Minimal",
            "album": "",
            "duration": 0
        });
        let meta: Metadata = serde_json::from_value(json).unwrap();
        assert_eq!(meta.artists, Vec::<String>::new());
    }

    #[test]
    fn metadata_deserialize_null_artists() {
        let json = json!({
            "title": "Null Artists",
            "artists": null,
            "album": "",
            "duration": 0
        });
        let meta: Metadata = serde_json::from_value(json).unwrap();
        assert_eq!(meta.artists, Vec::<String>::new());
    }

    #[test]
    fn metadata_deserialize_defaults() {
        // Completely empty JSON — all fields should default
        let json = json!({});
        let meta: Metadata = serde_json::from_value(json).unwrap();
        assert_eq!(meta.title, "");
        assert_eq!(meta.artists, Vec::<String>::new());
        assert_eq!(meta.album, "");
        assert_eq!(meta.year, None);
        assert_eq!(meta.duration, 0);
        assert_eq!(meta.thumbnail_path, None);
        assert_eq!(meta.thumbnail_source_id, None);
    }

    #[test]
    fn metadata_round_trip() {
        let meta = Metadata {
            title: "Test Song".to_string(),
            artists: vec!["Artist1".to_string(), "Artist2".to_string()],
            album: "Test Album".to_string(),
            year: Some(2024),
            duration: 240_000_000,
            thumbnail_path: Some("/path/to/thumb.jpg".to_string()),
            thumbnail_source_id: Some("src-1".to_string()),
        };
        let json = serde_json::to_string(&meta).unwrap();
        let back: Metadata = serde_json::from_str(&json).unwrap();
        assert_eq!(meta, back);
    }

    #[test]
    fn metadata_round_trip_minimal() {
        let meta = Metadata {
            title: String::new(),
            artists: Vec::new(),
            album: String::new(),
            year: None,
            duration: 0,
            thumbnail_path: None,
            thumbnail_source_id: None,
        };
        let json = serde_json::to_string(&meta).unwrap();
        let back: Metadata = serde_json::from_str(&json).unwrap();
        assert_eq!(meta, back);
    }

    #[test]
    fn metadata_serialization_skips_none_fields() {
        let meta = Metadata {
            title: "Song".to_string(),
            artists: vec!["A".to_string()],
            album: String::new(),
            year: None,
            duration: 100,
            thumbnail_path: None,
            thumbnail_source_id: None,
        };
        let val = serde_json::to_value(&meta).unwrap();
        assert!(!val.as_object().unwrap().contains_key("year"));
        assert!(!val.as_object().unwrap().contains_key("thumbnailPath"));
        assert!(!val.as_object().unwrap().contains_key("thumbnailSourceId"));
    }

    #[test]
    fn metadata_serialization_uses_camel_case_keys() {
        let meta = Metadata {
            title: "Song".to_string(),
            artists: vec![],
            album: String::new(),
            year: None,
            duration: 0,
            thumbnail_path: Some("/thumb.jpg".to_string()),
            thumbnail_source_id: Some("s1".to_string()),
        };
        let val = serde_json::to_value(&meta).unwrap();
        let obj = val.as_object().unwrap();
        assert!(obj.contains_key("thumbnailPath"));
        assert!(obj.contains_key("thumbnailSourceId"));
        // Should NOT have snake_case keys
        assert!(!obj.contains_key("thumbnail_path"));
        assert!(!obj.contains_key("thumbnail_source_id"));
    }

    #[test]
    fn metadata_dart_json_compat() {
        // JSON as produced by Dart's _$MetadataToJson
        let dart_json = json!({
            "title": "My Song",
            "artists": ["Singer A", "Singer B"],
            "album": "Album X",
            "year": 2023,
            "duration": 195000000,
            "thumbnailPath": null,
            "thumbnailSourceId": null
        });
        let meta: Metadata = serde_json::from_value(dart_json).unwrap();
        assert_eq!(meta.title, "My Song");
        assert_eq!(meta.artists, vec!["Singer A", "Singer B"]);
        assert_eq!(meta.album, "Album X");
        assert_eq!(meta.year, Some(2023));
        assert_eq!(meta.duration, 195_000_000);
        assert_eq!(meta.thumbnail_path, None);
        assert_eq!(meta.thumbnail_source_id, None);
    }
}
