import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sons, música e vibração. Configurações salvas em SharedPreferences.
class Sfx {
  static bool music = true;
  static bool sound = true;
  static bool vibration = true;
  static bool _ready = false;
  static final Map<String, int> _last = {};

  static const files = ['click.wav', 'coin.wav', 'cash.wav', 'build.wav', 'upgrade.wav', 'alert.wav'];

  static Future<void> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    music = p.getBool('set_music') ?? true;
    sound = p.getBool('set_sound') ?? true;
    vibration = p.getBool('set_vibration') ?? true;
  }

  static Future<void> saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('set_music', music);
    await p.setBool('set_sound', sound);
    await p.setBool('set_vibration', vibration);
  }

  static Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll([...files, 'music.wav']);
      FlameAudio.bgm.initialize();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static void play(String file, {double volume = 0.55}) {
    if (!sound || !_ready) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[file] ?? 0) < 110) return; // evita empilhar sons iguais
    _last[file] = now;
    try {
      FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }

  static void startMusic() {
    if (!music || !_ready) return;
    try {
      FlameAudio.bgm.play('music.wav', volume: 0.3);
    } catch (_) {}
  }

  static void stopMusic() {
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }

  static void pauseMusic() {
    try {
      FlameAudio.bgm.pause();
    } catch (_) {}
  }

  static void resumeMusic() {
    if (!music) return;
    try {
      FlameAudio.bgm.resume();
    } catch (_) {}
  }

  static void click() {
    play('click.wav', volume: 0.4);
    haptic();
  }

  static void haptic() {
    if (vibration) HapticFeedback.lightImpact();
  }
}
