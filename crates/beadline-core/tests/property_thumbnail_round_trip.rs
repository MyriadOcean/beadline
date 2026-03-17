// Feature: thumbnail-cache-dedup, Property 1: For any byte sequence, cache_from_bytes then get_thumbnail returns Some
use beadline_core::thumbnail_cache::ThumbnailCache;
use proptest::prelude::*;
use tempfile::TempDir;

proptest! {
    #[test]
    fn prop_round_trip(bytes: Vec<u8>) {
        let dir = TempDir::new().unwrap();
        let cache = ThumbnailCache::new(dir.path().to_path_buf());
        let hash = cache.cache_from_bytes(&bytes).unwrap();
        let result = cache.get_thumbnail(&hash);
        prop_assert!(result.is_some());
    }
}
