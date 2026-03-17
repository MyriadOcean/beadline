// Feature: thumbnail-cache-dedup, Property 6: find_missing_entries returns exactly the subset with no file
use beadline_core::thumbnail_cache::ThumbnailCache;
use proptest::prelude::*;
use tempfile::TempDir;
use std::collections::HashSet;

fn fake_hash(seed: u64) -> String {
    format!("{:064x}", seed)
}

proptest! {
    #[test]
    fn prop_find_missing(
        // Byte sequences to actually cache
        cached_bytes in proptest::collection::vec(proptest::collection::vec(any::<u8>(), 0..=32), 0..=5),
        // Additional fake hashes that have no file
        missing_seeds in proptest::collection::vec(any::<u64>(), 0..=5),
    ) {
        let dir = TempDir::new().unwrap();
        let cache = ThumbnailCache::new(dir.path().to_path_buf());

        // Cache the byte sequences and collect their hashes
        let mut cached_hashes = HashSet::new();
        for bytes in &cached_bytes {
            let hash = cache.cache_from_bytes(bytes).unwrap();
            cached_hashes.insert(hash);
        }

        // Build the "uncached" set from fake hashes that don't collide with cached ones
        let uncached_hashes: HashSet<String> = missing_seeds.iter()
            .map(|&s| fake_hash(s))
            .filter(|h| !cached_hashes.contains(h))
            .collect();

        // Full referenced set = cached + uncached
        let all_hashes: HashSet<String> = cached_hashes.iter().cloned()
            .chain(uncached_hashes.iter().cloned())
            .collect();

        let missing = cache.find_missing_entries(&all_hashes);

        // Result must equal exactly the uncached subset
        prop_assert_eq!(&missing, &uncached_hashes);
    }
}
