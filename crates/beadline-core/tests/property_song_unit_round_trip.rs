// Feature: song-unit-rust-migration, Property 1: SongUnit JSON round-trip
// **Validates: Requirements 2.3, 2.4, 2.5, 2.6**

use proptest::prelude::*;

use beadline_core::model::metadata::Metadata;
use beadline_core::model::playback_preferences::PlaybackPreferences;
use beadline_core::model::source::{
    AudioFormat, AudioSource, DisplaySource, DisplayType, HoverSource, InstrumentalSource,
    LyricsFormat, SourceOrigin,
};
use beadline_core::model::source_collection::SourceCollection;
use beadline_core::model::song_unit::SongUnit;

// ---------------------------------------------------------------------------
// Strategies
// ---------------------------------------------------------------------------

fn arb_source_origin() -> impl Strategy<Value = SourceOrigin> {
    prop_oneof![
        any::<String>()
            .prop_filter("non-empty path", |s| !s.is_empty())
            .prop_map(|path| SourceOrigin::LocalFile { path }),
        any::<String>()
            .prop_filter("non-empty url", |s| !s.is_empty())
            .prop_map(|url| SourceOrigin::Url { url }),
        (any::<String>(), any::<String>()).prop_map(|(provider, resource_id)| SourceOrigin::Api {
            provider,
            resource_id,
        }),
    ]
}

fn arb_audio_format() -> impl Strategy<Value = AudioFormat> {
    prop_oneof![
        Just(AudioFormat::Mp3),
        Just(AudioFormat::Flac),
        Just(AudioFormat::Wav),
        Just(AudioFormat::Aac),
        Just(AudioFormat::Ogg),
        Just(AudioFormat::M4a),
        Just(AudioFormat::Other),
    ]
}

fn arb_display_type() -> impl Strategy<Value = DisplayType> {
    prop_oneof![Just(DisplayType::Video), Just(DisplayType::Image),]
}

fn arb_audio_source() -> impl Strategy<Value = AudioSource> {
    (
        any::<String>(),
        arb_source_origin(),
        any::<i32>(),
        proptest::option::of(any::<String>()),
        arb_audio_format(),
        proptest::option::of(any::<i64>()),
        any::<i64>(),
    )
        .prop_map(
            |(id, origin, priority, display_name, format, duration, offset)| AudioSource {
                id,
                origin,
                priority,
                display_name,
                format,
                duration,
                offset,
                source_type: "audio".to_string(),
            },
        )
}

fn arb_display_source() -> impl Strategy<Value = DisplaySource> {
    (
        any::<String>(),
        arb_source_origin(),
        any::<i32>(),
        proptest::option::of(any::<String>()),
        arb_display_type(),
        proptest::option::of(any::<i64>()),
        any::<i64>(),
    )
        .prop_map(
            |(id, origin, priority, display_name, display_type, duration, offset)| DisplaySource {
                id,
                origin,
                priority,
                display_name,
                display_type,
                duration,
                offset,
                source_type: "display".to_string(),
            },
        )
}

fn arb_instrumental_source() -> impl Strategy<Value = InstrumentalSource> {
    (
        any::<String>(),
        arb_source_origin(),
        any::<i32>(),
        proptest::option::of(any::<String>()),
        arb_audio_format(),
        proptest::option::of(any::<i64>()),
        any::<i64>(),
    )
        .prop_map(
            |(id, origin, priority, display_name, format, duration, offset)| InstrumentalSource {
                id,
                origin,
                priority,
                display_name,
                format,
                duration,
                offset,
                source_type: "accompaniment".to_string(),
            },
        )
}

fn arb_hover_source() -> impl Strategy<Value = HoverSource> {
    (
        any::<String>(),
        arb_source_origin(),
        any::<i32>(),
        proptest::option::of(any::<String>()),
        any::<i64>(),
    )
        .prop_map(|(id, origin, priority, display_name, offset)| {
            HoverSource {
                id,
                origin,
                priority,
                display_name,
                format: LyricsFormat::Lrc, // Only variant
                offset,
                source_type: "hover".to_string(),
            }
        })
}

fn arb_source_collection() -> impl Strategy<Value = SourceCollection> {
    (
        proptest::collection::vec(arb_display_source(), 0..=3),
        proptest::collection::vec(arb_audio_source(), 0..=3),
        proptest::collection::vec(arb_instrumental_source(), 0..=3),
        proptest::collection::vec(arb_hover_source(), 0..=3),
    )
        .prop_map(
            |(display_sources, audio_sources, instrumental_sources, hover_sources)| {
                SourceCollection {
                    display_sources,
                    audio_sources,
                    instrumental_sources,
                    hover_sources,
                }
            },
        )
}

fn arb_metadata() -> impl Strategy<Value = Metadata> {
    (
        any::<String>(),
        proptest::collection::vec(any::<String>(), 0..=3),
        any::<String>(),
        proptest::option::of(any::<i32>()),
        any::<i64>(),
        proptest::option::of(any::<String>()),
        proptest::option::of(any::<String>()),
    )
        .prop_map(
            |(title, artists, album, year, duration, thumbnail_path, thumbnail_source_id)| {
                Metadata {
                    title,
                    artists,
                    album,
                    year,
                    duration,
                    thumbnail_path,
                    thumbnail_source_id,
                }
            },
        )
}

fn arb_playback_preferences() -> impl Strategy<Value = PlaybackPreferences> {
    (
        any::<bool>(),
        proptest::option::of(any::<String>()),
        proptest::option::of(any::<String>()),
        proptest::option::of(any::<String>()),
        proptest::option::of(any::<String>()),
    )
        .prop_map(
            |(
                prefer_instrumental,
                preferred_display_source_id,
                preferred_audio_source_id,
                preferred_instrumental_source_id,
                preferred_hover_source_id,
            )| {
                PlaybackPreferences {
                    prefer_instrumental,
                    preferred_display_source_id,
                    preferred_audio_source_id,
                    preferred_instrumental_source_id,
                    preferred_hover_source_id,
                }
            },
        )
}

fn arb_song_unit() -> impl Strategy<Value = SongUnit> {
    (
        any::<String>(),
        arb_metadata(),
        arb_source_collection(),
        proptest::collection::vec(any::<String>(), 0..=5),
        arb_playback_preferences(),
        proptest::option::of(any::<String>()),
        any::<bool>(),
        proptest::option::of(any::<i64>()),
        proptest::option::of(any::<String>()),
    )
        .prop_map(
            |(
                id,
                metadata,
                sources,
                tag_ids,
                preferences,
                library_location_id,
                is_temporary,
                discovered_at,
                original_file_path,
            )| {
                SongUnit {
                    id,
                    metadata,
                    sources,
                    tag_ids,
                    preferences,
                    library_location_id,
                    is_temporary,
                    discovered_at,
                    original_file_path,
                }
            },
        )
}

// ---------------------------------------------------------------------------
// Property test
// ---------------------------------------------------------------------------

proptest! {
    #[test]
    fn song_unit_json_round_trip(su in arb_song_unit()) {
        let json = serde_json::to_string(&su).unwrap();
        let deserialized: SongUnit = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(su, deserialized);
    }
}
