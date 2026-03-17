// Unit tests for hash compatibility with Dart's calculateHash() method.
// These verify that the Rust calculate_hash produces the same hash as Dart
// for known inputs by manually constructing the expected JSON and computing SHA-256.

use sha2::{Digest, Sha256};

use beadline_core::hash::calculate_hash;
use beadline_core::model::metadata::Metadata;
use beadline_core::model::playback_preferences::PlaybackPreferences;
use beadline_core::model::source::{
    AudioFormat, AudioSource, DisplaySource, DisplayType, HoverSource, InstrumentalSource,
    LyricsFormat, SourceOrigin,
};
use beadline_core::model::source_collection::SourceCollection;
use beadline_core::model::song_unit::SongUnit;

/// Helper: compute SHA-256 hex digest of a string, matching Dart's sha256.convert(utf8.encode(s)).
fn sha256_hex(s: &str) -> String {
    let digest = Sha256::digest(s.as_bytes());
    format!("{:x}", digest)
}

fn empty_prefs() -> PlaybackPreferences {
    PlaybackPreferences {
        prefer_instrumental: false,
        preferred_display_source_id: None,
        preferred_audio_source_id: None,
        preferred_instrumental_source_id: None,
        preferred_hover_source_id: None,
    }
}

/// Test 1: Simple SongUnit with one audio source (local file).
///
/// Dart would produce this hash_data JSON:
/// {"title":"Test Song","artists":["Artist A"],"album":"Test Album","year":2024,"duration":240,"sources":[{"type":"SourceType.audio","origin":{"type":"localFile","path":"song.mp3"}}]}
#[test]
fn hash_simple_audio_source_local_file() {
    let su = SongUnit {
        id: "su-001".to_string(),
        metadata: Metadata {
            title: "Test Song".to_string(),
            artists: vec!["Artist A".to_string()],
            album: "Test Album".to_string(),
            year: Some(2024),
            duration: 240_000_000, // 240 seconds in microseconds
            thumbnail_path: None,
            thumbnail_source_id: None,
        },
        sources: SourceCollection {
            display_sources: vec![],
            audio_sources: vec![AudioSource {
                id: "a1".to_string(),
                origin: SourceOrigin::LocalFile {
                    path: "/music/song.mp3".to_string(),
                },
                priority: 0,
                display_name: None,
                format: AudioFormat::Mp3,
                duration: Some(240_000_000),
                offset: 0,
                source_type: "audio".to_string(),
            }],
            instrumental_sources: vec![],
            hover_sources: vec![],
        },
        tag_ids: vec![],
        preferences: empty_prefs(),
        library_location_id: None,
        is_temporary: false,
        discovered_at: None,
        original_file_path: None,
    };

    // Manually construct the JSON that Dart's jsonEncode would produce.
    // Key ordering in serde_json::json! matches insertion order, and
    // serde_json::to_string serializes map keys in insertion order.
    // Dart's jsonEncode also uses insertion order of the Map literal.
    //
    // Dart hash_data map literal order: title, artists, album, year, duration, sources
    // Our Rust json! macro order: title, artists, album, year, duration, sources
    //
    // For the source origin, local file path "/music/song.mp3" → normalized to "song.mp3"
    // Origin JSON: {"type":"localFile","path":"song.mp3"}
    // Source entry: {"type":"SourceType.audio","origin":{"type":"localFile","path":"song.mp3"}}
    let expected_json = r#"{"title":"Test Song","artists":["Artist A"],"album":"Test Album","year":2024,"duration":240,"sources":[{"type":"SourceType.audio","origin":{"type":"localFile","path":"song.mp3"}}]}"#;
    let expected_hash = sha256_hex(expected_json);

    let actual_hash = calculate_hash(&su);
    assert_eq!(
        actual_hash, expected_hash,
        "Hash mismatch.\nExpected JSON: {}\nExpected hash: {}\nActual hash: {}",
        expected_json, expected_hash, actual_hash
    );
}

