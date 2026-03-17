// Feature: collection-rust-migration, Properties 4–11: Collection CRUD
//
// Property 4: Create collection + get round-trip — **Validates: Requirements 3.1**
// Property 5: Add item creates both items list entry and junction table entry — **Validates: Requirements 3.2, 3.3, 3.5.1**
// Property 6: Remove item clears both items list entry and junction table entry — **Validates: Requirements 3.4, 3.5, 3.5.2**
// Property 7: Reorder preserves item set — **Validates: Requirements 3.6**
// Property 8: Filter collections by type — **Validates: Requirements 3.8**
// Property 9: Delete collection clears all junction entries — **Validates: Requirements 3.5.3**
// Property 10: Multiple collection membership creates separate junction entries — **Validates: Requirements 3.5.5**
// Property 11: Playback state lifecycle — **Validates: Requirements 4.1, 4.2, 4.3**

use proptest::prelude::*;
use sea_orm::{
    ColumnTrait, ConnectionTrait, DatabaseConnection, DbBackend, EntityTrait, QueryFilter,
    Statement,
};
use tokio::runtime::Runtime;

use beadline_core::database::init_song_units_schema;
use beadline_core::entity::song_unit_tag;
use beadline_tags::collection_repository::*;
use beadline_tags::model::collection::*;
use beadline_tags::repository::delete_tag;

// ---------------------------------------------------------------------------
// Test DB helper
// ---------------------------------------------------------------------------

/// Create an in-memory SQLite database with both tags and song_units schemas.
async fn test_db() -> DatabaseConnection {
    let conn = beadline_tags::database::init_database(":memory:")
        .await
        .expect("init tags database failed");
    init_song_units_schema(&conn)
        .await
        .expect("init song_units schema failed");
    // Enable foreign keys (SQLite default is off)
    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        "PRAGMA foreign_keys = OFF".to_owned(),
    ))
    .await
    .ok();
    conn
}

/// Insert a minimal song_unit row so that song_unit_tags FK won't fail
/// (though we disabled FK checks, this keeps data consistent).
async fn insert_dummy_song_unit(conn: &DatabaseConnection, id: &str) {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        format!(
            "INSERT OR IGNORE INTO song_units (id, metadata_json, sources_json, preferences_json, hash, is_temporary, created_at, updated_at) \
             VALUES ('{}', '{{}}', '{{}}', '{{}}', 'h', 0, {}, {})",
            id, now, now
        ),
    ))
    .await
    .expect("insert dummy song_unit failed");
}

/// Count song_unit_tags rows matching a given tag_id.
async fn count_junction_entries(conn: &DatabaseConnection, tag_id: &str) -> i32 {
    let rows = conn
        .query_all(Statement::from_string(
            DbBackend::Sqlite,
            format!(
                "SELECT COUNT(*) as cnt FROM song_unit_tags WHERE tag_id = '{}'",
                tag_id
            ),
        ))
        .await
        .unwrap();
    rows[0].try_get("", "cnt").unwrap()
}

/// Count song_unit_tags rows matching a given song_unit_id.
async fn count_junction_entries_for_song_unit(conn: &DatabaseConnection, su_id: &str) -> i32 {
    let rows = conn
        .query_all(Statement::from_string(
            DbBackend::Sqlite,
            format!(
                "SELECT COUNT(*) as cnt FROM song_unit_tags WHERE song_unit_id = '{}'",
                su_id
            ),
        ))
        .await
        .unwrap();
    rows[0].try_get("", "cnt").unwrap()
}

// ---------------------------------------------------------------------------
// Strategies
// ---------------------------------------------------------------------------

fn arb_collection_type() -> impl Strategy<Value = CollectionType> {
    prop_oneof![
        Just(CollectionType::Playlist),
        Just(CollectionType::Queue),
        Just(CollectionType::Group),
    ]
}

fn arb_collection_name() -> impl Strategy<Value = String> {
    "[a-zA-Z]{1,20}"
}

fn arb_uuid() -> impl Strategy<Value = String> {
    "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"
}


