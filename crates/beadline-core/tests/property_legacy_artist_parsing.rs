// Feature: song-unit-rust-migration, Property 2: Legacy artist string parsing
// **Validates: Requirements 2.7**

use proptest::prelude::*;

use beadline_core::model::metadata::parse_artist_string;

/// Generate a random artist name that does NOT contain any separator characters
/// or separator keywords, so we can reliably predict the parse result.
fn arb_artist_name() -> impl Strategy<Value = String> {
    // Use a restricted alphabet to avoid accidentally embedding separators
    // like ',', ';', '/', '&', '×', or keywords like "feat", "ft", "featuring"
    proptest::string::string_regex("[A-Za-z0-9 _\\-]{1,20}")
        .unwrap()
        .prop_filter("must not contain separator keywords", |s| {
            let lower = s.to_lowercase();
            // Reject if it contains keyword separators as whole words
            !lower.contains(',')
                && !lower.contains(';')
                && !lower.contains('/')
                && !lower.contains('&')
                && !lower.contains("feat")
                && !lower.contains(" ft ")
                && !lower.contains(" x ")
                && !s.contains('×')
        })
        .prop_map(|s| s.trim().to_string())
        .prop_filter("non-empty after trim", |s| !s.is_empty())
        .prop_filter("must not start or end with separator keywords", |s| {
            let lower = s.to_lowercase();
            // When joined with separators that add spaces, a name starting/ending
            // with "ft", "x", etc. can be misinterpreted as a keyword boundary.
            !lower.starts_with("ft ")
                && !lower.starts_with("ft.")
                && !lower.ends_with(" ft")
                && !lower.ends_with(" x")
                && !lower.starts_with("x ")
        })
}

/// Pick a random separator from the set of known separators.
fn arb_separator() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(", ".to_string()),
        Just("; ".to_string()),
        Just(" / ".to_string()),
        Just(" & ".to_string()),
        Just(" feat. ".to_string()),
        Just(" feat ".to_string()),
        Just(" ft. ".to_string()),
        Just(" ft ".to_string()),
        Just(" featuring ".to_string()),
        Just(" × ".to_string()),
        Just(" x ".to_string()),
    ]
}

proptest! {
    /// For any list of artist names joined by known separators, parsing the
    /// joined string must produce exactly those artist names (trimmed, non-empty).
    #[test]
    fn legacy_artist_parsing_splits_on_separators(
        artists in proptest::collection::vec(arb_artist_name(), 1..=5),
        sep in arb_separator(),
    ) {
        let joined = artists.join(&sep);
        let result = parse_artist_string(&joined);

        // Each result segment should be trimmed and non-empty
        for segment in &result {
            prop_assert!(!segment.is_empty(), "segment must be non-empty");
            prop_assert_eq!(segment, &segment.trim().to_string(), "segment must be trimmed");
        }

        // The number of parsed artists should match the input count
        prop_assert_eq!(
            result.len(),
            artists.len(),
            "expected {} artists but got {}: input={:?}, sep={:?}, result={:?}",
            artists.len(),
            result.len(),
            joined,
            sep,
            result
        );

        // Each parsed artist should match the trimmed input artist
        for (expected, actual) in artists.iter().zip(result.iter()) {
            prop_assert_eq!(
                expected.trim(),
                actual.as_str(),
                "artist mismatch: expected {:?}, got {:?}",
                expected.trim(),
                actual
            );
        }
    }

    /// Re-parsing the result of joining parsed segments with the same separator
    /// must produce the same result (idempotence).
    #[test]
    fn legacy_artist_parsing_idempotent(
        artists in proptest::collection::vec(arb_artist_name(), 1..=5),
        sep in arb_separator(),
    ) {
        let joined = artists.join(&sep);
        let first_parse = parse_artist_string(&joined);

        // Re-join with the same separator and parse again
        let rejoined = first_parse.join(&sep);
        let second_parse = parse_artist_string(&rejoined);

        prop_assert_eq!(
            &first_parse,
            &second_parse,
            "re-parsing should be idempotent: first={:?}, second={:?}",
            first_parse,
            second_parse
        );
    }
}
