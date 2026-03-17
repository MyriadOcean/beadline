use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use super::tag::Tag;

// ── Enums ──────────────────────────────────────────────────────────────

/// Classification of a collection's purpose.
///
/// All three variants share the same underlying data structure. The type
/// serves as a UI visibility hint:
/// - `Playlist` appears in the Playlists panel
/// - `Queue` appears in Queue Management
/// - `Group` is only visible through its parent
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CollectionType {
    Playlist,
    Queue,
    Group,
}

/// Distinguishes direct Song Unit references from collection references.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CollectionItemType {
    SongUnit,
    CollectionReference,
}

// ── Helper defaults for serde ──────────────────────────────────────────

fn default_true() -> bool {
    true
}

fn default_neg_one() -> i32 {
    -1
}

// ── CollectionItem ─────────────────────────────────────────────────────

/// A single entry in a collection's items list.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CollectionItem {
    pub id: String,
    #[serde(rename = "type")]
    pub item_type: CollectionItemType,
    #[serde(rename = "targetId")]
    pub target_id: String,
    pub order: i32,
    #[serde(default = "default_true", rename = "inheritLock")]
    pub inherit_lock: bool,
}

// ── CollectionMetadata ─────────────────────────────────────────────────

/// Metadata associated with a collection, stored as JSON in the
/// `playlist_metadata_json` column.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CollectionMetadata {
    #[serde(default)]
    pub is_locked: bool,
    #[serde(default)]
    pub display_order: i32,
    #[serde(default)]
    pub items: Vec<CollectionItem>,
    #[serde(default = "default_neg_one", rename = "currentIndex")]
    pub current_index: i32,
    #[serde(default, rename = "playbackPositionMs")]
    pub playback_position_ms: i64,
    #[serde(default, rename = "wasPlaying")]
    pub was_playing: bool,
    #[serde(default, rename = "removeAfterPlay")]
    pub remove_after_play: bool,
    #[serde(skip_serializing_if = "Option::is_none", rename = "temporarySongUnits")]
    pub temporary_song_units: Option<HashMap<String, serde_json::Value>>,
    #[serde(default, rename = "isQueue")]
    pub is_queue: bool,
    #[serde(rename = "createdAt")]
    pub created_at: String,
    #[serde(rename = "updatedAt")]
    pub updated_at: String,
}

/// Returns the current UTC time as an ISO 8601 string.
///
/// Uses a simple approach without the `chrono` crate: delegates to
/// `std::time::SystemTime` and formats manually.
pub fn now_iso8601() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};

    let dur = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    let secs = dur.as_secs();

    // Break epoch seconds into date/time components (UTC).
    let days = secs / 86400;
    let time_of_day = secs % 86400;
    let hours = time_of_day / 3600;
    let minutes = (time_of_day % 3600) / 60;
    let seconds = time_of_day % 60;

    // Convert days since epoch to y-m-d using a civil calendar algorithm.
    // Algorithm from Howard Hinnant (public domain).
    let z = days as i64 + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u64; // day of era [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };

    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}.000Z",
        y, m, d, hours, minutes, seconds
    )
}

impl CollectionMetadata {
    /// Creates an empty metadata instance for a new collection.
    pub fn empty(collection_type: CollectionType) -> Self {
        let now = now_iso8601();
        Self {
            is_locked: false,
            display_order: 0,
            items: vec![],
            current_index: -1,
            playback_position_ms: 0,
            was_playing: false,
            remove_after_play: false,
            temporary_song_units: None,
            is_queue: matches!(collection_type, CollectionType::Queue),
            created_at: now.clone(),
            updated_at: now,
        }
    }

    /// Returns `true` if the collection is currently playing (has a valid index).
    pub fn is_playing(&self) -> bool {
        self.current_index >= 0
    }

    /// Derives the `CollectionType` from the `is_group` DB flag and the
    /// `is_queue` metadata field.
    pub fn collection_type(&self, is_group: bool) -> CollectionType {
        if is_group {
            CollectionType::Group
        } else if self.is_queue {
            CollectionType::Queue
        } else {
            CollectionType::Playlist
        }
    }
}

// ── Collection ─────────────────────────────────────────────────────────

/// A collection (playlist, queue, or group) — a `Tag` composed with
/// `CollectionMetadata`.
#[derive(Debug, Clone, PartialEq)]
pub struct Collection {
    pub tag: Tag,
    pub metadata: CollectionMetadata,
    pub collection_type: CollectionType,
}

impl Collection {
    /// The underlying tag ID.
    pub fn id(&self) -> &str {
        &self.tag.id
    }

    /// The collection's display name (the tag value).
    pub fn name(&self) -> &str {
        &self.tag.value
    }

    /// Whether this collection is an active queue (currently playing).
    pub fn is_active_queue(&self) -> bool {
        self.metadata.is_playing()
    }

    /// Whether the collection is currently playing.
    pub fn is_playing(&self) -> bool {
        self.metadata.is_playing()
    }

    /// Number of items in the collection.
    pub fn item_count(&self) -> usize {
        self.metadata.items.len()
    }

