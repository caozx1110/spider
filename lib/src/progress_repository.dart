import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ProgressRepository {
  ProgressRepository._(this._preferences);

  static const _progressKey = 'spider_progress';
  static const _savedGameKey = 'spider_saved_game';

  final SharedPreferences _preferences;

  static Future<ProgressRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return ProgressRepository._(preferences);
  }

  Future<PlayerProgress> loadProgress() async {
    final raw = _preferences.getString(_progressKey);
    if (raw == null || raw.isEmpty) {
      return PlayerProgress.initial();
    }

    try {
      return PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlayerProgress.initial();
    }
  }

  Future<SpiderGameState?> loadSavedGame() async {
    final raw = _preferences.getString(_savedGameKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return SpiderGameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress(PlayerProgress progress) {
    return _preferences.setString(_progressKey, progress.toEncodedJson());
  }

  Future<void> saveGame(SpiderGameState? game) async {
    if (game == null) {
      await _preferences.remove(_savedGameKey);
      return;
    }

    await _preferences.setString(_savedGameKey, game.toEncodedJson());
  }
}
