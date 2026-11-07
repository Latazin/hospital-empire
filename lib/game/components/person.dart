import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../draw.dart';
import '../hospital_game.dart';
import 'room_component.dart';

enum Anim { idle, walk, work, wait }

enum Role { patient, doctor, nurse, receptionist, carrier, inspector, manager }

final _rnd = math.Random();

const _skins = [Color(0xFFFFE0BD), Color(0xFFF1C27D), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524), Color(0xFFFFD1B3)];
const _hairs = [Color(0xFF2B1B10), Color(0xFF5A3825), Color(0xFFD9A441), Color(0xFF8B2E16), Color(0xFF111111), Color(0xFF9E9E9E), Color(0xFFE57373)];
const _shirts = [Color(0xFFEF5350), Color(0xFF42A5F5), Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFAB47BC), Color(0xFF26C6DA), Color(0xFFFF7043), Color(0xFF8D6E63), Color(0xFFEC407A)];
const _pants = [Color(0xFF37474F), Color(0xFF1E3A8A), Color(0xFF5D4037), Color(0xFF263238), Color(0xFF455A64)];

/// Aparência individual de cada personagem.
class Look {
  Color skin, hair, shirt, pants;
  int hairStyle; // 0 curto, 1 longo, 2 coque, 3 careca, 4 topete
  Look(this.skin, this.hair, this.shirt, this.pants, this.hairStyle);
  factory Look.random() => Look(
        _skins[_rnd.nextInt(_skins.length)],
        _hairs[_rnd.nextInt(_hairs.length)],
        _shirts[_rnd.nextInt(_shirts.length)],
        _pants[_rnd.nextInt(_pants.length)],
        _rnd.nextInt(5),
      );
}

/// Personagem animado que anda pela grade isométrica seguindo waypoints.
/// Animações procedurais: caminhada, espera, trabalho, interação e comemoração.
class Person extends Component with HasGameReference<HospitalGame> {
  final Vector2 g;
  final Role role;
  final Look look;
  double speed;
  Anim anim = Anim.idle;
  bool facingLeft = false;
  double animT = 0;
  double celebrateT = 0;
  double talkT = 0;
  final double seed = _rnd.nextDouble() * 100;
  final List<Vector2> _path = [];
  VoidCallback? _onArrive;
  int _lastPriority = -1;
  Color? accent;

  static final Paint _p = Paint()..isAntiAlias = true;

  Person(Vector2 start, this.role, {Look? look, this.speed = 2.0, this.accent})
      : g = start.clone(),
        look = look ?? Look.random();

  bool get moving => _path.isNotEmpty;

  void walkTo(List<Vector2> pts, {VoidCallback? onArrive}) {
    _path
      ..clear()
      ..addAll(pts.map((e) => e.clone()));
    _onArrive = onArrive;
    anim = _path.isEmpty ? Anim.idle : Anim.walk;
    if (_path.isEmpty) onArrive?.call();
  }

  void celebrate([double dur = 0.9]) => celebrateT = dur;
  void talk([double dur = 1.0]) => talkT = dur;

  @override
  void update(double dt) {
    animT += dt;
    if (celebrateT > 0) celebrateT -= dt;
    if (talkT > 0) talkT -= dt;
    if (_path.isNotEmpty) {
      final target = _path.first;
      final dx = target.x - g.x, dy = target.y - g.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      final step = speed * dt;
      if (dist <= step) {
        g.setFrom(target);
        _path.removeAt(0);
        if (_path.isEmpty) {
          anim = Anim.idle;
          final cb = _onArrive;
          _onArrive = null;
          cb?.call();
        }
      } else {
        g.x += dx / dist * step;
        g.y += dy / dist * step;
        final sx = dx - dy; // direção horizontal na tela
        if (sx.abs() > 0.02) facingLeft = sx < 0;
      }
    }
    final pr = 1000 + ((g.x + g.y) * 20).toInt();
    if (pr != _lastPriority) {
      _lastPriority = pr;
      priority = pr;
    }
  }

  @override
  void render(Canvas c) {
    final pos = Iso.p(g.x, g.y);
    final walking = anim == Anim.walk;
    final t = animT * 10 + seed;
    final bob = walking ? (math.sin(t).abs() * 2.2) : math.sin(animT * 2.2 + seed) * 0.7;
    final jump = celebrateT > 0 ? math.sin(celebrateT * 11).abs() * 9 : 0.0;
    Iso.ellipse(c, pos, 20, 9, const Color(0x40000000));
    c.save();
    c.translate(pos.dx, pos.dy - bob - jump);
    if (facingLeft) c.scale(-1, 1);
    c.scale(0.92, 0.92);
    _drawFigure(c, t, walking);
    c.restore();
    renderOverlay(c, pos);
  }

