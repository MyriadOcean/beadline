use serde::{Deserialize, Serialize};

/// User preferences for source selection within a Song Unit.
///
/// JSON keys use the legacy `"accompaniment"` naming for DB compatibility.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PlaybackPreferences {
    #[serde(default, rename = "preferAccompaniment")]
    pub prefer_instrumental: bool,
    #[serde(
        skip_serializing_if = "Option::is_none",
        rename = "preferredDisplaySourceId"
    )]
    pub preferred_display_source_id: Option<String>,
    #[serde(
        skip_serializing_if = "Option::is_none",
        rename = "preferredAudioSourceId"
    )]
    pub preferred_audio_source_id: Option<String>,
    #[serde(
        skip_serializing_if = "Option::is_none",
        rename = "preferredAccompanimentSourceId"
    )]
    pub preferred_instrumental_source_id: Option<String>,
    #[serde(
        skip_serializing_if = "Option::is_none",
        rename = "preferredHoverSourceId"
    )]
    pub preferred_hover_source_id: Option<String>,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn round_trip_full() {
        let prefs = PlaybackPreferences {
            prefer_instrumental: true,
            preferred_display_source_id: Some("d1".to_string()),
            preferred_audio_source_id: Some("a1".to_string()),
            preferred_instrumental_source_id: Some("i1".to_string()),
            preferred_hover_source_id: Some("h1".to_string()),
        };
        let json = serde_json::to_string(&prefs).unwrap();
        let back: PlaybackPreferences = serde_json::from_str(&json).unwrap();
        assert_eq!(prefs, back);
    }

    #[test]
    fn round_trip_defaults() {
        let prefs = PlaybackPreferences {
            prefer_instrumental: false,
            preferred_display_source_id: None,
            preferred_audio_source_id: None,
            preferred_instrumental_source_id: None,
            preferred_hover_source_id: None,
        };
        let json = serde_json::to_string(&prefs).unwrap();
        let back: PlaybackPreferences = serde_json::from_str(&json).unwrap();
        assert_eq!(prefs, back);
    }

    #[test]
    fn dart_json_key_compatibility() {
        let prefs = PlaybackPreferences {
            prefer_instrumental: true,
            preferred_display_source_id: Some("d1".to_string()),
            preferred_audio_source_id: Some("a1".to_string()),
            preferred_instrumental_source_id: Some("i1".to_string()),
            preferred_hover_source_id: Some("h1".to_string()),
        };
        let val = serde_json::to_value(&prefs).unwrap();
        let obj = val.as_object().unwrap();

        // Must use Dart-compatible camelCase keys
        assert!(obj.contains_key("preferAccompaniment"));
        assert!(obj.contains_key("preferredDisplaySourceId"));
        assert!(obj.contains_key("preferredAudioSourceId"));
        assert!(obj.contains_key("preferredAccompanimentSourceId"));
        assert!(obj.contains_key("preferredHoverSourceId"));

        // Must NOT have snake_case keys
        assert!(!obj.contains_key("prefer_instrumental"));
        assert!(!obj.contains_key("preferred_display_source_id"));
        assert!(!obj.contains_key("preferred_instrumental_source_id"));
    }

    #[test]
    fn deserialize_dart_json() {
        let dart_json = json!({
            "preferAccompaniment": true,
            "preferredDisplaySourceId": "d1",
            "preferredAudioSourceId": null,
            "preferredAccompanimentSourceId": "i1",
            "preferredHoverSourceId": null
        });
        let prefs: PlaybackPreferences = serde_json::from_value(dart_json).unwrap();
        assert!(prefs.prefer_instrumental);
        assert_eq!(prefs.preferred_display_source_id, Some("d1".to_string()));
        assert_eq!(prefs.preferred_audio_source_id, None);
        assert_eq!(
            prefs.preferred_instrumental_source_id,
            Some("i1".to_string())
        );
        assert_eq!(prefs.preferred_hover_source_id, None);
    }

    #[test]
    fn deserialize_empty_json_uses_defaults() {
        let json = json!({});
        let prefs: PlaybackPreferences = serde_json::from_value(json).unwrap();
        assert!(!prefs.prefer_instrumental);
        assert_eq!(prefs.preferred_display_source_id, None);
        assert_eq!(prefs.preferred_audio_source_id, None);
        assert_eq!(prefs.preferred_instrumental_source_id, None);
        assert_eq!(prefs.preferred_hover_source_id, None);
    }

    #[test]
    fn serialization_skips_none_fields() {
        let prefs = PlaybackPreferences {
            prefer_instrumental: false,
            preferred_display_source_id: None,
            preferred_audio_source_id: None,
            preferred_instrumental_source_id: None,
            preferred_hover_source_id: None,
        };
        let val = serde_json::to_value(&prefs).unwrap();
        let obj = val.as_object().unwrap();

        // Only preferAccompaniment should be present (it's not skip_serializing_if)
        assert!(obj.contains_key("preferAccompaniment"));
        assert!(!obj.contains_key("preferredDisplaySourceId"));
        assert!(!obj.contains_key("preferredAudioSourceId"));
        assert!(!obj.contains_key("preferredAccompanimentSourceId"));
        assert!(!obj.contains_key("preferredHoverSourceId"));
    }
}
