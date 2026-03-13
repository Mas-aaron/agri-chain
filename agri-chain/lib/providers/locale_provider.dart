import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app locale and persists the language preference.
class LocaleProvider extends ChangeNotifier {
  static const String _keyLocale = 'agri_app_locale';

  static const Map<String, String> supportedLocales = {
    'en': '🇬🇧 English',
    'zh': '🇨🇳 中文 (Chinese)',
    'fr': '🇫🇷 Français (French)',
    'es': '🇪🇸 Español (Spanish)',
    'ar': '🇸🇦 العربية (Arabic)',
    'hi': '🇮🇳 हिन्दी (Hindi)',
    'pt': '🇧🇷 Português (Portuguese)',
    'ru': '🇷🇺 Русский (Russian)',
    'lg': 'Luganda',
    'sw': '🇹🇿 Kiswahili (Swahili)',
    'luo': 'Luo (Dholuo)',
    'laj': 'Lango',
    'alz': 'Alur',
  };

  Locale _locale = const Locale('en');
  String _currentCode = 'en';

  LocaleProvider() {
    _loadSaved();
  }

  Locale get locale => _locale;
  String get currentCode => _currentCode;
  String get languageLabel => supportedLocales[_currentCode] ?? 'English';

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyLocale);
    if (saved != null && supportedLocales.containsKey(saved)) {
      _currentCode = saved;
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(String code) async {
    if (!supportedLocales.containsKey(code)) return;
    _currentCode = code;
    _locale = Locale(code);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, code);
  }
}
