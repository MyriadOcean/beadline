import 'package:flutter/material.dart';
import '../i18n/translations.g.dart';

/// Widget for selecting app language on first launch.
/// Displays a dropdown of available languages.
class LanguageSelector extends StatefulWidget {
  const LanguageSelector({
    super.key,
    required this.onLanguageSelected,
  });

  final void Function(String languageCode) onLanguageSelected;

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  static const _languages = [
    (code: 'en', label: 'English'),
    (code: 'zh-Hans', label: '简体中文'),
    (code: 'zh-Hant', label: '繁體中文'),
  ];

  String _selectedCode = 'en';

  @override
  void initState() {
    super.initState();
    // Pre-select based on device locale
    final tag = LocaleSettings.currentLocale.languageTag;
    if (_languages.any((l) => l.code == tag)) {
      _selectedCode = tag;
    } else if (tag.startsWith('zh')) {
      _selectedCode = tag.contains('Hant') || tag.contains('TW') || tag.contains('HK')
          ? 'zh-Hant'
          : 'zh-Hans';
    }
  }

  Future<void> _onChanged(String? code) async {
    if (code == null) return;
    await LocaleSettings.setLocaleRaw(code);
    setState(() => _selectedCode = code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.language, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    context.t.settings.languageSelectorTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t.settings.languageSelectorSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  DropdownButtonFormField<String>(
                    value: _selectedCode,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: context.t.settings.language,
                    ),
                    items: _languages
                        .map((l) => DropdownMenuItem(value: l.code, child: Text(l.label)))
                        .toList(),
                    onChanged: _onChanged,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => widget.onLanguageSelected(_selectedCode),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(context.t.settings.languageSelectorContinue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t.settings.languageSelectorHint,
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
    );
  }
}
