// Feature: thumbnail-cache-dedup, Property 3: After purge_orphans, every remaining .jpg stem is in referenced_hashes
use beadline_core::thumbnail_cache::ThumbnailCache;
use proptest::prelude::*;
use tempfile::TempDir;
use std::collections::HashSet;
use std::fs;

// Generate a fake 64-char hex string from a u64 seed
fn fake_hash(seed: u64) -> String {
    format!("{:064x}", seed)
}

proptest! {
    #[test]
    fn prop_purge_correctness(
        // Generate between 0 and 10 file seeds
        seeds in proptest::collection::vec(any::<u64>(), 0..=10),
        // A bitmask to select which seeds are "referenced"
        keep_mask: u64,
    ) {
        let dir = TempDir::new().unwrap();
        let cache = ThumbnailCache::new(dir.path().to_path_buf());

        // Deduplicate seeds
        let unique_seeds: Vec<u64> = {
            let mut seen = HashSet::new();
            seeds.into_iter().filter(|s| seen.insert(*s)).collect()
        };

        // Pre-populate cache dir with .jpg files
        for (i, &seed) in unique_seeds.iter().enumerate() {
            let hash = fake_hash(seed);
            let path = dir.path().join(format!("{}.jpg", hash));
            fs::write(&path, b"fake").unwrap();
            let _ = i;
        }

        // Build referenced set from a subset
        let referenced: HashSet<String> = unique_seeds.iter().enumerate()
            .filter(|(i, _)| (keep_mask >> i) & 1 == 1)
            .map(|(_, &seed)| fake_hash(seed))
            .collect();

        cache.purge_orphans(&referenced).unwrap();

        // Assert every remaining .jpg stem is in referenced
        for entry in fs::read_dir(dir.path()).unwrap().flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("jpg") {
                let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_string();
                prop_assert!(referenced.contains(&stem), "Unexpected file remaining: {}", stem);
            }
        }
    }
}
