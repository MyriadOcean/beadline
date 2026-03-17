// Feature: song-unit-rust-migration, Property 7: Pagination correctness
// **Validates: Requirements 4.5**
//
// Feature: song-unit-rust-migration, Property 8: Library location filtering
// **Validates: Requirements 4.6**
//
// Feature: song-unit-rust-migration, Property 9: Hash-based dedup query
// **Validates: Requirements 4.7**
//
// Feature: song-unit-rust-migration, Property 10: Temporary Song Unit lifecycle
// **Validates: Requirements 4.8, 4.9, 4.10**

use proptest::prelude::*;
use sea_orm::{ConnectOptions, Database, DatabaseConnection};
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
// Strategies — reused from property_repository_crud.rs
// ---------------------------------------------------------------------------

fn arb_id() -> impl Strategy<Value = String> {
    "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"
}

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

fn arb_unique_tag_ids() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::hash_set(arb_id(), 0..=3).prop_map(|s| s.into_iter().collect())
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

/// Generate a SongUnit with a specific library_location_id.
fn arb_song_unit_with_location(location: String) -> impl Strategy<Value = SongUnit> {
    arb_song_unit().prop_map(move |mut su| {
        su.library_location_id = Some(location.clone());
        su
    })
}

/// Generate a temporary SongUnit with a specific file path.
fn arb_temporary_song_unit_with_path(path: String) -> impl Strategy<Value = SongUnit> {
    arb_song_unit().prop_map(move |mut su| {
        su.is_temporary = true;
        su.original_file_path = Some(path.clone());
        su
    })
}

/// Generate a non-temporary SongUnit.
fn arb_non_temporary_song_unit() -> impl Strategy<Value = SongUnit> {
    arb_song_unit().prop_map(|mut su| {
        su.is_temporary = false;
        su
    })
}


