/// Built-in named tag keys that are always present and cannot be deleted.
pub const BUILT_IN_KEYS: &[&str] = &["name", "artist", "album", "year", "genre", "duration"];

/// Classification of a tag's origin.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TagType {
    /// System-defined tag key (e.g. name, artist, album).
    BuiltIn,
    /// User-created tag.
    User,
    /// Automatically generated tag (e.g. user:xx, playlist:xx).
    Automatic,
}

/// A tag attached to a Song Unit.
///
/// - Named tag: `key` is `Some` (e.g. key="artist", value="luotianyi")
/// - Nameless tag: `key` is `None` (e.g. value="luotianyi")
///
/// A tag with `collection_metadata` set is a collection (playlist/queue/group).
/// This unifies the old separate `Collection` struct into `Tag` itself.
#[derive(Debug, Clone, PartialEq)]
pub struct Tag {
    pub id: String,
    pub key: Option<String>,
    pub value: String,
    pub tag_type: TagType,
    pub parent_id: Option<String>,
    pub alias_names: Vec<String>,
    pub include_children: bool,
    // Collection-awareness fields (from DB entity)
    pub is_group: bool,
    pub is_locked: bool,
    pub display_order: i32,
    /// Collection metadata — `Some` if this tag is a collection (playlist/queue/group).
    pub collection_metadata: Option<super::collection::CollectionMetadata>,
}

impl Tag {
    /// Returns `true` if this is a named tag (has a non-empty key).
    pub fn is_named(&self) -> bool {
        self.key.as_ref().map_or(false, |k| !k.is_empty())
    }

    /// Returns `true` if this is a nameless tag (no key or empty key).
    pub fn is_nameless(&self) -> bool {
        !self.is_named()
    }

    /// Whether this tag is an active queue (currently playing).
    pub fn is_active_queue(&self) -> bool {
        self.collection_metadata
            .as_ref()
            .map_or(false, |m| m.is_playing())
    }

    /// Whether this tag is currently playing.
    pub fn is_playing(&self) -> bool {
        self.is_active_queue()
    }

    /// Number of items in the collection metadata (0 if no metadata).
    pub fn item_count(&self) -> usize {
        self.collection_metadata
            .as_ref()
            .map_or(0, |m| m.items.len())
    }

    /// Derives the `CollectionType` from the tag's fields.
    pub fn collection_type(&self) -> Option<super::collection::CollectionType> {
        self.collection_metadata
            .as_ref()
            .map(|m| m.collection_type(self.is_group))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    fn arb_tag_type() -> impl Strategy<Value = TagType> {
        prop_oneof![
            Just(TagType::BuiltIn),
            Just(TagType::User),
            Just(TagType::Automatic),
        ]
    }

    /// Generate an Option<String> key that covers all classification-relevant cases:
    /// None, Some(""), and Some(non-empty).
    fn arb_key() -> impl Strategy<Value = Option<String>> {
        prop_oneof![
            Just(None),
            Just(Some(String::new())),
            "[a-z][a-z0-9_]{0,15}".prop_map(Some),
        ]
    }

    fn arb_tag() -> impl Strategy<Value = Tag> {
        (
            "[a-f0-9]{8}",       // id
            arb_key(),           // key
            "[a-z0-9]{1,20}",    // value
            arb_tag_type(),      // tag_type
        )
            .prop_map(|(id, key, value, tag_type)| Tag {
                id,
                key,
                value,
                tag_type,
                parent_id: None,
                alias_names: vec![],
                include_children: false,
                is_group: false,
                is_locked: false,
                display_order: 0,
                collection_metadata: None,
            })
    }

    proptest! {
        // Feature: tag-search-system, Property 1: Tag classification is determined by key field
        // Validates: Requirements 2.1, 2.3, 2.4, 2.5

        #[test]
        fn tag_classification_mutually_exclusive_and_exhaustive(tag in arb_tag()) {
            // is_named and is_nameless must be mutually exclusive and exhaustive
            prop_assert_ne!(tag.is_named(), tag.is_nameless(),
                "is_named and is_nameless must differ");
            prop_assert!(tag.is_named() || tag.is_nameless(),
                "every tag must be either named or nameless");
        }

        #[test]
        fn named_iff_key_is_some_nonempty(tag in arb_tag()) {
            let has_nonempty_key = tag.key.as_ref().map_or(false, |k| !k.is_empty());
            prop_assert_eq!(tag.is_named(), has_nonempty_key,
                "is_named must be true iff key is Some with non-empty value");
            prop_assert_eq!(tag.is_nameless(), !has_nonempty_key,
                "is_nameless must be true iff key is None or empty");
        }
    }
}
