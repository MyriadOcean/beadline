/// A Dart-side suggestion model with accessible fields.
///
/// Mirrors the Rust `DartSuggestion` struct from the bridge crate.
/// Used until FRB codegen is re-run to generate bindings for the new type.
class DartSuggestion {
  const DartSuggestion({
    required this.displayText,
    required this.insertText,
    required this.suggestionType,
  });

  /// Text shown to the user in the dropdown.
  final String displayText;

  /// Text inserted into the query when the user selects this suggestion.
  final String insertText;

  /// One of: "named_tag_key", "named_tag_value", "nameless_tag", "hierarchical_tag"
  final String suggestionType;
}
