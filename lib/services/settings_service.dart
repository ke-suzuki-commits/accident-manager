import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// アプリ設定（Gemini APIキー等）を管理するサービス
class SettingsService extends ChangeNotifier {
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyUserName = 'user_name';

  String _geminiApiKey = '';
  String _userName = '';

  String get geminiApiKey => _geminiApiKey;
  String get userName => _userName;
  bool get hasApiKey => _geminiApiKey.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _geminiApiKey = prefs.getString(_keyGeminiApiKey) ?? '';
    _userName = prefs.getString(_keyUserName) ?? '';
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiApiKey, key);
    _geminiApiKey = key;
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    _userName = name;
    notifyListeners();
  }
}