    /// Whether the collection is locked.
    pub fn is_locked(&self) -> bool {
        self.metadata.is_locked
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::tag::{Tag, TagType};
    use proptest::prelude::*;

    // ── Generators ─────────────────────────────────────────────────────

    fn arb_collection_type() -> impl Strategy<Value = CollectionType> {
        prop_oneof![
            Just(CollectionType::Playlist),
            Just(CollectionType::Queue),
            Just(CollectionType::Group),
        ]
    }

    fn arb_collection_item_type() -> impl Strategy<Value = CollectionItemType> {
        prop_oneof![
            Just(CollectionItemType::SongUnit),
            Just(CollectionItemType::CollectionReference),
        ]
    }

    fn arb_collection_item() -> impl Strategy<Value = CollectionItem> {
        (
            "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}", // id (UUID-like)
            arb_collection_item_type(),
            "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}", // target_id
            0..1000i32,       // order
            any::<bool>(),    // inherit_lock
        )
            .prop_map(|(id, item_type, target_id, order, inherit_lock)| CollectionItem {
                id,
                item_type,
                target_id,
                order,
                inherit_lock,
            })
    }

    fn arb_collection_name() -> impl Strategy<Value = String> {
        "[a-zA-Z]{1,20}"
    }

    fn arb_iso_timestamp() -> impl Strategy<Value = String> {
        (2000..2030i32, 1..13u32, 1..29u32, 0..24u32, 0..60u32, 0..60u32).prop_map(
            |(y, mo, d, h, mi, s)| {
                format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}.000Z", y, mo, d, h, mi, s)
            },
        )
    }

    fn arb_collection_metadata() -> impl Strategy<Value = CollectionMetadata> {
        (
            any::<bool>(),                          // is_locked
            0..100i32,                              // display_order
            prop::collection::vec(arb_collection_item(), 0..10), // items
            -1..50i32,                              // current_index
            0..600_000i64,                          // playback_position_ms
            any::<bool>(),                          // was_playing
            any::<bool>(),                          // remove_after_play
            any::<bool>(),                          // is_queue
            arb_iso_timestamp(),                    // created_at
            arb_iso_timestamp(),                    // updated_at
        )
            .prop_map(
                |(
                    is_locked,
                    display_order,
                    items,
                    current_index,
                    playback_position_ms,
                    was_playing,
                    remove_after_play,
                    is_queue,
                    created_at,
                    updated_at,
                )| {
                    CollectionMetadata {
                        is_locked,
                        display_order,
                        items,
                        current_index,
                        playback_position_ms,
                        was_playing,
                        remove_after_play,
                        temporary_song_units: None,
                        is_queue,
                        created_at,
                        updated_at,
                    }
                },
            )
    }

    fn arb_tag() -> impl Strategy<Value = Tag> {
        (
            "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}",
            arb_collection_name(),
        )
            .prop_map(|(id, value)| Tag {
                id,
                key: Some("playlist".to_string()),
                value,
                tag_type: TagType::Automatic,
                parent_id: None,
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                has_collection_metadata: true,
            })
    }

    fn arb_collection() -> impl Strategy<Value = Collection> {
        (arb_tag(), arb_collection_metadata(), arb_collection_type()).prop_map(
            |(tag, metadata, collection_type)| Collection {
                tag,
                metadata,
                collection_type,
            },
        )
    }

    // ── Property Tests ─────────────────────────────────────────────────

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]

        // Feature: collection-rust-migration, Property 1: CollectionType round-trip
        // **Validates: Requirements 1.7, 1.8**
        //
        // For any CollectionType, mapping to DB fields (is_group, is_queue)
        // and deriving back must produce the original type.
        #[test]
        fn collection_type_round_trip(ct in arb_collection_type()) {
            // Map CollectionType → DB fields
            let (is_group, is_queue) = match ct {
                CollectionType::Group    => (true,  false),
                CollectionType::Queue    => (false, true),
                CollectionType::Playlist => (false, false),
            };

            // Reconstruct: create a metadata with the is_queue field, then derive type
            let metadata = CollectionMetadata {
                is_queue,
                // remaining fields don't matter for type derivation
                is_locked: false,
                display_order: 0,
                items: vec![],
                current_index: -1,
                playback_position_ms: 0,
                was_playing: false,
                remove_after_play: false,
                temporary_song_units: None,
                created_at: String::new(),
                updated_at: String::new(),
            };

            let derived = metadata.collection_type(is_group);
            prop_assert_eq!(derived, ct,
                "CollectionType round-trip failed: {:?} → (is_group={}, is_queue={}) → {:?}",
                ct, is_group, is_queue, derived);
        }

        // Feature: collection-rust-migration, Property 2: Convenience method correctness
        // **Validates: Requirements 1.6**
        //
        // For any valid Collection, is_active_queue() and is_playing() return true
        // iff current_index >= 0, and item_count() equals items.len().
        #[test]
        fn convenience_method_correctness(collection in arb_collection()) {
            let expected_playing = collection.metadata.current_index >= 0;

            prop_assert_eq!(collection.is_active_queue(), expected_playing,
                "is_active_queue() should be {} for current_index={}",
                expected_playing, collection.metadata.current_index);

            prop_assert_eq!(collection.is_playing(), expected_playing,
                "is_playing() should be {} for current_index={}",
                expected_playing, collection.metadata.current_index);

            prop_assert_eq!(collection.item_count(), collection.metadata.items.len(),
                "item_count() should equal items.len()");
        }

        // Feature: collection-rust-migration, Property 3: CollectionMetadata JSON round-trip
        // **Validates: Requirements 2.3, 2.4**
        //
        // For any valid CollectionMetadata, serializing to JSON then deserializing
        // back produces an equivalent instance.
        #[test]
        fn collection_metadata_json_round_trip(metadata in arb_collection_metadata()) {
            let json = serde_json::to_string(&metadata)
                .expect("serialization should not fail");
            let deserialized: CollectionMetadata = serde_json::from_str(&json)
                .expect("deserialization should not fail");

            prop_assert_eq!(&deserialized, &metadata,
                "JSON round-trip failed.\nOriginal:      {:?}\nDeserialized:  {:?}\nJSON:          {}",
                metadata, deserialized, json);
        }
    }
}
