// Feature: collection-rust-migration, Properties 12–13: Content Resolution
//
// Property 12: Content resolution returns all reachable Song Units — **Validates: Requirements 5.1, 5.2, 5.6**
// Property 13: Circular reference detection — **Validates: Requirements 5.5**

use proptest::prelude::*;
use sea_orm::{ConnectionTrait, DatabaseConnection, DbBackend, Statement};
use tokio::runtime::Runtime;

use beadline_core::database::init_song_units_schema;
use beadline_tags::collection_repository::*;
use beadline_tags::model::collection::*;

// ---------------------------------------------------------------------------
// Test DB helper (same pattern as property_collection_crud.rs)
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

// ---------------------------------------------------------------------------
// Strategies
// ---------------------------------------------------------------------------

fn arb_collection_name() -> impl Strategy<Value = String> {
    "[a-zA-Z]{1,20}"
}

fn arb_uuid() -> impl Strategy<Value = String> {
    "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"
}


// ---------------------------------------------------------------------------
// Property 12: Content resolution returns all reachable Song Units
// **Validates: Requirements 5.1, 5.2, 5.6**
//
// For any tree-structured collection graph (no circular references),
// `resolve_content` SHALL return the target IDs of every SongUnit item
// reachable from the root collection, in the order they appear in each
// collection's items list (depth-first).
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn content_resolution_returns_all_reachable_song_units(
        // Root collection song units (1-4)
        root_su_ids in prop::collection::vec(arb_uuid(), 1..=4),
        // Child collection song units (1-4)
        child_su_ids in prop::collection::vec(arb_uuid(), 1..=4),
        // Grandchild collection song units (0-3)
        grandchild_su_ids in prop::collection::vec(arb_uuid(), 0..=3),
        // Where to insert the child reference in root's items (before or after root SUs)
        child_ref_at_start in any::<bool>(),
        // Whether to include a grandchild collection
        include_grandchild in any::<bool>(),
    ) {
        // Feature: collection-rust-migration, Property 12: Content resolution returns all reachable Song Units
        // **Validates: Requirements 5.1, 5.2, 5.6**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Insert all dummy song units
            for id in root_su_ids.iter().chain(child_su_ids.iter()).chain(grandchild_su_ids.iter()) {
                insert_dummy_song_unit(&conn, id).await;
            }

            // Create collections: root, child, and optionally grandchild
            let root = create_collection(&conn, "root".into(), None, CollectionType::Playlist)
                .await.unwrap();
            let child = create_collection(&conn, "child".into(), None, CollectionType::Playlist)
                .await.unwrap();

            let root_id = root.id().to_owned();
            let child_id = child.id().to_owned();

            // Add song units to child collection
            for su_id in &child_su_ids {
                add_item_to_collection(&conn, &child_id, CollectionItemType::SongUnit, su_id, true)
                    .await.unwrap();
            }

            // Optionally create grandchild and link it to child
            let _grandchild_id = if include_grandchild && !grandchild_su_ids.is_empty() {
                let gc = create_collection(&conn, "grandchild".into(), None, CollectionType::Playlist)
                    .await.unwrap();
                let gc_id = gc.id().to_owned();
                for su_id in &grandchild_su_ids {
                    add_item_to_collection(&conn, &gc_id, CollectionItemType::SongUnit, su_id, true)
                        .await.unwrap();
                }
                // Add grandchild reference to child
                add_item_to_collection(&conn, &child_id, CollectionItemType::CollectionReference, &gc_id, true)
                    .await.unwrap();
                Some(gc_id)
            } else {
                None
            };

            // Build root collection: either [child_ref, root_sus...] or [root_sus..., child_ref]
            if child_ref_at_start {
                add_item_to_collection(&conn, &root_id, CollectionItemType::CollectionReference, &child_id, true)
                    .await.unwrap();
                for su_id in &root_su_ids {
                    add_item_to_collection(&conn, &root_id, CollectionItemType::SongUnit, su_id, true)
                        .await.unwrap();
                }
            } else {
                for su_id in &root_su_ids {
                    add_item_to_collection(&conn, &root_id, CollectionItemType::SongUnit, su_id, true)
                        .await.unwrap();
                }
                add_item_to_collection(&conn, &root_id, CollectionItemType::CollectionReference, &child_id, true)
                    .await.unwrap();
            }

            // Resolve content
            let resolved = resolve_content(&conn, &root_id, 10).await.unwrap();

            // Build expected order (depth-first)
            let mut expected = Vec::new();
            if child_ref_at_start {
                // child ref expanded first
                expected.extend(child_su_ids.iter().cloned());
                if include_grandchild && !grandchild_su_ids.is_empty() {
                    expected.extend(grandchild_su_ids.iter().cloned());
                }
                expected.extend(root_su_ids.iter().cloned());
            } else {
                expected.extend(root_su_ids.iter().cloned());
                // child ref expanded after root SUs
                expected.extend(child_su_ids.iter().cloned());
                if include_grandchild && !grandchild_su_ids.is_empty() {
                    expected.extend(grandchild_su_ids.iter().cloned());
                }
            }

            prop_assert_eq!(
                &resolved, &expected,
                "Resolved content should match expected depth-first order.\n\
                 child_ref_at_start={}, include_grandchild={}\n\
                 resolved={:?}\n\
                 expected={:?}",
                child_ref_at_start, include_grandchild, resolved, expected
            );

            // Also verify count matches total reachable SUs
            let total_expected = root_su_ids.len()
                + child_su_ids.len()
                + if include_grandchild { grandchild_su_ids.len() } else { 0 };
            prop_assert_eq!(resolved.len(), total_expected,
                "Resolved count should equal total reachable song units");

            Ok(())
        })?;
    }
}

