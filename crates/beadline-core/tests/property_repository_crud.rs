// Feature: song-unit-rust-migration, Property 4: Repository insert/get round-trip
// **Validates: Requirements 4.1, 4.4, 4.11**
//
// Feature: song-unit-rust-migration, Property 5: Repository update persistence
// **Validates: Requirements 4.2**
//
// Feature: song-unit-rust-migration, Property 6: Repository delete with tag cleanup
// **Validates: Requirements 4.3, 4.11**

use proptest::prelude::*;
use sea_orm::{
    ConnectOptions, ConnectionTrait, Database, DatabaseConnection, DbBackend, Statement,
};
use tokio::runtime::Runtime;

use beadline_core::model::metadata::Metadata;
use beadline_core::model::playback_preferences::PlaybackPreferences;
use beadline_core::model::song_unit::SongUnit;
use beadline_core::model::source::{
    AudioFormat, AudioSource, DisplaySource, DisplayType, HoverSource, InstrumentalSource,
    LyricsFormat, SourceOrigin,
};
use beadline_core::model::source_collection::SourceCollection;
use beadline_core::repository;

// ---------------------------------------------------------------------------
// Test DB helper
// ---------------------------------------------------------------------------

async fn test_db() -> DatabaseConnection {
    let mut opts = ConnectOptions::new("sqlite::memory:");
    opts.sqlx_logging(false);
    let conn = Database::connect(opts).await.unwrap();
    beadline_core::database::init_song_units_schema(&conn)
        .await
        .unwrap();
    conn
}

// ---------------------------------------------------------------------------
// Strategies — constrained for DB validity
// ---------------------------------------------------------------------------

/// Generate a UUID-like unique ID.
fn arb_id() -> impl Strategy<Value = String> {
    "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"
}

/// Generate a non-empty safe string (no NUL bytes, reasonable length).
fn arb_safe_string() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 _-]{1,30}"
}

