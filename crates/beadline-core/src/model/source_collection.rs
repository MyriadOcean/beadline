use serde::{Deserialize, Serialize};

use super::source::{
    AudioSource, DisplaySource, HoverSource, InstrumentalSource, SourceOrigin, SourceType,
};

/// A grouped set of sources organized by type.
///
/// JSON keys use camelCase to match the existing Dart format stored in the database.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SourceCollection {
    #[serde(default, rename = "displaySources")]
    pub display_sources: Vec<DisplaySource>,
    #[serde(default, rename = "audioSources")]
    pub audio_sources: Vec<AudioSource>,
    /// JSON key stays `"accompanimentSources"` for DB compat, but the Rust field
    /// uses the preferred `instrumental_sources` naming.
    #[serde(default, rename = "accompanimentSources")]
    pub instrumental_sources: Vec<InstrumentalSource>,
    #[serde(default, rename = "hoverSources")]
    pub hover_sources: Vec<HoverSource>,
}

/// A reference to any source, used for iteration in hash calculation.
pub struct SourceRef<'a> {
    pub source_type: SourceType,
    pub origin: &'a SourceOrigin,
}

impl SourceCollection {
    /// Returns a flat list of references to all sources across every type.
    /// Useful for hash calculation and other aggregate operations.
    pub fn all_sources(&self) -> Vec<SourceRef<'_>> {
        let mut refs = Vec::new();
        for s in &self.display_sources {
            refs.push(SourceRef {
                source_type: SourceType::Display,
                origin: &s.origin,
            });
        }
        for s in &self.audio_sources {
            refs.push(SourceRef {
                source_type: SourceType::Audio,
                origin: &s.origin,
            });
        }
        for s in &self.instrumental_sources {
            refs.push(SourceRef {
                source_type: SourceType::Accompaniment,
                origin: &s.origin,
            });
        }
        for s in &self.hover_sources {
            refs.push(SourceRef {
                source_type: SourceType::Hover,
                origin: &s.origin,
            });
        }
        refs
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::source::{
        AudioFormat, AudioSource, DisplaySource, DisplayType, HoverSource, InstrumentalSource,
        LyricsFormat, SourceOrigin,
    };
    use serde_json::json;

    fn sample_collection() -> SourceCollection {
        SourceCollection {
            display_sources: vec![DisplaySource {
                id: "d1".to_string(),
                origin: SourceOrigin::Url {
                    url: "https://example.com/video.mp4".to_string(),
                },
                priority: 0,
                display_name: None,
                display_type: DisplayType::Video,
                duration: Some(300_000_000),
                offset: 0,
                source_type: "display".to_string(),
            }],
            audio_sources: vec![AudioSource {
                id: "a1".to_string(),
                origin: SourceOrigin::LocalFile {
                    path: "/music/song.mp3".to_string(),
                },
                priority: 0,
                display_name: Some("Main".to_string()),
                format: AudioFormat::Mp3,
                duration: Some(240_000_000),
                offset: 0,
                source_type: "audio".to_string(),
            }],
            instrumental_sources: vec![InstrumentalSource {
                id: "i1".to_string(),
                origin: SourceOrigin::LocalFile {
                    path: "/music/karaoke.mp3".to_string(),
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
                    path: "/lyrics/song.lrc".to_string(),
                },
                priority: 0,
                display_name: None,
                format: LyricsFormat::Lrc,
                offset: 0,
                source_type: "hover".to_string(),
            }],
        }
    }

    #[test]
    fn round_trip_serialization() {
        let col = sample_collection();
        let json = serde_json::to_string(&col).unwrap();
        let back: SourceCollection = serde_json::from_str(&json).unwrap();
        assert_eq!(col, back);
    }

    #[test]
    fn dart_json_key_compatibility() {
        let col = sample_collection();
        let val = serde_json::to_value(&col).unwrap();
        let obj = val.as_object().unwrap();

        // Must use camelCase keys matching Dart
        assert!(obj.contains_key("displaySources"));
        assert!(obj.contains_key("audioSources"));
        assert!(obj.contains_key("accompanimentSources"));
        assert!(obj.contains_key("hoverSources"));

        // Must NOT have snake_case keys
        assert!(!obj.contains_key("display_sources"));
        assert!(!obj.contains_key("audio_sources"));
        assert!(!obj.contains_key("instrumental_sources"));
        assert!(!obj.contains_key("hover_sources"));
    }

    #[test]
    fn deserialize_empty_collection() {
        let json = json!({});
        let col: SourceCollection = serde_json::from_value(json).unwrap();
        assert!(col.display_sources.is_empty());
        assert!(col.audio_sources.is_empty());
        assert!(col.instrumental_sources.is_empty());
        assert!(col.hover_sources.is_empty());
    }

    #[test]
    fn deserialize_dart_json_with_camel_case_keys() {
        let dart_json = json!({
            "displaySources": [],
            "audioSources": [{
                "id": "a1",
                "origin": {"type": "localFile", "path": "/song.mp3"},
                "priority": 0,
                "format": "mp3",
                "sourceType": "audio"
            }],
            "accompanimentSources": [],
            "hoverSources": []
        });
        let col: SourceCollection = serde_json::from_value(dart_json).unwrap();
        assert_eq!(col.audio_sources.len(), 1);
        assert_eq!(col.audio_sources[0].id, "a1");
    }

    #[test]
    fn all_sources_returns_all_types() {
        let col = sample_collection();
        let refs = col.all_sources();
        assert_eq!(refs.len(), 4);
        assert_eq!(refs[0].source_type, SourceType::Display);
        assert_eq!(refs[1].source_type, SourceType::Audio);
        assert_eq!(refs[2].source_type, SourceType::Accompaniment);
        assert_eq!(refs[3].source_type, SourceType::Hover);
    }

    #[test]
    fn all_sources_empty_collection() {
        let col = SourceCollection {
            display_sources: vec![],
            audio_sources: vec![],
            instrumental_sources: vec![],
            hover_sources: vec![],
        };
        assert!(col.all_sources().is_empty());
    }

    #[test]
    fn all_sources_preserves_origins() {
        let col = sample_collection();
        let refs = col.all_sources();

        // Display source origin
        assert_eq!(
            *refs[0].origin,
            SourceOrigin::Url {
                url: "https://example.com/video.mp4".to_string()
            }
        );
        // Audio source origin
        assert_eq!(
            *refs[1].origin,
            SourceOrigin::LocalFile {
                path: "/music/song.mp3".to_string()
            }
        );
    }
}
