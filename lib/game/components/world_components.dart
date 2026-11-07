import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/format.dart';
import '../draw.dart';
import '../hospital_game.dart';

/// Terreno, ruas, estacionamento, entrada de ambulâncias, corredor e paredes
/// externas. Desenhado uma vez numa Picture (barato para celulares intermediários).
class Ground extends Component with HasGameReference<HospitalGame> {
  ui.Picture? _pic;
  int _unit = -1;
  Ground() {
    priority = 0;
  }

  static const _themes = [
    Color(0xFF7BC86C), Color(0xFF8BD3C7), Color(0xFF9CCC65), Color(0xFFA5D6A7),
    Color(0xFF80CBC4), Color(0xFFC5E1A5), Color(0xFFB39DDB),
  ];

  @override
  void render(Canvas c) {
    if (_pic == null || _unit != game.s.unit) {
      _unit = game.s.unit;
      _pic?.dispose();
      _pic = recordPicture(_draw);
    }
    c.drawPicture(_pic!);
  }

  void _draw(Canvas c) {
    final grass = _themes[(_unit - 1) % _themes.length];
    Iso.floor(c, -18, -12, 52, 46, grass);
    final rnd = math.Random(42);
    for (int i = 0; i < 420; i++) {
      final gx = -18.0 + rnd.nextDouble() * 52, gy = -12.0 + rnd.nextDouble() * 46;
      if (gx > -0.5 && gx < 21.5 && gy > 1.5 && gy < 14.5) continue;
      final p = Iso.p(gx, gy);
      Iso.ellipse(c, p, 6.0 + rnd.nextDouble() * 6, 3, Iso.shade(grass, -0.1 - rnd.nextDouble() * 0.08));
    }
    // Rua e calçada
    Iso.floor(c, -11.5, -12, 3, 46, const Color(0xFF5B6270));
    for (double gy = -12; gy < 34; gy += 1.5) {
      Iso.floor(c, -10.1, gy, 0.2, 0.7, const Color(0xFFFFF59D));
    }
    Iso.floor(c, -8.5, -12, 1, 46, const Color(0xFFCFD3D8));
    // Caminho até a entrada
    Iso.floor(c, -7.5, 7, 7.5, 2, const Color(0xFFE8DCC8));
    for (double gx = -7.5; gx < 0; gx += 1) {
      Iso.floor(c, gx, 7, 0.5, 2, const Color(0xFFDDCFB6));
    }
    // Estacionamento
    Iso.floor(c, -7.5, -1.5, 6.8, 7.8, const Color(0xFF6B7280));
    for (double gy = -1; gy <= 6; gy += 1.4) {
      Iso.floor(c, -7.2, gy, 2.6, 0.08, Colors.white);
      Iso.floor(c, -3.9, gy, 2.6, 0.08, Colors.white);
    }
    final carColors = [const Color(0xFFE53935), const Color(0xFF1E88E5), const Color(0xFFFDD835), const Color(0xFF8E24AA), const Color(0xFF43A047), const Color(0xFFFFFFFF)];
    int k = 0;
    for (double gy = -0.7; gy < 5.5; gy += 1.4) {
      for (final gx in [-6.8, -3.5]) {
        if (rnd.nextDouble() < 0.3) continue;
        _car(c, gx, gy, carColors[k++ % carColors.length]);
      }
    }
    TextCache.draw(c, 'P', Iso.p(-4.2, 6.7), 18, Colors.white, stroke: const Color(0xFF1565C0));
    // Entrada de ambulâncias
    Iso.floor(c, -7.5, 9.6, 6.8, 4.6, const Color(0xFFB0BEC5));
    Iso.floor(c, -7.5, 9.6, 6.8, 0.15, const Color(0xFFE53935));
    Iso.floor(c, -7.5, 14.05, 6.8, 0.15, const Color(0xFFE53935));
    Iso.paintOnWallX(c, Iso.p(-6.4, 11.4), (cc) {
      TextCache.draw(cc, 'EMERGÊNCIA', const Offset(60, 0), 15, const Color(0xFFE53935));
    });
    Iso.box(c, -1.4, 9.8, 0.2, 4.2, 4, const Color(0xFFFFFFFF));
    // Heliponto
    Iso.cylinder(c, 26, 5, 2.4, 6, const Color(0xFF90A4AE));
    TextCache.draw(c, 'H', Iso.p(26, 5, 7), 34, Colors.white, stroke: const Color(0xFFE53935));
    // Jardim e chafariz
    Iso.cylinder(c, 26, 16, 1.4, 8, const Color(0xFFB0BEC5));
    Iso.ellipse(c, Iso.p(26, 16, 8), 1.1 * Iso.tw, 1.1 * Iso.th, const Color(0xFF4FC3F7));
    Iso.cylinder(c, 26, 16, 0.25, 22, const Color(0xFFCFD8DC));
    for (double gy = 17; gy < 30; gy += 1.0) {
      Iso.floor(c, 8, gy, 1.2, 0.8, const Color(0xFFE8DCC8));
    }

    // ---------------- Prédio ----------------
    Iso.box(c, -0.3, 1.7, 21.6, 12.6, 6, const Color(0xFFBDBDBD), z: -6);
    // Corredor
    for (int i = 0; i < 21; i++) {
      for (int j = 0; j < 2; j++) {
        Iso.floor(c, i.toDouble(), 7.0 + j, 1, 1, (i + j).isEven ? const Color(0xFFF7F3EA) : const Color(0xFFE9E2D2));
      }
    }
    Iso.floor(c, 0, 7.92, 21, 0.16, const Color(0xFF90CAF9)); // faixa-guia
    // Paredes externas do fundo (altas)
    const wall = Color(0xFFF2EBDD);
    Iso.box(c, -0.25, 1.75, 21.25, 0.25, 70, wall, top: const Color(0xFF26A69A));
    Iso.box(c, -0.25, 2, 0.25, 5, 70, wall, top: const Color(0xFF26A69A));
    Iso.box(c, -0.25, 9, 0.25, 5, 70, wall, top: const Color(0xFF26A69A));
    Iso.box(c, -0.25, 7, 0.25, 2, 26, wall, z: 44, top: const Color(0xFF26A69A));
    // janelas
    for (double gx = 5.5; gx < 21; gx += 2) {
      Iso.faceX(c, gx, gx + 1.1, 2.0, 30, 56, const Color(0xFF9ED8F0));
      Iso.faceX(c, gx + 0.52, gx + 0.58, 2.0, 30, 56, Colors.white);
    }
    for (final gy in [3.0, 5.0, 10.0, 12.0]) {
      Iso.faceY(c, gy, gy + 1.1, 0.0, 30, 56, const Color(0xFF9ED8F0));
    }
    // Letreiro pintado na parede
    Iso.paintOnWallX(c, Iso.p(4.6, 2.0, 70), (cc) {
      TextCache.draw(cc, 'HOSPITAL EMPIRE', const Offset(118, 14), 24, const Color(0xFF19B5A5),
          stroke: const Color(0xFF0D5E56));
    });
    // Cruz na fachada
    final cross = Iso.p(2.4, 2.0, 50);
    Iso.rrect(c, Rect.fromCenter(center: cross, width: 8, height: 26), 2, const Color(0xFFE53935));
    Iso.rrect(c, Rect.fromCenter(center: cross, width: 26, height: 8), 2, const Color(0xFFE53935));
    // Portas automáticas da entrada
    Iso.faceY(c, 7.1, 8.9, 0.0, 0, 42, const Color(0x5590CAF9));
    // Marquise
    Iso.box(c, -2.2, 6.6, 2.2, 2.8, 4, const Color(0xFF19B5A5), z: 46);
    for (final gy in [6.7, 9.2]) {
      final b = Iso.p(-2.0, gy), t = Iso.p(-2.0, gy, 46);
      Iso.rrect(c, Rect.fromLTRB(b.dx - 2, t.dy, b.dx + 2, b.dy), 1, const Color(0xFFECEFF1));
    }
  }