/// Test 2: SongUnit with multiple source types.
#[test]
fn hash_multiple_source_types() {
    let su = SongUnit {
        id: "su-002".to_string(),
        metadata: Metadata {
            title: "Multi Source".to_string(),
            artists: vec!["Singer".to_string(), "Rapper".to_string()],
            album: "Collab".to_string(),
            year: Some(2023),
            duration: 300_000_000, // 300 seconds
            thumbnail_path: None,
            thumbnail_source_id: None,
        },
        sources: SourceCollection {
            display_sources: vec![DisplaySource {
                id: "d1".to_string(),
                origin: SourceOrigin::Url {
                    url: "https://example.com/video.mp4".to_string(),
                },
                priority: 0,
                display_name: None,
                display_type: DisplayType::Video,
                duration: None,
                offset: 0,
                source_type: "display".to_string(),
            }],
            audio_sources: vec![AudioSource {
                id: "a1".to_string(),
                origin: SourceOrigin::LocalFile {
                    path: "track.mp3".to_string(),
                },
                priority: 0,
                display_name: None,
                format: AudioFormat::Mp3,
                duration: Some(300_000_000),
                offset: 0,
                source_type: "audio".to_string(),
            }],
            instrumental_sources: vec![InstrumentalSource {
                id: "i1".to_string(),
                origin: SourceOrigin::LocalFile {
                    path: "karaoke.mp3".to_string(),
                },
                priority: 0,
                display_name: None,
                format: AudioFormat::Mp3,
                duration: None,
                offset: 0,
                source_type: "accompaniment".to_string(),
            }],
            hover_sources: vec![HoverSource {
                id: "h1".to_string(),
                origin: SourceOrigin::LocalFile {
                    path: "lyrics.lrc".to_string(),
                },
                priority: 0,
                display_name: None,
                format: LyricsFormat::Lrc,
                offset: 0,
                source_type: "hover".to_string(),
            }],
        },
        tag_ids: vec![],
        preferences: empty_prefs(),
        library_location_id: None,
        is_temporary: false,
        discovered_at: None,
        original_file_path: None,
    };

    // Sources order: display, audio, accompaniment, hover (from all_sources())
    // Display origin: {"type":"url","url":"https://example.com/video.mp4"} — no path normalization
    // Audio origin: {"type":"localFile","path":"track.mp3"} — already filename only
    // Accompaniment origin: {"type":"localFile","path":"karaoke.mp3"}
    // Hover origin: {"type":"localFile","path":"lyrics.lrc"}
    let expected_json = r#"{"title":"Multi Source","artists":["Singer","Rapper"],"album":"Collab","year":2023,"duration":300,"sources":[{"type":"SourceType.display","origin":{"type":"url","url":"https://example.com/video.mp4"}},{"type":"SourceType.audio","origin":{"type":"localFile","path":"track.mp3"}},{"type":"SourceType.accompaniment","origin":{"type":"localFile","path":"karaoke.mp3"}},{"type":"SourceType.hover","origin":{"type":"localFile","path":"lyrics.lrc"}}]}"#;
    let expected_hash = sha256_hex(expected_json);

    let actual_hash = calculate_hash(&su);
    assert_eq!(
        actual_hash, expected_hash,
        "Hash mismatch.\nExpected JSON: {}\nExpected hash: {}\nActual hash: {}",
        expected_json, expected_hash, actual_hash
    );
}

