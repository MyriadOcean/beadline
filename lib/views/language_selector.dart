import 'package:flutter/material.dart';
import '../i18n/translations.g.dart';

/// Widget for selecting app language on first launch.
/// Displays available languages with native names and flags/icons.
/// Appears before configuration mode selection.
class LanguageSelector extends StatefulWidget {
  const LanguageSelector({
    super.key,
    required this.onLanguageSelected,
  });

  /// Callback when a language is selected
  final void Function(String languageCode) onLanguageSelected;

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String? _selectedLanguage;

  // Language options with native names
  final List<LanguageOption> _languages = [
    LanguageOption(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      icon: '🇬🇧',
    ),
    LanguageOption(
      code: 'zh-CN',
      nativeName: '简体中文',
      englishName: 'Simplified Chinese',
      icon: '🇨🇳',
    ),
    LanguageOption(
      code: 'zh-TW',
      nativeName: '繁體中文',
      englishName: 'Traditional Chinese',
      icon: '🇹🇼',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-select device locale if available
    final deviceLocale = LocaleSettings.currentLocale.languageTag;
    if (_languages.any((lang) => lang.code == deviceLocale)) {
      _selectedLanguage = deviceLocale;
    } else {
      // Default to English if device locale not supported
      _selectedLanguage = 'en';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(theme),
                      const SizedBox(height: 48),
                      ..._languages.map((lang) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLanguageOption(theme, lang),
                          )),
                      const SizedBox(height: 32),
                      _buildContinueButton(theme),
                      const SizedBox(height: 16),
                      Text(
                        'You can change the language later in Settings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.language,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Choose Your Language',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Select your preferred language for the app',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLanguageOption(ThemeData theme, LanguageOption language) {
    final isSelected = _selectedLanguage == language.code;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLanguage = language.code;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Flag/Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    language.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Language names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.nativeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.englishName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Radio button
              Radio<String>(
                value: language.code,
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    return FilledButton(
      onPressed: _selectedLanguage != null
          ? () async {
              // Apply language immediately
              await LocaleSettings.setLocaleRaw(_selectedLanguage!);
              widget.onLanguageSelected(_selectedLanguage!);
            }
          : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: const Text('Continue'),
    );
  }
}

/// Data class for language options
class LanguageOption {

  LanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.icon,
  });
  final String code;
  final String nativeName;
  final String englishName;
  final String icon;
}