  void _car(Canvas c, double gx, double gy, Color col) {
    Iso.box(c, gx, gy, 2.2, 0.9, 9, col, z: 2);
    Iso.box(c, gx + 0.5, gy + 0.08, 1.1, 0.74, 7, Iso.shade(col, 0.2), z: 11);
    Iso.faceX(c, gx + 0.55, gx + 1.55, gy + 0.82, 12, 17, const Color(0xFF90CAF9));
  }
}

/// Paredes baixas da frente: desenhadas por cima das salas.
class FrontWalls extends Component {
  ui.Picture? _pic;
  FrontWalls() {
    priority = 900;
  }
  @override
  void render(Canvas c) {
    _pic ??= recordPicture((pc) {
      const wall = Color(0xFFF2EBDD);
      Iso.box(pc, 0, 14, 21.25, 0.25, 10, wall, top: const Color(0xFF26A69A));
      Iso.box(pc, 21, 1.75, 0.25, 12.25, 10, wall, top: const Color(0xFF26A69A));
    });
    c.drawPicture(_pic!);
  }
}

/// Recepção: balcão, recepcionista, cadeiras de espera.
class ReceptionComponent extends Component with HasGameReference<HospitalGame> {
  ui.Picture? _pic;
  int _tier = -1;
  ReceptionComponent() {
    priority = 10;
  }