  /// Indicadores por cima da cabeça (balões, barras). Sem espelhamento.
  void renderOverlay(Canvas c, Offset pos) {}

  Color get _shirtColor {
    switch (role) {
      case Role.doctor:
        return const Color(0xFFFFFFFF);
      case Role.nurse:
        return const Color(0xFF7FD3E8);
      case Role.receptionist:
        return const Color(0xFFF48FB1);
      case Role.carrier:
        return const Color(0xFFFF9800);
      case Role.inspector:
        return const Color(0xFF37474F);
      case Role.manager:
        return accent ?? const Color(0xFF3F51B5);
      case Role.patient:
        return look.shirt;
    }
  }

  Color get _pantsColor {
    switch (role) {
      case Role.doctor:
        return const Color(0xFF1E88E5);
      case Role.nurse:
        return const Color(0xFF4FB3CC);
      case Role.inspector:
      case Role.manager:
        return const Color(0xFF263238);
      default:
        return look.pants;
    }
  }

  Color get skinColor => look.skin;

  void _drawFigure(Canvas c, double t, bool walking) {
    final swing = walking ? math.sin(t) * 4.5 : 0.0;
    final cel = celebrateT > 0;
    final working = anim == Anim.work;

    // Pernas
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.6
      ..color = _pantsColor;
    c.drawLine(const Offset(-3, -12), Offset(-3.0 + swing, -1), _p);
    c.drawLine(const Offset(3, -12), Offset(3.0 - swing, -1), _p);
    _p.style = PaintingStyle.fill;
    _p.color = const Color(0xFF2B2B2B);
    c.drawOval(Rect.fromCenter(center: Offset(-2.0 + swing, 0), width: 6, height: 3.5), _p);
    c.drawOval(Rect.fromCenter(center: Offset(4.0 - swing, 0), width: 6, height: 3.5), _p);

    // Braços (atrás do corpo quando andando)
    final shirt = _shirtColor;
    final armColor = role == Role.doctor ? const Color(0xFFF1F1F1) : Iso.shade(shirt, -0.1);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..color = armColor;
    Offset lh, rh;
    if (cel) {
      lh = const Offset(-11, -37);
      rh = const Offset(11, -37);
    } else if (working) {
      final w = math.sin(animT * 9 + seed) * 3;
      lh = Offset(9, -18.0 + w);
      rh = Offset(12, -20.0 - w);
    } else if (talkT > 0) {
      lh = const Offset(-9, -14);
      rh = Offset(12, -24.0 + math.sin(animT * 12) * 3);
    } else {
      lh = Offset(-9.0 - swing * 0.6, -13);
      rh = Offset(9.0 + swing * 0.6, -13);
    }
    c.drawLine(const Offset(-6, -24), lh, _p);
    c.drawLine(const Offset(6, -24), rh, _p);
    _p.style = PaintingStyle.fill;
    _p.color = skinColor;
    c.drawCircle(lh, 2.4, _p);
    c.drawCircle(rh, 2.4, _p);

    // Corpo
    final body = RRect.fromLTRBR(-7.5, -28, 7.5, -10.5, const Radius.circular(5));
    _p.color = shirt;
    c.drawRRect(body, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Iso.shade(shirt, -0.35);
    c.drawRRect(body, _p);
    _p.style = PaintingStyle.fill;

    switch (role) {
      case Role.doctor:
        _p.color = look.shirt;
        c.drawRect(const Rect.fromLTRB(-1.6, -27, 1.6, -14), _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF455A64);
        c.drawArc(const Rect.fromLTRB(-5, -28, 5, -18), 0.2, 2.7, false, _p);
        _p.style = PaintingStyle.fill;
        _p.color = const Color(0xFF90A4AE);
        c.drawCircle(const Offset(0, -18), 1.8, _p);
        break;
      case Role.nurse:
        _p.color = const Color(0xFFE53935);
        c.drawRect(const Rect.fromLTRB(2, -25, 6, -24), _p);
        c.drawRect(const Rect.fromLTRB(3.5, -26.5, 4.5, -22.5), _p);
        break;
      case Role.carrier:
        _p.color = const Color(0xFFFFEB3B);
        c.drawRect(const Rect.fromLTRB(-7.5, -20, 7.5, -18), _p);
        break;
      case Role.inspector:
      case Role.manager:
        _p.color = const Color(0xFFFFFFFF);
        c.drawPath(Path()..moveTo(-3, -28)..lineTo(3, -28)..lineTo(0, -23)..close(), _p);
        _p.color = role == Role.inspector ? const Color(0xFFB71C1C) : const Color(0xFFFFC107);
        c.drawPath(Path()..moveTo(-1.2, -26)..lineTo(1.2, -26)..lineTo(1.6, -16)..lineTo(0, -14.5)..lineTo(-1.6, -16)..close(), _p);
        break;
      default:
        break;
    }

    // Cabeça
    const head = Offset(0, -35);
    _p.color = skinColor;
    c.drawCircle(head, 7.6, _p);
    _p.color = Iso.shade(skinColor, -0.15);
    c.drawCircle(const Offset(-6.2, -35), 2, _p);
    _drawHair(c, head);
    // Olhos (piscam)
    final blink = math.sin(animT * 1.3 + seed * 3) > 0.985;
    _p.color = const Color(0xFF1B1B1B);
    if (blink) {
      c.drawRect(const Rect.fromLTRB(0.5, -35.5, 3.5, -34.8), _p);
      c.drawRect(const Rect.fromLTRB(4.5, -35.5, 7.0, -34.8), _p);
    } else {
      c.drawCircle(const Offset(2.2, -35.5), 1.3, _p);
      c.drawCircle(const Offset(5.6, -35.5), 1.2, _p);
    }
    // Boca
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF7A3B2E);
    if (sad) {
      c.drawArc(const Rect.fromLTRB(1.5, -31.5, 6.5, -28.5), 3.5, 2.4, false, _p);
    } else {
      c.drawArc(Rect.fromLTRB(1.5, cel ? -33.5 : -33.0, 6.5, cel ? -29.0 : -30.0), 0.3, 2.4, false, _p);
    }
    _p.style = PaintingStyle.fill;

    // Acessórios de cabeça
    switch (role) {
      case Role.nurse:
        _p.color = const Color(0xFFFFFFFF);
        c.drawRRect(RRect.fromLTRBR(-5, -46, 5, -41.5, const Radius.circular(2)), _p);
        _p.color = const Color(0xFFE53935);
        c.drawRect(const Rect.fromLTRB(-0.6, -45.5, 0.6, -42), _p);
        c.drawRect(const Rect.fromLTRB(-1.8, -44.3, 1.8, -43.1), _p);
        break;
      case Role.receptionist:
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF37474F);
        c.drawArc(const Rect.fromLTRB(-8.5, -44, 8.5, -30), 3.4, 2.6, false, _p);
        c.drawLine(const Offset(7, -34), const Offset(5, -30), _p);
        _p.style = PaintingStyle.fill;
        break;
      case Role.carrier:
        _p.color = const Color(0xFFFF9800);
        c.drawArc(const Rect.fromLTRB(-8, -46, 8, -36), 3.14, 3.14, true, _p);
        c.drawRect(const Rect.fromLTRB(0, -41.5, 11, -40), _p);
        break;
      case Role.inspector:
        _p.color = const Color(0xFF212121);
        c.drawRect(const Rect.fromLTRB(-9, -42, 9, -40.5), _p);
        c.drawRect(const Rect.fromLTRB(-6, -49, 6, -41.5), _p);
        _p.color = const Color(0xFFB71C1C);
        c.drawRect(const Rect.fromLTRB(-6, -43.5, 6, -42), _p);
        // prancheta
        _p.color = const Color(0xFF8D6E63);
        c.drawRect(const Rect.fromLTRB(8, -24, 15, -14), _p);
        _p.color = const Color(0xFFFFFFFF);
        c.drawRect(const Rect.fromLTRB(9, -22.5, 14, -15.5), _p);
        break;
      default:
        break;
    }
    drawExtra(c);
  }

  bool get sad => false;

  void drawExtra(Canvas c) {}

  void _drawHair(Canvas c, Offset head) {
    if (role == Role.inspector) return;
    _p.color = look.hair;
    switch (look.hairStyle) {
      case 0:
        c.drawArc(Rect.fromCircle(center: head.translate(0, -1), radius: 8), 3.0, 3.6, true, _p);
        break;
      case 1:
        c.drawArc(Rect.fromCircle(center: head.translate(0, -1), radius: 8.2), 2.8, 3.9, true, _p);
        c.drawRRect(RRect.fromLTRBR(-8.5, -37, -3, -26, const Radius.circular(3)), _p);
        break;
      case 2:
        c.drawArc(Rect.fromCircle(center: head.translate(0, -1), radius: 8), 3.0, 3.5, true, _p);
        c.drawCircle(head.translate(-3, -9), 4, _p);
        break;
      case 3:
        c.drawArc(Rect.fromCircle(center: head, radius: 8), 3.6, 0.9, false, _p);
        break;
      default:
        c.drawArc(Rect.fromCircle(center: head.translate(0, -1), radius: 8), 3.0, 3.5, true, _p);
        c.drawPath(Path()..moveTo(-2, -43)..quadraticBezierTo(8, -50, 9, -40)..lineTo(2, -41)..close(), _p);
    }
  }
}

