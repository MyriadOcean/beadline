// Feature: song-unit-rust-migration
// Unit tests for Dart JSON compatibility
// **Validates: Requirements 2.1, 2.2**

use beadline_core::model::metadata::Metadata;
use beadline_core::model::playback_preferences::PlaybackPreferences;
use beadline_core::model::source::{AudioFormat, DisplayType, LyricsFormat, SourceOrigin};
use beadline_core::model::source_collection::SourceCollection;

// ---------------------------------------------------------------------------
// Test: Metadata JSON from Dart database
// ---------------------------------------------------------------------------

#[test]
fn deserialize_dart_metadata_json() {
    let metadata_json = r#"{
        "title": "千本桜",
        "artists": ["初音ミク"],
        "album": "千本桜",
        "year": 2011,
        "duration": 252000000,
        "thumbnailPath": null,
        "thumbnailSourceId": "src-thumb-1"
    }"#;

    let meta: Metadata = serde_json::from_str(metadata_json).unwrap();
    assert_eq!(meta.title, "千本桜");
    assert_eq!(meta.artists, vec!["初音ミク"]);
    assert_eq!(meta.album, "千本桜");
    assert_eq!(meta.year, Some(2011));
    assert_eq!(meta.duration, 252_000_000);
    assert_eq!(meta.thumbnail_path, None);
    assert_eq!(
        meta.thumbnail_source_id,
        Some("src-thumb-1".to_string())
    );
}

// ---------------------------------------------------------------------------
// Test: Sources JSON from Dart database
// ---------------------------------------------------------------------------

#[test]
fn deserialize_dart_sources_json() {
    let sources_json = r#"{
        "displaySources": [{
            "sourceType": "display",
            "id": "d-1",
            "origin": {"type": "url", "url": "https://example.com/video.mp4"},
            "priority": 0,
            "displayName": null,
            "displayType": "video",
            "duration": 252000000,
            "offset": 0
        }],
        "audioSources": [{
            "sourceType": "audio",
            "id": "a-1",
            "origin": {"type": "localFile", "path": "/music/senbonzakura.mp3"},
            "priority": 0,
            "displayName": "Main Audio",
            "format": "mp3",
            "duration": 252000000,
            "offset": 0
        }],
        "accompanimentSources": [],
        "hoverSources": [{
            "sourceType": "hover",
            "id": "h-1",
            "origin": {"type": "localFile", "path": "/lyrics/senbonzakura.lrc"},
            "priority": 0,
            "displayName": null,
            "format": "lrc",
            "offset": 0
        }]
    }"#;

    let sources: SourceCollection = serde_json::from_str(sources_json).unwrap();

    // Display sources
    assert_eq!(sources.display_sources.len(), 1);
    let ds = &sources.display_sources[0];
    assert_eq!(ds.id, "d-1");
    assert_eq!(ds.source_type, "display");
    assert_eq!(
        ds.origin,
        SourceOrigin::Url {
            url: "https://example.com/video.mp4".to_string()
        }
    );
    assert_eq!(ds.display_name, None);
    assert_eq!(ds.display_type, DisplayType::Video);
    assert_eq!(ds.duration, Some(252_000_000));
    assert_eq!(ds.offset, 0);

    // Audio sources
    assert_eq!(sources.audio_sources.len(), 1);
    let aus = &sources.audio_sources[0];
    assert_eq!(aus.id, "a-1");
    assert_eq!(aus.source_type, "audio");
    assert_eq!(
        aus.origin,
        SourceOrigin::LocalFile {
            path: "/music/senbonzakura.mp3".to_string()
        }
    );
    assert_eq!(aus.display_name, Some("Main Audio".to_string()));
    assert_eq!(aus.format, AudioFormat::Mp3);
    assert_eq!(aus.duration, Some(252_000_000));
    assert_eq!(aus.offset, 0);

    // Accompaniment sources (empty)
    assert!(sources.instrumental_sources.is_empty());

    // Hover sources
    assert_eq!(sources.hover_sources.len(), 1);
    let hs = &sources.hover_sources[0];
    assert_eq!(hs.id, "h-1");
    assert_eq!(hs.source_type, "hover");
    assert_eq!(
        hs.origin,
        SourceOrigin::LocalFile {
            path: "/lyrics/senbonzakura.lrc".to_string()
        }
    );
    assert_eq!(hs.display_name, None);
    assert_eq!(hs.format, LyricsFormat::Lrc);
    assert_eq!(hs.offset, 0);
}

// ---------------------------------------------------------------------------
// Test: Preferences JSON from Dart database
// ---------------------------------------------------------------------------

