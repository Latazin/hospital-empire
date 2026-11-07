import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/economy.dart';
import '../core/format.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/progression.dart';
import '../core/save_service.dart';
import 'components/person.dart';
import 'components/room_component.dart';
import 'components/world_components.dart';
import 'draw.dart';

/// Mundo do jogo renderizado pelo Flame: hospital isométrico, personagens
/// autônomos, fluxo de pacientes, transporte de dinheiro e eventos.
class HospitalGame extends FlameGame {
  final GameState s;
  HospitalGame(this.s);

  final rnd = math.Random();
  final List<RoomComponent> rooms = [];
  late final ReceptionComponent reception;
  late final TreasuryComponent treasury;
  final List<Patient> pQueue = [];
  final List<Carrier> carriers = [];
  final List<Person> wanderers = [];
  Person? receptionist;
  Person? inspector;
  double checkinProgress = 0;

  double time = 0;
  double _spawnT = 2;
  double _emergencyT = 70;
  double _epidemicT = 420;
  double _inspectionT = 200;
  double _saveT = 0, _notifyT = 0, _autoT = 0, _checkT = 0;
  double _lastFullMsg = -10;
  Vector2? _camTarget;
  final Set<String> _notifiedAch = {};

  /// Chamado quando o jogador toca numa área: 'room:<id>', 'reception', 'treasury'.
  void Function(String target)? onTapTarget;

  @override
  Color backgroundColor() => const Color(0xFF5FAE57);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = 0.8;
    final start = Iso.p(5, 8);
    camera.viewfinder.position = Vector2(start.dx, start.dy);

    world.add(Ground());
    world.add(FrontWalls());
    reception = ReceptionComponent();
    treasury = TreasuryComponent();
    world.add(reception);
    world.add(treasury);
    for (final t in roomTypes) {
      final r = RoomComponent(t);
      rooms.add(r);
      world.add(r);
    }
    receptionist = Person(Vector2(2.15, 2.45), Role.receptionist);
    world.add(receptionist!);
    for (int i = 0; i < 2; i++) {
      final w = Person(Vector2(6.0 + i * 8, 8), i == 0 ? Role.nurse : Role.doctor, speed: 1.2);
      wanderers.add(w);
      world.add(w);
    }
    const treePos = [
      [-13.0, -6.0], [-13.0, 0.0], [-13.0, 6.0], [-13.0, 14.0], [-13.0, 22.0], [23.0, 0.0],
      [23.5, 10.0], [28.0, 11.0], [24.0, 20.0], [29.0, 22.0], [12.0, 18.0], [4.0, 19.0],
      [16.0, 24.0], [1.0, 24.0], [-5.0, 18.0], [-4.0, 24.0], [30.0, 3.0], [20.0, 17.5],
    ];
    for (final p in treePos) {
      world.add(Tree(Vector2(p[0], p[1]), size: 0.8 + rnd.nextDouble() * 0.5));
    }

