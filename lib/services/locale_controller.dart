import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide language state.
///
/// Wrap MaterialApp in a `ValueListenableBuilder<Locale>` driven by
/// [localeController.value] so the UI rebuilds whenever the user picks
/// a new language from the drawer.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(const Locale('en'));

  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'app_locale';

  /// Supported languages. Keys here must also exist in `Translations._all`.
  static const List<({Locale locale, String label, String nativeName})>
      supported = [
    (locale: Locale('en'), label: 'English', nativeName: 'English'),
    (locale: Locale('ta'), label: 'Tamil', nativeName: 'தமிழ்'),
    (locale: Locale('hi'), label: 'Hindi', nativeName: 'हिंदी'),
  ];

  /// Load the persisted language at app start. Call from `main()`
  /// before `runApp`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && supported.any((l) => l.locale.languageCode == code)) {
      value = Locale(code);
    }
  }

  /// Switch language and persist the choice.
  Future<void> setLocale(Locale locale) async {
    if (value == locale) return;
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

/// Convenience global so callers can write `localeController.setLocale(...)`
/// without typing the singleton path every time.
final LocaleController localeController = LocaleController.instance;