  static final deskSpot = Vector2(2.15, 4.0);
  static final chairs = <Vector2>[
    for (final yy in [5.3, 6.3])
      for (final xx in [0.8, 1.7, 2.6, 3.5, 4.4]) Vector2(xx, yy),
  ];

  bool contains(Vector2 gp) => gp.x >= 0 && gp.x <= 5 && gp.y >= 2 && gp.y <= 7;

  @override
  void render(Canvas c) {
    final tier = Eco.tier(game.s.receptionLevel);
    if (_pic == null || tier != _tier) {
      _tier = tier;
      _pic?.dispose();
      _pic = recordPicture(_draw);
    }
    c.drawPicture(_pic!);
    final q = game.queue.length, max = Eco.queueMax(game.s);
    TextCache.pill(c, 'Recepção  Nv ${game.s.receptionLevel}', Iso.p(2.5, 3.2, 64), 10,
        const Color(0xFFE91E63), Colors.white);
    TextCache.draw(c, 'Fila $q/$max', Iso.p(2.5, 3.2, 47), 9,
        q >= max ? const Color(0xFFFF8A80) : Colors.white,
        stroke: const Color(0xFF23314D));
    // barra de check-in
    final prog = game.checkinProgress;
    if (prog > 0) {
      final r = Rect.fromCenter(center: Iso.p(2.5, 2.9, 36), width: 44, height: 6);
      Iso.rrect(c, r.inflate(1.5), 4, const Color(0xFF23314D));
      Iso.rrect(c, Rect.fromLTWH(r.left, r.top, r.width * prog.clamp(0, 1), r.height), 3,
          const Color(0xFFFF80AB));
    }
  }

  void _draw(Canvas c) {
    final f1 = _tier >= 2 ? const Color(0xFFFFE4EC) : const Color(0xFFFFF0E0);
    final f2 = Iso.shade(f1, -0.06);
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        Iso.floor(c, i.toDouble(), 2.0 + j, 1, 1, (i + j).isEven ? f1 : f2);
      }
    }
    if (_tier >= 1) Iso.floor(c, 0.5, 4.9, 4.4, 1.9, const Color(0xFFF8BBD0));
    Iso.box(c, 4.92, 2, 0.16, 5, 18, const Color(0xFFF5F0E6));
    // Balcão
    final wood = _tier >= 3 ? const Color(0xFF5D4037) : const Color(0xFFE91E63);
    Iso.box(c, 1.2, 2.9, 2.6, 0.55, 18, wood, top: const Color(0xFFFFFFFF));
    Iso.box(c, 1.6, 2.95, 0.4, 0.1, 10, const Color(0xFF263238), z: 18);
    Iso.box(c, 2.9, 2.95, 0.4, 0.1, 10, const Color(0xFF263238), z: 18);
    // Cadeiras de espera
    for (final ch in chairs) {
      Iso.box(c, ch.x - 0.3, ch.y - 0.1, 0.6, 0.45, 7, const Color(0xFF26A69A));
      Iso.box(c, ch.x - 0.3, ch.y - 0.15, 0.6, 0.1, 16, const Color(0xFF00897B));
    }
    // Bebedouro e plantas
    Iso.box(c, 4.3, 2.3, 0.4, 0.4, 22, const Color(0xFFECEFF1));
    Iso.cylinder(c, 4.5, 2.5, 0.16, 10, const Color(0xFF81D4FA), z: 22);
    if (_tier >= 1) {
      Iso.cylinder(c, 0.4, 2.4, 0.22, 9, const Color(0xFFD7744A));
      Iso.circle(c, Iso.p(0.4, 2.4, 18), 10, const Color(0xFF43A047));
    }
    if (_tier >= 2) {
      Iso.box(c, 0.2, 4.0, 0.2, 0.9, 30, const Color(0xFF263238));
      Iso.faceY(c, 4.05, 4.85, 0.4, 12, 28, const Color(0xFF4FC3F7));
    }
    if (_tier >= 3) {
      Iso.cylinder(c, 4.4, 4.2, 0.3, 4, const Color(0xFFFFC107));
      Iso.circle(c, Iso.p(4.4, 4.2, 14), 8, const Color(0xFFFFD54F));
    }
  }
}

