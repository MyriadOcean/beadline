use sha2::{Digest, Sha256};
use serde_json;

use crate::model::song_unit::SongUnit;
use crate::model::source::SourceOrigin;

/// Compute a SHA-256 hash from a Song Unit's metadata and source origins.
///
/// The hash is compatible with the Dart `calculateHash()` method:
/// - Duration is converted from microseconds to seconds
/// - Local file paths are normalized to filename only
/// - Source type uses Dart's `SourceType.toString()` format
/// - JSON key ordering matches Dart's `jsonEncode` (insertion order of Map literals)
///
/// Dart's `jsonEncode` preserves the insertion order of Map literals, so we must
/// produce JSON with keys in the exact same order. `serde_json::json!` uses BTreeMap
/// (alphabetical order) by default, which doesn't match. We build the JSON string
/// manually to guarantee key ordering.
pub fn calculate_hash(song_unit: &SongUnit) -> String {
    let json_string = build_hash_json(song_unit);
    let digest = Sha256::digest(json_string.as_bytes());
    format!("{:x}", digest)
}

/// Build the JSON string for hashing, with key ordering matching Dart's `calculateHash()`.
///
/// Dart hash_data map literal order: title, artists, album, year, duration, sources
/// Dart origin toJson() order for localFile: type, path
/// Dart origin toJson() order for url: type, url
/// Dart origin toJson() order for api: type, provider, resourceId
/// Dart source entry order: type, origin
fn build_hash_json(song_unit: &SongUnit) -> String {
    let mut json = String::with_capacity(512);
    json.push('{');

    // "title": ...
    json.push_str("\"title\":");
    json.push_str(&serde_json::to_string(&song_unit.metadata.title).unwrap());

    // "artists": [...]
    json.push_str(",\"artists\":");
    json.push_str(&serde_json::to_string(&song_unit.metadata.artists).unwrap());

    // "album": ...
    json.push_str(",\"album\":");
    json.push_str(&serde_json::to_string(&song_unit.metadata.album).unwrap());

    // "year": ... (null or number)
    json.push_str(",\"year\":");
    match song_unit.metadata.year {
        Some(y) => json.push_str(&y.to_string()),
        None => json.push_str("null"),
    }

    // "duration": ... (seconds)
    json.push_str(",\"duration\":");
    json.push_str(&(song_unit.metadata.duration / 1_000_000).to_string());

    // "sources": [...]
    json.push_str(",\"sources\":[");
    let sources = song_unit.sources.all_sources();
    for (i, s) in sources.iter().enumerate() {
        if i > 0 {
            json.push(',');
        }
        json.push('{');
        // "type": "SourceType.xxx"
        json.push_str("\"type\":\"");
        json.push_str(&s.source_type.to_string());
        json.push('"');
        // "origin": {...}
        json.push_str(",\"origin\":");
        json.push_str(&origin_to_ordered_json(s.origin));
        json.push('}');
    }
    json.push(']');

    json.push('}');
    json
}

/// Serialize a SourceOrigin to JSON with key ordering matching Dart's `toJson()`.
fn origin_to_ordered_json(origin: &SourceOrigin) -> String {
    match origin {
        SourceOrigin::LocalFile { path } => {
            // Normalize to filename only
            let filename = path.rsplit(&['/', '\\'][..]).next().unwrap_or(path);
            let mut s = String::with_capacity(64);
            s.push_str("{\"type\":\"localFile\",\"path\":");
            s.push_str(&serde_json::to_string(filename).unwrap());
            s.push('}');
            s
        }
        SourceOrigin::Url { url } => {
            let mut s = String::with_capacity(64);
            s.push_str("{\"type\":\"url\",\"url\":");
            s.push_str(&serde_json::to_string(url).unwrap());
            s.push('}');
            s
        }
        SourceOrigin::Api {
            provider,
            resource_id,
        } => {
            let mut s = String::with_capacity(64);
            s.push_str("{\"type\":\"api\",\"provider\":");
            s.push_str(&serde_json::to_string(provider).unwrap());
            s.push_str(",\"resourceId\":");
            s.push_str(&serde_json::to_string(resource_id).unwrap());
            s.push('}');
            s
        }
    }
}

// We intentionally keep SourceType's Display impl for the hash format.
// The Display impl in source.rs produces "SourceType.display", "SourceType.audio", etc.
// which matches Dart's SourceType.toString().