fn arb_source_origin() -> impl Strategy<Value = SourceOrigin> {
    prop_oneof![
        arb_safe_string().prop_map(|path| SourceOrigin::LocalFile {
            path: format!("/music/{path}.mp3")
        }),
        arb_safe_string().prop_map(|name| SourceOrigin::Url {
            url: format!("https://example.com/{name}.mp3")
        }),
        (arb_safe_string(), arb_safe_string()).prop_map(|(provider, rid)| SourceOrigin::Api {
            provider,
            resource_id: rid,
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

fn arb_audio_source() -> impl Strategy<Value = AudioSource> {
    (
        arb_id(),
        arb_source_origin(),
        0..10i32,
        proptest::option::of(arb_safe_string()),
        arb_audio_format(),
        proptest::option::of(0..600_000_000i64),
        0..10_000i64,
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
        arb_id(),
        arb_source_origin(),
        0..10i32,
        proptest::option::of(arb_safe_string()),
        prop_oneof![Just(DisplayType::Video), Just(DisplayType::Image)],
        proptest::option::of(0..600_000_000i64),
        0..10_000i64,
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
        arb_id(),
        arb_source_origin(),
        0..10i32,
        proptest::option::of(arb_safe_string()),
        arb_audio_format(),
        proptest::option::of(0..600_000_000i64),
        0..10_000i64,
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
        arb_id(),
        arb_source_origin(),
        0..10i32,
        proptest::option::of(arb_safe_string()),
        0..10_000i64,
    )
        .prop_map(|(id, origin, priority, display_name, offset)| HoverSource {
            id,
            origin,
            priority,
            display_name,
            format: LyricsFormat::Lrc,
            offset,
            source_type: "hover".to_string(),
        })
}

fn arb_source_collection() -> impl Strategy<Value = SourceCollection> {
    (
        proptest::collection::vec(arb_display_source(), 0..=2),
        proptest::collection::vec(arb_audio_source(), 0..=2),
        proptest::collection::vec(arb_instrumental_source(), 0..=2),
        proptest::collection::vec(arb_hover_source(), 0..=2),
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
        arb_safe_string(),
        proptest::collection::vec(arb_safe_string(), 0..=3),
        arb_safe_string(),
        proptest::option::of(1900..2100i32),
        0..600_000_000i64,
        proptest::option::of(arb_safe_string()),
        proptest::option::of(arb_id()),
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
        proptest::option::of(arb_id()),
        proptest::option::of(arb_id()),
        proptest::option::of(arb_id()),
        proptest::option::of(arb_id()),
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

/// Generate unique tag IDs (deduplicated).
fn arb_unique_tag_ids() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::hash_set(arb_id(), 0..=5).prop_map(|s| s.into_iter().collect())
}

/// Generate a valid SongUnit with unique ID and unique tag IDs.
fn arb_song_unit() -> impl Strategy<Value = SongUnit> {
    (
        arb_id(),
        arb_metadata(),
        arb_source_collection(),
        arb_unique_tag_ids(),
        arb_playback_preferences(),
        proptest::option::of(arb_id()),
        any::<bool>(),
        proptest::option::of(0..2_000_000_000_000i64),
        proptest::option::of(arb_safe_string().prop_map(|s| format!("/path/{s}.mp3"))),
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
// Property 4: Repository insert/get round-trip
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(50))]

    #[test]
    fn repository_insert_get_round_trip(su in arb_song_unit()) {
        // Feature: song-unit-rust-migration, Property 4: Repository insert/get round-trip
        // **Validates: Requirements 4.1, 4.4, 4.11**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert
            repository::insert_song_unit(&conn, &su).await.unwrap();

            // Get by ID
            let retrieved = repository::get_song_unit(&conn, &su.id)
                .await
                .unwrap()
                .expect("Song unit should exist after insert");

            // Verify all domain fields match
            prop_assert_eq!(&retrieved.id, &su.id);
            prop_assert_eq!(&retrieved.metadata, &su.metadata);
            prop_assert_eq!(&retrieved.sources, &su.sources);
            prop_assert_eq!(&retrieved.preferences, &su.preferences);

            // Tag IDs may be in different order — compare as sorted
            let mut expected_tags = su.tag_ids.clone();
            expected_tags.sort();
            let mut actual_tags = retrieved.tag_ids.clone();
            actual_tags.sort();
            prop_assert_eq!(&actual_tags, &expected_tags);

            prop_assert_eq!(&retrieved.library_location_id, &su.library_location_id);
            prop_assert_eq!(retrieved.is_temporary, su.is_temporary);
            prop_assert_eq!(&retrieved.discovered_at, &su.discovered_at);
            prop_assert_eq!(&retrieved.original_file_path, &su.original_file_path);

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 5: Repository update persistence
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(50))]

    #[test]
    fn repository_update_persistence(
        su in arb_song_unit(),
        new_metadata in arb_metadata(),
        new_sources in arb_source_collection(),
        new_prefs in arb_playback_preferences(),
        new_tags in arb_unique_tag_ids(),
    ) {
        // Feature: song-unit-rust-migration, Property 5: Repository update persistence
        // **Validates: Requirements 4.2**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert original
            repository::insert_song_unit(&conn, &su).await.unwrap();

            // Modify fields
            let updated_su = SongUnit {
                id: su.id.clone(),
                metadata: new_metadata.clone(),
                sources: new_sources.clone(),
                preferences: new_prefs.clone(),
                tag_ids: new_tags.clone(),
                library_location_id: su.library_location_id.clone(),
                is_temporary: !su.is_temporary,
                discovered_at: su.discovered_at.map(|d| d + 1000),
                original_file_path: su.original_file_path.clone(),
            };

            // Update
            repository::update_song_unit(&conn, &updated_su).await.unwrap();

            // Get and verify
            let retrieved = repository::get_song_unit(&conn, &su.id)
                .await
                .unwrap()
                .expect("Song unit should exist after update");

            prop_assert_eq!(&retrieved.metadata, &new_metadata);
            prop_assert_eq!(&retrieved.sources, &new_sources);
            prop_assert_eq!(&retrieved.preferences, &new_prefs);
            prop_assert_eq!(retrieved.is_temporary, !su.is_temporary);

            let mut expected_tags = new_tags.clone();
            expected_tags.sort();
            let mut actual_tags = retrieved.tag_ids.clone();
            actual_tags.sort();
            prop_assert_eq!(&actual_tags, &expected_tags);

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 6: Repository delete with tag cleanup
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(50))]

    #[test]
    fn repository_delete_with_tag_cleanup(su in arb_song_unit()) {
        // Feature: song-unit-rust-migration, Property 6: Repository delete with tag cleanup
        // **Validates: Requirements 4.3, 4.11**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert
            repository::insert_song_unit(&conn, &su).await.unwrap();

            // Verify it exists
            let exists = repository::get_song_unit(&conn, &su.id).await.unwrap();
            prop_assert!(exists.is_some(), "Song unit should exist after insert");

            // Delete
            repository::delete_song_unit(&conn, &su.id).await.unwrap();

            // Verify get returns None
            let after_delete = repository::get_song_unit(&conn, &su.id).await.unwrap();
            prop_assert!(after_delete.is_none(), "Song unit should be None after delete");

            // Verify no tag associations remain
            let tag_rows = conn
                .query_all(Statement::from_string(
                    DbBackend::Sqlite,
                    format!(
                        "SELECT COUNT(*) as cnt FROM song_unit_tags WHERE song_unit_id = '{}'",
                        su.id
                    ),
                ))
                .await
                .unwrap();
            let count: i32 = tag_rows[0].try_get("", "cnt").unwrap();
            prop_assert_eq!(count, 0, "No tag associations should remain after delete");

            Ok(())
        })?;
    }
}
