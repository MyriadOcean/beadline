use lofty::file::{AudioFile, TaggedFileExt};
use lofty::picture::PictureType;
use lofty::prelude::Accessor;
use lofty::probe::Probe;
use std::path::Path;

/// Metadata extracted from an audio file via lofty.
#[derive(Debug, Clone)]
pub struct LoftyMetadata {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub year: Option<u32>,
    pub duration_ms: u64,
    /// Embedded artwork bytes (JPEG/PNG). Empty if none found.
    pub artwork: Vec<u8>,
}

/// Extract metadata + embedded artwork from an audio file using lofty.
/// Returns `None` if the file cannot be read or is not a supported format.
pub fn extract_media_metadata(file_path: String) -> Option<LoftyMetadata> {
    let path = Path::new(&file_path);
    if !path.exists() {
        return None;
    }

    let tagged_file = Probe::open(path).ok()?.read().ok()?;

    let properties = tagged_file.properties();
    let duration_ms = properties.duration().as_millis() as u64;

    // Try primary tag first, then fall back to any available tag
    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

    let (title, artist, album, year) = if let Some(t) = tag {
        (
            t.title().map(|s| s.to_string()),
            t.artist().map(|s| s.to_string()),
            t.album().map(|s| s.to_string()),
            t.year(),
        )
    } else {
        (None, None, None, None)
    };

    // Extract artwork: prefer front cover, fall back to first picture
    let artwork = tag
        .and_then(|t| {
            let pictures = t.pictures();
            pictures
                .iter()
                .find(|p| p.pic_type() == PictureType::CoverFront)
                .or_else(|| pictures.first())
                .map(|p| p.data().to_vec())
        })
        .unwrap_or_default();

    Some(LoftyMetadata {
        title,
        artist,
        album,
        year,
        duration_ms,
        artwork,
    })
}
