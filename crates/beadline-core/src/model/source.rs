use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// SourceOrigin
// ---------------------------------------------------------------------------

/// The provenance of a source — local file path, URL, or API reference.
///
/// Uses internally-tagged representation: `{"type": "localFile", "path": "..."}`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum SourceOrigin {
    #[serde(rename = "localFile")]
    LocalFile { path: String },
    #[serde(rename = "url")]
    Url { url: String },
    #[serde(rename = "api")]
    Api {
        provider: String,
        #[serde(rename = "resourceId")]
        resource_id: String,
    },
}

impl SourceOrigin {
    /// Convert to a JSON value for hash calculation.
    pub fn to_json_value(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AudioFormat {
    Mp3,
    Flac,
    Wav,
    Aac,
    Ogg,
    M4a,
    Other,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DisplayType {
    Video,
    Image,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LyricsFormat {
    Lrc,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SourceType {
    Display,
    Audio,
    Accompaniment,
    Hover,
}

impl std::fmt::Display for SourceType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SourceType::Display => write!(f, "SourceType.display"),
            SourceType::Audio => write!(f, "SourceType.audio"),
            SourceType::Accompaniment => write!(f, "SourceType.accompaniment"),
            SourceType::Hover => write!(f, "SourceType.hover"),
        }
    }
}

// ---------------------------------------------------------------------------
// Source structs
// ---------------------------------------------------------------------------

// Default functions for sourceType fields — used by serde(default = "...").

fn default_source_type_audio() -> String {
    "audio".to_string()
}

fn default_source_type_display() -> String {
    "display".to_string()
}

fn default_source_type_accompaniment() -> String {
    "accompaniment".to_string()
}

fn default_source_type_hover() -> String {
    "hover".to_string()
}

/// Audio source.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AudioSource {
    pub id: String,
    pub origin: SourceOrigin,
    pub priority: i32,
    #[serde(skip_serializing_if = "Option::is_none", rename = "displayName")]
    pub display_name: Option<String>,
    pub format: AudioFormat,
    /// Duration in microseconds.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration: Option<i64>,
    /// Offset in microseconds (default 0).
    #[serde(default)]
    pub offset: i64,
    /// Discriminator written to JSON for DB compat. Always `"audio"`.
    #[serde(rename = "sourceType", default = "default_source_type_audio")]
    pub source_type: String,
}

impl AudioSource {
    pub fn get_source_type(&self) -> SourceType {
        SourceType::Audio
    }
}

/// Display source (video or image).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DisplaySource {
    pub id: String,
    pub origin: SourceOrigin,
    pub priority: i32,
    #[serde(skip_serializing_if = "Option::is_none", rename = "displayName")]
    pub display_name: Option<String>,
    #[serde(rename = "displayType")]
    pub display_type: DisplayType,
    /// Duration in microseconds.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration: Option<i64>,
    /// Offset in microseconds (default 0).
    #[serde(default)]
    pub offset: i64,
    /// Discriminator written to JSON for DB compat. Always `"display"`.
    #[serde(rename = "sourceType", default = "default_source_type_display")]
    pub source_type: String,
}

impl DisplaySource {
    pub fn get_source_type(&self) -> SourceType {
        SourceType::Display
    }
}

/// Instrumental / accompaniment source.
///
/// Maps to Dart's `AccompanimentSource`. The JSON key `sourceType` serializes
/// as `"accompaniment"` for database compatibility.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct InstrumentalSource {
    pub id: String,
    pub origin: SourceOrigin,
    pub priority: i32,
    #[serde(skip_serializing_if = "Option::is_none", rename = "displayName")]
    pub display_name: Option<String>,
    pub format: AudioFormat,
    /// Duration in microseconds.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration: Option<i64>,
    /// Offset in microseconds (default 0).
    #[serde(default)]
    pub offset: i64,
    /// Discriminator written to JSON for DB compat. Always `"accompaniment"`.
    #[serde(rename = "sourceType", default = "default_source_type_accompaniment")]
    pub source_type: String,
}

