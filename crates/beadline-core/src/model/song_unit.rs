use serde::{Deserialize, Serialize};

use super::metadata::Metadata;
use super::playback_preferences::PlaybackPreferences;
use super::source_collection::SourceCollection;

/// The core playback entity — a logical aggregate describing how to play a song.
///
/// Contains metadata, sources, tags, and playback preferences.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SongUnit {
    pub id: String,
    pub metadata: Metadata,
    pub sources: SourceCollection,
    #[serde(default)]
    pub tag_ids: Vec<String>,
    pub preferences: PlaybackPreferences,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub library_location_id: Option<String>,
    #[serde(default)]
    pub is_temporary: bool,
    /// Milliseconds since epoch.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub discovered_at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub original_file_path: Option<String>,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::source::{AudioFormat, AudioSource, SourceOrigin};
    use crate::model::source_collection::SourceCollection;
    use serde_json::json;

    fn sample_song_unit() -> SongUnit {
        SongUnit {
            id: "su-001".to_string(),
            metadata: Metadata {
                title: "Test Song".to_string(),
                artists: vec!["Artist A".to_string(), "Artist B".to_string()],
                album: "Test Album".to_string(),
                year: Some(2024),
                duration: 240_000_000,
                thumbnail_path: Some("/thumb.jpg".to_string()),
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
            tag_ids: vec!["tag-1".to_string(), "tag-2".to_string()],
            preferences: PlaybackPreferences {
                prefer_instrumental: false,
                preferred_display_source_id: None,
                preferred_audio_source_id: Some("a1".to_string()),
                preferred_instrumental_source_id: None,
                preferred_hover_source_id: None,
            },
            library_location_id: Some("lib-1".to_string()),
            is_temporary: false,
            discovered_at: None,
            original_file_path: None,
        }
    }

    #[test]
    fn round_trip_full() {
        let su = sample_song_unit();
        let json = serde_json::to_string(&su).unwrap();
        let back: SongUnit = serde_json::from_str(&json).unwrap();
        assert_eq!(su, back);
    }

    #[test]
    fn round_trip_temporary() {
        let su = SongUnit {
            id: "tmp-001".to_string(),
            metadata: Metadata {
                title: "Discovered Track".to_string(),
                artists: vec![],
                album: String::new(),
                year: None,
                duration: 180_000_000,
                thumbnail_path: None,
                thumbnail_source_id: None,
            },
            sources: SourceCollection {
                display_sources: vec![],
                audio_sources: vec![AudioSource {
                    id: "a1".to_string(),
                    origin: SourceOrigin::LocalFile {
                        path: "/downloads/track.flac".to_string(),
                    },
                    priority: 0,
                    display_name: None,
                    format: AudioFormat::Flac,
                    duration: Some(180_000_000),
                    offset: 0,
                    source_type: "audio".to_string(),
                }],
                instrumental_sources: vec![],
                hover_sources: vec![],
            },
            tag_ids: vec![],
            preferences: PlaybackPreferences {
                prefer_instrumental: false,
                preferred_display_source_id: None,
                preferred_audio_source_id: None,
                preferred_instrumental_source_id: None,
                preferred_hover_source_id: None,
            },
            library_location_id: None,
            is_temporary: true,
            discovered_at: Some(1700000000000),
            original_file_path: Some("/downloads/track.flac".to_string()),
        };
        let json = serde_json::to_string(&su).unwrap();
        let back: SongUnit = serde_json::from_str(&json).unwrap();
        assert_eq!(su, back);
    }

    #[test]
    fn serialization_skips_none_optional_fields() {
        let su = sample_song_unit();
        let val = serde_json::to_value(&su).unwrap();
        let obj = val.as_object().unwrap();

        // discovered_at and original_file_path are None → should be absent
        assert!(!obj.contains_key("discovered_at"));
        assert!(!obj.contains_key("original_file_path"));
    }

    #[test]
    fn deserialize_minimal_json() {
        let json = json!({
            "id": "su-min",
            "metadata": {"title": "Min", "album": "", "duration": 0},
            "sources": {},
            "preferences": {}
        });
        let su: SongUnit = serde_json::from_value(json).unwrap();
        assert_eq!(su.id, "su-min");
        assert!(su.tag_ids.is_empty());
        assert!(!su.is_temporary);
        assert_eq!(su.library_location_id, None);
        assert_eq!(su.discovered_at, None);
        assert_eq!(su.original_file_path, None);
    }

    #[test]
    fn deserialize_with_all_source_types() {
        let json = json!({
            "id": "su-full",
            "metadata": {
                "title": "Full Song",
                "artists": ["A"],
                "album": "Album",
                "year": 2023,
                "duration": 300000000
            },
            "sources": {
                "displaySources": [{
                    "id": "d1",
                    "origin": {"type": "url", "url": "https://example.com/v.mp4"},
                    "priority": 0,
                    "displayType": "video",
                    "sourceType": "display"
                }],
                "audioSources": [{
                    "id": "a1",
                    "origin": {"type": "localFile", "path": "/song.mp3"},
                    "priority": 0,
                    "format": "mp3",
                    "sourceType": "audio"
                }],
                "accompanimentSources": [{
                    "id": "i1",
                    "origin": {"type": "localFile", "path": "/karaoke.mp3"},
                    "priority": 0,
                    "format": "mp3",
                    "sourceType": "accompaniment"
                }],
                "hoverSources": [{
                    "id": "h1",
                    "origin": {"type": "localFile", "path": "/lyrics.lrc"},
                    "priority": 0,
                    "format": "lrc",
                    "sourceType": "hover"
                }]
            },
            "tag_ids": ["t1"],
            "preferences": {"preferAccompaniment": true},
            "library_location_id": "loc-1",
            "is_temporary": false
        });
        let su: SongUnit = serde_json::from_value(json).unwrap();
        assert_eq!(su.sources.display_sources.len(), 1);
        assert_eq!(su.sources.audio_sources.len(), 1);
        assert_eq!(su.sources.instrumental_sources.len(), 1);
        assert_eq!(su.sources.hover_sources.len(), 1);
        assert!(su.preferences.prefer_instrumental);
        assert_eq!(su.tag_ids, vec!["t1"]);
    }
}
