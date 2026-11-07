import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/economy.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../draw.dart';
import '../hospital_game.dart';
import 'person.dart';

/// Uma sala do hospital: piso, divisórias, equipamentos que evoluem por nível,
/// vagas de atendimento, médico, gerente e pilha de dinheiro.
class RoomComponent extends Component with HasGameReference<HospitalGame> {
  final RoomType type;
  final Plot plot;

  ui.Picture? _pic;
  String _picKey = '';
  double stash = 0;
  bool claimed = false;
  final List<Patient?> occupants = List<Patient?>.filled(4, null);
  final List<double> progress = List<double>.filled(4, 0);
  final List<bool> serving = List<bool>.filled(4, false);
  double buildAnim = 0;
  double sparkle = 0;
  Person? doctor;
  Person? managerFig;
  bool _init = false;
  bool _lastBuilt = false;
  int _lastLevel = 1;
  double _t = 0;

  RoomComponent(this.type) : plot = plots[type.plot] {
    priority = 10;
  }

  RoomSave get save => game.s.room(type.id);
  bool get built => save.built;
  bool get operational => built && buildAnim <= 0;
  int get slots => Eco.roomSlots(save.level);
  double get x => plot.x;
  double get y => plot.y;

  Vector2 get corridorPoint => Vector2(x + 2, 8);
  Vector2 get doorPoint => plot.top ? Vector2(x + 2, y + 4.75) : Vector2(x + 2, y + 0.3);
  Vector2 stationOrigin(int i) => Vector2(x + 0.4 + i * 0.9, plot.top ? y + 0.9 : y + 1.0);
  Vector2 patientSpot(int i) => stationOrigin(i) + Vector2(0.36, 1.5);
  Vector2 get doctorSpot => Vector2(x + 3.65, plot.top ? y + 3.7 : y + 4.4);
  Vector2 get managerSpot => Vector2(x + 0.55, plot.top ? y + 4.2 : y + 4.5);
  Vector2 get stashSpot => plot.top ? Vector2(x + 3.2, y + 4.3) : Vector2(x + 0.9, y + 0.45);

  bool contains(Vector2 gp) =>
      gp.x >= x && gp.x <= x + plotW && gp.y >= y && gp.y <= y + plotD;

  int freeSlot() {
    if (!operational) return -1;
    for (int i = 0; i < slots; i++) {
      if (occupants[i] == null) return i;
    }
    return -1;
  }

  void reserve(int i, Patient p) {
    occupants[i] = p;
    progress[i] = 0;
    serving[i] = false;
  }

  void beginService(int i) => serving[i] = true;
  double slotProgress(int i) => progress[i];

  double take(double max) {
    final v = math.min(stash, max);
    stash -= v;
    return v;
  }

