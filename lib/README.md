# Beadline Source Code Structure

This directory contains the Dart source code for Beadline, organized following the MVVM (Model-View-ViewModel) architecture pattern.

## Directory Structure

```
lib/
├── core/               # Cross-cutting concerns
│   └── di/            # Dependency injection setup
├── models/            # Domain models (immutable data classes)
├── data/              # Data layer (database, file system, storage)
├── repositories/      # Business logic and data operations
├── services/          # Application services (player, import/export)
├── viewmodels/        # State management and presentation logic
├── views/             # Flutter widgets and UI components
└── main.dart          # Application entry point
```

## Architecture Layers

### Model Layer (`models/`)
Pure domain models representing core business entities:
- `SongUnit` - Logical playback entity with metadata, sources, tags
- `Source` - Input data (Display, Audio, Accompaniment, Hover)
- `Tag` - Hierarchical tags with aliases
- `Query` - Query expression AST
- Immutable value objects with no framework dependencies

### Data Layer (`data/`)
Direct interaction with storage mechanisms:
- Local database (SQLite)
- File system operations
- Settings storage
- Platform-specific implementations

### Repository Layer (`repositories/`)
Encapsulates business logic and provides clean APIs:
- `LibraryRepository` - Song Unit CRUD operations
- `TagRepository` - Tag management and alias resolution
- `SearchRepository` - Query execution and source search
- `SettingsRepository` - Configuration management

### Service Layer (`services/`)
Application-level services:
- `PlayerEngine` - Media playback and source routing
- `ImportExportService` - ZIP-based serialization
- `QueryParser` - Query expression parsing

### ViewModel Layer (`viewmodels/`)
State management and presentation logic:
- Extends `ChangeNotifier` for reactive updates
- Coordinates between repositories/services
- Transforms model data for views
- No direct UI dependencies

### View Layer (`views/`)
Flutter widgets that render UI:
- Observes ViewModels via `Consumer` or `Provider`
- Handles user input
- Contains no business logic

## Dependency Flow

```
Views → ViewModels → Repositories/Services → Data Layer → Models
```

## State Management

- **Provider** package for dependency injection and state management
- ViewModels extend `ChangeNotifier` to notify views of state changes
- Views use `Consumer<T>` or `context.watch<T>()` to observe ViewModels

## Dependency Injection

All dependencies are registered in `core/di/service_locator.dart` using the `get_it` package:

```dart
// Registration (in service_locator.dart)
getIt.registerLazySingleton<LibraryRepository>(LibraryRepository.new);

// Usage (in ViewModels or Services)
final repository = getIt<LibraryRepository>();
```

## Testing

- Unit tests in `test/` directory mirror the `lib/` structure
- Property-based tests use `faker` for data generation
- Each test runs minimum 100 iterations as per design spec
- Tests are tagged with property numbers from design document

## Code Style

- Strict linting enabled via `analysis_options.yaml`
- Implicit casts and dynamic types disabled
- Prefer `const` constructors and final fields
- Use single quotes for strings
- Sort imports alphabetically (package imports first)

## Getting Started

1. Ensure dependencies are installed: `flutter pub get`
2. Run the app: `flutter run`
3. Run tests: `flutter test`
4. Check for issues: `flutter analyze`