/// Tesouraria: cofre, pilhas de moedas que crescem com o saldo.
class TreasuryComponent extends Component with HasGameReference<HospitalGame> {
  ui.Picture? _pic;
  TreasuryComponent() {
    priority = 10;
  }

  static final depositSpot = Vector2(2.5, 10.6);
  static Vector2 home(int i) => Vector2(0.7 + i * 0.75, 12.8);

  bool contains(Vector2 gp) => gp.x >= 0 && gp.x <= 5 && gp.y >= 9 && gp.y <= 14;

  @override
  void render(Canvas c) {
    _pic ??= recordPicture(_draw);
    c.drawPicture(_pic!);
    final s = game.s;
    final max = Eco.treasuryMax(s);
    final ratio = (s.treasury / max).clamp(0.0, 1.0).toDouble();
    final piles = (ratio * 8).ceil();
    for (int k = 0; k < piles; k++) {
      Iso.cylinder(c, 1.0 + (k % 4) * 0.45, 11.4 + (k ~/ 4) * 0.5, 0.2, 4.0 + ratio * 14,
          const Color(0xFFFFC83D));
    }
    TextCache.pill(c, 'Tesouraria  Nv ${s.treasuryLevel}', Iso.p(2.5, 11.5, 66), 10,
        const Color(0xFF8D6E63), Colors.white);
    TextCache.draw(c, '\$${fmt(s.treasury)} / ${fmt(max)}', Iso.p(2.5, 11.5, 49), 9,
        ratio >= 1 ? const Color(0xFFFF8A80) : const Color(0xFFFFE082),
        stroke: const Color(0xFF23314D));
  }

  void _draw(Canvas c) {
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        Iso.floor(c, i.toDouble(), 9.0 + j, 1, 1, (i + j).isEven ? const Color(0xFFEFE6D8) : const Color(0xFFE2D6C3));
      }
    }
    Iso.box(c, 4.92, 9, 0.16, 5, 18, const Color(0xFFF5F0E6));
    for (final seg in [[0.0, 2.0], [3.0, 2.0]]) {
      Iso.box(c, seg[0], 8.94, seg[1], 0.12, 8, const Color(0xFFF5F0E6));
      Iso.box(c, seg[0], 8.94, seg[1], 0.12, 12, const Color(0x88FFE082), z: 8, outline: false);
    }
    // Cofre
    Iso.box(c, 3.2, 11.0, 1.4, 1.4, 34, const Color(0xFF78909C), top: const Color(0xFF90A4AE));
    final door = Iso.p(3.2, 11.7, 17);
    Iso.ellipse(c, door, 22, 30, const Color(0xFF546E7A));
    Iso.ellipse(c, door, 12, 16, const Color(0xFFFFC107));
    // Mesa de contagem
    Iso.box(c, 0.6, 9.6, 1.4, 0.6, 14, const Color(0xFF8D6E63), top: const Color(0xFF4CAF50));
  }
}

