# Beadline (珠链) — Introduction

Beadline is a music player and library manager. Unlike typical file players, it organizes music around **Song Units** — logical entities that can hold multiple media sources, rich tags, and playback preferences all in one place.

---

## Song Unit

A Song Unit is the core thing you manage in Beadline. It represents one song, but it's not tied to a single file.

A Song Unit can hold:
- Multiple display sources (MV, live performance, static cover art...)
- Multiple audio tracks (original vocal, instrumental, different recordings...)
- Accompaniment tracks (karaoke backing)
- Lyrics files (LRC format, synchronized)
- Metadata and tags

At any moment, exactly one source per output type is playing. You can switch between them during playback without losing your position.

This means you can keep your MV, live version, and karaoke version of the same song all in one place, and switch between them on the fly.

---

## Sources

A Source is a piece of media attached to a Song Unit. There are four kinds:

| Type | What it is | Output |
|------|------------|--------|
| Display | Video or image content shown on screen | Display |
| Audio | The main audio track | Audio |
| Accompaniment | A karaoke or instrumental track | Audio (exclusive with Audio) |
| Lyrics | An LRC synchronized lyrics file | Lyrics overlay |

Sources can be local files, direct URLs, or content from online platforms via a configured API bridge.

When a Song Unit has multiple sources of the same type, you set a priority order. Beadline uses the top one by default, and you can switch manually during playback.

---

## Outputs

Beadline has three output channels. Only one source can be active per channel at a time:

- **Display** — what's shown on screen (the active display source, which may contain video or image content)
- **Audio** — what you hear (audio source or accompaniment source, never both)
- **Lyrics** — synchronized lyrics, shown on screen or in a floating overlay

---

## Tags

Tags are how you organize and find Song Units. There are three kinds:

### Built-in tags

Standard metadata fields that are always present:

- `name` — song title
- `artist` — performer
- `album` — album name
- `time` — year or era
- `duration` — length in seconds

### User tags

Tags you create yourself. They support:

- **Hierarchy** — tags can have parent/child relationships. Searching for a parent automatically includes all its children.
- **Aliases** — a tag can have multiple names (e.g. across languages). Any alias works in search and resolves to the same tag.

Example hierarchy:
```
luotianyi
├── luotianyi/v4
│   └── luotianyi/v4/meng
└── luotianyi/live
```

Searching `tag:luotianyi` matches all of the above.

### Automatic tags

Maintained by the system, not editable manually:

- `user:xx` — who added or requested a song
- `playlist:xx` — which playlist a song belongs to

---

## Playlists, Groups, and Queues Are Tags

This is one of Beadline's key ideas: **playlists are just tags**.

When you add a Song Unit to a playlist called "favorites", Beadline applies the tag `playlist:favorites` to it. There's no separate playlist object — it's all the same tag system.

The same applies to the play queue. Songs in the queue can carry `user:xx` tags that record who requested them, which feeds into the song request system.

This means everything — playlists, groups, requests — is searchable, filterable, and manageable through the same tag interface.

---

## Searching

Beadline has a query expression language for searching your library. You type expressions directly in the search bar.

Default behavior: bare keywords search by name.
```
hello  →  name:*hello*
```

Some examples:
```
artist:luotianyi              # songs by luotianyi
-album:singles                # exclude the "singles" album
time:[2017-2024]              # songs from 2017 to 2024
artist:luotianyi OR artist:yanhe   # either artist
(tag:live OR tag:mv) artist:luotianyi  # grouped conditions
```

Tag aliases are transparent — searching by any alias finds the same results.

---

## Lyrics

Lyrics are a source type (LRC format). They have three display modes:

- **Off** — no lyrics
- **Screen** — shown in the main display area, either KTV style (current + next line) or rolling scroll
- **Floating** — a system overlay window that stays on top of other apps, draggable and resizable

---

## Online Sources

Beadline is primarily local-file focused, but supports online sources as a supplement:

- Direct URLs (MP3, MP4, HLS, DASH)
- Platform content via self-hosted API bridges (Bilibili, NetEase, etc.)

Beadline never calls third-party APIs directly. You configure your own bridge server and point Beadline at it — keeping you in control of privacy and legal compliance.

---

## Import & Export

Song Units can be exported as ZIP files containing the metadata and any local source files. Batch export wraps multiple Song Units into a single archive. Files are deduplicated by content hash, so shared files aren't duplicated on disk.
