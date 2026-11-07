import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../core/state.dart';
import 'renderer.dart';
import 'world.dart';

/// Jogo Flame: câmera isométrica, simulação e desenho do hospital.
class HospitalGame extends FlameGame {
  final GameState s;
  late final HospitalWorld w;
  late final SceneRenderer scene;
  HospitalGame(this.s) { w = HospitalWorld(s); scene = SceneRenderer(w, s); }

  Vector2? _camTarget;
  Vector2 vel = Vector2.zero();
  bool dragging = false;
  void Function(String target)? onTap;

  static const minZoom = 0.22, maxZoom = 1.05;

  @override
  Color backgroundColor() => const Color(0xFF74C863);

  @override
  Future<void> onLoad() async {
    world.add(scene);
    camera.viewfinder.anchor = Anchor.center;
    // começa perto (hospital pequeno) e abre o enquadramento conforme cresce
    final n = s.builtCount;
    camera.viewfinder.zoom = (size.x / (n <= 2 ? 980 : n <= 4 ? 1060 : 1150)).clamp(0.3, 0.7);
    final o = n <= 2 ? iso(5.6, 7.9) : iso(6.5, 7.2);
    camera.viewfinder.position = Vector2(o.dx, o.dy);
    w.onFocus = (g) => focus(g[0], g[1]);
    for (var i = 0; i < 3; i++) { Future.delayed(Duration(milliseconds: 700 * i), () => w.spawnPatient()); }
  }

  double get zoom => camera.viewfinder.zoom;
  set zoom(double z) { camera.viewfinder.zoom = z.clamp(minZoom, maxZoom).toDouble(); _clamp(); }

  Vector2 screenToWorld(Offset o) {
    final vf = camera.viewfinder;
    return Vector2((o.dx - size.x / 2) / vf.zoom + vf.position.x, (o.dy - size.y / 2) / vf.zoom + vf.position.y);
  }
  Offset worldToScreen(Offset w0) {
    final vf = camera.viewfinder;
    return Offset((w0.dx - vf.position.x) * vf.zoom + size.x / 2, (w0.dy - vf.position.y) * vf.zoom + size.y / 2);
  }
  void panBy(Offset d) { _camTarget = null; final vf = camera.viewfinder; vf.position = vf.position - Vector2(d.dx, d.dy) / vf.zoom; _clamp(); }
  void zoomAt(Offset focal, double factor) {
    final before = screenToWorld(focal);
    zoom = zoom * factor;
    final after = screenToWorld(focal);
    camera.viewfinder.position = camera.viewfinder.position + (before - after); _camTarget = null; _clamp();
  }
  void _clamp() { final p = camera.viewfinder.position; camera.viewfinder.position = Vector2(p.x.clamp(-2200.0, 2600.0), p.y.clamp(-800.0, 2000.0)); }
  void focus(double gx, double gy, {double offY = 0}) { final o = iso(gx, gy); _camTarget = Vector2(o.dx, o.dy + offY / zoom); }
  void focusArea(String target, {bool sheet = false}) {
    final off = sheet ? size.y * 0.2 : 0.0;
    if (target == 'reception') { focus(2.5, 4.5, offY: off); }
    else if (target == 'treasury') { focus(2.5, 11.5, offY: off); }
    else if (target.startsWith('room:')) { final rm = w.rooms.firstWhere((r) => r.t.id == target.substring(5)); focus(rm.x + 2, rm.y + 2.5, offY: off); }
  }
  Rect get viewRect { final a = screenToWorld(Offset.zero), b = screenToWorld(Offset(size.x, size.y)); return Rect.fromLTRB(a.x, a.y, b.x, b.y); }

  /// Toque no mundo: presentes, pilhas de dinheiro, salas, recepção, cofre.
  void tapAt(Offset screen, {String? openRoom}) {
    final wp = screenToWorld(screen), wo = Offset(wp.x, wp.y);
    for (final g in [...w.gifts]) { if ((iso(g.gx, g.gy, g.z + 10) - wo).distance < 60 + 20 / zoom * 0.2) { w.openGift(g); return; } }
    final gp = toGrid(wp.x, wp.y);
    for (final rm in w.rooms) {
      if (rm.stash > 0.5) { final pl = rm.pile(); if ((iso(pl[0], pl[1], 12) - wo).distance < 46) { w.grabStash(rm); return; } }
    }
    for (final rm in w.rooms) {
      if (!s.built(rm.t.id) && rm.t != s.nextRoom) continue;
      final plate = iso(rm.x + 2, rm.y + 2.5, rm.top ? 92 : 80);
      if (rm.contains(gp[0], gp[1]) || ((plate.dx - wo.dx).abs() < 140 && (plate.dy - wo.dy).abs() < 30)) {
        if (openRoom == rm.t.id) { w.tapRoomBoost(rm, wo); } else { onTap?.call('room:${rm.t.id}'); w.tapRoomBoost(rm, wo); }
        return;
      }
    }
    if (gp[0] >= 0 && gp[0] <= 5 && gp[1] >= 2 && gp[1] <= 7.2) { onTap?.call('reception'); return; }
    if (gp[0] >= 0 && gp[0] <= 5 && gp[1] >= 8.9 && gp[1] <= 14) { if (s.treasury >= 1) { s.collect(); } else { onTap?.call('treasury'); } return; }
    onTap?.call('none');
  }

  double _saveT = 0;
  void Function()? onAutosave;

  @override
  void update(double dt) {
    final step = math.min(dt, 0.1);
    super.update(step);
    w.update(step);
    final vf = camera.viewfinder;
    if (_camTarget != null) {
      final d = _camTarget! - vf.position;
      if (d.length < 2) { _camTarget = null; } else { vf.position = vf.position + d * math.min(1.0, step * 5); }
    } else if (!dragging && vel.length > 5) {
      vf.position = vf.position - vel * step / vf.zoom; vel.scale(math.pow(0.03, step).toDouble()); _clamp();
    }
    scene.view = viewRect.inflate(200);
    scene.zoom = zoom;
    _saveT += step;
    if (_saveT > 10) { _saveT = 0; onAutosave?.call(); }
  }
}