class Tree extends Component {
  final Vector2 g;
  final double size;
  final double seed;
  double _t = 0;
  Tree(this.g, {this.size = 1}) : seed = math.Random().nextDouble() * 10 {
    priority = 1000 + ((g.x + g.y) * 20).toInt();
  }
  @override
  void update(double dt) => _t += dt;
  @override
  void render(Canvas c) {
    final k = size;
    final b = Iso.p(g.x, g.y);
    Iso.ellipse(c, b, k * 40, k * 16, const Color(0x33000000));
    Iso.rrect(c, Rect.fromLTRB(b.dx - k * 3, b.dy - k * 26, b.dx + k * 3, b.dy), 2,
        const Color(0xFF8D6E63));
    final sway = math.sin(_t * 1.4 + seed) * 1.5;
    final top = b.translate(sway, -k * 36);
    Iso.circle(c, top, k * 17, const Color(0xFF2E7D32));
    Iso.circle(c, top.translate(-k * 8, k * 6), k * 12, const Color(0xFF388E3C));
    Iso.circle(c, top.translate(k * 8, k * 5), k * 12, const Color(0xFF43A047));
    Iso.circle(c, top.translate(-k * 3, -k * 6), k * 9, const Color(0xFF66BB6A));
  }
}

/// Ambulância que chega com pacientes de emergência.
class Ambulance extends Component {
  final Vector2 g;
  final List<Vector2> _path;
  final VoidCallback? onArrive;
  final VoidCallback? onDone;
  double _t = 0;
  double _wait = -1;
  bool _arrived = false;
  bool alongX = false;

  Ambulance({this.onArrive, this.onDone})
      : g = Vector2(-10.6, -12),
        _path = [Vector2(-10.6, 11.8), Vector2(-4.8, 11.8)];

  @override
  void update(double dt) {
    _t += dt;
    priority = 1000 + ((g.x + g.y) * 20).toInt();
    if (_wait > 0) {
      _wait -= dt;
      if (_wait <= 0) {
        _path.addAll([Vector2(-10.6, 11.8), Vector2(-10.6, 34)]);
      }
      return;
    }
    if (_path.isEmpty) {
      if (!_arrived) {
        _arrived = true;
        onArrive?.call();
        _wait = 3;
      } else {
        onDone?.call();
        removeFromParent();
      }
      return;
    }
    final t = _path.first;
    final d = t - g;
    final step = dt * 6;
    if (d.length <= step) {
      g.setFrom(t);
      _path.removeAt(0);
    } else {
      g.add(d.normalized() * step);
      alongX = d.x.abs() > d.y.abs();
    }
  }

  @override
  void render(Canvas c) {
    final w = alongX ? 2.0 : 0.9, d = alongX ? 0.9 : 2.0;
    final x = g.x - w / 2, y = g.y - d / 2;
    Iso.ellipse(c, Iso.p(g.x, g.y), 80, 30, const Color(0x33000000));
    Iso.box(c, x, y, w, d, 22, Colors.white, z: 3);
    if (alongX) {
      Iso.faceX(c, x, x + w, y + d, 10, 14, const Color(0xFFE53935));
    } else {
      Iso.faceY(c, y, y + d, x + w, 10, 14, const Color(0xFFE53935));
    }
    final light = Iso.p(g.x, g.y, 28);
    final on = (_t * 6).floor().isEven;
    Iso.circle(c, light.translate(-5, 0), 3.5, on ? const Color(0xFFFF1744) : const Color(0xFF2979FF));
    Iso.circle(c, light.translate(5, 0), 3.5, on ? const Color(0xFF2979FF) : const Color(0xFFFF1744));
    TextCache.draw(c, '✚', Iso.p(g.x, g.y, 25), 12, const Color(0xFFE53935));
  }
}

/// Texto flutuante (+$, NÍVEL, avisos).
class FloatingText extends Component {
  final Offset origin;
  final String text;
  final Color color;
  final double size;
  double _t = 0;
  static const life = 1.3;
  FloatingText(this.origin, this.text, this.color, {this.size = 11}) {
    priority = 5000;
  }
  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas c) {
    final k = _t / life;
    final a = (((1 - k) * 255).clamp(0, 255).toInt() ~/ 32) * 32 + 31;
    final scale = k < 0.15 ? 0.6 + k / 0.15 * 0.5 : 1.1 - (k - 0.15) * 0.1;
    c.save();
    c.translate(origin.dx, origin.dy - 48 - k * 42);
    c.scale(scale, scale);
    TextCache.draw(c, text, Offset.zero, size, color.withAlpha(a),
        stroke: const Color(0xFF23314D).withAlpha(a));
    c.restore();
  }
}