enum PState { arriving, queued, toRoom, inService, leaving }

/// Paciente: chega, espera na recepção, é atendido numa sala, paga e vai embora.
class Patient extends Person {
  PState state = PState.arriving;
  final bool vip, emergency, sick;
  RoomComponent? room;
  int slot = -1;
  double waited = 0;
  double emergencyLeft = 45;
  bool waitingForRoom = false;

  Patient(Vector2 start, {this.vip = false, this.emergency = false, this.sick = false})
      : super(start, Role.patient, speed: emergency ? 2.4 : 1.9) {
    if (vip) look.shirt = const Color(0xFFFFC107);
    if (emergency) look.shirt = const Color(0xFFFFFFFF);
  }

  @override
  Color get skinColor => sick ? Color.lerp(look.skin, const Color(0xFF8BC34A), 0.45)! : look.skin;

  @override
  bool get sad => waited > 25 || (emergency && emergencyLeft < 15);

  @override
  void update(double dt) {
    super.update(dt);
    if (state == PState.queued || state == PState.arriving) waited += dt;
    if (emergency && state != PState.leaving && state != PState.inService) emergencyLeft -= dt;
  }

  @override
  void drawExtra(Canvas c) {
    if (vip) {
      final p = Paint()..color = const Color(0xFFFFD700);
      c.drawPath(
          Path()
            ..moveTo(-5, -42)
            ..lineTo(-5, -48)
            ..lineTo(-2.5, -45)
            ..lineTo(0, -49)
            ..lineTo(2.5, -45)
            ..lineTo(5, -48)
            ..lineTo(5, -42)
            ..close(),
          p);
    }
    if (emergency) {
      final p = Paint()..color = const Color(0xFFE53935);
      c.drawRect(const Rect.fromLTRB(-1.2, -24, 1.2, -16), p);
      c.drawRect(const Rect.fromLTRB(-4, -21.2, 4, -18.8), p);
      final band = Paint()..color = const Color(0xFFFFFFFF);
      c.drawRect(const Rect.fromLTRB(-7.8, -41, 7.8, -38.5), band);
    }
  }

