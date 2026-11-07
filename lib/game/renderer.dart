import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/state.dart';
import 'art.dart';
import 'world.dart';

/// Desenha o hospital inteiro a partir dos sprites pré-renderizados,
/// com ordenação por profundidade, rótulos, partículas e dia/noite.
class SceneRenderer extends Component {
  final HospitalWorld w;
  final GameState s;
  Rect view = Rect.zero;
  double zoom = 1;
  SceneRenderer(this.w, this.s);

  final Paint _p = Paint()..filterQuality = FilterQuality.medium..isAntiAlias = true;
  final Paint _shadow = Paint()..color = const Color(0x40141A33)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  static final Map<String, _OT> _tc = {};

  // ---------------- dia/noite ----------------
  double night = 0, dusk = 0;
  void _dayNight() {
    final ph = (w.t / 300 + 0.02) % 1; double n = 0, du = 0;
    if (ph < 0.6) {
    } else if (ph < 0.68) { du = (ph - 0.6) / 0.08; }
    else if (ph < 0.73) { final k = (ph - 0.68) / 0.05; du = 1 - k; n = k; }
    else if (ph < 0.9) { n = 1; }
    else { n = 1 - (ph - 0.9) / 0.1; du = math.sin(n * math.pi) * 0.6; }
    night = n; dusk = du;
  }

