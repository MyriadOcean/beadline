// Feature: thumbnail-cache-dedup, Property 4: purge_orphans never deletes non-.jpg files
use beadline_core::thumbnail_cache::ThumbnailCache;
use proptest::prelude::*;
use std::collections::HashSet;
use std::fs;
use tempfile::TempDir;

fn fake_hash(seed: u64) -> String {
    format!("{:064x}", seed)
}

proptest! {
    #[test]
    fn prop_purge_safety(
        jpg_seeds in proptest::collection::vec(any::<u64>(), 0..=5),
        other_seeds in proptest::collection::vec(any::<u64>(), 1..=5),
    ) {
        let dir = TempDir::new().unwrap();
        let cache = ThumbnailCache::new(dir.path().to_path_buf());

        // Create .jpg files
        for seed in &jpg_seeds {
            let path = dir.path().join(format!("{}.jpg", fake_hash(*seed)));
            fs::write(&path, b"fake_jpg").unwrap();
        }

        // Create non-.jpg files with various extensions
        let other_extensions = [".png", ".tmp", ".json", ".txt"];
        let mut non_jpg_paths = Vec::new();
        for (i, seed) in other_seeds.iter().enumerate() {
            let ext = other_extensions[i % other_extensions.len()];
            let path = dir.path().join(format!("{}{}", fake_hash(*seed), ext));
            fs::write(&path, b"fake_other").unwrap();
            non_jpg_paths.push(path);
        }

        // Purge with empty set — all .jpg files should be deleted
        let empty: HashSet<String> = HashSet::new();
        cache.purge_orphans(&empty).unwrap();

        // All non-.jpg files must still exist
        for path in &non_jpg_paths {
            prop_assert!(path.exists(), "Non-.jpg file was deleted: {:?}", path);
        }
    }
}
