import '../../models/source.dart';

/// Helper class for source with validation status
class SourceWithValidation {
  SourceWithValidation(this.source, this.error);
  final Source source;
  final String? error;
}