  @override
  void renderOverlay(Canvas c, Offset pos) {
    final top = pos.translate(0, -52);
    if (state == PState.inService && room != null && slot >= 0) {
      final prog = room!.slotProgress(slot);
      final bg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xAA23314D);
      final fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4CD964);
      final r = Rect.fromCircle(center: top, radius: 6);
      c.drawArc(r, 0, 6.283, false, bg);
      c.drawArc(r, -1.57, 6.283 * prog, false, fg);
    } else if (waitingForRoom) {
      TextCache.pill(c, 'sem sala!', top, 8, const Color(0xFFFFF3CD), const Color(0xFF8A5A00));
    } else if (emergency && state != PState.leaving) {
      final pulse = 0.5 + 0.5 * math.sin(animT * 8);
      Iso.circle(c, top, 7.0 + pulse * 2, Color.lerp(const Color(0xFFE53935), const Color(0xFFFF8A80), pulse)!);
      TextCache.draw(c, '${emergencyLeft.ceil()}', top, 8, Colors.white);
    } else if (vip && state != PState.leaving) {
      TextCache.draw(c, 'VIP', top, 9, const Color(0xFFFFD700), stroke: const Color(0xFF6D4C00));
    } else if (sad && state == PState.queued) {
      TextCache.draw(c, '😤', top, 11, Colors.black);
    }
  }
}

/// Carregador: busca o dinheiro nas salas e leva até a tesouraria.
class Carrier extends Person {
  double load = 0;
  bool busy = false;
  bool blocked = false;
  final int index;
  double retryT = 0;

  Carrier(Vector2 start, this.index) : super(start, Role.carrier, speed: 2.2);

  @override
  void drawExtra(Canvas c) {
    if (load <= 0) return;
    final size = (4 + math.log(load + 1) * 0.9).clamp(5.0, 11.0).toDouble();
    final p = Paint()..color = const Color(0xFF8D6E63);
    c.drawCircle(Offset(-9, -22), size, p);
    TextCache.draw(c, '\$', const Offset(-9, -22), size * 1.1, const Color(0xFFFFE082));
  }

  @override
  void renderOverlay(Canvas c, Offset pos) {
    if (blocked) {
      TextCache.pill(c, 'Tesouraria cheia!', pos.translate(0, -56), 8, const Color(0xFFFFE0E0),
          const Color(0xFFB71C1C));
    } else if (load > 0 && moving) {
      TextCache.draw(c, '\$${fmt(load)}', pos.translate(0, -54), 9, const Color(0xFFFFE082),
          stroke: const Color(0xFF4E342E));
    }
  }
}