// ---------------------------------------------------------------------------
// Property 7: Pagination correctness
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(30))]

    #[test]
    fn pagination_correctness(
        song_units in proptest::collection::vec(arb_song_unit(), 3..=10)
    ) {
        // Feature: song-unit-rust-migration, Property 7: Pagination correctness
        // **Validates: Requirements 4.5**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert all song units (ensure unique IDs)
            let mut inserted_ids: Vec<String> = Vec::new();
            for su in &song_units {
                // Skip duplicates from random generation
                if inserted_ids.contains(&su.id) {
                    continue;
                }
                repository::insert_song_unit(&conn, su).await.unwrap();
                inserted_ids.push(su.id.clone());
            }

            let total = repository::get_song_unit_count(&conn).await.unwrap();
            prop_assert_eq!(total, inserted_ids.len() as u64);

            // Get all song units for reference
            let all = repository::get_all_song_units(&conn).await.unwrap();
            prop_assert_eq!(all.len(), inserted_ids.len());

            // Test pagination: page through with limit=3
            let limit: u64 = 3;
            let mut collected_ids: Vec<String> = Vec::new();
            let mut offset: u64 = 0;
            loop {
                let page = repository::get_song_units_paginated(&conn, offset, limit)
                    .await
                    .unwrap();

                // Each page must have at most `limit` results
                prop_assert!(
                    page.len() as u64 <= limit,
                    "Page at offset {} has {} items, expected at most {}",
                    offset,
                    page.len(),
                    limit
                );

                if page.is_empty() {
                    break;
                }

                for su in &page {
                    collected_ids.push(su.id.clone());
                }
                offset += page.len() as u64;
            }

            // Union of all pages must equal the full set
            let mut all_ids: Vec<String> = all.iter().map(|su| su.id.clone()).collect();
            all_ids.sort();
            collected_ids.sort();
            prop_assert_eq!(&collected_ids, &all_ids, "Paginated union must equal full set");

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 8: Library location filtering
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(30))]

    #[test]
    fn library_location_filtering(
        loc_a_units in proptest::collection::vec(arb_song_unit_with_location("loc-a".to_string()), 1..=3),
        loc_b_units in proptest::collection::vec(arb_song_unit_with_location("loc-b".to_string()), 1..=3),
        loc_c_units in proptest::collection::vec(arb_song_unit_with_location("loc-c".to_string()), 0..=2),
    ) {
        // Feature: song-unit-rust-migration, Property 8: Library location filtering
        // **Validates: Requirements 4.6**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let mut inserted_a = Vec::new();
            let mut inserted_b = Vec::new();
            let mut all_ids = std::collections::HashSet::new();

            for su in &loc_a_units {
                if all_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                all_ids.insert(su.id.clone());
                inserted_a.push(su.id.clone());
            }
            for su in &loc_b_units {
                if all_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                all_ids.insert(su.id.clone());
                inserted_b.push(su.id.clone());
            }
            for su in &loc_c_units {
                if all_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                all_ids.insert(su.id.clone());
            }

            // Query location A
            let result_a = repository::get_song_units_by_library_location(&conn, "loc-a")
                .await
                .unwrap();
            let mut result_a_ids: Vec<String> = result_a.iter().map(|su| su.id.clone()).collect();
            result_a_ids.sort();
            inserted_a.sort();
            prop_assert_eq!(&result_a_ids, &inserted_a, "Location A filter must return exactly A units");

            // Query location B
            let result_b = repository::get_song_units_by_library_location(&conn, "loc-b")
                .await
                .unwrap();
            let mut result_b_ids: Vec<String> = result_b.iter().map(|su| su.id.clone()).collect();
            result_b_ids.sort();
            inserted_b.sort();
            prop_assert_eq!(&result_b_ids, &inserted_b, "Location B filter must return exactly B units");

            // Query non-existent location
            let result_none = repository::get_song_units_by_library_location(&conn, "loc-nonexistent")
                .await
                .unwrap();
            prop_assert!(result_none.is_empty(), "Non-existent location must return empty");

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 9: Hash-based dedup query
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(30))]

    #[test]
    fn hash_based_dedup_query(
        song_units in proptest::collection::vec(arb_song_unit(), 3..=8)
    ) {
        // Feature: song-unit-rust-migration, Property 9: Hash-based dedup query
        // **Validates: Requirements 4.7**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert all (skip duplicate IDs)
            let mut inserted: Vec<SongUnit> = Vec::new();
            let mut seen_ids = std::collections::HashSet::new();
            for su in &song_units {
                if seen_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                seen_ids.insert(su.id.clone());
                inserted.push(su.clone());
            }

            // For each inserted song unit, query by its hash and verify
            for su in &inserted {
                let hash = beadline_core::hash::calculate_hash(su);
                let results = repository::get_song_units_by_hash(&conn, &hash)
                    .await
                    .unwrap();

                // The queried song unit must be in the results
                let result_ids: Vec<&String> = results.iter().map(|r| &r.id).collect();
                prop_assert!(
                    result_ids.contains(&&su.id),
                    "Song unit {} must appear in hash query results",
                    su.id
                );

                // All results must have the same hash
                for r in &results {
                    let r_hash = beadline_core::hash::calculate_hash(r);
                    prop_assert_eq!(
                        &r_hash, &hash,
                        "All results for hash query must have matching hash"
                    );
                }
            }

            // Query a hash that shouldn't exist
            let fake_results = repository::get_song_units_by_hash(&conn, "0000000000000000000000000000000000000000000000000000000000000000")
                .await
                .unwrap();
            prop_assert!(fake_results.is_empty(), "Fake hash must return empty");

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 10: Temporary Song Unit lifecycle
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(30))]

    #[test]
    fn temporary_song_unit_lifecycle(
        temp_units in proptest::collection::vec(
            arb_temporary_song_unit_with_path("/music/temp_song.mp3".to_string()), 1..=3
        ),
        temp_other_path in proptest::collection::vec(
            arb_temporary_song_unit_with_path("/music/other_song.mp3".to_string()), 0..=2
        ),
        non_temp_units in proptest::collection::vec(arb_non_temporary_song_unit(), 1..=3),
    ) {
        // Feature: song-unit-rust-migration, Property 10: Temporary Song Unit lifecycle
        // **Validates: Requirements 4.8, 4.9, 4.10**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let mut all_ids = std::collections::HashSet::new();
            let mut temp_count = 0u64;
            let mut non_temp_ids = Vec::new();

            // Insert temporary units with target path
            for su in &temp_units {
                if all_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                all_ids.insert(su.id.clone());
                temp_count += 1;
            }

            // Insert temporary units with other path
            for su in &temp_other_path {
                if all_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                all_ids.insert(su.id.clone());
                temp_count += 1;
            }

            // Insert non-temporary units
            for su in &non_temp_units {
                if all_ids.contains(&su.id) { continue; }
                repository::insert_song_unit(&conn, su).await.unwrap();
                all_ids.insert(su.id.clone());
                non_temp_ids.push(su.id.clone());
            }

            // (a) has_temporary_for_path returns true for paths with temp units
            let has_temp = repository::has_temporary_for_path(&conn, "/music/temp_song.mp3")
                .await
                .unwrap();
            prop_assert!(has_temp, "has_temporary_for_path should be true for temp path");

            // has_temporary_for_path returns false for non-existent path
            let has_none = repository::has_temporary_for_path(&conn, "/music/nonexistent.mp3")
                .await
                .unwrap();
            prop_assert!(!has_none, "has_temporary_for_path should be false for non-existent path");

            // (b) get_temporary_song_units returns exactly the temporary ones
            let temps = repository::get_temporary_song_units(&conn).await.unwrap();
            prop_assert_eq!(
                temps.len() as u64,
                temp_count,
                "get_temporary_song_units count mismatch"
            );
            for t in &temps {
                prop_assert!(t.is_temporary, "All returned units must be temporary");
            }

            // (c) delete_all_temporary removes all temporary, leaves non-temporary intact
            let deleted = repository::delete_all_temporary(&conn).await.unwrap();
            prop_assert_eq!(deleted, temp_count, "delete_all_temporary count mismatch");

            // Verify no temporary remain
            let temps_after = repository::get_temporary_song_units(&conn).await.unwrap();
            prop_assert!(temps_after.is_empty(), "No temporary units should remain after delete_all");

            // Verify non-temporary units still exist
            for id in &non_temp_ids {
                let su = repository::get_song_unit(&conn, id).await.unwrap();
                prop_assert!(su.is_some(), "Non-temporary unit {} should still exist", id);
            }

            Ok(())
        })?;
    }
}
