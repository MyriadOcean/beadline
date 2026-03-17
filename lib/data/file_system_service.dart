import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Service for file system operations
/// Provides platform-independent file access and directory scanning
class FileSystemService {
  /// Get the application documents directory
  Future<Directory> getAppDocumentsDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  /// Get the application support directory
  Future<Directory> getAppSupportDirectory() async {
    return getApplicationSupportDirectory();
  }

  /// Get the temporary directory
  Future<Directory> getTempDirectory() async {
    return getTemporaryDirectory();
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return file.existsSync();
  }

  /// Check if a directory exists
  Future<bool> directoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    return directory.existsSync();
  }

  /// Read a file as bytes
  Future<List<int>> readFileAsBytes(String filePath) async {
    final file = File(filePath);
    return file.readAsBytes();
  }

  /// Read a file as string
  Future<String> readFileAsString(String filePath) async {
    final file = File(filePath);
    return file.readAsString();
  }

  /// Write bytes to a file
  Future<void> writeFileAsBytes(String filePath, List<int> bytes) async {
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  /// Write string to a file
  Future<void> writeFileAsString(String filePath, String content) async {
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Copy a file
  Future<void> copyFile(String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);
    await sourceFile.copy(destinationPath);
  }

  /// Move a file
  Future<void> moveFile(String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);
    await sourceFile.rename(destinationPath);
  }

  /// Delete a file
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Create a directory
  Future<void> createDirectory(String dirPath) async {
    final directory = Directory(dirPath);
    await directory.create(recursive: true);
  }

  /// Delete a directory
  Future<void> deleteDirectory(String dirPath, {bool recursive = false}) async {
    final directory = Directory(dirPath);
    if (directory.existsSync()) {
      await directory.delete(recursive: recursive);
    }
  }

  /// List files in a directory
  Future<List<FileSystemEntity>> listDirectory(
    String dirPath, {
    bool recursive = false,
  }) async {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      return [];
    }

    return directory.list(recursive: recursive, followLinks: false).toList();
  }

  /// Scan directory for audio files
  Future<List<File>> scanForAudioFiles(
    String dirPath, {
    bool recursive = true,
  }) async {
    final audioExtensions = {
      '.mp3',
      '.m4a',
      '.aac',
      '.flac',
      '.wav',
      '.ogg',
      '.opus',
      '.wma',
    };

    return _scanForFilesByExtensions(
      dirPath,
      audioExtensions,
      recursive: recursive,
    );
  }

  /// Scan directory for video files
  Future<List<File>> scanForVideoFiles(
    String dirPath, {
    bool recursive = true,
  }) async {
    final videoExtensions = {
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
    };

    return _scanForFilesByExtensions(
      dirPath,
      videoExtensions,
      recursive: recursive,
    );
  }

  /// Scan directory for image files
  Future<List<File>> scanForImageFiles(
    String dirPath, {
    bool recursive = true,
  }) async {
    final imageExtensions = {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.svg',
    };

    return _scanForFilesByExtensions(
      dirPath,
      imageExtensions,
      recursive: recursive,
    );
  }

  /// Scan directory for lyrics files
  Future<List<File>> scanForLyricsFiles(
    String dirPath, {
    bool recursive = true,
  }) async {
    final lyricsExtensions = {'.lrc', '.txt'};

    return _scanForFilesByExtensions(
      dirPath,
      lyricsExtensions,
      recursive: recursive,
    );
  }

  /// Scan directory for all media files (audio, video, image, lyrics)
  Future<Map<String, List<File>>> scanForAllMediaFiles(
    String dirPath, {
    bool recursive = true,
  }) async {
    final results = <String, List<File>>{};

    results['audio'] = await scanForAudioFiles(dirPath, recursive: recursive);
    results['video'] = await scanForVideoFiles(dirPath, recursive: recursive);
    results['image'] = await scanForImageFiles(dirPath, recursive: recursive);
    results['lyrics'] = await scanForLyricsFiles(dirPath, recursive: recursive);

    return results;
  }

  /// Helper method to scan for files by extensions
  Future<List<File>> _scanForFilesByExtensions(
    String dirPath,
    Set<String> extensions, {
    bool recursive = true,
  }) async {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      return [];
    }

    final files = <File>[];
    final entities = await directory
        .list(recursive: recursive, followLinks: false)
        .toList();

    for (final entity in entities) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (extensions.contains(extension)) {
          files.add(entity);
        }
      }
    }

    return files;
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return file.length();
  }

  /// Get file last modified time
  Future<DateTime> getFileLastModified(String filePath) async {
    final file = File(filePath);
    return file.lastModifiedSync();
  }

  /// Get the basename of a file path
  String getBasename(String filePath) {
    return path.basename(filePath);
  }

  /// Get the directory name of a file path
  String getDirname(String filePath) {
    return path.dirname(filePath);
  }

  /// Get the extension of a file path
  String getExtension(String filePath) {
    return path.extension(filePath);
  }

  /// Join path components
  String joinPath(List<String> components) {
    return path.joinAll(components);
  }

  /// Normalize a path
  String normalizePath(String filePath) {
    return path.normalize(filePath);
  }

  /// Check if a path is absolute
  bool isAbsolute(String filePath) {
    return path.isAbsolute(filePath);
  }

  /// Convert a relative path to absolute
  String toAbsolutePath(String relativePath, String basePath) {
    if (path.isAbsolute(relativePath)) {
      return relativePath;
    }
    return path.normalize(path.join(basePath, relativePath));
  }

  /// Convert an absolute path to relative
  String toRelativePath(String absolutePath, String basePath) {
    return path.relative(absolutePath, from: basePath);
  }

  /// Get the library directory for storing Song Unit sources
  Future<Directory> getLibraryDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final libraryDir = Directory(path.join(appDir.path, 'library'));

    if (!libraryDir.existsSync()) {
      await libraryDir.create(recursive: true);
    }

    return libraryDir;
  }

  /// Get the sources directory for a specific Song Unit
  Future<Directory> getSongUnitSourcesDirectory(String songUnitId) async {
    final libraryDir = await getLibraryDirectory();
    final sourcesDir = Directory(
      path.join(libraryDir.path, 'sources', songUnitId),
    );

    if (!sourcesDir.existsSync()) {
      await sourcesDir.create(recursive: true);
    }

    return sourcesDir;
  }

  /// Get the exports directory
  Future<Directory> getExportsDirectory() async {
    final libraryDir = await getLibraryDirectory();
    final exportsDir = Directory(path.join(libraryDir.path, 'exports'));

    if (!exportsDir.existsSync()) {
      await exportsDir.create(recursive: true);
    }

    return exportsDir;
  }

  /// Copy directory recursively
  Future<void> copyDirectory(String sourcePath, String destinationPath) async {
    final sourceDir = Directory(sourcePath);
    final destDir = Directory(destinationPath);

    if (!sourceDir.existsSync()) {
      throw Exception('Source directory does not exist: $sourcePath');
    }

    await destDir.create(recursive: true);

    await for (final entity in sourceDir.list()) {
      final newPath = path.join(destinationPath, path.basename(entity.path));

      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await copyDirectory(entity.path, newPath);
      }
    }
  }

  /// Get available disk space in bytes
  Future<int?> getAvailableDiskSpace() async {
    // Platform-specific implementation would be needed
    // For now, return null to indicate not implemented
    return null;
  }

  /// Validate that a file is a valid audio file
  Future<bool> isValidAudioFile(String filePath) async {
    if (!await fileExists(filePath)) {
      return false;
    }

    final extension = getExtension(filePath).toLowerCase();
    final validExtensions = {
      '.mp3',
      '.m4a',
      '.aac',
      '.flac',
      '.wav',
      '.ogg',
      '.opus',
      '.wma',
    };

    return validExtensions.contains(extension);
  }

  /// Validate that a file is a valid video file
  Future<bool> isValidVideoFile(String filePath) async {
    if (!await fileExists(filePath)) {
      return false;
    }

    final extension = getExtension(filePath).toLowerCase();
    final validExtensions = {
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
    };

    return validExtensions.contains(extension);
  }

  /// Validate that a file is a valid image file
  Future<bool> isValidImageFile(String filePath) async {
    if (!await fileExists(filePath)) {
      return false;
    }

    final extension = getExtension(filePath).toLowerCase();
    final validExtensions = {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.svg',
    };

    return validExtensions.contains(extension);
  }

  /// Validate that a file is a valid lyrics file
  Future<bool> isValidLyricsFile(String filePath) async {
    if (!await fileExists(filePath)) {
      return false;
    }

    final extension = getExtension(filePath).toLowerCase();
    return extension == '.lrc' || extension == '.txt';
  }
}
