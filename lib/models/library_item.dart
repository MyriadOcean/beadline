import 'song_unit.dart';

/// Unified library item wrapping a SongUnit.
///
/// This exists as a thin wrapper to provide a consistent sort interface.
/// Both full and temporary Song Units are represented here.
class LibraryItem {
  LibraryItem(this.songUnit);

  final SongUnit songUnit;

  String get id => songUnit.id;
  String get displayTitle => songUnit.displayName;

  String? get displayArtist {
    if (songUnit.metadata.artists.isNotEmpty) {
      return songUnit.metadata.artists.first;
    }
    return null;
  }

  /// Sort date: use discoveredAt for temporary Song Units, fallback to now.
  DateTime get sortDate => songUnit.discoveredAt ?? DateTime.now();

  /// Whether this item is a temporary (auto-discovered) Song Unit.
  bool get isTemporary => songUnit.isTemporary;
}