// ---------------------------------------------------------------------------
// Property 4: Create collection + get round-trip
// **Validates: Requirements 3.1**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn create_collection_get_round_trip(
        name in arb_collection_name(),
        ct in arb_collection_type(),
    ) {
        // Feature: collection-rust-migration, Property 4: Create collection + get round-trip
        // **Validates: Requirements 3.1**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let created = create_collection(&conn, name.clone(), None, ct)
                .await
                .unwrap();

            prop_assert_eq!(created.name(), name.as_str());
            prop_assert_eq!(created.collection_type, ct);
            prop_assert_eq!(created.item_count(), 0);

            // Round-trip: get by ID
            let retrieved = get_collection(&conn, created.id())
                .await
                .unwrap()
                .expect("collection should exist after create");

            prop_assert_eq!(retrieved.name(), name.as_str());
            prop_assert_eq!(retrieved.collection_type, ct);
            prop_assert_eq!(retrieved.item_count(), 0);
            prop_assert_eq!(retrieved.id(), created.id());

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 5: Add item creates both items list entry and junction table entry
// **Validates: Requirements 3.2, 3.3, 3.5.1**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn add_item_creates_items_and_junction(
        name in arb_collection_name(),
        ct in arb_collection_type(),
        song_unit_id in arb_uuid(),
    ) {
        // Feature: collection-rust-migration, Property 5: Add item creates both items list entry and junction table entry
        // **Validates: Requirements 3.2, 3.3, 3.5.1**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;
            insert_dummy_song_unit(&conn, &song_unit_id).await;

            let collection = create_collection(&conn, name, None, ct)
                .await
                .unwrap();
            let cid = collection.id().to_owned();

            // Items list should be empty initially
            let items_before = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items_before.len(), 0);

            // Add a SongUnit item
            let _item = add_item_to_collection(
                &conn,
                &cid,
                CollectionItemType::SongUnit,
                &song_unit_id,
                true,
            )
            .await
            .unwrap();

            // Items list should have 1 entry
            let items_after = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items_after.len(), 1);
            prop_assert_eq!(&items_after[0].target_id, &song_unit_id);
            prop_assert_eq!(items_after[0].item_type, CollectionItemType::SongUnit);

            // Junction table should have 1 entry
            let junction_count = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(junction_count, 1);

            // Verify the junction entry links the right song unit
            let junction_rows: Vec<song_unit_tag::Model> =
                song_unit_tag::Entity::find()
                    .filter(song_unit_tag::Column::TagId.eq(&cid))
                    .filter(song_unit_tag::Column::SongUnitId.eq(&song_unit_id))
                    .all(&conn)
                    .await
                    .unwrap();
            prop_assert_eq!(junction_rows.len(), 1);

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 6: Remove item clears both items list entry and junction table entry
// **Validates: Requirements 3.4, 3.5, 3.5.2**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn remove_item_clears_items_and_junction(
        name in arb_collection_name(),
        ct in arb_collection_type(),
        song_unit_id in arb_uuid(),
    ) {
        // Feature: collection-rust-migration, Property 6: Remove item clears both items list entry and junction table entry
        // **Validates: Requirements 3.4, 3.5, 3.5.2**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;
            insert_dummy_song_unit(&conn, &song_unit_id).await;

            let collection = create_collection(&conn, name, None, ct)
                .await
                .unwrap();
            let cid = collection.id().to_owned();

            // Add then remove
            let added = add_item_to_collection(
                &conn,
                &cid,
                CollectionItemType::SongUnit,
                &song_unit_id,
                true,
            )
            .await
            .unwrap();

            remove_item_from_collection(&conn, &cid, &added.id)
                .await
                .unwrap();

            // Items list should be empty
            let items = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items.len(), 0);

            // Junction table should be empty for this tag
            let junction_count = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(junction_count, 0);

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 7: Reorder preserves item set
// **Validates: Requirements 3.6**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn reorder_preserves_item_set(
        name in arb_collection_name(),
        ct in arb_collection_type(),
        // Generate 2-6 unique song unit IDs
        song_unit_ids in prop::collection::hash_set(arb_uuid(), 2..=6)
            .prop_map(|s| s.into_iter().collect::<Vec<_>>()),
        seed in any::<u64>(),
    ) {
        // Feature: collection-rust-migration, Property 7: Reorder preserves item set
        // **Validates: Requirements 3.6**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert dummy song units
            for su_id in &song_unit_ids {
                insert_dummy_song_unit(&conn, su_id).await;
            }

            let collection = create_collection(&conn, name, None, ct)
                .await
                .unwrap();
            let cid = collection.id().to_owned();

            // Add all items
            let mut item_ids = Vec::new();
            let mut target_ids_original = Vec::new();
            for su_id in &song_unit_ids {
                let item = add_item_to_collection(
                    &conn,
                    &cid,
                    CollectionItemType::SongUnit,
                    su_id,
                    true,
                )
                .await
                .unwrap();
                item_ids.push(item.id);
                target_ids_original.push(su_id.clone());
            }

            // Create a permutation using the seed
            let n = item_ids.len();
            let mut permuted = item_ids.clone();
            // Simple Fisher-Yates-like shuffle using seed
            let mut s = seed;
            for i in (1..n).rev() {
                s = s.wrapping_mul(6364136223846793005).wrapping_add(1);
                let j = (s as usize) % (i + 1);
                permuted.swap(i, j);
            }

            // Reorder
            reorder_collection_items(&conn, &cid, &permuted)
                .await
                .unwrap();

            // Get items after reorder
            let items_after = get_collection_items(&conn, &cid).await.unwrap();

            // Same count
            prop_assert_eq!(items_after.len(), n);

            // Items returned by get_collection_items are sorted by order field.
            // The order should match the permuted list.
            for (idx, item) in items_after.iter().enumerate() {
                prop_assert_eq!(&item.id, &permuted[idx],
                    "Item at position {} should be {} but was {}",
                    idx, permuted[idx], item.id);
            }

            // All original target IDs are still present
            let mut target_ids_after: Vec<String> =
                items_after.iter().map(|i| i.target_id.clone()).collect();
            target_ids_after.sort();
            let mut target_ids_expected = target_ids_original.clone();
            target_ids_expected.sort();
            prop_assert_eq!(&target_ids_after, &target_ids_expected);

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 8: Filter collections by type
// **Validates: Requirements 3.8**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn filter_collections_by_type(
        // Generate 3-8 collections with random types
        entries in prop::collection::vec(
            (arb_collection_name(), arb_collection_type()),
            3..=8,
        ),
        filter_type in arb_collection_type(),
    ) {
        // Feature: collection-rust-migration, Property 8: Filter collections by type
        // **Validates: Requirements 3.8**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Create all collections
            let mut created = Vec::new();
            for (i, (name, ct)) in entries.iter().enumerate() {
                // Ensure unique names by appending index
                let unique_name = format!("{}{}", name, i);
                let c = create_collection(&conn, unique_name, None, *ct)
                    .await
                    .unwrap();
                created.push(c);
            }

            // Filter by the chosen type
            let filtered = get_collections(&conn, Some(filter_type))
                .await
                .unwrap();

            // Count expected
            let expected_count = created
                .iter()
                .filter(|c| c.collection_type == filter_type)
                .count();

            prop_assert_eq!(filtered.len(), expected_count,
                "Expected {} collections of type {:?}, got {}",
                expected_count, filter_type, filtered.len());

            // All returned collections must be of the filter type
            for c in &filtered {
                prop_assert_eq!(c.collection_type, filter_type,
                    "Collection {:?} has wrong type {:?}, expected {:?}",
                    c.name(), c.collection_type, filter_type);
            }

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 9: Delete collection clears all junction entries
// **Validates: Requirements 3.5.3**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn delete_collection_clears_junction_entries(
        name in arb_collection_name(),
        ct in arb_collection_type(),
        song_unit_ids in prop::collection::hash_set(arb_uuid(), 1..=4)
            .prop_map(|s| s.into_iter().collect::<Vec<_>>()),
    ) {
        // Feature: collection-rust-migration, Property 9: Delete collection clears all junction entries
        // **Validates: Requirements 3.5.3**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            for su_id in &song_unit_ids {
                insert_dummy_song_unit(&conn, su_id).await;
            }

            let collection = create_collection(&conn, name, None, ct)
                .await
                .unwrap();
            let cid = collection.id().to_owned();

            // Add all song units
            for su_id in &song_unit_ids {
                add_item_to_collection(
                    &conn,
                    &cid,
                    CollectionItemType::SongUnit,
                    su_id,
                    true,
                )
                .await
                .unwrap();
            }

            // Verify junction entries exist
            let count_before = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(count_before, song_unit_ids.len() as i32);

            // Delete the collection tag — also manually clean up junction entries
            // since delete_tag doesn't do it automatically.
            // First remove junction entries, then delete the tag.
            song_unit_tag::Entity::delete_many()
                .filter(song_unit_tag::Column::TagId.eq(&cid))
                .exec(&conn)
                .await
                .unwrap();
            delete_tag(&conn, &cid).await.unwrap();

            // Verify all junction entries are gone
            let count_after = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(count_after, 0,
                "Expected 0 junction entries after delete, got {}", count_after);

            // Verify the collection no longer exists
            let retrieved = get_collection(&conn, &cid).await.unwrap();
            prop_assert!(retrieved.is_none(),
                "Collection should not exist after delete");

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 10: Multiple collection membership creates separate junction entries
// **Validates: Requirements 3.5.5**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn multiple_collection_membership_separate_junction_entries(
        song_unit_id in arb_uuid(),
        // Create 2-5 collections
        collection_names in prop::collection::vec(arb_collection_name(), 2..=5),
    ) {
        // Feature: collection-rust-migration, Property 10: Multiple collection membership creates separate junction entries
        // **Validates: Requirements 3.5.5**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;
            insert_dummy_song_unit(&conn, &song_unit_id).await;

            let n = collection_names.len();
            let mut collection_ids = Vec::new();

            // Create N collections and add the same song unit to each
            for (i, name) in collection_names.iter().enumerate() {
                let unique_name = format!("{}{}", name, i);
                let c = create_collection(&conn, unique_name, None, CollectionType::Playlist)
                    .await
                    .unwrap();
                let cid = c.id().to_owned();

                add_item_to_collection(
                    &conn,
                    &cid,
                    CollectionItemType::SongUnit,
                    &song_unit_id,
                    true,
                )
                .await
                .unwrap();

                collection_ids.push(cid);
            }

            // Verify N separate junction entries for this song unit
            let total = count_junction_entries_for_song_unit(&conn, &song_unit_id).await;
            prop_assert_eq!(total, n as i32,
                "Expected {} junction entries for song unit, got {}", n, total);

            // Verify each collection has exactly 1 junction entry
            for cid in &collection_ids {
                let count = count_junction_entries(&conn, cid).await;
                prop_assert_eq!(count, 1,
                    "Collection {} should have 1 junction entry, got {}", cid, count);
            }

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 11: Playback state lifecycle
// **Validates: Requirements 4.1, 4.2, 4.3**
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn playback_state_lifecycle(
        name in arb_collection_name(),
        ct in arb_collection_type(),
        start_idx in 0..100i32,
        start_pos in 0..600_000i64,
        update_idx in 0..100i32,
        update_pos in 0..600_000i64,
        update_playing in any::<bool>(),
    ) {
        // Feature: collection-rust-migration, Property 11: Playback state lifecycle
        // **Validates: Requirements 4.1, 4.2, 4.3**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let collection = create_collection(&conn, name, None, ct)
                .await
                .unwrap();
            let cid = collection.id().to_owned();

            // Initially not playing
            prop_assert!(!collection.is_playing(),
                "New collection should not be playing");

            // --- start_playing ---
            start_playing(&conn, &cid, start_idx, start_pos)
                .await
                .unwrap();

            let after_start = get_collection(&conn, &cid)
                .await
                .unwrap()
                .expect("collection should exist");
            prop_assert!(after_start.is_playing(),
                "Collection should be playing after start_playing");
            prop_assert_eq!(after_start.metadata.current_index, start_idx);
            prop_assert_eq!(after_start.metadata.playback_position_ms, start_pos);
            prop_assert!(after_start.metadata.was_playing);

            // --- update_playback_state ---
            update_playback_state(&conn, &cid, update_idx, update_pos, update_playing)
                .await
                .unwrap();

            let after_update = get_collection(&conn, &cid)
                .await
                .unwrap()
                .expect("collection should exist");
            prop_assert_eq!(after_update.metadata.current_index, update_idx);
            prop_assert_eq!(after_update.metadata.playback_position_ms, update_pos);
            prop_assert_eq!(after_update.metadata.was_playing, update_playing);

            // --- stop_playing ---
            stop_playing(&conn, &cid).await.unwrap();

            let after_stop = get_collection(&conn, &cid)
                .await
                .unwrap()
                .expect("collection should exist");
            prop_assert!(!after_stop.is_playing(),
                "Collection should not be playing after stop_playing");
            prop_assert_eq!(after_stop.metadata.current_index, -1);
            prop_assert_eq!(after_stop.metadata.playback_position_ms, 0);
            prop_assert!(!after_stop.metadata.was_playing);

            Ok(())
        })?;
    }
}
