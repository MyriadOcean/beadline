// Feature: thumbnail-cache-dedup, Property 5: get_thumbnail returns None for any input with length != 64
use beadline_core::thumbnail_cache::ThumbnailCache;
use proptest::prelude::*;
use tempfile::TempDir;

proptest! {
    #[test]
    fn prop_hash_guard(s in ".*".prop_filter("length != 64", |s| s.len() != 64)) {
        let dir = TempDir::new().unwrap();
        let cache = ThumbnailCache::new(dir.path().to_path_buf());
        prop_assert!(cache.get_thumbnail(&s).is_none());
    }
}
