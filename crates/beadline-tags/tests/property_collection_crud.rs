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

async fn test_db() -> DatabaseConnection {
    let conn = beadline_tags::database::init_database(":memory:")
        .await
        .expect("init tags database failed");
    init_song_units_schema(&conn)
        .await
        .expect("init song_units schema failed");
    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        "PRAGMA foreign_keys = OFF".to_owned(),
    ))
    .await
    .ok();
    conn
}

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
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let created = create_collection(&conn, name.clone(), None, ct)
                .await
                .unwrap();

            prop_assert_eq!(&created.value, &name);
            prop_assert_eq!(created.collection_type(), Some(ct));
            prop_assert_eq!(created.item_count(), 0);

            let retrieved = get_collection(&conn, &created.id)
                .await
                .unwrap()
                .expect("collection should exist after create");

            prop_assert_eq!(&retrieved.value, &name);
            prop_assert_eq!(retrieved.collection_type(), Some(ct));
            prop_assert_eq!(retrieved.item_count(), 0);
            prop_assert_eq!(&retrieved.id, &created.id);

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
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;
            insert_dummy_song_unit(&conn, &song_unit_id).await;

            let tag = create_collection(&conn, name, None, ct)
                .await
                .unwrap();
            let cid = tag.id.clone();

            let items_before = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items_before.len(), 0);

            let _item = add_item_to_collection(
                &conn, &cid, CollectionItemType::SongUnit, &song_unit_id, true,
            ).await.unwrap();

            let items_after = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items_after.len(), 1);
            prop_assert_eq!(&items_after[0].target_id, &song_unit_id);
            prop_assert_eq!(items_after[0].item_type, CollectionItemType::SongUnit);

            let junction_count = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(junction_count, 1);

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
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;
            insert_dummy_song_unit(&conn, &song_unit_id).await;

            let tag = create_collection(&conn, name, None, ct).await.unwrap();
            let cid = tag.id.clone();

            let added = add_item_to_collection(
                &conn, &cid, CollectionItemType::SongUnit, &song_unit_id, true,
            ).await.unwrap();

            remove_item_from_collection(&conn, &cid, &added.id).await.unwrap();

            let items = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items.len(), 0);

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
        song_unit_ids in prop::collection::hash_set(arb_uuid(), 2..=6)
            .prop_map(|s| s.into_iter().collect::<Vec<_>>()),
        seed in any::<u64>(),
    ) {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            for su_id in &song_unit_ids {
                insert_dummy_song_unit(&conn, su_id).await;
            }

            let tag = create_collection(&conn, name, None, ct).await.unwrap();
            let cid = tag.id.clone();

            let mut item_ids = Vec::new();
            let mut target_ids_original = Vec::new();
            for su_id in &song_unit_ids {
                let item = add_item_to_collection(
                    &conn, &cid, CollectionItemType::SongUnit, su_id, true,
                ).await.unwrap();
                item_ids.push(item.id);
                target_ids_original.push(su_id.clone());
            }

            let n = item_ids.len();
            let mut permuted = item_ids.clone();
            let mut s = seed;
            for i in (1..n).rev() {
                s = s.wrapping_mul(6364136223846793005).wrapping_add(1);
                let j = (s as usize) % (i + 1);
                permuted.swap(i, j);
            }

            reorder_collection_items(&conn, &cid, &permuted).await.unwrap();

            let items_after = get_collection_items(&conn, &cid).await.unwrap();
            prop_assert_eq!(items_after.len(), n);

            for (idx, item) in items_after.iter().enumerate() {
                prop_assert_eq!(&item.id, &permuted[idx]);
            }

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
        entries in prop::collection::vec(
            (arb_collection_name(), arb_collection_type()),
            3..=8,
        ),
        filter_type in arb_collection_type(),
    ) {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let mut created = Vec::new();
            for (i, (name, ct)) in entries.iter().enumerate() {
                let unique_name = format!("{}{}", name, i);
                let tag = create_collection(&conn, unique_name, None, *ct).await.unwrap();
                created.push((*ct, tag));
            }

            let filtered = get_collections(&conn, Some(filter_type)).await.unwrap();

            let expected_count = created.iter().filter(|(ct, _)| *ct == filter_type).count();

            prop_assert_eq!(filtered.len(), expected_count,
                "Expected {} collections of type {:?}, got {}",
                expected_count, filter_type, filtered.len());

            for tag in &filtered {
                prop_assert_eq!(tag.collection_type(), Some(filter_type),
                    "Tag {:?} has wrong type {:?}, expected {:?}",
                    tag.value, tag.collection_type(), filter_type);
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
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            for su_id in &song_unit_ids {
                insert_dummy_song_unit(&conn, su_id).await;
            }

            let tag = create_collection(&conn, name, None, ct).await.unwrap();
            let cid = tag.id.clone();

            for su_id in &song_unit_ids {
                add_item_to_collection(
                    &conn, &cid, CollectionItemType::SongUnit, su_id, true,
                ).await.unwrap();
            }

            let count_before = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(count_before, song_unit_ids.len() as i32);

            song_unit_tag::Entity::delete_many()
                .filter(song_unit_tag::Column::TagId.eq(&cid))
                .exec(&conn)
                .await
                .unwrap();
            delete_tag(&conn, &cid).await.unwrap();

            let count_after = count_junction_entries(&conn, &cid).await;
            prop_assert_eq!(count_after, 0);

            let retrieved = get_collection(&conn, &cid).await.unwrap();
            prop_assert!(retrieved.is_none());

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
        collection_names in prop::collection::vec(arb_collection_name(), 2..=5),
    ) {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;
            insert_dummy_song_unit(&conn, &song_unit_id).await;

            let n = collection_names.len();
            let mut collection_ids = Vec::new();

            for (i, name) in collection_names.iter().enumerate() {
                let unique_name = format!("{}{}", name, i);
                let tag = create_collection(&conn, unique_name, None, CollectionType::Playlist)
                    .await.unwrap();
                let cid = tag.id.clone();

                add_item_to_collection(
                    &conn, &cid, CollectionItemType::SongUnit, &song_unit_id, true,
                ).await.unwrap();

                collection_ids.push(cid);
            }

            let total = count_junction_entries_for_song_unit(&conn, &song_unit_id).await;
            prop_assert_eq!(total, n as i32);

            for cid in &collection_ids {
                let count = count_junction_entries(&conn, cid).await;
                prop_assert_eq!(count, 1);
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
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            let tag = create_collection(&conn, name, None, ct).await.unwrap();
            let cid = tag.id.clone();

            prop_assert!(!tag.is_playing(), "New collection should not be playing");

            // --- start_playing ---
            start_playing(&conn, &cid, start_idx, start_pos).await.unwrap();

            let after_start = get_collection(&conn, &cid).await.unwrap().unwrap();
            let m = after_start.collection_metadata.as_ref().unwrap();
            prop_assert!(after_start.is_playing());
            prop_assert_eq!(m.current_index, start_idx);
            prop_assert_eq!(m.playback_position_ms, start_pos);
            prop_assert!(m.was_playing);

            // --- update_playback_state ---
            update_playback_state(&conn, &cid, update_idx, update_pos, update_playing)
                .await.unwrap();

            let after_update = get_collection(&conn, &cid).await.unwrap().unwrap();
            let m = after_update.collection_metadata.as_ref().unwrap();
            prop_assert_eq!(m.current_index, update_idx);
            prop_assert_eq!(m.playback_position_ms, update_pos);
            prop_assert_eq!(m.was_playing, update_playing);

            // --- stop_playing ---
            stop_playing(&conn, &cid).await.unwrap();

            let after_stop = get_collection(&conn, &cid).await.unwrap().unwrap();
            let m = after_stop.collection_metadata.as_ref().unwrap();
            prop_assert!(!after_stop.is_playing());
            prop_assert_eq!(m.current_index, -1);
            prop_assert_eq!(m.playback_position_ms, 0);
            prop_assert!(!m.was_playing);

            Ok(())
        })?;
    }
}
