# Beadline — Development Guide

## Project Overview

Beadline is a Flutter application with a Rust core. The UI and application logic live in Dart/Flutter; performance-critical and platform-independent logic (database, tag engine, query parser, thumbnail cache) lives in Rust crates exposed via `flutter_rust_bridge`.

```
beadline/
├── lib/                    # Dart/Flutter source
│   ├── main.dart
│   ├── models/             # Data models (JSON-serializable)
│   ├── repositories/       # Data access layer
│   ├── services/           # Business logic
│   ├── viewmodels/         # State management (Provider)
│   ├── views/              # UI screens and widgets
│   ├── data/               # Persistent storage helpers
│   ├── core/               # DI, error handling, utilities
│   └── i18n/               # Localization (slang)
├── crates/
│   ├── beadline-core/      # Song Unit DB, thumbnail cache
│   ├── beadline-tags/      # Tag engine, query parser/evaluator
│   └── ffi_beadline/       # flutter_rust_bridge FFI layer
├── rust_builder/           # Dart package wrapping the Rust FFI
├── android/
├── ios/
├── linux/
├── macos/
├── windows/
└── web/
```

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.11.0`)
- [Rust toolchain](https://rustup.rs/) (stable)
- [flutter_rust_bridge_codegen](https://cjycode.com/flutter_rust_bridge/) — for regenerating the FFI bindings
- Platform-specific toolchains as needed (Android SDK, Xcode, etc.)

Check your environment:
```bash
flutter doctor
rustup show
```

---

## Getting Started

```bash
# Install Flutter dependencies
flutter pub get

# Build the Rust library (required before first run)
# This is handled automatically by the build system on most platforms,
# but you can trigger it manually:
cargo build --release -p ffi_beadline

# Run on a connected device or emulator
flutter run
```

---

## Code Generation

Several parts of the codebase are generated and must be regenerated after changes.

### JSON serialization (json_serializable)

Run after modifying any model annotated with `@JsonSerializable`:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Localization (slang)

Run after modifying any `.i18n.json` file under `lib/i18n/`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Translation files:
- `lib/i18n/en.i18n.json` — English (base)
- `lib/i18n/zh-Hans.i18n.json` — Simplified Chinese
- `lib/i18n/zh-Hant.i18n.json` — Traditional Chinese

### Rust FFI bindings (flutter_rust_bridge)

Run after modifying any `#[flutter_rust_bridge::frb]`-annotated Rust API in `crates/ffi_beadline/src/api/`:
```bash
flutter_rust_bridge_codegen generate
```

This regenerates `crates/ffi_beadline/src/frb_generated.rs` and the corresponding Dart bindings in `lib/src/rust/`.

---

## Architecture

### Dart layer

| Layer | Location | Responsibility |
|-------|----------|----------------|
| Models | `lib/models/` | Plain data classes, JSON serialization |
| Repositories | `lib/repositories/` | Data access, calls Rust FFI or local storage |
| Services | `lib/services/` | Business logic (player engine, import/export, discovery, etc.) |
| ViewModels | `lib/viewmodels/` | State management via `provider` |
| Views | `lib/views/` | Flutter widgets and screens |
| Data | `lib/data/` | `shared_preferences`-backed storage helpers |
| Core | `lib/core/` | DI setup (`get_it`), error handling, undo manager |

### Rust crates

| Crate | Responsibility |
|-------|----------------|
| `beadline-core` | SQLite database, Song Unit CRUD, thumbnail cache |
| `beadline-tags` | Tag model, query parser (EBNF), query evaluator, tag suggestions |
| `ffi_beadline` | FFI bridge — exposes Rust APIs to Dart via `flutter_rust_bridge` |

The FFI API surface is organized by domain in `crates/ffi_beadline/src/api/`:
- `song_unit_api.rs` — Song Unit CRUD
- `tag_api.rs` — Tag management
- `collection_api.rs` — Source collections
- `parser_api.rs` / `evaluator_api.rs` — Query expression parsing and evaluation
- `thumbnail_cache_api.rs` — Thumbnail cache operations
- `media_api.rs` — Media metadata extraction
- `suggestion_api.rs` — Tag autocomplete suggestions

### Media playback

Media playback uses `media_kit` (replaces the older `audioplayers`/`video_player` split). `media_kit_libs_video` covers both audio and video on all platforms — do **not** add `media_kit_libs_audio` alongside it, as this causes duplicate class errors on Android.

Background audio and media session integration (lock screen controls, MPRIS on Linux) is handled by `audio_service` + `audio_service_mpris`.

### Floating lyrics window

The floating lyrics overlay uses `desktop_multi_window` to spawn a separate native window on desktop platforms. This window is managed by `DesktopWindowManager` in `lib/services/desktop_window_manager.dart` and rendered by `lib/views/floating_lyrics_window.dart`.

---

## Running Tests

### Dart tests
```bash
flutter test
```

### Rust tests
```bash
# Unit and integration tests
cargo test

# Property-based tests (uses proptest)
cargo test -p beadline-core
cargo test -p beadline-tags
```

Property tests live in `crates/beadline-core/tests/` and `crates/beadline-tags/tests/`. Regression files (`.proptest-regressions`) are committed and should not be deleted.

### Android media button testing (adb)

| Action | Command | Keycode |
|--------|---------|---------|
| Play | `adb shell input keyevent KEYCODE_MEDIA_PLAY` | 126 |
| Pause | `adb shell input keyevent KEYCODE_MEDIA_PAUSE` | 127 |
| Next | `adb shell input keyevent KEYCODE_MEDIA_NEXT` | 87 |
| Previous | `adb shell input keyevent KEYCODE_MEDIA_PREVIOUS` | 88 |
| Stop | `adb shell input keyevent KEYCODE_MEDIA_STOP` | 86 |
| Play/Pause | `adb shell input keyevent KEYCODE_MEDIA_PLAY_PAUSE` | 85 |

---

## Release Builds

### Android

Direct distribution (split APKs by ABI, recommended):
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=debug-info/
```

Google Play Store (App Bundle):
```bash
flutter build appbundle --release
```

Size analysis:
```bash
flutter build apk --release --analyze-size --target-platform android-x64
```

### Windows

Direct distribution:
```bash
flutter build windows --release --obfuscate --split-debug-info=debug-info/ --build-name=0.6.0
```

Size analysis:
```bash
flutter build windows --release --analyze-size
```

### Other platforms

```bash
flutter build ios       # iOS
flutter build macos     # macOS
flutter build linux     # Linux
flutter build web       # Web
```

---

## Dependency Notes

- `slang` / `slang_flutter` / `slang_build_runner` — i18n solution (replaces `flutter_localizations` for string management)
- `get_it ^9.x` — service locator for DI
- `archive ^4.x` — ZIP import/export
- `desktop_multi_window` — floating lyrics window on desktop
- `window_manager` — fullscreen and window control on desktop
- `flutter_native_splash` — splash screen generation; config is at the bottom of `pubspec.yaml`

---

## Splash Screen

Splash screen assets and colors are configured in `pubspec.yaml` under `flutter_native_splash`. To regenerate after changes:
```bash
dart run flutter_native_splash:create
```

---

## Linting & Analysis

```bash
flutter analyze
```

Lint rules are configured in `analysis_options.yaml` using `flutter_lints`.