/// Test 3: Local file path normalization — paths with directories are stripped to filename.
#[test]
fn hash_local_file_path_normalization() {
    let su = SongUnit {
        id: "su-003".to_string(),
        metadata: Metadata {
            title: "Path Test".to_string(),
            artists: vec![],
            album: "".to_string(),
            year: None,
            duration: 60_000_000, // 60 seconds
            thumbnail_path: None,
            thumbnail_source_id: None,
        },
        sources: SourceCollection {
            display_sources: vec![],
            audio_sources: vec![
                AudioSource {
                    id: "a1".to_string(),
                    origin: SourceOrigin::LocalFile {
                        path: "/path/to/song.mp3".to_string(),
                    },
                    priority: 0,
                    display_name: None,
                    format: AudioFormat::Mp3,
                    duration: None,
                    offset: 0,
                    source_type: "audio".to_string(),
                },
                AudioSource {
                    id: "a2".to_string(),
                    origin: SourceOrigin::LocalFile {
                        path: "C:\\Users\\Music\\track.flac".to_string(),
                    },
                    priority: 1,
                    display_name: None,
                    format: AudioFormat::Flac,
                    duration: None,
                    offset: 0,
                    source_type: "audio".to_string(),
                },
            ],
            instrumental_sources: vec![],
            hover_sources: vec![],
        },
        tag_ids: vec![],
        preferences: empty_prefs(),
        library_location_id: None,
        is_temporary: false,
        discovered_at: None,
        original_file_path: None,
    };

    // Both paths should be normalized:
    // "/path/to/song.mp3" → "song.mp3"
    // "C:\Users\Music\track.flac" → "track.flac"
    // year is null in JSON
    let expected_json = r#"{"title":"Path Test","artists":[],"album":"","year":null,"duration":60,"sources":[{"type":"SourceType.audio","origin":{"type":"localFile","path":"song.mp3"}},{"type":"SourceType.audio","origin":{"type":"localFile","path":"track.flac"}}]}"#;
    let expected_hash = sha256_hex(expected_json);

    let actual_hash = calculate_hash(&su);
    assert_eq!(
        actual_hash, expected_hash,
        "Hash mismatch.\nExpected JSON: {}\nExpected hash: {}\nActual hash: {}",
        expected_json, expected_hash, actual_hash
    );
}

/// Test 4: SongUnit with no sources — empty sources array.
#[test]
fn hash_no_sources() {
    let su = SongUnit {
        id: "su-004".to_string(),
        metadata: Metadata {
            title: "Empty".to_string(),
            artists: vec!["Solo".to_string()],
            album: "Album".to_string(),
            year: None,
            duration: 0,
            thumbnail_path: None,
            thumbnail_source_id: None,
        },
        sources: SourceCollection {
            display_sources: vec![],
            audio_sources: vec![],
            instrumental_sources: vec![],
            hover_sources: vec![],
        },
        tag_ids: vec![],
        preferences: empty_prefs(),
        library_location_id: None,
        is_temporary: false,
        discovered_at: None,
        original_file_path: None,
    };

    let expected_json =
        r#"{"title":"Empty","artists":["Solo"],"album":"Album","year":null,"duration":0,"sources":[]}"#;
    let expected_hash = sha256_hex(expected_json);

    let actual_hash = calculate_hash(&su);
    assert_eq!(actual_hash, expected_hash);
}

/// Test 5: API origin source — no path normalization should occur.
#[test]
fn hash_api_origin_no_path_normalization() {
    let su = SongUnit {
        id: "su-005".to_string(),
        metadata: Metadata {
            title: "API Song".to_string(),
            artists: vec!["Artist".to_string()],
            album: "".to_string(),
            year: Some(2022),
            duration: 180_000_000,
            thumbnail_path: None,
            thumbnail_source_id: None,
        },
        sources: SourceCollection {
            display_sources: vec![],
            audio_sources: vec![AudioSource {
                id: "a1".to_string(),
                origin: SourceOrigin::Api {
                    provider: "netease".to_string(),
                    resource_id: "12345".to_string(),
                },
                priority: 0,
                display_name: None,
                format: AudioFormat::Mp3,
                duration: None,
                offset: 0,
                source_type: "audio".to_string(),
            }],
            instrumental_sources: vec![],
            hover_sources: vec![],
        },
        tag_ids: vec![],
        preferences: empty_prefs(),
        library_location_id: None,
        is_temporary: false,
        discovered_at: None,
        original_file_path: None,
    };

    // API origin: {"type":"api","provider":"netease","resourceId":"12345"}
    let expected_json = r#"{"title":"API Song","artists":["Artist"],"album":"","year":2022,"duration":180,"sources":[{"type":"SourceType.audio","origin":{"type":"api","provider":"netease","resourceId":"12345"}}]}"#;
    let expected_hash = sha256_hex(expected_json);

    let actual_hash = calculate_hash(&su);
    assert_eq!(
        actual_hash, expected_hash,
        "Hash mismatch.\nExpected JSON: {}\nExpected hash: {}\nActual hash: {}",
        expected_json, expected_hash, actual_hash
    );
}
