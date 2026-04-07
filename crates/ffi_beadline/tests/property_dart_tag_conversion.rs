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
        "[a-f0-9\\-]{8,36}",
        arb_optional_string(),
        "[a-z0-9]{1,30}",
        arb_tag_type(),
        arb_optional_string(),
        arb_alias_names(),
        any::<bool>(),
        any::<bool>(),
        any::<bool>(),
        any::<i32>(),
    )
        .prop_map(
            |(id, key, value, tag_type, parent_id, alias_names, include_children, is_group, is_locked, display_order)| {
                Tag {
                    id, key, value, tag_type, parent_id, alias_names,
                    include_children, is_group, is_locked, display_order,
                    collection_metadata: None,
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
        "[a-f0-9\\-]{8,36}",
        "[a-z0-9]{1,30}",
        arb_optional_string(),
        arb_tag_type_string(),
        arb_optional_string(),
        arb_alias_names(),
        any::<bool>(),
        any::<bool>(),
        any::<bool>(),
        any::<i32>(),
    )
        .prop_map(
            |(id, name, key, tag_type, parent_id, alias_names, include_children, is_group, is_locked, display_order)| {
                DartTag {
                    id, name, key, tag_type, parent_id, alias_names,
                    include_children, is_group, is_locked, display_order,
                    has_collection_metadata: false,
                }
            },
        )
}

fn expected_tag_type_str(tt: &TagType) -> &'static str {
    match tt {
        TagType::BuiltIn => "builtIn",
        TagType::User => "user",
        TagType::Automatic => "automatic",
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn tag_to_dart_tag_preserves_all_fields(tag in arb_tag()) {
        let dt = to_dart_tag(tag.clone());
        prop_assert_eq!(&dt.id, &tag.id);
        prop_assert_eq!(&dt.name, &tag.value);
        prop_assert_eq!(&dt.key, &tag.key);
        prop_assert_eq!(dt.tag_type.as_str(), expected_tag_type_str(&tag.tag_type));
        prop_assert_eq!(&dt.parent_id, &tag.parent_id);
        prop_assert_eq!(&dt.alias_names, &tag.alias_names);
        prop_assert_eq!(dt.include_children, tag.include_children);
        prop_assert_eq!(dt.is_group, tag.is_group);
        prop_assert_eq!(dt.is_locked, tag.is_locked);
        prop_assert_eq!(dt.display_order, tag.display_order);
        prop_assert_eq!(dt.has_collection_metadata, tag.collection_metadata.is_some());
    }

    #[test]
    fn dart_tag_round_trip_preserves_all_fields(dt in arb_dart_tag()) {
        let tag = from_dart_tag(DartTag {
            id: dt.id.clone(), name: dt.name.clone(), key: dt.key.clone(),
            tag_type: dt.tag_type.clone(), parent_id: dt.parent_id.clone(),
            alias_names: dt.alias_names.clone(), include_children: dt.include_children,
            is_group: dt.is_group, is_locked: dt.is_locked,
            display_order: dt.display_order,
            has_collection_metadata: dt.has_collection_metadata,
        });
        let round_tripped = to_dart_tag(tag);
        prop_assert_eq!(&round_tripped.id, &dt.id);
        prop_assert_eq!(&round_tripped.name, &dt.name);
        prop_assert_eq!(&round_tripped.key, &dt.key);
        prop_assert_eq!(&round_tripped.tag_type, &dt.tag_type);
        prop_assert_eq!(&round_tripped.parent_id, &dt.parent_id);
        prop_assert_eq!(&round_tripped.alias_names, &dt.alias_names);
        prop_assert_eq!(round_tripped.include_children, dt.include_children);
        prop_assert_eq!(round_tripped.is_group, dt.is_group);
        prop_assert_eq!(round_tripped.is_locked, dt.is_locked);
        prop_assert_eq!(round_tripped.display_order, dt.display_order);
        // from_dart_tag sets collection_metadata to None, so round-trip always false
        prop_assert_eq!(round_tripped.has_collection_metadata, false);
    }
}
