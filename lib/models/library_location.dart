import 'package:json_annotation/json_annotation.dart';

import 'configuration_mode.dart';

part 'library_location.g.dart';

/// A user-configured directory path where Song Unit data and source files are stored
@JsonSerializable()
class LibraryLocation {
  const LibraryLocation({
    required this.id,
    required this.name,
    required this.rootPath,
    this.isDefault = false,
    required this.addedAt,
    this.isAccessible = true,
    this.configMode,
  });

  /// Create from JSON
  factory LibraryLocation.fromJson(Map<String, dynamic> json) =>
      _$LibraryLocationFromJson(json);

  /// Unique identifier for this library location
  final String id;

  /// User-friendly name for this library location
  final String name;

  /// Absolute path to the library root directory
  final String rootPath;

  /// Whether this is the default library location for new Song Units
  final bool isDefault;

  /// When this library location was added
  final DateTime addedAt;

  /// Runtime status indicating if the location is currently accessible
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isAccessible;

  /// Per-location configuration mode override.
  /// If null, the global configuration mode is used.
  final ConfigurationMode? configMode;

  /// Create a copy with updated fields
  LibraryLocation copyWith({
    String? id,
    String? name,
    String? rootPath,
    bool? isDefault,
    DateTime? addedAt,
    bool? isAccessible,
    ConfigurationMode? configMode,
    bool clearConfigMode = false,
  }) {
    return LibraryLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      rootPath: rootPath ?? this.rootPath,
      isDefault: isDefault ?? this.isDefault,
      addedAt: addedAt ?? this.addedAt,
      isAccessible: isAccessible ?? this.isAccessible,
      configMode: clearConfigMode ? null : (configMode ?? this.configMode),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$LibraryLocationToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LibraryLocation &&
        other.id == id &&
        other.name == name &&
        other.rootPath == rootPath &&
        other.isDefault == isDefault &&
        other.addedAt == addedAt &&
        other.isAccessible == isAccessible &&
        other.configMode == configMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      id, name, rootPath, isDefault, addedAt, isAccessible, configMode,
    );
  }

  @override
  String toString() {
    return 'LibraryLocation(id: $id, name: $name, rootPath: $rootPath, '
        'isDefault: $isDefault, addedAt: $addedAt, isAccessible: $isAccessible, '
        'configMode: $configMode)';
  }
}
