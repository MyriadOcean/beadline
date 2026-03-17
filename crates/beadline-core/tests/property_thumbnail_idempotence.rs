// Feature: thumbnail-cache-dedup, Property 2: For any byte sequence, cache_from_bytes twice returns same hash and leaves exactly one file
use beadline_core::thumbnail_cache::ThumbnailCache;
use proptest::prelude::*;
use tempfile::TempDir;
use std::fs;

proptest! {
    #[test]
    fn prop_idempotence(bytes: Vec<u8>) {
        let dir = TempDir::new().unwrap();
        let cache = ThumbnailCache::new(dir.path().to_path_buf());
        let hash1 = cache.cache_from_bytes(&bytes).unwrap();
        let hash2 = cache.cache_from_bytes(&bytes).unwrap();
        prop_assert_eq!(&hash1, &hash2);
        // Count .jpg files in the cache dir
        let jpg_count = fs::read_dir(dir.path()).unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| e.path().extension().and_then(|x| x.to_str()) == Some("jpg"))
            .count();
        prop_assert_eq!(jpg_count, 1);
    }
}
