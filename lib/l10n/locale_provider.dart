import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { bn, en }

const _prefsKey = 'app_language';

/// Holds the signed-in device's bn/en UI language choice and persists it
/// locally (SharedPreferences — a per-device preference, not data, so it's
/// deliberately outside the Firestore/SQLite sync path). Defaults to bn on
/// first launch, matching this app's original all-Bangla design.
class LocaleProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.bn;
  AppLanguage get language => _language;
  bool get isBangla => _language == AppLanguage.bn;

  Locale get locale => Locale(_language == AppLanguage.bn ? 'bn' : 'en');

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'en') _language = AppLanguage.en;
      notifyListeners();
    } catch (_) {
      // Local preference read failed — fall back to the bn default.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language == AppLanguage.en ? 'en' : 'bn');
    } catch (_) {
      // Best-effort — the in-memory choice still applies this session.
    }
  }
}