  /// Limpa a sala (ex.: prestígio).
  void resetRuntime() {
    stash = 0;
    for (int i = 0; i < 4; i++) {
      occupants[i] = null;
      serving[i] = false;
      progress[i] = 0;
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    final b = built;
    final lvl = save.level;
    if (!_init) {
      _init = true;
      _lastBuilt = b;
      _lastLevel = lvl;
    }
    if (b && !_lastBuilt) {
      buildAnim = 2.6;
      game.cameraFocus(Vector2(x + 2, y + 2.5));
    }
    if (b && lvl != _lastLevel && Eco.tier(lvl) != Eco.tier(_lastLevel)) sparkle = 1.6;
    if (b && lvl > _lastLevel) {
      game.floatText(Vector2(x + 2, y + 2.5), 'NÍVEL $lvl', const Color(0xFF7CFFB2), size: 13);
    }
    _lastBuilt = b;
    _lastLevel = lvl;
    if (sparkle > 0) sparkle -= dt;

    if (buildAnim > 0) {
      buildAnim -= dt;
      if (buildAnim <= 0) {
        Sfx.play('build.wav');
        game.floatText(Vector2(x + 2, y + 2.5), '${type.name} pronto!', Colors.white, size: 13);
        sparkle = 1.6;
      }
    }

    _syncStaff();

    bool anyServing = false;
    for (int i = 0; i < 4; i++) {
      if (!serving[i]) continue;
      anyServing = true;
      progress[i] += dt / Eco.roomTime(game.s, type, lvl);
      if (progress[i] >= 1) _complete(i);
    }
    if (doctor != null && !doctor!.moving) {
      doctor!.anim = anyServing ? Anim.work : Anim.idle;
    }
  }

  void _syncStaff() {
    if (operational && doctor == null) {
      final nurseRooms = ['enfermaria', 'uti', 'maternidade', 'farmacia'];
      doctor = Person(doctorSpot, nurseRooms.contains(type.id) ? Role.nurse : Role.doctor)
        ..facingLeft = true;
      game.world.add(doctor!);
    } else if (!built && doctor != null) {
      doctor!.removeFromParent();
      doctor = null;
    }
    final m = built ? game.s.activeManager(type.id) : null;
    if (m != null && managerFig == null) {
      managerFig = Person(managerSpot, Role.manager, accent: m.color);
      game.world.add(managerFig!);
    } else if (m == null && managerFig != null) {
      managerFig!.removeFromParent();
      managerFig = null;
    } else if (m != null && managerFig != null && managerFig!.accent != m.color) {
      managerFig!.accent = m.color;
    }
    // O gerente circula de vez em quando pela sala
    if (managerFig != null && !managerFig!.moving && math.Random().nextDouble() < 0.004) {
      final target = managerFig!.g.distanceTo(managerSpot) < 0.1
          ? Vector2(x + 2.2, plot.top ? y + 3.9 : y + 4.3)
          : managerSpot;
      managerFig!.speed = 0.9;
      managerFig!.walkTo([target], onArrive: () => managerFig?.talk(1.2));
    }
  }

  void _complete(int i) {
    final p = occupants[i];
    serving[i] = false;
    progress[i] = 0;
    occupants[i] = null;
    if (p == null) return;
    final mult = p.vip ? 10.0 : p.emergency ? 5.0 : 1.0;
    final pay = Eco.roomIncome(game.s, type, save.level) * mult;
    stash += pay;
    game.s.onPatientServed(vip: p.vip, emergency: p.emergency);
    game.floatText(patientSpot(i), '+\$${fmt(pay)}',
        p.vip ? const Color(0xFFFFD700) : const Color(0xFF9CFF6B));
    Sfx.play('coin.wav', volume: 0.25);
    p.celebrate();
    doctor?.celebrate(0.5);
    if (p.emergency) game.onEmergencyTreated(p);
    if (p.vip && math.Random().nextDouble() < 0.25) {
      game.s.addCard(math.Random().nextInt(cardDefs.length));
    }
    game.patientLeaves(p, this, i);
  }

  // ------------------------------------------------------------ desenho
  @override
  void render(Canvas c) {
    final lvl = save.level;
    final key = built ? 'b${Eco.roomSlots(lvl)}t${Eco.tier(lvl)}' : 'locked';
    if (_pic == null || key != _picKey) {
      _pic?.dispose();
      _pic = recordPicture((pc) => built ? _drawRoom(pc, lvl) : _drawLot(pc));
      _picKey = key;
    }
    if (built && buildAnim > 0) {
      _drawLot(c);
      _drawConstruction(c);
      return;
    }
    c.drawPicture(_pic!);
    if (!built) {
      _drawLockedSign(c);
      return;
    }
    // Pilha de dinheiro aguardando o carregador
    if (stash > 0.5) {
      final n = (1 + math.log(stash + 1) / math.ln10).clamp(1, 6).toInt();
      final sp = stashSpot;
      for (int k = 0; k < n; k++) {
        Iso.cylinder(c, sp.x + (k % 2) * 0.22, sp.y + (k ~/ 2) * 0.12, 0.2, 5,
            const Color(0xFFFFC83D), z: 4.0 * (k ~/ 2));
      }
      TextCache.pill(c, '\$${fmt(stash)}', Iso.p(sp.x, sp.y, 30), 9,
          const Color(0xFFFFF4C2), const Color(0xFF6D4C00));
    }
    // Placa da sala
    final label = Iso.p(x + 2, y + 2.5, plot.top ? 62 : 58);
    TextCache.pill(c, '${type.name}  Nv $lvl', label, 10, type.accent, Colors.white);
    final tier = Eco.tier(lvl);
    for (int s = 0; s < tier; s++) {
      TextCache.draw(c, '★', label.translate(-10.0 + s * 10, -13), 10, const Color(0xFFFFD700),
          stroke: const Color(0xFF6D4C00));
    }
    if (sparkle > 0) _drawSparkle(c);
  }

  void _drawSparkle(Canvas c) {
    final rnd = math.Random(7);
    for (int i = 0; i < 14; i++) {
      final gx = x + rnd.nextDouble() * 4, gy = y + rnd.nextDouble() * 5;
      final h = 10.0 + ((1.6 - sparkle) * 40 + rnd.nextDouble() * 30) % 60;
      final a = ((sparkle / 1.6 * 255).clamp(0, 255).toInt() ~/ 32) * 32 + 31;
      TextCache.draw(c, '✦', Iso.p(gx, gy, h), i.isEven ? 12 : 15,
          const Color(0xFFFFF59D).withAlpha(a));
    }
  }

  void _drawLot(Canvas c) {
    Iso.floor(c, x, y, plotW, plotD, const Color(0xFFB0B4BA));
    for (int i = 0; i < 8; i++) {
      final yy = y + i * (plotD / 8);
      Iso.floor(c, x, yy, 0.18, plotD / 16, i.isEven ? const Color(0xFFFFC400) : const Color(0xFF2B2B2B));
      Iso.floor(c, x + plotW - 0.18, yy, 0.18, plotD / 16, i.isEven ? const Color(0xFF2B2B2B) : const Color(0xFFFFC400));
    }
    for (int i = 0; i < 6; i++) {
      final xx = x + i * (plotW / 6);
      Iso.floor(c, xx, y, plotW / 12, 0.18, i.isEven ? const Color(0xFFFFC400) : const Color(0xFF2B2B2B));
      Iso.floor(c, xx, y + plotD - 0.18, plotW / 12, 0.18, i.isEven ? const Color(0xFF2B2B2B) : const Color(0xFFFFC400));
    }
    // cones
    for (final o in [Offset(x + 0.5, y + 0.5), Offset(x + 3.5, y + 4.5)]) {
      final b = Iso.p(o.dx, o.dy);
      Iso.poly(c, [b.translate(-5, 0), b.translate(5, 0), b.translate(0, -14)], const Color(0xFFFF6D00));
      Iso.poly(c, [b.translate(-3, -5), b.translate(3, -5), b.translate(2, -8), b.translate(-2, -8)], Colors.white);
    }
    // sacos de cimento
    Iso.box(c, x + 2.8, y + 0.6, 0.6, 0.4, 7, const Color(0xFFD7CCC8));
  }

  void _drawLockedSign(Canvas c) {
    final s = game.s;
    final reason = s.lockReason(type);
    final center = Iso.p(x + 2, y + 2.5, 26);
    // poste da placa
    final base = Iso.p(x + 2, y + 2.5);
    Iso.rrect(c, Rect.fromLTRB(base.dx - 1.5, center.dy, base.dx + 1.5, base.dy), 1, const Color(0xFF6D4C41));
    if (reason != null) {
      TextCache.pill(c, '🔒 ${type.name}', center, 10, const Color(0xFF546E7A), Colors.white);
      TextCache.draw(c, reason, center.translate(0, 18), 8, Colors.white, stroke: const Color(0xFF23314D));
    } else {
      final can = s.money >= type.buildCost;
      final pulse = can ? 1.0 + 0.06 * math.sin(_t * 6) : 1.0;
      c.save();
      c.translate(center.dx, center.dy);
      c.scale(pulse, pulse);
      TextCache.pill(c, '🏗️ ${type.name}', Offset.zero, 10,
          can ? const Color(0xFF2ECC71) : const Color(0xFF90A4AE), Colors.white);
      c.restore();
      TextCache.draw(c, '\$${fmt(type.buildCost)}', center.translate(0, 18), 10,
          can ? const Color(0xFFB9FF9E) : Colors.white, stroke: const Color(0xFF23314D));
    }
  }

  void _drawConstruction(Canvas c) {
    final prog = 1.0 - buildAnim / 2.6;
    final h = 10.0 + prog * 50;
    const wood = Color(0xFFB07B4A);
    for (final px in [x + 0.3, x + 3.6]) {
      for (final py in [y + 0.3, y + 4.6]) {
        final b = Iso.p(px, py), t = Iso.p(px, py, h);
        Iso.rrect(c, Rect.fromLTRB(b.dx - 1.5, t.dy, b.dx + 1.5, b.dy), 1, const Color(0xFF78909C));
      }
    }
    Iso.box(c, x + 0.3, y + 0.3, 3.4, 4.4, 3, wood, z: h * 0.5);
    Iso.box(c, x + 0.3, y + 0.3, 3.4, 4.4, 3, wood, z: h);
    // operário martelando
    final hp = Iso.p(x + 2, y + 2.5, h + 10 + (math.sin(_t * 18).abs() * 6));
    TextCache.draw(c, '🔨', hp, 16, Colors.black);
    final bar = Rect.fromCenter(center: Iso.p(x + 2, y + 2.5, h + 34), width: 70, height: 9);
    Iso.rrect(c, bar.inflate(2), 6, const Color(0xFF23314D));
    Iso.rrect(c, Rect.fromLTWH(bar.left, bar.top, bar.width * prog, bar.height), 5, const Color(0xFF4CD964));
  }

  void _drawRoom(Canvas c, int lvl) {
    final tier = Eco.tier(lvl);
    final f = type.floor;
    final alt = Iso.shade(f, tier >= 2 ? -0.1 : -0.05);
    // Piso quadriculado (fica mais sofisticado com o nível)
    for (int i = 0; i < plotW; i++) {
      for (int j = 0; j < plotD; j++) {
        Iso.floor(c, x + i, y + j, 1, 1, (i + j).isEven ? f : alt);
      }
    }
    if (tier >= 1) {
      Iso.floor(c, x + 0.9, y + 2.6, 2.2, 1.4, Iso.shade(type.accent, 0.55));
    }
    final wallCol = tier >= 3 ? const Color(0xFFFFF8E1) : const Color(0xFFF5F0E6);
    final trim = tier >= 3 ? const Color(0xFFFFC107) : Iso.shade(type.accent, 0.2);
    // Divisória esquerda (baixa, estilo "casa de bonecas")
    Iso.box(c, x - 0.08, y, 0.16, plotD, 18, wallCol);
    Iso.box(c, x - 0.08, y, 0.16, plotD, 3, trim, z: 18);
    if (plot.top) {
      // frente com porta
      Iso.box(c, x, y + plotD - 0.12, 1.5, 0.12, 12, wallCol);
      Iso.box(c, x + 2.5, y + plotD - 0.12, 1.5, 0.12, 12, wallCol);
      Iso.box(c, x + 1.5, y + plotD - 0.12, 0.08, 0.12, 30, trim);
      Iso.box(c, x + 2.42, y + plotD - 0.12, 0.08, 0.12, 30, trim);
      Iso.box(c, x + 1.5, y + plotD - 0.12, 1.0, 0.12, 4, trim, z: 30);
    } else {
      // divisória de vidro do corredor com porta
      for (final seg in [[0.0, 1.5], [2.5, 1.5]]) {
        Iso.box(c, x + seg[0], y - 0.06, seg[1], 0.12, 8, wallCol);
        Iso.box(c, x + seg[0], y - 0.06, seg[1], 0.12, 12, const Color(0x8899D9F0), z: 8, outline: false);
      }
      Iso.box(c, x + 1.5, y - 0.06, 0.08, 0.12, 30, trim);
      Iso.box(c, x + 2.42, y - 0.06, 0.08, 0.12, 30, trim);
      Iso.box(c, x + 1.5, y - 0.06, 1.0, 0.12, 4, trim, z: 30);
    }
    // Decoração por nível
    final cornerY = plot.top ? y + 0.3 : y + 0.45;
    if (tier >= 1) _plant(c, x + 3.6, cornerY);
    if (tier >= 2) {
      Iso.box(c, x + 0.15, plot.top ? y + 3.4 : y + 3.6, 0.35, 0.8, 26, const Color(0xFFECEFF1));
      Iso.faceY(c, plot.top ? y + 3.5 : y + 3.7, plot.top ? y + 4.1 : y + 4.3, x + 0.5, 6, 22,
          Iso.shade(type.accent, 0.3));
      _plant(c, plot.top ? x + 0.4 : x + 0.3, plot.top ? y + 0.3 : y + 4.6);
    }
    if (tier >= 3) {
      final gp = Iso.p(x + 2, y + 2.5, 50);
      final glow = Paint()
        ..shader = RadialGradient(colors: [const Color(0x66FFF59D), const Color(0x00FFF59D)])
            .createShader(Rect.fromCircle(center: gp.translate(0, 30), radius: 80));
      c.drawCircle(gp.translate(0, 30), 80, glow);
      final sx = plot.top ? x + 0.3 : x + 3.7, sy = plot.top ? y + 2.6 : y + 3.2;
      Iso.cylinder(c, sx, sy, 0.18, 22, const Color(0xFFFFC107));
      Iso.circle(c, Iso.p(sx, sy, 28), 6, const Color(0xFFFFD54F));
    }
    // Estações de atendimento (vagas liberadas e futuras)
    final open = Eco.roomSlots(lvl);
    for (int i = 0; i < 4; i++) {
      final o = stationOrigin(i);
      if (i < open) {
        _station(c, o.x, o.y, tier);
      } else {
        Iso.floor(c, o.x, o.y, 0.72, 1.0, const Color(0x2223314D));
        final cp = Iso.p(o.x + 0.36, o.y + 0.5);
        TextCache.draw(c, '+', cp, 14, const Color(0x6623314D));
      }
    }
  }

  void _plant(Canvas c, double gx, double gy) {
    Iso.cylinder(c, gx, gy, 0.22, 9, const Color(0xFFD7744A));
    final top = Iso.p(gx, gy, 18);
    Iso.circle(c, top, 9, const Color(0xFF43A047));
    Iso.circle(c, top.translate(-5, 4), 6, const Color(0xFF66BB6A));
    Iso.circle(c, top.translate(5, 3), 6, const Color(0xFF2E7D32));
  }

  void _station(Canvas c, double sx, double sy, int tier) {
    final acc = type.accent;
    final metal = tier >= 2 ? const Color(0xFFCFD8DC) : const Color(0xFFB0BEC5);
    switch (type.station) {
      case StationKind.desk:
        Iso.box(c, sx, sy, 0.72, 0.45, 15, tier >= 3 ? const Color(0xFF6D4C41) : const Color(0xFFA1887F));
        Iso.box(c, sx + 0.2, sy + 0.05, 0.3, 0.08, 10, const Color(0xFF263238), z: 15);
        Iso.box(c, sx + 0.2, sy + 0.8, 0.32, 0.32, 8, acc);
        break;
      case StationKind.bench:
        Iso.box(c, sx, sy, 0.72, 0.6, 16, Colors.white, top: const Color(0xFFE0E0E0));
        for (int k = 0; k < 3; k++) {
          Iso.cylinder(c, sx + 0.15 + k * 0.22, sy + 0.25, 0.08, 7,
              [const Color(0xFF7E57C2), const Color(0xFF26C6DA), const Color(0xFFFF7043)][k], z: 16);
        }
        if (tier >= 1) Iso.box(c, sx + 0.1, sy + 0.05, 0.25, 0.2, 9, const Color(0xFF455A64), z: 16);
        break;
      case StationKind.shelf:
        Iso.box(c, sx, sy, 0.72, 0.32, 34, const Color(0xFFECEFF1));
        for (int r = 0; r < 3; r++) {
          for (int k = 0; k < 3; k++) {
            Iso.faceX(c, sx + 0.06 + k * 0.22, sx + 0.22 + k * 0.22, sy + 0.32, 4.0 + r * 10.0, 11.0 + r * 10.0,
                [const Color(0xFF66BB6A), const Color(0xFFEF5350), const Color(0xFF42A5F5)][(k + r) % 3]);
          }
        }
        Iso.box(c, sx + 0.1, sy + 0.75, 0.5, 0.3, 12, acc);
        break;
      case StationKind.bed:
        Iso.box(c, sx, sy, 0.7, 1.1, 10, metal);
        Iso.box(c, sx + 0.04, sy + 0.04, 0.62, 1.02, 3, Colors.white, z: 10);
        Iso.box(c, sx + 0.1, sy + 0.08, 0.5, 0.25, 3, const Color(0xFFFFFFFF), z: 13);
        Iso.box(c, sx + 0.04, sy + 0.45, 0.62, 0.6, 2, acc, z: 13);
        break;
      case StationKind.scanner:
        Iso.box(c, sx, sy, 0.72, 0.8, 22, const Color(0xFFECEFF1));
        Iso.ellipse(c, Iso.p(sx + 0.36, sy + 0.8, 12), 26, 18, const Color(0xFF37474F));
        Iso.ellipse(c, Iso.p(sx + 0.36, sy + 0.8, 12), 16, 10, acc);
        break;
      case StationKind.surgery:
        Iso.box(c, sx + 0.1, sy + 0.1, 0.5, 0.9, 12, const Color(0xFF80CBC4));
        final lamp = Iso.p(sx + 0.36, sy + 0.5, 48);
        Iso.circle(c, lamp, 8, const Color(0xFFB0BEC5));
        Iso.circle(c, lamp, 5, const Color(0xFFFFF9C4));
        break;
      case StationKind.monitor:
        Iso.box(c, sx, sy, 0.7, 1.1, 10, metal);
        Iso.box(c, sx + 0.04, sy + 0.45, 0.62, 0.6, 3, acc, z: 10);
        Iso.box(c, sx + 0.02, sy + 0.02, 0.2, 0.16, 18, const Color(0xFF263238), z: 10);
        Iso.faceX(c, sx + 0.04, sx + 0.2, sy + 0.18, 18, 26, const Color(0xFF00E676));
        break;
      case StationKind.crib:
        Iso.box(c, sx + 0.08, sy + 0.1, 0.56, 0.8, 12, const Color(0xFFFFFFFF));
        Iso.box(c, sx + 0.12, sy + 0.14, 0.48, 0.72, 2, const Color(0xFFF8BBD0), z: 12);
        Iso.box(c, sx + 0.2, sy + 0.95, 0.3, 0.2, 10, const Color(0xFFBBDEFB));
        break;
    }
  }
}
