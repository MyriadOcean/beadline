use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::fmt::Write as FmtWrite;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, thiserror::Error)]
pub enum ThumbnailCacheError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
}

pub struct CacheStats {
    pub total_entries: u32,
    pub total_bytes: u64,
    pub orphan_count: u32,
}

pub struct ThumbnailCache {
    cache_dir: PathBuf,
}

impl ThumbnailCache {
    pub fn new(cache_dir: PathBuf) -> Self {
        ThumbnailCache { cache_dir }
    }

    /// SHA-256 hash bytes, write `<hash>.jpg` if absent, return 64-char hex hash.
    pub fn cache_from_bytes(&self, bytes: &[u8]) -> Result<String, ThumbnailCacheError> {
        let digest = Sha256::digest(bytes);
        let mut hash = String::with_capacity(64);
        for byte in digest.iter() {
            write!(hash, "{:02x}", byte).unwrap();
        }
        let path = self.cache_dir.join(format!("{}.jpg", hash));

        if !path.exists() {
            fs::create_dir_all(&self.cache_dir)?;
            fs::write(&path, bytes)?;
        }

        Ok(hash)
    }

    /// Return path if file exists, None if not or if hash is not 64 hex chars.
    pub fn get_thumbnail(&self, content_hash: &str) -> Option<PathBuf> {
        if content_hash.len() != 64 {
            return None;
        }
        let path = self.cache_dir.join(format!("{}.jpg", content_hash));
        if path.exists() {
            Some(path)
        } else {
            None
        }
    }

    /// Delete .jpg files not in referenced_hashes. Returns count deleted.
    /// Per-file errors are swallowed (logged).
    pub fn purge_orphans(
        &self,
        referenced_hashes: &HashSet<String>,
    ) -> Result<u32, ThumbnailCacheError> {
        let entries = fs::read_dir(&self.cache_dir)?;
        let mut deleted = 0u32;

        for entry in entries {
            let entry = match entry {
                Ok(e) => e,
                Err(e) => {
                    eprintln!("thumbnail_cache: error reading dir entry: {}", e);
                    continue;
                }
            };

            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("jpg") {
                continue;
            }

            let stem = path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("")
                .to_string();

            if !referenced_hashes.contains(&stem) {
                if let Err(e) = fs::remove_file(&path) {
                    eprintln!("thumbnail_cache: failed to delete {:?}: {}", path, e);
                } else {
                    deleted += 1;
                }
            }
        }

        Ok(deleted)
    }

    /// Return subset of referenced_hashes with no corresponding file.
    pub fn find_missing_entries(&self, referenced_hashes: &HashSet<String>) -> HashSet<String> {
        referenced_hashes
            .iter()
            .filter(|hash| {
                let path = self.cache_dir.join(format!("{}.jpg", hash));
                !path.exists()
            })
            .cloned()
            .collect()
    }

    /// Return aggregate stats.
    pub fn get_cache_stats(&self, referenced_hashes: &HashSet<String>) -> CacheStats {
        let Ok(entries) = fs::read_dir(&self.cache_dir) else {
            return CacheStats {
                total_entries: 0,
                total_bytes: 0,
                orphan_count: 0,
            };
        };

        let mut total_entries = 0u32;
        let mut total_bytes = 0u64;
        let mut orphan_count = 0u32;

        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("jpg") {
                continue;
            }

            total_entries += 1;

            if let Ok(meta) = fs::metadata(&path) {
                total_bytes += meta.len();
            }

            let stem = path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("")
                .to_string();

            if !referenced_hashes.contains(&stem) {
                orphan_count += 1;
            }
        }

        CacheStats {
            total_entries,
            total_bytes,
            orphan_count,
        }
    }
}
