import 'package:json_annotation/json_annotation.dart';

/// Configuration storage mode for the application
@JsonEnum()
enum ConfigurationMode {
  /// All configuration stored in platform-specific app data directory
  centralized,

  /// Entry point files stored alongside source files for portability
  inPlace;

  /// Convert to JSON
  String toJson() => name;

  /// Create from JSON
  static ConfigurationMode fromJson(String json) {
    return ConfigurationMode.values.firstWhere(
      (mode) => mode.name == json,
      orElse: () => ConfigurationMode.centralized,
    );
  }
}
