import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Persists recent search terms to a JSON file on disk.
class SearchHistoryStorage {
  static const String _fileName = 'search_history.json';

  Future<String> _filePath() async {
    final dir = await getApplicationSupportDirectory();
    return path.join(dir.path, _fileName);
  }

  /// Load the search history list from disk. Returns empty list on error.
  Future<List<String>> loadHistory() async {
    try {
      final file = File(await _filePath());
      if (!file.existsSync()) return [];
      final json = jsonDecode(await file.readAsString());
      return (json as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Save the search history list to disk.
  Future<void> saveHistory(List<String> history) async {
    try {
      final file = File(await _filePath());
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(history));
    } catch (_) {
      // Silently fail — history is non-critical
    }
  }
}