  // ---------------- primitivas ----------------
  void spr(Canvas c, String name, double gx, double gy, {double h = 0, bool flip = false, double scale = 1, double alpha = 1}) {
    final sp = Art.spr[name]; if (sp == null) return;
    final o = iso(gx, gy, h);
    _drawSpr(c, sp, o.dx, o.dy, flip: flip, scale: scale, alpha: alpha);
  }
  void _drawSpr(Canvas c, Spr sp, double x, double y, {bool flip = false, double scale = 1, double alpha = 1}) {
    final dst = Rect.fromLTWH(x - sp.ax * scale, y - sp.ay * scale, sp.src.width * scale, sp.src.height * scale);
    if (!dst.overlaps(view)) return;
    _p.color = Color.fromRGBO(255, 255, 255, alpha);
    if (flip) { c.save(); c.translate(x, 0); c.scale(-1, 1); c.translate(-x, 0); c.drawImageRect(sp.img, sp.src, Rect.fromLTWH(x - (sp.src.width - sp.ax) * scale, dst.top, dst.width, dst.height), _p); c.restore(); }
    else { c.drawImageRect(sp.img, sp.src, dst, _p); }
  }
  _OT _text(String t, double size, Color color, {Color? stroke}) {
    final k = '$t|$size|${color.toARGB32()}|${stroke?.toARGB32()}';
    return _tc[k] ??= _OT(t, size, color, stroke);
  }
  void txt(Canvas c, String t, Offset at, double size, Color color, {Color stroke = const Color(0xFF1E2A47)}) {
    if (_tc.length > 400) _tc.clear();
    final tp = _text(t, size, color, stroke: stroke); tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }
  /// Placa estilo jogo: pílula com gradiente, borda clara e contorno escuro.
  double plate(Canvas c, String t, Offset at, double size, Color bg, {Color fg = Colors.white}) {
    final tp = _text(t, size, fg, stroke: const Color(0x881E2A47));
    final w = tp.width + size * 1.4, h = size * 1.75;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w, height: h), Radius.circular(h / 2));
    c.drawRRect(r.shift(const Offset(0, 5)), Paint()..color = const Color(0x55141A33));
    c.drawRRect(r.inflate(3), Paint()..color = const Color(0xFF1E2A47));
    c.drawRRect(r, Paint()..shader = ui.Gradient.linear(r.outerRect.topCenter, r.outerRect.bottomCenter, [Color.lerp(bg, Colors.white, 0.28)!, bg, Color.lerp(bg, Colors.black, 0.18)!], [0, 0.55, 1]));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + h * 0.3, r.top + 3, r.width - h * 0.6, h * 0.28), Radius.circular(h)), Paint()..color = const Color(0x44FFFFFF));
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2 - 1));
    return w;
  }
  void bar(Canvas c, Offset at, double w, double h, double r, Color col) {
    final o = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w + 6, height: h + 6), Radius.circular(h));
    c.drawRRect(o, Paint()..color = const Color(0xFF1E2A47));
    if (r > 0) {
      final f = RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - w / 2, at.dy - h / 2, math.max(h, w * r.clamp(0.0, 1.0)), h), Radius.circular(h / 2));
      c.drawRRect(f, Paint()..shader = ui.Gradient.linear(f.outerRect.topCenter, f.outerRect.bottomCenter, [Color.lerp(col, Colors.white, 0.35)!, col]));
    }
  }
  void upBadge(Canvas c, Offset at) {
    c.drawCircle(at + const Offset(0, 3), 19, Paint()..color = const Color(0x55141A33));
    c.drawCircle(at, 19, Paint()..color = const Color(0xFF1E2A47));
    c.drawCircle(at, 16, Paint()..shader = ui.Gradient.linear(at - const Offset(0, 16), at + const Offset(0, 16), [const Color(0xFF8CF5A6), const Color(0xFF22A04A)]));
    final p = Path()..moveTo(at.dx, at.dy - 11)..lineTo(at.dx + 10, at.dy)..lineTo(at.dx + 4, at.dy)..lineTo(at.dx + 4, at.dy + 10)..lineTo(at.dx - 4, at.dy + 10)..lineTo(at.dx - 4, at.dy)..lineTo(at.dx - 10, at.dy)..close();
    c.drawPath(p, Paint()..color = Colors.white);
  }
  void bubble(Canvas c, Offset at, String kind) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at - const Offset(0, 22), width: 46, height: 38), const Radius.circular(16));
    c.drawRRect(r.shift(const Offset(0, 3)), Paint()..color = const Color(0x44141A33));
    c.drawRRect(r, Paint()..color = Colors.white);
    c.drawRRect(r, Paint()..color = const Color(0xFF1E2A47)..style = PaintingStyle.stroke..strokeWidth = 2.5);
    final tail = Path()..moveTo(at.dx - 8, r.bottom - 1)..lineTo(at.dx, at.dy + 6)..lineTo(at.dx + 8, r.bottom - 1)..close();
    c.drawPath(tail, Paint()..color = Colors.white);
    final cc = r.center;
    if (kind == 'happy') {
      final h = Path()..moveTo(cc.dx, cc.dy + 9)..cubicTo(cc.dx - 18, cc.dy - 4, cc.dx - 8, cc.dy - 16, cc.dx, cc.dy - 6)..cubicTo(cc.dx + 8, cc.dy - 16, cc.dx + 18, cc.dy - 4, cc.dx, cc.dy + 9)..close();
      c.drawPath(h, Paint()..color = const Color(0xFFFF4D6D));
    } else if (kind == 'angry') {
      txt(c, '!', cc, 28, const Color(0xFFFF5A5F), stroke: const Color(0xFF7A1010));
    } else if (kind == 'sick') {
      c.drawCircle(cc, 11, Paint()..color = const Color(0xFF9CCC65));
      c.drawRect(Rect.fromCenter(center: cc + const Offset(-4, -2), width: 3, height: 3), Paint()..color = const Color(0xFF1E2A47));
      c.drawRect(Rect.fromCenter(center: cc + const Offset(4, -2), width: 3, height: 3), Paint()..color = const Color(0xFF1E2A47));
      c.drawArc(Rect.fromCenter(center: cc + const Offset(0, 7), width: 10, height: 6), math.pi, math.pi, false, Paint()..color = const Color(0xFF1E2A47)..style = PaintingStyle.stroke..strokeWidth = 2);
    } else if (kind.startsWith('room:')) {
      final t = roomById(kind.substring(5));
      c.drawCircle(cc, 12, Paint()..color = t.accent);
      c.drawRect(Rect.fromCenter(center: cc, width: 4, height: 14), Paint()..color = Colors.white);
      c.drawRect(Rect.fromCenter(center: cc, width: 14, height: 4), Paint()..color = Colors.white);
    }
  }

  /// Efeito "mola" da sala ao melhorar (achata e estica a partir do chão).
  void _pop(Canvas c, RoomRt rm, void Function() draw) {
    if (rm.pop <= 0) { draw(); return; }
    final k = 1 - rm.pop, e = math.sin(k * math.pi * 3) * math.exp(-k * 3.2) * 0.09;
    final o = iso(rm.x + 2, rm.y + 2.5);
    c.save(); c.translate(o.dx, o.dy); c.scale(1 - e * 0.6, 1 + e); c.translate(-o.dx, -o.dy); draw(); c.restore();
  }

  // ---------------- personagens ----------------
  Spr? _frame(Person p, String dir) {
    final v = Art.chars[p.sprite]; if (v == null) return null;
    final f = v[dir]; if (f == null) return null;
    String key;
    if (p.cel > 0) { final ph = (p.cel * 11) % math.pi; key = 'cel_${(ph / math.pi * 4).floor().clamp(0, 3)}'; }
    else if (p.anim == 'walk') { key = '${p is Carrier && p.load > 0 ? 'walkload' : 'walk'}_${((p.t * 11 / (math.pi * 2)) * 8).floor() % 8}'; }
    else if (p.sit) { key = 'sit_0'; }
    else if (p.anim == 'work') { key = 'work_${((p.t * 10 / (math.pi * 2)) * 4).floor() % 4}'; }
    else if (p.talk > 0) { key = 'talk_${((p.t * 12) / math.pi).floor() % 2}'; }
    else { key = 'idle_0'; }
    return f[key] ?? f['idle_0'] ?? f.values.first;
  }
  void person(Canvas c, Person p) {
    final dx = math.sin(p.ang), dz = math.cos(p.ang);
    final front = dx + dz >= 0, flip = dx - dz < 0;
    final fr = _frame(p, front ? 'f' : 'b'); if (fr == null) return;
    final o = iso(p.gx, p.gy);
    final jump = p.cel > 0 ? 0.0 : 0.0;
    var y = o.dy - (p.sit ? (p.z - 14) * 2 : p.z * 2) - jump;
    if (!p.sit) c.drawOval(Rect.fromCenter(center: o, width: 44, height: 18), _shadow);
    if (p.anim == 'idle' && !p.sit && p.cel <= 0) y += math.sin(p.t * 2.4 + p.seed) * 1.2;
    _drawSpr(c, fr, o.dx, y, flip: flip);
  }

  // ---------------- quadro ----------------
  @override
  void render(Canvas c) {
    if (!Art.ready) return;
    _dayNight();
    final sx = w.shake > 0 ? rr(-1, 1) * w.shake * 22 : 0.0, sy = w.shake > 0 ? rr(-1, 1) * w.shake * 22 : 0.0;
    c.save(); c.translate(sx, sy);
    for (final b in Art.bg) {
      final dst = Rect.fromLTWH(-b.ax, -b.ay, b.img.width.toDouble(), b.img.height.toDouble());
      if (dst.overlaps(view)) c.drawImageRect(b.img, Rect.fromLTWH(0, 0, dst.width, dst.height), dst, _p..color = Colors.white);
    }
    // pisos e paredes das áreas
    spr(c, 'rec_${GameState.tier(s.rl)}', 0, 0);
    spr(c, 'tre_${math.min(3, s.trl ~/ 10)}', 0, 0);
    final next = s.nextRoom;
    for (final rm in w.rooms) {
      final b = s.built(rm.t.id);
      if (!b && rm.t != next) { spr(c, 'garden_${rm.t.plot % 4}', rm.x, rm.y); continue; }
      if (!b || rm.buildAnim > 0) { spr(c, rm.top ? 'lot_top' : 'lot_bot', rm.x, rm.y); continue; }
      _pop(c, rm, () => spr(c, 'room_${rm.t.id}_${GameState.tier(s.lvlOf(rm.t.id))}', rm.x, rm.y));
    }
    // objetos ordenados por profundidade
    final items = <(double, void Function())>[];
    for (final rm in w.rooms) {
      final b = s.built(rm.t.id);
      if (b && rm.buildAnim > 0) { final k = 1 - rm.buildAnim / 2.8; items.add((rm.x + rm.y + 4.5, () => spr(c, 'scaffold_${(k * 2.99).floor()}', rm.x, rm.y))); continue; }
      if (!b) continue;
      final l = s.lvlOf(rm.t.id), tier = GameState.tier(l), n = GameState.slots(l);
      for (var i = 0; i < n; i++) {
        final x = rm.x + colX[i % 2], y = rm.y + rowY[i >> 1];
        items.add((x + y + 0.9, () => _pop(c, rm, () => spr(c, 'st_${rm.t.id}_$tier', x, y))));
      }
      if (rm.stash > 0.5) {
        final pl = rm.pile(), n = (1 + math.log(rm.stash + 1) / math.ln10 * 1.3).clamp(1, 14).toInt();
        final name = n >= 12 ? 'pile_14' : n >= 8 ? 'pile_9' : n >= 5 ? 'pile_6' : n >= 2 ? 'pile_3' : 'pile_1';
        items.add((pl[0] + pl[1], () => spr(c, name, pl[0], pl[1])));
      }
    }
    final tr = (s.treasury / s.treMax).clamp(0.0, 1.0);
    if (tr > 0.01) {
      for (var k = 0; k < (tr * 6).ceil(); k++) { final gx = 0.9 + (k % 3) * 0.75, gy = 11.25 + (k ~/ 3) * 0.6; items.add((gx + gy, () => spr(c, tr > 0.66 ? 'pile_9' : tr > 0.33 ? 'pile_6' : 'pile_3', gx, gy))); }
    }
    items.add((5.65, () => spr(c, 'rec_counter', 0, 0)));
    items.add((7.55, () => spr(c, 'rec_chairs1', 0, 0)));
    items.add((8.55, () => spr(c, 'rec_chairs2', 0, 0)));
    for (final p in w.people) { items.add((p.depth, () => person(c, p))); }
    for (final car in w.cars) {
      final name = 'veh_${car.sprite}_${car.dir > 0 ? 'a' : 'b'}';
      final flip = car.axis == 'x';
      items.add((car.depth, () => spr(c, name, car.gx, car.gy, flip: flip)));
    }
    for (final g in w.gifts) {
      items.add((g.depth, () {
        final landed = g.z <= 0.5;
        if (landed) {
          final pul = 0.5 + 0.5 * math.sin(w.t * 6), o = iso(g.gx, g.gy);
          c.drawOval(Rect.fromCenter(center: o, width: 90 + pul * 14, height: 44 + pul * 7), Paint()..color = Color.fromRGBO(255, 226, 122, 0.35 + pul * 0.25)..style = PaintingStyle.stroke..strokeWidth = 5);
          if (g.life < 6 && (w.t * 8).floor() % 2 == 1) return;
          spr(c, g.gold ? 'gift_gold' : 'gift_red', g.gx, g.gy, scale: 1 + math.sin(w.t * 6) * 0.05);
        } else {
          spr(c, g.gold ? 'giftchute_gold' : 'giftchute_red', g.gx, g.gy, h: g.z);
        }
      }));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) { it.$2(); }
    spr(c, 'ov_front', 0, 0);
    spr(c, 'ov_over', 0, 0);
    for (final rm in w.rooms) {
      if (rm.glow <= 0.01) continue;
      final o = iso(rm.x + 2, rm.y + 2.5, 20);
      c.drawCircle(o, 260, Paint()..blendMode = BlendMode.plus..shader = ui.Gradient.radial(o, 260, [Color.fromRGBO(255, 226, 122, 0.55 * rm.glow), Color.fromRGBO(255, 200, 80, 0.18 * rm.glow), const Color(0x00FFC850)], [0, 0.45, 1]));
    }
    _clouds(c);
    _night(c);
    _labels(c);
    _particles(c);
    c.restore();
  }

  void _clouds(Canvas c) {
    if (zoom > 0.9) return;
    final a = ((0.9 - zoom) * 1.6).clamp(0.0, 0.7);
    for (var i = 0; i < 5; i++) {
      final x = ((w.t * 14 + i * 900) % 4200) - 1800, y = -900.0 + i * 420 - (w.t * 4 + i * 100) % 300;
      final sp = Art.spr['cloud_0']; if (sp != null) _drawSpr(c, sp, x, y, alpha: a, scale: 1.2);
    }
  }
  void _night(Canvas c) {
    if (night < 0.02 && dusk < 0.02) return;
    final tint = night >= dusk ? Color.lerp(Colors.white, const Color(0xFF4A56A8), night * 0.7)! : Color.lerp(Colors.white, const Color(0xFFFFB089), dusk * 0.45)!;
    c.drawRect(view.inflate(400), Paint()..color = tint..blendMode = BlendMode.multiply);
    if (night < 0.05) return;
    final glow = Paint()..blendMode = BlendMode.plus;
    void light(double gx, double gy, double h, double r, Color col, double a) {
      final o = iso(gx, gy, h);
      glow.shader = ui.Gradient.radial(o, r, [col.withValues(alpha: a), col.withValues(alpha: a * 0.35), col.withValues(alpha: 0)], [0, 0.35, 1]);
      c.drawCircle(o, r, glow);
    }
    const warm = Color(0xFFFFBE64), gold = Color(0xFFFFD23C);
    for (final rm in w.rooms) { if (s.built(rm.t.id)) light(rm.x + 2, rm.y + 2.5, 0, 300, GameState.tier(s.lvlOf(rm.t.id)) >= 3 ? gold : warm, 0.45 * night); }
    light(2.5, 4.5, 0, 320, warm, 0.45 * night); light(2.5, 11.5, 0, 280, gold, 0.35 * night);
    light(11, 1.9, 92, 420, gold, 0.4 * night); light(1.9, 1.9, 92, 170, const Color(0xFFFF4040), 0.45 * night);
    for (final l in const [[-7.75, -8.0], [-7.75, -2.0], [-7.75, 4.0], [-7.75, 10.6], [-7.75, 17.0], [3.0, 15.65], [10.0, 15.65], [17.0, 15.65], [21.75, 6.0], [21.75, 12.0], [-1.0, 18.9], [6.0, 18.9], [13.0, 18.9], [20.0, 18.9], [27.0, 18.9]]) {
      light(l[0], l[1], 63, 90, warm, 0.9 * night); light(l[0], l[1], 0, 200, warm, 0.35 * night);
    }
    for (final car in w.cars) { if (car.kind == 'amb') light(car.gx, car.gy, 38, 160, (w.t * 7).floor() % 2 == 0 ? const Color(0xFFFF3040) : const Color(0xFF3C78FF), 0.6); }
  }

  void _labels(Canvas c) {
    final next = s.nextRoom;
    var p = iso(2.5, 3.6, 84);
    plate(c, 'Recepção  Nv ${s.rl}', p, 22, const Color(0xFFE84A7F));
    final q = w.queue.length, mx = s.qmax;
    txt(c, 'Fila $q/$mx', p + const Offset(0, 36), 20, q >= mx ? const Color(0xFFFF9E9E) : Colors.white);
    if (w.checkin > 0) bar(c, iso(desk[0], desk[1], 54), 72, 10, w.checkin, const Color(0xFFFF80AB));
    p = iso(2.5, 11.5, 80);
    final tr = s.treasury / s.treMax;
    plate(c, 'Cofre  Nv ${s.trl}', p, 22, const Color(0xFF8D6E63));
    bar(c, p + const Offset(0, 38), 150, 16, tr, tr >= 0.999 ? const Color(0xFFFF5A5F) : const Color(0xFFFFC531));
    txt(c, '\$${fmt(s.treasury)}', p + const Offset(0, 39), 17, Colors.white);
    for (final rm in w.rooms) {
      final cc = iso(rm.x + 2, rm.y + 2.5, rm.top ? 92 : 80), t = rm.t;
      if (!s.built(rm.t.id)) {
        if (t != next) continue;
        final why = s.lockReason(t);
        if (why != null) { plate(c, t.name, cc, 22, const Color(0xFF5E6B85)); _lock(c, cc + const Offset(0, -40)); txt(c, why, cc + const Offset(0, 36), 19, Colors.white); }
        else {
          final can = s.money >= t.build, sc = can ? 1 + 0.07 * math.sin(w.t * 6) : 1.0;
          c.save(); c.translate(cc.dx, cc.dy); c.scale(sc); plate(c, 'CONSTRUIR ${t.name}', Offset.zero, 22, can ? const Color(0xFF3FD46B) : const Color(0xFF8D99AE)); c.restore();
          txt(c, '\$${fmt(t.build)}', cc + const Offset(0, 38), 24, can ? const Color(0xFFC8FFB0) : Colors.white);
          if (can) _bigArrow(c, cc + Offset(0, -70 - (math.sin(w.t * 6).abs()) * 22));
        }
        continue;
      }
      if (rm.buildAnim > 0) { bar(c, cc + const Offset(0, 20), 140, 14, 1 - rm.buildAnim / 2.8, const Color(0xFF4CFF7A)); continue; }
      final l = s.lvlOf(t.id), tier = GameState.tier(l);
      final pw = plate(c, '${t.name}  Nv $l', cc, 22, tier >= 3 ? const Color(0xFFD99000) : t.accent);
      for (var k = 0; k < tier; k++) { _star(c, cc + Offset(-(tier - 1) * 13.0 + k * 26, -34), 11); }
      if (l < GameState.maxL && s.money >= s.upCost(t, l)) upBadge(c, cc + Offset(pw / 2 + 24, math.sin(w.t * 7) * 5));
      if (rm.stash > 0.5) { final pl = rm.pile(); plate(c, '\$${fmt(rm.stash)}', iso(pl[0], pl[1], 30), 17, const Color(0xFFFFE27A), fg: const Color(0xFF6D4C00)); }
    }
    for (final g in w.gifts) { if (g.z <= 0.5) plate(c, 'TOQUE!', iso(g.gx, g.gy, 44 + math.sin(w.t * 5) * 3), 18, const Color(0xFFFFC531), fg: Colors.white); }
    for (final pp in w.people) { _personOver(c, pp); }
  }
  void _bigArrow(Canvas c, Offset o) {
    final p = Path()..moveTo(o.dx, o.dy + 30)..lineTo(o.dx + 28, o.dy)..lineTo(o.dx + 12, o.dy)..lineTo(o.dx + 12, o.dy - 26)..lineTo(o.dx - 12, o.dy - 26)..lineTo(o.dx - 12, o.dy)..lineTo(o.dx - 28, o.dy)..close();
    c.drawPath(p.shift(const Offset(0, 5)), Paint()..color = const Color(0x55141A33));
    c.drawPath(p, Paint()..color = const Color(0xFF1E2A47)..style = PaintingStyle.stroke..strokeWidth = 7..strokeJoin = StrokeJoin.round);
    c.drawPath(p, Paint()..shader = ui.Gradient.linear(o - const Offset(0, 26), o + const Offset(0, 30), [const Color(0xFFA8FFB8), const Color(0xFF22B04A)]));
  }
  void _star(Canvas c, Offset at, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) { final a = -math.pi / 2 + i * math.pi / 5, rr = i.isEven ? r : r * 0.45; final pt = at + Offset(math.cos(a) * rr, math.sin(a) * rr); i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy); }
    path.close();
    c.drawPath(path, Paint()..color = const Color(0xFF6D4C00)..style = PaintingStyle.stroke..strokeWidth = 4..strokeJoin = StrokeJoin.round);
    c.drawPath(path, Paint()..shader = ui.Gradient.linear(at - Offset(0, r), at + Offset(0, r), [const Color(0xFFFFF1A0), const Color(0xFFFFB300)]));
  }
  void _lock(Canvas c, Offset at) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at + const Offset(0, 5), width: 26, height: 20), const Radius.circular(5)), Paint()..color = const Color(0xFFFFC531));
    c.drawArc(Rect.fromCenter(center: at - const Offset(0, 4), width: 16, height: 18), math.pi, math.pi, false, Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.stroke..strokeWidth = 4);
    c.drawCircle(at + const Offset(0, 5), 3, Paint()..color = const Color(0xFF6D4C00));
  }
  void _personOver(Canvas c, Person p) {
    final h = iso(p.gx, p.gy, p.z + 52);
    if (p is Patient) {
      if (p.state == 'service' && p.room != null && p.slot >= 0) {
        final pr = p.room!.prog[p.slot];
        c.drawCircle(h, 18, Paint()..color = const Color(0xDD161E36));
        c.drawArc(Rect.fromCircle(center: h, radius: 13), -math.pi / 2, math.pi * 2 * pr, false, Paint()..color = const Color(0xFF4CFF7A)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
        return;
      }
      if (p.noRoom) { plate(c, 'sem vaga!', h, 17, const Color(0xFFFFF3CD), fg: const Color(0xFF8A5A00)); return; }
      if (p.emg && p.state != 'leaving') {
        final pu = 0.5 + 0.5 * math.sin(w.t * 9);
        c.drawCircle(h, 19 + pu * 5, Paint()..color = Color.lerp(const Color(0xFFE53935), const Color(0xFFFF8A80), pu)!);
        c.drawCircle(h, 19 + pu * 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
        txt(c, '${math.max(0, p.emgLeft.ceil())}', h + const Offset(0, 1), 20, Colors.white);
        return;
      }
      if (p.vip && p.bub == null && p.state != 'leaving') { txt(c, 'VIP', h, 22, const Color(0xFFFFD54F), stroke: const Color(0xFF5B3A00)); return; }
    }
    if (p is Carrier && p.blocked) { plate(c, 'Cofre cheio!', h, 17, const Color(0xFFFFE0E0), fg: const Color(0xFFB71C1C)); return; }
    if (p.bub != null) bubble(c, h, p.bub!);
  }

  void _particles(Canvas c) {
    final paint = Paint();
    for (final q in w.parts) {
      final a = (1 - q.life / q.max).clamp(0.0, 1.0);
      switch (q.k) {
        case 'spark':
          final s = q.s * (0.5 + a); paint.color = q.c.withValues(alpha: a);
          final path = Path()..moveTo(q.x, q.y - s)..lineTo(q.x + s * .3, q.y - s * .3)..lineTo(q.x + s, q.y)..lineTo(q.x + s * .3, q.y + s * .3)..lineTo(q.x, q.y + s)..lineTo(q.x - s * .3, q.y + s * .3)..lineTo(q.x - s, q.y)..lineTo(q.x - s * .3, q.y - s * .3)..close();
          c.drawPath(path, paint);
          break;
        case 'conf':
          c.save(); c.translate(q.x, q.y); c.rotate(q.r); paint.color = q.c.withValues(alpha: a); c.drawRect(Rect.fromCenter(center: Offset.zero, width: q.s, height: q.s / 2), paint); c.restore();
          break;
        case 'coin':
          final sp = Art.spr['coin'];
          if (sp != null) { _drawSpr(c, sp, q.x, q.y + sp.ay * 0.35, scale: 0.35 + 0.15 * (math.cos(q.r).abs()), alpha: a); }
          break;
        case 'smoke':
          paint.color = const Color(0xFFEBE4D7).withValues(alpha: a * 0.75); c.drawOval(Rect.fromCenter(center: Offset(q.x, q.y), width: q.s * (2 - a) * 4, height: q.s * (2 - a) * 2.8), paint);
          break;
        case 'arrow':
          final o = Offset(q.x, q.y);
          final path = Path()..moveTo(o.dx, o.dy - 16)..lineTo(o.dx + 14, o.dy)..lineTo(o.dx + 6, o.dy)..lineTo(o.dx + 6, o.dy + 14)..lineTo(o.dx - 6, o.dy + 14)..lineTo(o.dx - 6, o.dy)..lineTo(o.dx - 14, o.dy)..close();
          c.drawPath(path, Paint()..color = const Color(0xFF1E2A47).withValues(alpha: a)..style = PaintingStyle.stroke..strokeWidth = 4..strokeJoin = StrokeJoin.round);
          c.drawPath(path, Paint()..color = const Color(0xFF3FD46B).withValues(alpha: a));
          break;
        case 'ring':
          final k = q.life / q.max, rad = q.s + k * 260;
          c.drawOval(Rect.fromCenter(center: Offset(q.x, q.y), width: rad * 2, height: rad), Paint()..color = q.c.withValues(alpha: (1 - k) * 0.9)..style = PaintingStyle.stroke..strokeWidth = 10 * (1 - k) + 2);
          break;
        case 'beam':
          final k = q.life / q.max, al = math.sin(k * math.pi), wd = q.s * (0.6 + 0.4 * al);
          final r = Rect.fromLTWH(q.x - wd / 2, q.y - 900, wd, 900);
          c.drawRect(r, Paint()..blendMode = BlendMode.plus..shader = ui.Gradient.linear(Offset(r.left, 0), Offset(r.right, 0), [q.c.withValues(alpha: 0), q.c.withValues(alpha: 0.5 * al), q.c.withValues(alpha: 0)]));
          break;
        case 'bolt':
          final o = Offset(q.x, q.y);
          final path = Path()..moveTo(o.dx + 4, o.dy - 16)..lineTo(o.dx - 8, o.dy + 2)..lineTo(o.dx, o.dy + 2)..lineTo(o.dx - 4, o.dy + 16)..lineTo(o.dx + 9, o.dy - 3)..lineTo(o.dx + 1, o.dy - 3)..close();
          c.drawPath(path, Paint()..color = const Color(0xFF6D4C00).withValues(alpha: a)..style = PaintingStyle.stroke..strokeWidth = 3);
          c.drawPath(path, Paint()..color = const Color(0xFFFFE27A).withValues(alpha: a));
          break;
      }
    }
    for (final f in w.floats) {
      final k = f.t / 1.25, sc = k < 0.1 ? 0.3 + k / 0.1 * 1.05 : k < 0.2 ? 1.35 - (k - 0.1) / 0.1 * 0.3 : 1.05 - math.min(0.1, (k - 0.2) * 0.2);
      final tp = _text(f.s, f.size, f.color, stroke: const Color(0xFF1E2A47));
      c.save(); c.translate(f.x, f.y - k * 80); c.scale(sc);
      if (k > 0.7) { c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, (1 - k) / 0.3)); tp.paint(c, Offset(-tp.width / 2, -tp.height / 2)); c.restore(); }
      else { tp.paint(c, Offset(-tp.width / 2, -tp.height / 2)); }
      c.restore();
    }
  }
}

/// Texto com contorno de verdade (traço + preenchimento), estilo jogo.
class _OT {
  late final TextPainter fill;
  TextPainter? line;
  _OT(String t, double size, Color color, Color? stroke) {
    TextStyle st(Paint? fg) => TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: size, height: 1, color: fg == null ? color : null, foreground: fg);
    fill = TextPainter(text: TextSpan(text: t, style: st(null)), textDirection: TextDirection.ltr)..layout();
    if (stroke != null) {
      line = TextPainter(text: TextSpan(text: t, style: st(Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(3.0, size * 0.2)..strokeJoin = StrokeJoin.round..color = stroke)), textDirection: TextDirection.ltr)..layout();
    }
  }
  double get width => fill.width;
  double get height => fill.height;
  void paint(Canvas c, Offset o) {
    if (line != null) { line!.paint(c, o + Offset(0, fill.height * 0.07)); line!.paint(c, o); }
    fill.paint(c, o);
  }
}
