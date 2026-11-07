import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// Salvamento com cópia de segurança alternada: se o save principal
/// corromper (app fechado no meio da gravação), o backup é usado.
class SaveService {
  static const _main = 'he_save_main';
  static const _backup = 'he_save_backup';
  static int _count = 0;
  static bool _wiped = false;

  static Future<GameState> load() async {
    final p = await SharedPreferences.getInstance();
    for (final key in [_main, _backup]) {
      final raw = p.getString(key);
      if (raw == null) continue;
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        return GameState.fromJson(j);
      } catch (_) {
        // tenta o próximo
      }
    }
    return GameState();
  }

  static Future<void> save(GameState s) async {
    if (_wiped) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode(s.toJson());
      await p.setString(_main, raw);
      if (_count++ % 4 == 0) await p.setString(_backup, raw);
      s.lastSaveMs = DateTime.now().millisecondsSinceEpoch;
    } catch (_) {}
  }

  static Future<void> wipe() async {
    _wiped = true;
    final p = await SharedPreferences.getInstance();
    await p.remove(_main);
    await p.remove(_backup);
  }
}
