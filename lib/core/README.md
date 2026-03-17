# Core Directory

This directory contains cross-cutting concerns and utilities used throughout the application.

## Structure

- `di/` - Dependency injection setup using get_it
- `constants/` - Application-wide constants (to be added)
- `utils/` - Utility functions and helpers (to be added)
- `errors/` - Custom error classes and exceptions (to be added)

## Dependency Injection

The service locator pattern is implemented using `get_it`. All dependencies should be registered in `di/service_locator.dart` during app initialization.

### Registration Types

- **Singleton**: `registerLazySingleton()` - Single instance created on first use
- **Factory**: `registerFactory()` - New instance created each time
- **Singleton (eager)**: `registerSingleton()` - Single instance created immediately

### Usage

```dart
// In service_locator.dart
getIt.registerLazySingleton<MyService>(() => MyService());

// In your code
final myService = getIt<MyService>();
```
