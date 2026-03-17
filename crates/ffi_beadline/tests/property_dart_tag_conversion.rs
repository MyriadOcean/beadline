//! Property-based tests for DartTag ↔ Tag conversion functions.

use beadline_tags::model::tag::{Tag, TagType};
use ffi_beadline::api::tag_api::{from_dart_tag, to_dart_tag, DartTag};
use proptest::prelude::*;

// ── Generators ──────────────────────────────────────────────────────────

fn arb_tag_type() -> impl Strategy<Value = TagType> {
    prop_oneof![
        Just(TagType::BuiltIn),
        Just(TagType::User),
        Just(TagType::Automatic),
    ]
}

fn arb_optional_string() -> impl Strategy<Value = Option<String>> {
    prop_oneof![
        Just(None),
        "[a-z0-9_]{1,20}".prop_map(Some),
    ]
}

fn arb_alias_names() -> impl Strategy<Value = Vec<String>> {
    prop::collection::vec("[a-z0-9]{1,15}", 0..5)
}

fn arb_tag() -> impl Strategy<Value = Tag> {
    (
        "[a-f0-9\\-]{8,36}",   // id
        arb_optional_string(),  // key
        "[a-z0-9]{1,30}",      // value
        arb_tag_type(),         // tag_type
        arb_optional_string(),  // parent_id
        arb_alias_names(),      // alias_names
        any::<bool>(),          // include_children
        any::<bool>(),          // is_group
        any::<bool>(),          // is_locked
        any::<i32>(),           // display_order
        any::<bool>(),          // has_collection_metadata
    )
        .prop_map(
            |(id, key, value, tag_type, parent_id, alias_names, include_children, is_group, is_locked, display_order, has_collection_metadata)| {
                Tag {
                    id,
                    key,
                    value,
                    tag_type,
                    parent_id,
                    alias_names,
                    include_children,
                    is_group,
                    is_locked,
                    display_order,
                    has_collection_metadata,
                }
            },
        )
}

fn arb_tag_type_string() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("builtIn".to_string()),
        Just("user".to_string()),
        Just("automatic".to_string()),
    ]
}

fn arb_dart_tag() -> impl Strategy<Value = DartTag> {
    (
        "[a-f0-9\\-]{8,36}",   // id
        "[a-z0-9]{1,30}",      // name
        arb_optional_string(),  // key
        arb_tag_type_string(),  // tag_type
        arb_optional_string(),  // parent_id
        arb_alias_names(),      // alias_names
        any::<bool>(),          // include_children
        any::<bool>(),          // is_group
        any::<bool>(),          // is_locked
        any::<i32>(),           // display_order
        any::<bool>(),          // has_collection_metadata
    )
        .prop_map(
            |(id, name, key, tag_type, parent_id, alias_names, include_children, is_group, is_locked, display_order, has_collection_metadata)| {
                DartTag {
                    id,
                    name,
                    key,
                    tag_type,
                    parent_id,
                    alias_names,
                    include_children,
                    is_group,
                    is_locked,
                    display_order,
                    has_collection_metadata,
                }
            },
        )
}

// ── Helpers ─────────────────────────────────────────────────────────────

fn expected_tag_type_str(tt: &TagType) -> &'static str {
    match tt {
        TagType::BuiltIn => "builtIn",
        TagType::User => "user",
        TagType::Automatic => "automatic",
    }
}

// ── Property Tests ──────────────────────────────────────────────────────

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    // Feature: dart-rust-cleanup, Property 1: Rust Tag → DartTag field preservation
    // **Validates: Requirements 1.4, 1.5, 2.1, 2.2, 2.3, 2.6, 2.7, 2.8, 2.9, 2.12**
    #[test]
    fn tag_to_dart_tag_preserves_all_fields(tag in arb_tag()) {
        let dt = to_dart_tag(tag.clone());

        prop_assert_eq!(&dt.id, &tag.id, "id mismatch");
        prop_assert_eq!(&dt.name, &tag.value, "name/value mismatch");
        prop_assert_eq!(&dt.key, &tag.key, "key mismatch");
        prop_assert_eq!(dt.tag_type.as_str(), expected_tag_type_str(&tag.tag_type), "tag_type mismatch");
        prop_assert_eq!(&dt.parent_id, &tag.parent_id, "parent_id mismatch");
        prop_assert_eq!(&dt.alias_names, &tag.alias_names, "alias_names mismatch");
        prop_assert_eq!(dt.include_children, tag.include_children, "include_children mismatch");
        prop_assert_eq!(dt.is_group, tag.is_group, "is_group mismatch");
        prop_assert_eq!(dt.is_locked, tag.is_locked, "is_locked mismatch");
        prop_assert_eq!(dt.display_order, tag.display_order, "display_order mismatch");
        prop_assert_eq!(dt.has_collection_metadata, tag.has_collection_metadata, "has_collection_metadata mismatch");
    }

    // Feature: dart-rust-cleanup, Property 2: DartTag → Rust Tag round-trip for updates
    // **Validates: Requirements 2.4**
    #[test]
    fn dart_tag_round_trip_preserves_all_fields(dt in arb_dart_tag()) {
        let tag = from_dart_tag(DartTag {
            id: dt.id.clone(),
            name: dt.name.clone(),
            key: dt.key.clone(),
            tag_type: dt.tag_type.clone(),
            parent_id: dt.parent_id.clone(),
            alias_names: dt.alias_names.clone(),
            include_children: dt.include_children,
            is_group: dt.is_group,
            is_locked: dt.is_locked,
            display_order: dt.display_order,
            has_collection_metadata: dt.has_collection_metadata,
        });
        let round_tripped = to_dart_tag(tag);

        prop_assert_eq!(&round_tripped.id, &dt.id, "id mismatch after round-trip");
        prop_assert_eq!(&round_tripped.name, &dt.name, "name mismatch after round-trip");
        prop_assert_eq!(&round_tripped.key, &dt.key, "key mismatch after round-trip");
        prop_assert_eq!(&round_tripped.tag_type, &dt.tag_type, "tag_type mismatch after round-trip");
        prop_assert_eq!(&round_tripped.parent_id, &dt.parent_id, "parent_id mismatch after round-trip");
        prop_assert_eq!(&round_tripped.alias_names, &dt.alias_names, "alias_names mismatch after round-trip");
        prop_assert_eq!(round_tripped.include_children, dt.include_children, "include_children mismatch after round-trip");
        prop_assert_eq!(round_tripped.is_group, dt.is_group, "is_group mismatch after round-trip");
        prop_assert_eq!(round_tripped.is_locked, dt.is_locked, "is_locked mismatch after round-trip");
        prop_assert_eq!(round_tripped.display_order, dt.display_order, "display_order mismatch after round-trip");
        prop_assert_eq!(round_tripped.has_collection_metadata, dt.has_collection_metadata, "has_collection_metadata mismatch after round-trip");
    }
}