// ---------------------------------------------------------------------------
// Property 13: Circular reference detection
// **Validates: Requirements 5.5**
//
// - would_create_circular_reference(id, id) SHALL return true (self-reference)
// - For any graph where adding A → B would create a cycle, it SHALL return true
// - For any acyclic graph, it SHALL return false
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn circular_reference_detection(
        name_a in arb_collection_name(),
        name_b in arb_collection_name(),
        name_c in arb_collection_name(),
    ) {
        // Feature: collection-rust-migration, Property 13: Circular reference detection
        // **Validates: Requirements 5.5**
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let conn = test_db().await;

            // Create three collections A, B, C
            let a = create_collection(&conn, format!("{}A", name_a), None, CollectionType::Playlist)
                .await.unwrap();
            let b = create_collection(&conn, format!("{}B", name_b), None, CollectionType::Playlist)
                .await.unwrap();
            let c = create_collection(&conn, format!("{}C", name_c), None, CollectionType::Playlist)
                .await.unwrap();

            let a_id = a.id().to_owned();
            let b_id = b.id().to_owned();
            let c_id = c.id().to_owned();

            // --- Self-reference: always circular ---
            let self_ref = would_create_circular_reference(&conn, &a_id, &a_id).await.unwrap();
            prop_assert!(self_ref, "Self-reference should always be detected as circular");

            // --- Build chain: A → B → C ---
            add_item_to_collection(&conn, &a_id, CollectionItemType::CollectionReference, &b_id, true)
                .await.unwrap();
            add_item_to_collection(&conn, &b_id, CollectionItemType::CollectionReference, &c_id, true)
                .await.unwrap();

            // C → A would create cycle: A → B → C → A
            let c_to_a = would_create_circular_reference(&conn, &c_id, &a_id).await.unwrap();
            prop_assert!(c_to_a,
                "C → A should be circular (creates A → B → C → A cycle)");

            // A → C should NOT be circular (A already reaches C via B, but C doesn't reference A)
            let a_to_c = would_create_circular_reference(&conn, &a_id, &c_id).await.unwrap();
            prop_assert!(!a_to_c,
                "A → C should not be circular (C has no references back to A)");

            // B → A would create cycle: A → B → A
            let b_to_a = would_create_circular_reference(&conn, &b_id, &a_id).await.unwrap();
            prop_assert!(b_to_a,
                "B → A should be circular (creates A → B → A cycle)");

            // C → B would create cycle: B → C → B
            let c_to_b = would_create_circular_reference(&conn, &c_id, &b_id).await.unwrap();
            prop_assert!(c_to_b,
                "C → B should be circular (creates B → C → B cycle)");

            Ok(())
        })?;
    }
}