#[test]
fn deserialize_dart_preferences_json() {
    let preferences_json = r#"{
        "preferAccompaniment": false,
        "preferredDisplaySourceId": "d-1",
        "preferredAudioSourceId": "a-1",
        "preferredAccompanimentSourceId": null,
        "preferredHoverSourceId": "h-1"
    }"#;

    let prefs: PlaybackPreferences = serde_json::from_str(preferences_json).unwrap();
    assert!(!prefs.prefer_instrumental);
    assert_eq!(
        prefs.preferred_display_source_id,
        Some("d-1".to_string())
    );
    assert_eq!(
        prefs.preferred_audio_source_id,
        Some("a-1".to_string())
    );
    assert_eq!(prefs.preferred_instrumental_source_id, None);
    assert_eq!(
        prefs.preferred_hover_source_id,
        Some("h-1".to_string())
    );
}

// ---------------------------------------------------------------------------
// Test: Legacy format with "artist" string instead of "artists" array
// ---------------------------------------------------------------------------

#[test]
fn deserialize_legacy_artist_string_format() {
    let legacy_json = r#"{
        "title": "千本桜",
        "artist": "初音ミク, 鏡音リン",
        "album": "千本桜",
        "year": 2011,
        "duration": 252000000
    }"#;

    let meta: Metadata = serde_json::from_str(legacy_json).unwrap();
    assert_eq!(meta.title, "千本桜");
    assert_eq!(meta.artists, vec!["初音ミク", "鏡音リン"]);
    assert_eq!(meta.album, "千本桜");
    assert_eq!(meta.year, Some(2011));
    assert_eq!(meta.duration, 252_000_000);
}

#[test]
fn deserialize_legacy_artist_with_feat_separator() {
    let legacy_json = r#"{
        "title": "Song",
        "artist": "ArtistA feat. ArtistB",
        "album": "",
        "duration": 0
    }"#;

    let meta: Metadata = serde_json::from_str(legacy_json).unwrap();
    assert_eq!(meta.artists, vec!["ArtistA", "ArtistB"]);
}

#[test]
fn deserialize_legacy_artist_with_mixed_separators() {
    let legacy_json = r#"{
        "title": "Collab",
        "artist": "A, B & C feat. D",
        "album": "",
        "duration": 0
    }"#;

    let meta: Metadata = serde_json::from_str(legacy_json).unwrap();
    assert_eq!(meta.artists, vec!["A", "B", "C", "D"]);
}

// ---------------------------------------------------------------------------
// Test: Round-trip — serialize then deserialize produces same values
// ---------------------------------------------------------------------------

#[test]
fn metadata_round_trip_preserves_dart_format() {
    let meta = Metadata {
        title: "千本桜".to_string(),
        artists: vec!["初音ミク".to_string()],
        album: "千本桜".to_string(),
        year: Some(2011),
        duration: 252_000_000,
        thumbnail_path: None,
        thumbnail_source_id: Some("src-thumb-1".to_string()),
    };

    let json = serde_json::to_string(&meta).unwrap();
    let back: Metadata = serde_json::from_str(&json).unwrap();
    assert_eq!(meta, back);

    // Verify JSON keys are camelCase
    let val: serde_json::Value = serde_json::from_str(&json).unwrap();
    let obj = val.as_object().unwrap();
    assert!(obj.contains_key("thumbnailSourceId"));
    assert!(!obj.contains_key("thumbnail_source_id"));
}

#[test]
fn sources_round_trip_preserves_dart_format() {
    let sources_json = r#"{
        "displaySources": [{
            "sourceType": "display",
            "id": "d-1",
            "origin": {"type": "url", "url": "https://example.com/video.mp4"},
            "priority": 0,
            "displayType": "video",
            "duration": 252000000,
            "offset": 0
        }],
        "audioSources": [],
        "accompanimentSources": [],
        "hoverSources": []
    }"#;

    let sources: SourceCollection = serde_json::from_str(sources_json).unwrap();
    let reserialized = serde_json::to_string(&sources).unwrap();
    let back: SourceCollection = serde_json::from_str(&reserialized).unwrap();
    assert_eq!(sources, back);
}

#[test]
fn preferences_round_trip_preserves_dart_format() {
    let prefs = PlaybackPreferences {
        prefer_instrumental: false,
        preferred_display_source_id: Some("d-1".to_string()),
        preferred_audio_source_id: Some("a-1".to_string()),
        preferred_instrumental_source_id: None,
        preferred_hover_source_id: Some("h-1".to_string()),
    };

    let json = serde_json::to_string(&prefs).unwrap();
    let back: PlaybackPreferences = serde_json::from_str(&json).unwrap();
    assert_eq!(prefs, back);

    // Verify JSON keys use Dart naming
    let val: serde_json::Value = serde_json::from_str(&json).unwrap();
    let obj = val.as_object().unwrap();
    assert!(obj.contains_key("preferAccompaniment"));
    assert!(obj.contains_key("preferredDisplaySourceId"));
    assert!(obj.contains_key("preferredAudioSourceId"));
    assert!(obj.contains_key("preferredHoverSourceId"));
}
