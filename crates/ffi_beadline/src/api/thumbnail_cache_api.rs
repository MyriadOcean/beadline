use beadline_core::thumbnail_cache::ThumbnailCache;
use std::collections::HashSet;
use std::path::PathBuf;

/// FRB-compatible cache stats struct.
pub struct RustCacheStats {
    pub total_entries: u32,
    pub total_bytes: u64,
    pub orphan_count: u32,
}

fn make_cache(cache_dir: String) -> ThumbnailCache {
    ThumbnailCache::new(PathBuf::from(cache_dir))
}

/// Cache bytes and return the 64-char hex content hash.
pub fn thumbnail_cache_from_bytes(cache_dir: String, bytes: Vec<u8>) -> Result<String, String> {
    make_cache(cache_dir)
        .cache_from_bytes(&bytes)
        .map_err(|e| e.to_string())
}

/// Return absolute path string if the entry exists, None otherwise.
pub fn thumbnail_cache_get(cache_dir: String, content_hash: String) -> Option<String> {
    make_cache(cache_dir)
        .get_thumbnail(&content_hash)
        .map(|p| p.to_string_lossy().into_owned())
}

/// Delete orphan .jpg files. Returns count deleted.
pub fn thumbnail_cache_purge_orphans(
    cache_dir: String,
    referenced_hashes: Vec<String>,
) -> Result<u32, String> {
    let set: HashSet<String> = referenced_hashes.into_iter().collect();
    make_cache(cache_dir)
        .purge_orphans(&set)
        .map_err(|e| e.to_string())
}

/// Return hashes from the input set that have no corresponding file.
pub fn thumbnail_cache_find_missing(
    cache_dir: String,
    referenced_hashes: Vec<String>,
) -> Vec<String> {
    let set: HashSet<String> = referenced_hashes.into_iter().collect();
    make_cache(cache_dir)
        .find_missing_entries(&set)
        .into_iter()
        .collect()
}

/// Return aggregate cache statistics.
pub fn thumbnail_cache_get_stats(
    cache_dir: String,
    referenced_hashes: Vec<String>,
) -> RustCacheStats {
    let set: HashSet<String> = referenced_hashes.into_iter().collect();
    let stats = make_cache(cache_dir).get_cache_stats(&set);
    RustCacheStats {
        total_entries: stats.total_entries,
        total_bytes: stats.total_bytes,
        orphan_count: stats.orphan_count,
    }
}