    s.onReset = _resetWorld;
    s.ensureDaily();
    s.ensureWeekly();
    for (final a in achievementDefs) {
      if (s.achievementDone(a)) _notifiedAch.add(a.id);
    }
  }

  // ================================================================ câmera
  Vector2 screenToWorld(Offset o) {
    final vf = camera.viewfinder;
    return Vector2((o.dx - size.x / 2) / vf.zoom + vf.position.x,
        (o.dy - size.y / 2) / vf.zoom + vf.position.y);
  }

  void panBy(Offset delta) {
    _camTarget = null;
    final vf = camera.viewfinder;
    vf.position = Vector2(vf.position.x - delta.dx / vf.zoom, vf.position.y - delta.dy / vf.zoom);
    _clampCamera();
  }

  Vector2 get treasuryCenter => Vector2(2.5, 11.5);

  double get zoom => camera.viewfinder.zoom;
  set zoom(double z) {
    camera.viewfinder.zoom = z.clamp(0.42, 2.2).toDouble();
    _clampCamera();
  }

  void _clampCamera() {
    final p = camera.viewfinder.position;
    camera.viewfinder.position =
        Vector2(p.x.clamp(-750.0, 950.0).toDouble(), p.y.clamp(-120.0, 720.0).toDouble());
  }

  void cameraFocus(Vector2 g) {
    final o = Iso.p(g.x, g.y);
    _camTarget = Vector2(o.dx, o.dy);
  }

  void focusArea(String target) {
    if (target == 'reception') {
      cameraFocus(Vector2(2.5, 4.5));
    } else if (target == 'treasury') {
      cameraFocus(Vector2(2.5, 11.5));
    } else if (target.startsWith('room:')) {
      final r = rooms.firstWhere((r) => r.type.id == target.substring(5));
      cameraFocus(Vector2(r.x + 2, r.y + 2.5));
    }
  }

  void tapAt(Offset screen) {
    final w = screenToWorld(screen);
    final gp = Iso.toGrid(w.x, w.y);
    String? target;
    for (final r in rooms) {
      if (r.hit(gp)) target = 'room:${r.type.id}';
    }
    if (target == null && reception.hit(gp)) target = 'reception';
    if (target == null && treasury.hit(gp)) target = 'treasury';
    if (target != null) {
      Sfx.click();
      onTapTarget?.call(target);
    }
  }

  // ================================================================ efeitos
  void floatText(Vector2 g, String text, Color color, {double size = 11}) {
    world.add(FloatingText(Iso.p(g.x, g.y), text, color, size: size));
  }

  // ================================================================ loop
  @override
  void update(double dt) {
    final step = math.min(dt, 0.1); // evita saltos após travadas
    super.update(step);
    time += step;
    s.addStat('playSeconds', step);

    if (_camTarget != null) {
      final vf = camera.viewfinder;
      final d = _camTarget! - vf.position;
      if (d.length < 2) {
        _camTarget = null;
      } else {
        vf.position = vf.position + d * math.min(1.0, step * 4);
      }
    }

    _updateEvents(step);

    _spawnT -= step;
    if (_spawnT <= 0) {
      _spawnT = Eco.spawnInterval(s) * (0.7 + rnd.nextDouble() * 0.6);
      spawnPatient();
    }

    _processQueue(step);
    _updateCarriers(step);
    _updateWanderers();

    final ai = Eco.autoCollectInterval(s);
    if (ai.isFinite) {
      _autoT += step;
      if (_autoT >= ai) {
        _autoT = 0;
        final v = s.collect(auto: true);
        if (v > 0) floatText(Vector2(2.5, 11.5), '+\$${fmt(v)}', const Color(0xFF9CFF6B), size: 12);
      }
    }

    _saveT += step;
    if (_saveT >= 15) {
      _saveT = 0;
      SaveService.save(s);
    }

    _checkT += step;
    if (_checkT >= 2) {
      _checkT = 0;
      s.ensureDaily();
      s.ensureWeekly();
      for (final a in achievementDefs) {
        if (!_notifiedAch.contains(a.id) && s.achievementDone(a)) {
          _notifiedAch.add(a.id);
          s.toast('🏆 Conquista desbloqueada: ${a.name}');
          Sfx.play('coin.wav');
        }
      }
      if (s.objectiveDone) s.markDirty();
    }

    _notifyT += step;
    if (_notifyT >= 0.25) {
      _notifyT = 0;
      s.markDirty();
      s.flushIfDirty();
    }
  }

  void _updateEvents(double dt) {
    // Epidemia
    if (s.epidemic) {
      s.epidemicLeft -= dt;
      if (s.epidemicLeft <= 0) {
        s.epidemic = false;
        s.toast('✅ Epidemia controlada!');
      }
    } else {
      _epidemicT -= dt;
      if (_epidemicT <= 0) {
        _epidemicT = 480.0 + rnd.nextDouble() * 360;
        s.epidemic = true;
        s.epidemicLeft = 60;
        Sfx.play('alert.wav');
        s.toast('🦠 EPIDEMIA! Muitos pacientes por 60s');
      }
    }
    // Emergências
    _emergencyT -= dt;
    if (_emergencyT <= 0) {
      _emergencyT = 100.0 + rnd.nextDouble() * 120;
      startEmergency();
    }
    // Inspeções
    if (inspector == null) {
      _inspectionT -= dt;
      if (_inspectionT <= 0) {
        _inspectionT = 300.0 + rnd.nextDouble() * 120;
        startInspection();
      }
    }
    // Emergências que esperaram demais
    for (final p in pQueue.toList()) {
      if (p.emergency && p.emergencyLeft <= 0) {
        final idx = pQueue.indexOf(p);
        pQueue.remove(p);
        if (idx == 0) checkinProgress = 0;
        s.rep = math.max(0, s.rep - 10);
        s.toast('😞 Uma emergência não foi atendida a tempo (-10 rep)');
        p.state = PState.leaving;
        p.walkTo([Vector2(0.4, 8.6), Vector2(-1.2, 8.8), Vector2(-3.5, 11.5)],
            onArrive: () => p.removeFromParent());
        _layoutQueue();
      }
    }
  }

  // ================================================================ pacientes
  void spawnPatient({bool emergency = false, Vector2? from}) {
    if (!emergency && pQueue.length >= Eco.queueMax(s)) {
      s.onTurnedAway();
      if (time - _lastFullMsg > 5) {
        _lastFullMsg = time;
        floatText(Vector2(0.3, 8), 'Fila cheia! Melhore a Recepção', const Color(0xFFFF8A80));
      }
      return;
    }
    final vip = !emergency && rnd.nextDouble() < 0.06;
    final start = from ?? Vector2(-8.0 + rnd.nextDouble() * 0.6 - 0.3, rnd.nextBool() ? -12.0 : 30.0);
    final p = Patient(start, vip: vip, emergency: emergency, sick: s.epidemic && rnd.nextDouble() < 0.7);
    world.add(p);
    if (emergency) {
      pQueue.insert(pQueue.isEmpty ? 0 : 1, p);
    } else {
      pQueue.add(p);
    }
    final path = from == null
        ? [Vector2(start.x, 8.0), Vector2(-1, 8.0), Vector2(0.4, 8.0)]
        : [Vector2(-1.2, 8.8), Vector2(0.4, 8.0)];
    p.walkTo(path, onArrive: () {
      p.state = PState.queued;
      _layoutQueue();
    });
  }

  Vector2 queueSpot(int i) => i == 0
      ? ReceptionComponent.deskSpot
      : ReceptionComponent.chairs[(i - 1) % ReceptionComponent.chairs.length];

  void _layoutQueue() {
    for (int i = 0; i < pQueue.length; i++) {
      final p = pQueue[i];
      if (p.state != PState.queued) continue;
      final target = queueSpot(i);
      if (p.g.distanceTo(target) > 0.05) {
        final via = p.g.x < 1.0 ? [Vector2(1.2, 7.6), target] : [target];
        p.walkTo(via);
      }
    }
  }

  void _processQueue(double dt) {
    if (pQueue.isEmpty) {
      checkinProgress = 0;
      receptionist?.anim = Anim.idle;
      return;
    }
    final head = pQueue.first;
    if (head.state != PState.queued || head.moving ||
        head.g.distanceTo(ReceptionComponent.deskSpot) > 0.08) {
      receptionist?.anim = Anim.idle;
      return;
    }
    head.facingLeft = true;
    receptionist?.anim = Anim.work;
    if (checkinProgress < 1) {
      checkinProgress += dt / Eco.checkinTime(s);
      if (head.talkT <= 0) head.talk(0.8);
      return;
    }
    final room = _pickRoom();
    if (room == null) {
      head.waitingForRoom = true;
      receptionist?.anim = Anim.idle;
      return;
    }
    head.waitingForRoom = false;
    final slot = room.freeSlot();
    room.reserve(slot, head);
    pQueue.removeAt(0);
    checkinProgress = 0;
    head.state = PState.toRoom;
    head.room = room;
    head.slot = slot;
    head.walkTo([Vector2(2.15, 7.6), Vector2(room.x + 2.11, 8.0), ..._roomEntry(room, slot)],
        onArrive: () {
      head.state = PState.inService;
      head.facingLeft = !room.plot.top;
      room.beginService(slot);
    });
    _layoutQueue();
  }

  List<Vector2> _roomEntry(RoomComponent r, int slot) {
    final spot = r.patientSpot(slot);
    if (r.plot.top) {
      return [r.doorPoint, Vector2(spot.x, r.y + 3.3), spot];
    }
    return [r.doorPoint, Vector2(r.x + 2.11, r.y + 0.7), Vector2(r.x + 2.11, r.y + 2.85), spot];
  }

  List<Vector2> _roomExit(RoomComponent r, int slot) {
    final spot = r.patientSpot(slot);
    if (r.plot.top) {
      return [Vector2(spot.x, r.y + 3.3), r.doorPoint];
    }
    return [Vector2(r.x + 2.11, r.y + 2.85), Vector2(r.x + 2.11, r.y + 0.7), r.doorPoint];
  }

  RoomComponent? _pickRoom() {
    final free = rooms.where((r) => r.freeSlot() >= 0).toList();
    if (free.isEmpty) return null;
    // Preferência leve para as salas menos ocupadas
    free.sort((a, b) {
      final oa = a.occupants.where((o) => o != null).length / a.slots;
      final ob = b.occupants.where((o) => o != null).length / b.slots;
      return oa.compareTo(ob);
    });
    final best = free.where((r) {
      final o = r.occupants.where((x) => x != null).length / r.slots;
      final o0 = free.first.occupants.where((x) => x != null).length / free.first.slots;
      return o <= o0 + 0.001;
    }).toList();
    return best[rnd.nextInt(best.length)];
  }

  void patientLeaves(Patient p, RoomComponent r, int slot) {
    p.state = PState.leaving;
    p.room = null;
    p.slot = -1;
    final up = rnd.nextBool();
    p.walkTo([
      ..._roomExit(r, slot),
      Vector2(r.x + 2.11, 8.6),
      Vector2(0.4, 8.6),
      Vector2(-1, 8.6),
      Vector2(-7.7, 8.6),
      Vector2(-7.7, up ? -12.0 : 30.0),
    ], onArrive: () => p.removeFromParent());
  }

  // ================================================================ emergências
  void startEmergency() {
    Sfx.play('alert.wav');
    s.toast('🚑 Ambulância chegando com uma emergência!');
    world.add(Ambulance(onArrive: () {
      spawnPatient(emergency: true, from: Vector2(-3.5, 11.6));
    }));
  }

  void onEmergencyTreated(Patient p) {
    if (p.emergencyLeft <= 0) return;
    s.addStat('emergencies');
    s.gold += 2;
    s.toast('🚑 Emergência salva! +2 ouro');
    if (rnd.nextDouble() < 0.15) s.addCard(rnd.nextInt(cardDefs.length));
  }

  // ================================================================ inspeção
  void startInspection() {
    s.toast('📋 O inspetor da Vigilância Sanitária chegou!');
    Sfx.play('alert.wav');
    final insp = Person(Vector2(-7.7, -12), Role.inspector, speed: 1.7);
    inspector = insp;
    world.add(insp);
    final pts = <Vector2>[Vector2(-7.7, 8.3), Vector2(0.4, 8.3), Vector2(2.15, 7.6)];
    final built = rooms.where((r) => r.operational).toList()..sort((a, b) => a.x.compareTo(b.x));
    for (final r in built) {
      pts.add(Vector2(r.x + 2.6, 8.3));
    }
    insp.walkTo(pts, onArrive: () {
      insp.talk(1.5);
      _evaluateInspection();
      insp.walkTo([Vector2(0.4, 8.4), Vector2(-7.7, 8.4), Vector2(-7.7, -12)], onArrive: () {
        insp.removeFromParent();
        if (inspector == insp) inspector = null;
      });
    });
  }

  void _evaluateInspection() {
    final built = rooms.where((r) => r.built).toList();
    double avgLvl = 0;
    for (final r in built) {
      avgLvl += r.save.level;
    }
    avgLvl /= math.max(1, built.length);
    double score = math.min(1.0, avgLvl / (8.0 * s.unit + 2)) * 0.4;
    if (pQueue.length < Eco.queueMax(s)) score += 0.2;
    if (s.treasury < Eco.treasuryMax(s) * 0.95) score += 0.2;
    score += math.min(1.0, s.ownedManagers.length / 3) * 0.1;
    score += built.length >= 2 ? 0.1 : 0.05;
    String grade;
    String msg;
    s.addStat('inspections');
    if (score >= 0.8) {
      grade = 'A';
      s.addStat('inspectionsA');
      s.gold += 10;
      s.rep += 50;
      msg = 'Excelente! +10 ouro e +50 reputação.';
      if (rnd.nextDouble() < 0.5) s.addCard(rnd.nextInt(cardDefs.length));
    } else if (score >= 0.6) {
      grade = 'B';
      s.gold += 5;
      s.rep += 20;
      msg = 'Muito bom! +5 ouro e +20 reputação.';
    } else if (score >= 0.4) {
      grade = 'C';
      s.rep += 5;
      msg = 'Regular. +5 reputação.\nDica: melhore salas, recepção e esvazie a tesouraria.';
    } else {
      grade = 'D';
      s.rep = math.max(0, s.rep - 20);
      msg = 'Reprovado! -20 reputação.\nFila cheia ou tesouraria lotada pesam na nota.';
    }
    s.dialog(GameDialog('Inspeção: nota $grade', msg, icon: '📋'));
  }

  // ================================================================ transporte
  void _updateCarriers(double dt) {
    final n = Eco.carriers(s);
    while (carriers.length < n) {
      final c = Carrier(TreasuryComponent.home(carriers.length), carriers.length);
      carriers.add(c);
      world.add(c);
    }
    for (final c in carriers) {
      c.speed = Eco.carrierSpeed(s);
      if (c.blocked) {
        c.retryT -= dt;
        if (c.retryT <= 0) {
          c.retryT = 1;
          _deposit(c);
        }
      } else if (!c.busy) {
        _dispatch(c);
      }
    }
  }

  List<Vector2> _toCorridor(Vector2 from) {
    if (from.x < 5 && from.y > 8.9) {
      return [Vector2(2.5, from.y), Vector2(2.5, 9.0), Vector2(2.5, 8.3)];
    }
    return [Vector2(from.x, 8.3)];
  }

  void _dispatch(Carrier c) {
    final targets = rooms.where((r) => r.operational && r.stash > 0.5 && !r.claimed).toList()
      ..sort((a, b) => b.stash.compareTo(a.stash));
    if (targets.isEmpty) return;
    final list = targets.take(3).toList()..sort((a, b) => a.x.compareTo(b.x));
    for (final r in list) {
      r.claimed = true;
    }
    c.busy = true;
    _visit(c, list, 0);
  }

  void _visit(Carrier c, List<RoomComponent> list, int i) {
    final cap = Eco.carrierCapacity(s);
    if (i >= list.length || c.load >= cap - 0.01) {
      for (int k = i; k < list.length; k++) {
        list[k].claimed = false;
      }
      _returnToTreasury(c);
      return;
    }
    final r = list[i];
    c.walkTo([..._toCorridor(c.g), Vector2(r.x + 2.0, 8.3), r.doorPoint], onArrive: () {
      final got = r.take(cap - c.load);
      c.load += got;
      r.claimed = false;
      _visit(c, list, i + 1);
    });
  }

  void _returnToTreasury(Carrier c) {
    c.walkTo([..._toCorridor(c.g), Vector2(2.5, 8.3), Vector2(2.5, 9.2), TreasuryComponent.depositSpot],
        onArrive: () => _deposit(c));
  }

  void _deposit(Carrier c) {
    if (c.load > 0) {
      final d = s.deposit(c.load);
      c.load -= d;
      if (d > 0) {
        floatText(TreasuryComponent.depositSpot, '+\$${fmt(d)}', const Color(0xFFFFD54F));
        Sfx.play('coin.wav', volume: 0.2);
      }
    }
    if (c.load > 0.01) {
      c.blocked = true;
      c.anim = Anim.wait;
      return;
    }
    c.blocked = false;
    c.load = 0;
    c.celebrate(0.4);
    c.walkTo([TreasuryComponent.home(c.index)], onArrive: () => c.busy = false);
  }

  // ================================================================ ambiente
  void _updateWanderers() {
    for (final w in wanderers) {
      if (!w.moving && rnd.nextDouble() < 0.006) {
        w.walkTo([Vector2(1.0 + rnd.nextDouble() * 19, 7.4 + rnd.nextDouble() * 1.2)]);
      }
      if (!w.moving && rnd.nextDouble() < 0.002) w.talk(1.5);
    }
  }

  void _resetWorld() {
    for (final p in world.children.whereType<Patient>().toList()) {
      p.removeFromParent();
    }
    pQueue.clear();
    checkinProgress = 0;
    for (final r in rooms) {
      r.resetRuntime();
      r.claimed = false;
    }
    for (final c in carriers) {
      c.removeFromParent();
    }
    carriers.clear();
  }
}