impl InstrumentalSource {
    pub fn get_source_type(&self) -> SourceType {
        SourceType::Accompaniment
    }
}

/// Hover source (lyrics).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HoverSource {
    pub id: String,
    pub origin: SourceOrigin,
    pub priority: i32,
    #[serde(skip_serializing_if = "Option::is_none", rename = "displayName")]
    pub display_name: Option<String>,
    pub format: LyricsFormat,
    /// Offset in microseconds (default 0).
    #[serde(default)]
    pub offset: i64,
    /// Discriminator written to JSON for DB compat. Always `"hover"`.
    #[serde(rename = "sourceType", default = "default_source_type_hover")]
    pub source_type: String,
}

impl HoverSource {
    pub fn get_source_type(&self) -> SourceType {
        SourceType::Hover
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn source_origin_local_file_round_trip() {
        let origin = SourceOrigin::LocalFile {
            path: "/music/song.mp3".to_string(),
        };
        let json = serde_json::to_value(&origin).unwrap();
        assert_eq!(json["type"], "localFile");
        assert_eq!(json["path"], "/music/song.mp3");
        let back: SourceOrigin = serde_json::from_value(json).unwrap();
        assert_eq!(origin, back);
    }

    #[test]
    fn source_origin_url_round_trip() {
        let origin = SourceOrigin::Url {
            url: "https://example.com/song.mp3".to_string(),
        };
        let json = serde_json::to_value(&origin).unwrap();
        assert_eq!(json["type"], "url");
        assert_eq!(json["url"], "https://example.com/song.mp3");
        let back: SourceOrigin = serde_json::from_value(json).unwrap();
        assert_eq!(origin, back);
    }

    #[test]
    fn source_origin_api_round_trip() {
        let origin = SourceOrigin::Api {
            provider: "netease".to_string(),
            resource_id: "12345".to_string(),
        };
        let json = serde_json::to_value(&origin).unwrap();
        assert_eq!(json["type"], "api");
        assert_eq!(json["provider"], "netease");
        assert_eq!(json["resourceId"], "12345");
        let back: SourceOrigin = serde_json::from_value(json).unwrap();
        assert_eq!(origin, back);
    }

    #[test]
    fn audio_format_serialization() {
        assert_eq!(serde_json::to_value(AudioFormat::Mp3).unwrap(), "mp3");
        assert_eq!(serde_json::to_value(AudioFormat::Flac).unwrap(), "flac");
        assert_eq!(serde_json::to_value(AudioFormat::M4a).unwrap(), "m4a");
        assert_eq!(serde_json::to_value(AudioFormat::Other).unwrap(), "other");
    }

    #[test]
    fn display_type_serialization() {
        assert_eq!(serde_json::to_value(DisplayType::Video).unwrap(), "video");
        assert_eq!(serde_json::to_value(DisplayType::Image).unwrap(), "image");
    }

    #[test]
    fn lyrics_format_serialization() {
        assert_eq!(serde_json::to_value(LyricsFormat::Lrc).unwrap(), "lrc");
    }

    #[test]
    fn source_type_serialization() {
        assert_eq!(
            serde_json::to_value(SourceType::Display).unwrap(),
            "display"
        );
        assert_eq!(serde_json::to_value(SourceType::Audio).unwrap(), "audio");
        assert_eq!(
            serde_json::to_value(SourceType::Accompaniment).unwrap(),
            "accompaniment"
        );
        assert_eq!(serde_json::to_value(SourceType::Hover).unwrap(), "hover");
    }

    #[test]
    fn source_type_display_matches_dart() {
        // Dart uses SourceType.display, SourceType.audio, etc. in hash calculation
        assert_eq!(SourceType::Display.to_string(), "SourceType.display");
        assert_eq!(SourceType::Audio.to_string(), "SourceType.audio");
        assert_eq!(
            SourceType::Accompaniment.to_string(),
            "SourceType.accompaniment"
        );
        assert_eq!(SourceType::Hover.to_string(), "SourceType.hover");
    }

    #[test]
    fn audio_source_round_trip() {
        let src = AudioSource {
            id: "a1".to_string(),
            origin: SourceOrigin::LocalFile {
                path: "/music/song.mp3".to_string(),
            },
            priority: 0,
            display_name: Some("Main Audio".to_string()),
            format: AudioFormat::Mp3,
            duration: Some(240_000_000),
            offset: 0,
            source_type: "audio".to_string(),
        };
        let json = serde_json::to_string(&src).unwrap();
        let back: AudioSource = serde_json::from_str(&json).unwrap();
        assert_eq!(src, back);
    }

    #[test]
    fn audio_source_dart_json_compat() {
        // JSON as produced by Dart's AudioSource.toJson()
        let dart_json = json!({
            "sourceType": "audio",
            "id": "a1",
            "origin": {"type": "localFile", "path": "/music/song.mp3"},
            "priority": 0,
            "displayName": null,
            "format": "mp3",
            "duration": 240000000,
            "offset": 0
        });
        let src: AudioSource = serde_json::from_value(dart_json).unwrap();
        assert_eq!(src.id, "a1");
        assert_eq!(src.format, AudioFormat::Mp3);
        assert_eq!(src.duration, Some(240_000_000));
        assert_eq!(src.source_type, "audio");
    }

    #[test]
    fn display_source_round_trip() {
        let src = DisplaySource {
            id: "d1".to_string(),
            origin: SourceOrigin::Url {
                url: "https://example.com/video.mp4".to_string(),
            },
            priority: 1,
            display_name: None,
            display_type: DisplayType::Video,
            duration: Some(300_000_000),
            offset: 5000,
            source_type: "display".to_string(),
        };
        let json = serde_json::to_string(&src).unwrap();
        let back: DisplaySource = serde_json::from_str(&json).unwrap();
        assert_eq!(src, back);
    }

    #[test]
    fn instrumental_source_serializes_as_accompaniment() {
        let src = InstrumentalSource {
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
        };
        let json = serde_json::to_value(&src).unwrap();
        assert_eq!(json["sourceType"], "accompaniment");
        let back: InstrumentalSource = serde_json::from_value(json).unwrap();
        assert_eq!(src, back);
    }

    #[test]
    fn hover_source_round_trip() {
        let src = HoverSource {
            id: "h1".to_string(),
            origin: SourceOrigin::LocalFile {
                path: "/lyrics/song.lrc".to_string(),
            },
            priority: 0,
            display_name: None,
            format: LyricsFormat::Lrc,
            offset: -500_000,
            source_type: "hover".to_string(),
        };
        let json = serde_json::to_string(&src).unwrap();
        let back: HoverSource = serde_json::from_str(&json).unwrap();
        assert_eq!(src, back);
    }

    #[test]
    fn audio_source_missing_optional_fields() {
        // Minimal JSON — no displayName, no duration, no offset, no sourceType
        let json = json!({
            "id": "a2",
            "origin": {"type": "url", "url": "https://cdn.example.com/track.flac"},
            "priority": 1,
            "format": "flac"
        });
        let src: AudioSource = serde_json::from_value(json).unwrap();
        assert_eq!(src.display_name, None);
        assert_eq!(src.duration, None);
        assert_eq!(src.offset, 0);
        assert_eq!(src.source_type, "audio");
    }

    #[test]
    fn source_origin_to_json_value() {
        let origin = SourceOrigin::LocalFile {
            path: "/music/song.mp3".to_string(),
        };
        let val = origin.to_json_value();
        assert_eq!(val["type"], "localFile");
        assert_eq!(val["path"], "/music/song.mp3");
    }
}
