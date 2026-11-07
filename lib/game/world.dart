import 'dart:math' as math;
import 'dart:ui';

import '../core/data.dart';
import '../core/format.dart';
import '../core/state.dart';

final rnd = math.Random();
double rr(double a, double b) => a + rnd.nextDouble() * (b - a);
T pick<T>(List<T> l) => l[rnd.nextInt(l.length)];
typedef V2 = List<double>;

const colX = [0.3, 2.95], rowY = [0.55, 2.85];
const seatH = {'chair': 13.0, 'lab': 13.0, 'pharma': 12.0, 'bed': 15.0, 'scan': 13.0, 'surgery': 16.0, 'icu': 15.0, 'baby': 15.0};
final chairs = <V2>[for (final y in [5.3, 6.3]) for (final x in [0.8, 1.7, 2.6, 3.5, 4.4]) [x, y]];
const desk = [2.15, 4.0];
const depositSpot = [2.5, 10.6];
V2 homeOf(int i) => [0.7 + i * 0.72, 12.9];
const nurseRooms = ['enfermaria', 'uti', 'maternidade', 'farmacia'];
const ailIcons = ['', 'bandage', 'sling', 'ice', '', 'bandage', '', 'sling'];

/// Conversão grade → pixels do mundo (escala 2x dos sprites).
Offset iso(double gx, double gy, [double hpx = 0]) => Offset((gx - gy) * 64, (gx + gy) * 32 - hpx * 2);
V2 toGrid(double wx, double wy) { final a = wx / 64, b = wy / 32; return [(a + b) / 2, (b - a) / 2]; }

class Person {
  double gx, gy, z = 0, speed, t = rnd.nextDouble() * 10, seed = rnd.nextDouble() * 10, ang = math.pi / 4;
  double cel = 0, talk = 0, bubT = 0, load = 0;
  String role, anim = 'idle', sprite;
  String? bub;
  bool sit = false;
  final List<V2> path = [];
  void Function()? cb;
  Person(this.gx, this.gy, this.role, this.sprite, {this.speed = 2});
  bool get moving => path.isNotEmpty;
  double get depth => gx + gy + 0.02;
  void walk(List<V2> pts, [void Function()? done]) {
    path..clear()..addAll(pts.map((p) => [p[0], p[1]])); cb = done; sit = false; z = 0;
    if (path.isEmpty) { anim = 'idle'; final c = cb; cb = null; c?.call(); } else { anim = 'walk'; }
  }
  void say(String e, [double dur = 1.6]) { bub = e; bubT = dur; }
  void lookAt(double x, double y) => ang = math.atan2(x - gx, y - gy);
  void update(double dt) {
    t += dt; if (cel > 0) cel -= dt; if (talk > 0) talk -= dt;
    if (bubT > 0) { bubT -= dt; if (bubT <= 0) bub = null; }
    if (path.isEmpty) return;
    final tg = path.first, dx = tg[0] - gx, dy = tg[1] - gy, d = math.sqrt(dx * dx + dy * dy), s = speed * dt;
    if (d <= s) {
      gx = tg[0]; gy = tg[1]; path.removeAt(0);
      if (path.isEmpty) { anim = 'idle'; final c = cb; cb = null; c?.call(); }
    } else {
      gx += dx / d * s; gy += dy / d * s;
      final ta = math.atan2(dx, dy); var da = ta - ang;
      while (da > math.pi) { da -= math.pi * 2; } while (da < -math.pi) { da += math.pi * 2; }
      ang += da * math.min(1.0, dt * 14);
    }
  }
}

class Patient extends Person {
  final bool vip, emg;
  String state = 'arriving', ail;
  RoomRt? room;
  int slot = -1;
  double waited = 0, emgLeft = 45;
  bool noRoom = false;
  Patient(double gx, double gy, {this.vip = false, this.emg = false, bool sick = false})
      : ail = sick ? 'sick' : pick(ailIcons),
        super(gx, gy, 'patient', vip ? 'vip' : emg ? 'emg' : sick ? 'patsick' : 'pat${rnd.nextInt(8)}', speed: emg ? 2.4 : 1.9);
  @override
  void update(double dt) {
    super.update(dt);
    if (state == 'queued' || state == 'arriving') { waited += dt; if (bub == null && state == 'queued' && rnd.nextDouble() < dt * 0.12) say(waited > 25 ? 'angry' : 'sick', 1.8); }
    if (emg && state != 'leaving' && state != 'service') emgLeft -= dt;
  }
}

class Carrier extends Person {
  final int i;
  bool busy = false, blocked = false;
  double retry = 0;
  Carrier(double gx, double gy, this.i) : super(gx, gy, 'carrier', 'carrier', speed: 2.2);
}

class RoomRt {
  final RoomType t;
  final double x, y;
  final bool top;
  double stash = 0, buildAnim = 0, tapCD = 0, pop = 0, glow = 0;
  bool claimed = false;
  bool? lastBuilt;
  final occ = List<Patient?>.filled(4, null), prog = List<double>.filled(4, 0), serv = List<bool>.filled(4, false);
  final List<Person> staff = [];
  Person? mgrFig;
  RoomRt(this.t) : x = plots[t.plot][0], y = plots[t.plot][1], top = plots[t.plot][2] == 1;
  V2 seat(int i) => [x + colX[i % 2] + 0.34, y + rowY[i >> 1] + 0.55];
  V2 docSpot(int i) => [x + (i % 2 == 1 ? 2.6 : 1.3), y + rowY[i >> 1] + 0.95];
  V2 door() => top ? [x + 2, y + 4.9] : [x + 2, y + 0.1];
  V2 corr() => [x + 2, top ? 7.55 : 8.45];
  V2 pile() => top ? [x + 0.55, y + 4.45] : [x + 3.45, y + 4.45];
  V2 mgrSpot() => top ? [x + 3.5, y + 4.4] : [x + 0.6, y + 4.4];
  V2 center() => [x + 2, y + 2.5];
  bool contains(double gx, double gy) => gx >= x && gx <= x + 4 && gy >= y && gy <= y + 5;
  List<V2> entry(int i) { final s = seat(i); return [corr(), door(), [x + 2, s[1]], s]; }
  List<V2> exit(int i) { final s = seat(i); return [[x + 2, s[1]], door(), corr()]; }
  int used() => occ.where((o) => o != null).length;
  void reset() { stash = 0; claimed = false; for (var i = 0; i < 4; i++) { occ[i] = null; serv[i] = false; prog[i] = 0; } }
}

class Car {
  double gx, gy, speed, wait = 0, len;
  String axis = 'y', kind, sprite;
  int dir = 1;
  List<V2> path, after;
  double stop;
  bool stopped = false, moving = true;
  void Function()? onStop;
  Car(this.kind, this.sprite, List<V2> pts, {this.speed = 5, this.stop = 0, this.after = const [], this.onStop, this.len = 1.8})
      : gx = pts[0][0], gy = pts[0][1], path = pts.sublist(1).map((p) => [p[0], p[1]]).toList();
  double get depth => gx + gy;
}

class Gift { double gx, gy, z = 280, life = 25; final bool gold; Gift(this.gx, this.gy, this.gold); double get depth => gx + gy; }

class Particle { double x, y, vx, vy, g, life = 0, max, s, r, vr; String k; Color c; Particle(this.k, this.x, this.y, this.vx, this.vy, this.g, this.max, this.s, this.c, [this.r = 0, this.vr = 0]); }
class FloatText { double x, y, t = 0, size; String s; Color color; FloatText(this.x, this.y, this.s, this.color, this.size); }

/// Simulação do hospital: fila, salas, transporte, eventos e ambiente.
class HospitalWorld {
  final GameState s;
  Fx get fx => s.fx!;
  HospitalWorld(this.s) {
    rooms = roomTypes.map((t) => RoomRt(t)).toList();
    for (final r in rooms) { r.lastBuilt = s.built(r.t.id); }
    for (final w in [[7.0, 'nurse', 'nur0'], [14.0, 'janitor', 'jan'], [18.0, 'doctor', 'doc1']]) {
      final p = Person(w[0] as double, 8, w[1] as String, w[2] as String, speed: 1.1); wander.add(p); people.add(p);
    }
    s.onReset = resetWorld;
  }
  late final List<RoomRt> rooms;
  final List<Person> people = [], wander = [], recep = [];
  final List<Patient> queue = [];
  final List<Carrier> carriers = [];
  final List<Car> cars = [];
  final List<Gift> gifts = [];
  final List<Particle> parts = [];
  final List<FloatText> floats = [];
  Person? guard, inspector;
  double t = 0, checkin = 0, doors = 0, shake = 0, lastFull = -99;
  double evSpawn = 2, evEmg = 80, evEpi = 420, evInsp = 210, evGift = 25, evPed = 3, evCar = 2, autoT = 0;
  void Function(String grade, String msg, Color color)? onInspection;
  void Function(V2 grid)? onFocus;

  // ---------------- efeitos de mundo ----------------
  void spark(Offset p, [Color c = const Color(0xFFFFF59D)]) => parts.add(Particle('spark', p.dx, p.dy, rr(-30, 30), rr(-50, -10), 40, rr(0.5, 0.9), rr(4, 8), c));
  static const confColors = [Color(0xFFFF5A5F), Color(0xFFFFC531), Color(0xFF3FD46B), Color(0xFF3E8BFF), Color(0xFF8F62F8), Color(0xFFFF6FB5), Color(0xFFFFFFFF)];
  void burst(Offset p, int n, List<String> kinds, [double speed = 240]) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 6.283, v = rr(0.3, 1) * speed, k = pick(kinds);
      parts.add(Particle(k, p.dx, p.dy, math.cos(a) * v, math.sin(a) * v * 0.6 - speed * 0.5, k == 'conf' ? 240 : 520, k == 'conf' ? rr(1.4, 2.4) : rr(0.6, 1.1), k == 'coin' ? rr(8, 12) : rr(6, 13), pick(confColors), rnd.nextDouble() * 6, rr(-8, 8)));
    }
  }
  /// Onda de choque (anel que se expande no chão).
  void ring(Offset p, Color c, [int n = 1]) { for (var i = 0; i < n; i++) { parts.add(Particle('ring', p.dx, p.dy, 0, 0, 0, 0.55 + i * 0.18, 30 + i * 10, c)); } }
  /// Raio de luz subindo (marcos de nível).
  void beam(Offset p, Color c) => parts.add(Particle('beam', p.dx, p.dy, 0, 0, 0, 1.1, 120, c));
  void floatTxt(double gx, double gy, String text, Color c, [double size = 26, double h = 46]) { final p = iso(gx, gy, h); floats.add(FloatText(p.dx, p.dy, text, c, size)); }

  // ---------------- atualização ----------------
  void update(double dt) {
    t += dt; s.addSt('play', dt);
    if (shake > 0) shake = math.max(0, shake - dt * 1.6);
    _events(dt);
    if ((evSpawn -= dt) <= 0) { evSpawn = s.spawnInterval * rr(0.7, 1.3); spawnPatient(); }
    _syncStaff();
    _processQueue(dt);
    for (final rm in rooms) { _roomUpdate(rm, dt); }
    _carriers(dt);
    for (final p in [...people]) { p.update(dt); }
    _cars(dt); _ambient(dt); _gifts(dt); _parts(dt);
    final ai = s.autoInterval;
    if (ai.isFinite) { autoT += dt; if (autoT >= ai) { autoT = 0; final v = s.collect(auto: true); if (v > 0) floatTxt(2.5, 11.5, '+\$${fmt(v)}', const Color(0xFF9CFF6B), 26, 60); } }
  }

  void _syncStaff() {
    final wantR = s.rl >= 20 ? 2 : 1;
    while (recep.length < wantR) { final p = Person(recep.isEmpty ? 2.15 : 3.25, 2.45, 'recep', 'rec')..ang = 0; recep.add(p); people.add(p); }
    if (s.rl >= 10 && guard == null) { guard = Person(0.7, 7.25, 'guard', 'guard')..ang = math.pi / 2; people.add(guard!); }
  }

  void _roomUpdate(RoomRt rm, double dt) {
    final b = s.built(rm.t.id);
    if (rm.lastBuilt == false && b) { rm.buildAnim = 2.8; onFocus?.call(rm.center()); fx.sfx('build'); }
    rm.lastBuilt = b;
    if (rm.tapCD > 0) rm.tapCD -= dt;
    if (rm.pop > 0) rm.pop = math.max(0, rm.pop - dt * 1.8);
    if (rm.glow > 0) rm.glow = math.max(0, rm.glow - dt * 0.9);
    if (rm.buildAnim > 0) {
      rm.buildAnim -= dt;
      if (rnd.nextDouble() < dt * 10) { final p = iso(rm.x + rr(0.3, 3.7), rm.y + rr(0.3, 4.7), rr(0, 30)); parts.add(Particle('smoke', p.dx, p.dy, rr(-20, 20), -36, 0, 1.2, rr(6, 12), const Color(0xFFEBE4D7))); }
      if (rm.buildAnim <= 0) {
        final c = iso(rm.x + 2, rm.y + 2.5, 30); burst(c, 90, ['conf', 'spark', 'coin'], 520); ring(c, const Color(0xFFFFE27A), 3); shake = 0.6; fx.sfx('level'); fx.buzz(40);
        rm.pop = 1; rm.glow = 1; fx.confetti(90);
        fx.banner('NOVA SALA!', '${rm.t.name} • ${s.builtCount}/${roomTypes.length} do hospital');
      }
    }
    final op = b && rm.buildAnim <= 0, l = s.lvlOf(rm.t.id), want = op ? GameState.slots(l) : 0;
    while (rm.staff.length < want) {
      final i = rm.staff.length, sp = rm.docSpot(i), nr = nurseRooms.contains(rm.t.id);
      final nurse = (i % 2 == 0) == nr;
      final p = Person(sp[0], sp[1], nurse ? 'nurse' : 'doctor', nurse ? 'nur${i % 2}' : 'doc${(i ~/ 2) % 2}');
      final se = rm.seat(i); p.lookAt(se[0], se[1]); rm.staff.add(p); people.add(p);
      burst(iso(sp[0], sp[1], 20), 12, ['spark'], 160);
    }
    while (rm.staff.length > want) { rm_(rm.staff.removeLast()); }
    for (var i = 0; i < rm.staff.length; i++) { final p = rm.staff[i]; p.anim = rm.serv[i] ? 'work' : 'idle'; if (!rm.serv[i] && rnd.nextDouble() < dt * 0.05) p.talk = 1; }
    final m = op ? s.activeMgr(rm.t.id) : null;
    if (m != null && rm.mgrFig == null) { final sp = rm.mgrSpot(); rm.mgrFig = Person(sp[0], sp[1], 'manager', 'mgr${m.sprite}', speed: 0.9); people.add(rm.mgrFig!); }
    else if (m == null && rm.mgrFig != null) { rm_(rm.mgrFig!); rm.mgrFig = null; }
    else if (m != null && rm.mgrFig != null && !rm.mgrFig!.moving && rnd.nextDouble() < dt * 0.25) {
      final f = rm.mgrFig!, sp = rm.mgrSpot(), here = (f.gx - sp[0]).abs() + (f.gy - sp[1]).abs() < 0.1;
      f.walk([here ? [rm.x + 2, rm.y + 2.3] : sp], () => f.talk = 1.2);
    }
    for (var i = 0; i < 4; i++) {
      if (!rm.serv[i]) continue;
      rm.prog[i] += dt / s.serviceTime(rm.t, l);
      if (rm.prog[i] >= 1) _complete(rm, i);
    }
  }

  void _complete(RoomRt rm, int i) {
    final p = rm.occ[i]; rm.serv[i] = false; rm.prog[i] = 0; rm.occ[i] = null;
    if (p == null) return;
    final mult = p.vip ? 10.0 : p.emg ? 5.0 : 1.0, pay = s.income(rm.t, s.lvlOf(rm.t.id)) * mult;
    rm.stash += pay; s.addSt('patients'); s.rep += p.vip ? 4 : p.emg ? 6 : 1; s.addXP(p.vip || p.emg ? 5 : 1);
    final se = rm.seat(i);
    floatTxt(se[0], se[1], '+\$${fmt(pay)}', p.vip ? const Color(0xFFFFD54F) : const Color(0xFF9CFF6B), p.vip ? 32 : 26, 40);
    burst(iso(se[0], se[1], 30), p.vip ? 14 : 4, ['coin'], 180);
    fx.sfx('coin', pitch: 1 + rnd.nextDouble() * 0.1);
    p.cel = 0.9; p.say('happy', 1.4);
    if (i < rm.staff.length) rm.staff[i].cel = 0.5;
    if (p.vip) { s.addSt('vip'); s.gold += 1; if (rnd.nextDouble() < 0.25) s.addCard(rnd.nextInt(cards.length)); floatTxt(se[0], se[1], '+1 ouro', const Color(0xFF7FD8FF), 24, 62); }
    if (p.emg && p.emgLeft > 0) { s.addSt('emergencies'); s.gold += 2; fx.toast('Emergência salva! +2 ouro'); if (rnd.nextDouble() < 0.15) s.addCard(rnd.nextInt(cards.length)); }
    p.state = 'leaving'; p.room = null; p.slot = -1; p.sit = false; p.z = 0;
    final up = rnd.nextBool();
    Future.delayed(const Duration(milliseconds: 450), () => p.walk([...rm.exit(i), [0.5, 8.6], [-1.2, 8.6], [-7.6, 8.6], [-7.6, up ? -13.0 : 31.0]], () => rm_(p)));
  }
  void rm_(Person p) => people.remove(p);

  // ---------------- pacientes ----------------
  void spawnPatient({bool emg = false, V2? from}) {
    if (!emg && queue.length >= s.qmax) {
      s.rep = math.max(0, s.rep - 0.5); s.addSt('turned');
      if (t - lastFull > 6) { lastFull = t; floatTxt(0.2, 8, 'Fila cheia! Melhore a Recepção', const Color(0xFFFF9E9E), 24, 50); }
      return;
    }
    final vip = !emg && rnd.nextDouble() < 0.06;
    final start = from ?? [-8.1 + rr(-0.25, 0.25), rnd.nextBool() ? -13.0 : 31.0];
    final p = Patient(start[0], start[1], vip: vip, emg: emg, sick: s.epidemic > 0 && rnd.nextDouble() < 0.7);
    people.add(p);
    if (emg) { queue.insert(math.min(1, queue.length), p); } else { queue.add(p); }
    final List<V2> pathPts = from != null ? (emg ? [[-1.5, 8.7], [0.5, 8.1]] : [[from[0], 8.0], [-1.2, 8.0], [0.5, 8.1]]) : [[start[0], 8.0], [-1.2, 8.0], [0.5, 8.1]];
    p.walk(pathPts, () { p.state = 'queued'; layoutQueue(); });
  }
  V2 queueSpot(int i) => i == 0 ? desk : chairs[(i - 1) % chairs.length];
  void layoutQueue() {
    for (var i = 0; i < queue.length; i++) {
      final p = queue[i];
      if (p.state != 'queued') continue;
      final tg = queueSpot(i);
      if ((p.gx - tg[0]).abs() + (p.gy - tg[1]).abs() > 0.05) {
        final via = p.gx < 1.0 && p.gy > 7 ? <V2>[[1.2, 7.4], tg] : <V2>[tg];
        final idx = i;
        p.walk(via, () { if (idx > 0) { p.sit = true; p.z = 12; p.ang = math.pi * 0.25; } else { p.ang = math.pi; } });
      }
    }
  }
  RoomRt? _pickRoom() {
    final free = rooms.where((r) => _free(r) >= 0).toList();
    if (free.isEmpty) return null;
    var best = double.infinity;
    for (final r in free) { best = math.min(best, r.used() / GameState.slots(s.lvlOf(r.t.id))); }
    return pick(free.where((r) => r.used() / GameState.slots(s.lvlOf(r.t.id)) <= best + 1e-6).toList());
  }
  int _free(RoomRt r) {
    if (!s.built(r.t.id) || r.buildAnim > 0) return -1;
    final n = GameState.slots(s.lvlOf(r.t.id));
    for (var i = 0; i < n; i++) { if (r.occ[i] == null) return i; }
    return -1;
  }
  void _processQueue(double dt) {
    if (queue.isEmpty) { checkin = 0; for (final r in recep) { r.anim = 'idle'; } return; }
    final h = queue.first;
    if (h.state != 'queued' || h.moving || (h.gx - desk[0]).abs() + (h.gy - desk[1]).abs() > 0.1) { for (final r in recep) { r.anim = 'idle'; } return; }
    h.ang = math.pi; for (final r in recep) { r.anim = 'work'; }
    if (checkin < 1) { checkin += dt / s.checkinTime; if (h.talk <= 0) h.talk = 0.8; return; }
    final room = _pickRoom();
    if (room == null) { h.noRoom = true; for (final r in recep) { r.anim = 'idle'; } return; }
    h.noRoom = false;
    final slot = _free(room); room.occ[slot] = h; room.prog[slot] = 0; room.serv[slot] = false;
    queue.removeAt(0); checkin = 0; h.state = 'toRoom'; h.room = room; h.slot = slot; h.say('room:${room.t.id}', 2.2);
    h.walk([[2.15, 7.6], ...room.entry(slot)], () { h.state = 'service'; h.sit = true; h.z = seatH[room.t.kind]!; final ds = room.docSpot(slot); h.lookAt(ds[0], ds[1]); room.serv[slot] = true; });
    layoutQueue();
  }

  // ---------------- transporte ----------------
  void _carriers(double dt) {
    while (carriers.length < s.carriers) { final h = homeOf(carriers.length), c = Carrier(h[0], h[1], carriers.length); carriers.add(c); people.add(c); }
    for (final c in carriers) {
      c.speed = s.carrierSpeed;
      if (c.blocked) { c.retry -= dt; if (c.retry <= 0) { c.retry = 1; _deposit(c); } }
      else if (!c.busy) { _dispatch(c); }
    }
  }
  List<V2> _toCorr(Carrier c) {
    if (c.gx < 5 && c.gy > 8.9) return [[2.5, c.gy], [2.5, 9.2], [2.5, 8.45]];
    return [[c.gx, (c.gy - 7.55).abs() < 0.2 ? 7.55 : 8.45]];
  }
  void _dispatch(Carrier c) {
    final ts = rooms.where((r) => s.built(r.t.id) && r.buildAnim <= 0 && r.stash > 0.5 && !r.claimed).toList()..sort((a, b) => b.stash.compareTo(a.stash));
    if (ts.isEmpty) return;
    final list = ts.take(3).toList()..sort((a, b) => a.x.compareTo(b.x));
    for (final r in list) { r.claimed = true; }
    c.busy = true; _visit(c, list, 0);
  }
  void _visit(Carrier c, List<RoomRt> list, int i) {
    final cap = s.carrierCap;
    if (i >= list.length || c.load >= cap - 0.01) { for (var k = i; k < list.length; k++) { list[k].claimed = false; } _goTreasury(c); return; }
    final r = list[i], pl = r.pile();
    c.walk([..._toCorr(c), r.corr(), r.door(), [r.x + 2, pl[1]], pl], () {
      final got = math.min(r.stash, cap - c.load); r.stash -= got; c.load += got; r.claimed = false;
      if (got > 0) burst(iso(pl[0], pl[1], 20), 4, ['coin'], 120);
      c.walk([[r.x + 2, pl[1]], r.door(), r.corr()], () => _visit(c, list, i + 1));
    });
  }
  void _goTreasury(Carrier c) => c.walk([..._toCorr(c), [2.5, 8.45], [2.5, 9.3], depositSpot], () => _deposit(c));
  void _deposit(Carrier c) {
    if (c.load > 0) {
      final space = math.max(0.0, s.treMax - s.treasury), d = math.min(space, c.load);
      s.treasury += d; c.load -= d;
      if (d > 0) { floatTxt(depositSpot[0], depositSpot[1], '+\$${fmt(d)}', const Color(0xFFFFD54F), 24, 40); fx.sfx('coin', pitch: 0.8); }
    }
    if (c.load > 0.01) { c.blocked = true; c.anim = 'idle'; return; }
    c.blocked = false; c.load = 0; c.cel = 0.4;
    c.walk([homeOf(c.i)], () { c.busy = false; c.ang = math.pi * 0.25; });
  }

  // ---------------- toques ----------------
  bool tapRoomBoost(RoomRt rm, Offset w) {
    if (!s.built(rm.t.id) || rm.buildAnim > 0 || rm.tapCD > 0) return false;
    rm.tapCD = 0.07; var any = false;
    for (var i = 0; i < 4; i++) { if (rm.serv[i]) { rm.prog[i] = math.min(0.999, rm.prog[i] + 0.12); any = true; } }
    if (any) {
      s.addSt('taps'); fx.sfx('boost'); fx.buzz(5);
      parts.add(Particle('bolt', w.dx + rr(-16, 16), w.dy - 20, rr(-40, 40), -160, 120, 0.6, 26, const Color(0xFFFFE27A)));
      for (var k = 0; k < 4; k++) { spark(w + Offset(rr(-28, 28), rr(-20, 20)), const Color(0xFFFFF176)); }
    }
    return any;
  }
  void grabStash(RoomRt rm) {
    final space = math.max(0.0, s.treMax - s.treasury), d = math.min(space, rm.stash), pl = rm.pile();
    if (d <= 0) { fx.sfx('nope'); floatTxt(pl[0], pl[1], 'Cofre cheio! Colete', const Color(0xFFFF9E9E), 24, 40); return; }
    rm.stash -= d; s.treasury += d; s.addSt('taps');
    burst(iso(pl[0], pl[1], 14), 10, ['coin'], 260); fx.sfx('coin', pitch: 1.2); fx.buzz(8);
    floatTxt(pl[0], pl[1], '+\$${fmt(d)} ao cofre', const Color(0xFFFFE27A), 24, 40);
  }
  void openGift(Gift g) {
    gifts.remove(g); s.addSt('gifts');
    final p = iso(g.gx, g.gy, 16);
    burst(p, 40, ['conf', 'spark', 'coin'], 400); fx.sfx('gift'); fx.buzz(25); shake = 0.2;
    final r = rnd.nextDouble();
    if (g.gold || r < 0.2) { final v = 3 + rnd.nextInt(5); s.gold += v; floatTxt(g.gx, g.gy, '+$v ouro', const Color(0xFF7FD8FF), 34, 50); fx.flyGold(v); }
    else if (r < 0.75) { final v = math.max(60.0, s.baseRate * rr(60, 180)); s.earn(v); floatTxt(g.gx, g.gy, '+\$${fmt(v)}', const Color(0xFFFFE27A), 34, 50); fx.flyMoney(v, coins: 12); }
    else if (r < 0.88) { s.addCard(rnd.nextInt(cards.length)); }
    else { s.gb = math.max(s.gb, nowMs()) + 3 * 60000; fx.banner('RENDA x2!', 'Presente surpresa: 3 minutos'); }
    s.addXP(3); s.changed();
  }

  // ---------------- eventos ----------------
  void _events(double dt) {
    if (s.epidemic > 0) { s.epidemic -= dt; if (s.epidemic <= 0) fx.toast('Epidemia controlada!'); }
    else if ((evEpi -= dt) <= 0) { evEpi = rr(480, 840); s.epidemic = 60; fx.sfx('alert'); fx.banner('EPIDEMIA!', 'Muitos pacientes por 60s'); }
    if ((evEmg -= dt) <= 0) { evEmg = rr(100, 220); startEmergency(); }
    if (inspector == null && (evInsp -= dt) <= 0) { evInsp = rr(300, 420); startInspection(); }
    if ((evGift -= dt) <= 0) { evGift = rr(45, 80); dropGift(); }
    for (final p in [...queue]) {
      if (p.emg && p.emgLeft <= 0) {
        final i = queue.indexOf(p); queue.removeAt(i); if (i == 0) checkin = 0;
        s.rep = math.max(0, s.rep - 10); fx.toast('Uma emergência não foi atendida a tempo (-10 rep)');
        p.state = 'leaving'; p.sit = false; p.z = 0; p.walk([[0.5, 8.6], [-1.2, 8.6], [-3.6, 11.6]], () => rm_(p)); layoutQueue();
      }
    }
  }
  void startEmergency() {
    fx.sfx('alert'); fx.toast('Ambulância chegando com uma emergência!');
    cars.add(Car('amb', 'amb', [[-9.7, -14], [-9.7, 11.9], [-3.6, 11.9]], speed: 6.5, stop: 3, after: [[-9.7, 11.9], [-9.7, 34]], len: 2.1, onStop: () => spawnPatient(emg: true, from: [-3.6, 11.0])));
  }
  void startInspection() {
    fx.toast('O inspetor da Vigilância Sanitária chegou!'); fx.sfx('alert');
    final p = Person(-8.1, -13, 'inspector', 'insp', speed: 1.7); inspector = p; people.add(p);
    final pts = <V2>[[-8.1, 8.3], [0.5, 8.3], [2.15, 7.6]];
    for (final r in rooms.where((r) => s.built(r.t.id)).toList()..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y))) { pts.add([r.x + 2.6, r.top ? 7.4 : 8.6]); }
    p.walk(pts, () {
      p.talk = 1.5; _evalInspection();
      p.walk([[0.5, 8.4], [-8.1, 8.4], [-8.1, -13]], () { rm_(p); if (inspector == p) inspector = null; });
    });
  }
  void _evalInspection() {
    final bs = rooms.where((r) => s.built(r.t.id)).toList();
    var avg = 0.0; for (final r in bs) { avg += s.lvlOf(r.t.id); } avg /= math.max(1, bs.length);
    var sc = math.min(1.0, avg / (8 * s.unit + 2)) * 0.4;
    if (queue.length < s.qmax) sc += 0.2;
    if (s.treasury < s.treMax * 0.95) sc += 0.2;
    sc += math.min(1.0, s.mgr.length / 3) * 0.1;
    sc += bs.length >= 2 ? 0.1 : 0.05;
    s.addSt('inspections');
    String g, msg; Color col;
    if (sc >= 0.8) { g = 'A'; col = const Color(0xFF3FD46B); s.addSt('inspectionsA'); s.gold += 10; s.rep += 50; msg = 'Excelente! +10 ouro e +50 de reputação.'; if (rnd.nextDouble() < 0.5) s.addCard(rnd.nextInt(cards.length)); fx.confetti(); fx.sfx('level'); }
    else if (sc >= 0.6) { g = 'B'; col = const Color(0xFF3E8BFF); s.gold += 5; s.rep += 20; msg = 'Muito bom! +5 ouro e +20 de reputação.'; }
    else if (sc >= 0.4) { g = 'C'; col = const Color(0xFFFF9F1C); s.rep += 5; msg = 'Regular. +5 de reputação. Melhore as salas, a recepção e esvazie o cofre.'; }
    else { g = 'D'; col = const Color(0xFFFF5A5F); s.rep = math.max(0, s.rep - 20); msg = 'Reprovado: -20 de reputação. Fila cheia ou cofre lotado pesam na nota.'; }
    onInspection?.call(g, msg, col); s.changed();
  }

  // ---------------- carros, pedestres, ambiente ----------------
  void _cars(double dt) {
    for (final c in [...cars]) {
      if (c.wait > 0) { c.wait -= dt; c.moving = false; if (c.wait <= 0 && c.after.isNotEmpty) { c.path = c.after.map((p) => [p[0], p[1]]).toList(); c.after = const []; } continue; }
      if (c.path.isEmpty) {
        if (c.stop > 0 && !c.stopped) { c.stopped = true; c.wait = c.stop; c.onStop?.call(); continue; }
        cars.remove(c); continue;
      }
      final tg = c.path.first, dx = tg[0] - c.gx, dy = tg[1] - c.gy, d = math.sqrt(dx * dx + dy * dy), st = c.speed * dt;
      c.moving = true;
      if (dx.abs() > dy.abs()) { c.axis = 'x'; c.dir = dx.sign.toInt(); } else if (d > 0.01) { c.axis = 'y'; c.dir = dy.sign.toInt(); }
      if (d <= st) { c.gx = tg[0]; c.gy = tg[1]; c.path.removeAt(0); } else { c.gx += dx / d * st; c.gy += dy / d * st; }
    }
    if ((evCar -= dt) <= 0) {
      evCar = rr(2.5, 6);
      final south = rnd.nextBool(), taxi = south && rnd.nextDouble() < 0.35 && queue.length < s.qmax - 1;
      final spr = taxi ? 'car_taxi' : pick(['car_red', 'car_green', 'car_purple']);
      if (south) {
        cars.add(Car(taxi ? 'taxi' : 'car', spr, [[-9.7, -14], if (taxi) [-9.7, 8], [-9.7, 34]], stop: taxi ? 1.3 : 0, after: taxi ? [[-9.7, 34]] : const [], onStop: taxi ? () => spawnPatient(from: [-8.3, 8]) : null));
        if (taxi) cars.last.path = [[-9.7, 8]];
      } else {
        cars.add(Car('car', spr, [[-11.3, 34], [-11.3, -14]]));
      }
    }
    if ((evPed -= dt) <= 0) {
      evPed = rr(3, 7);
      final down = rnd.nextBool(), p = Person(-7.95 + rr(-0.2, 0.2), down ? -13 : 31, 'ped', 'pat${rnd.nextInt(8)}', speed: rr(1.2, 1.8));
      people.add(p); p.walk([[p.gx, down ? 31 : -13]], () => rm_(p));
    }
  }
  void _ambient(double dt) {
    for (final w in wander) {
      if (!w.moving && rnd.nextDouble() < dt * 0.35) w.walk([[rr(1, 20.5), rr(7.35, 8.65)]]);
      if (!w.moving && rnd.nextDouble() < dt * 0.1) w.talk = 1.4;
      if (w.role == 'janitor') w.anim = w.moving ? 'walk' : 'work';
    }
    var near = false;
    for (final p in people) { if (p.gx > -1.6 && p.gx < 1.4 && p.gy > 7 && p.gy < 9.2) { near = true; break; } }
    doors = (doors + (near ? dt * 4 : -dt * 2)).clamp(0.0, 1.0).toDouble();
  }
  void dropGift([Rect? view]) {
    if (gifts.length >= 2) return;
    V2? spot;
    for (var k = 0; k < 40 && spot == null; k++) {
      final z = pick(const [[1.0, 20.0, 7.3, 8.7], [0.0, 20.0, 15.0, 18.0], [-7.0, -1.4, 7.2, 8.8], [-7.0, -1.0, -1.4, 6.0], [22.5, 30.0, 8.0, 20.0]]);
      final g = [rr(z[0], z[1]), rr(z[2], z[3])];
      if (view == null || view.deflate(80).contains(iso(g[0], g[1]))) spot = g;
    }
    spot ??= [rr(2, 19), 8];
    gifts.add(Gift(spot[0], spot[1], rnd.nextDouble() < 0.25)); fx.sfx('whoosh');
  }
  void _gifts(double dt) {
    for (final g in [...gifts]) {
      if (g.z > 0) { g.z = math.max(0, g.z - dt * 120); if (g.z == 0) { burst(iso(g.gx, g.gy), 10, ['smoke'], 80); fx.sfx('pop'); } }
      else { g.life -= dt; if (g.life <= 0) gifts.remove(g); }
    }
  }
  void _parts(double dt) {
    for (final p in [...parts]) {
      p.life += dt;
      if (p.life >= p.max) { parts.remove(p); continue; }
      if (p.k == 'smoke') { p.vy = -36; } else { p.vy += p.g * dt; }
      p.x += p.vx * dt; p.y += p.vy * dt; p.r += p.vr * dt;
      if (p.k == 'conf') { p.vx *= 0.98; p.vy = math.min(p.vy, 120); }
    }
    if (parts.length > 420) parts.removeRange(0, parts.length - 420);
    for (final f in [...floats]) { f.t += dt; if (f.t > 1.25) floats.remove(f); }
  }
  void levelFx(String id, int a, int b) {
    final rm = rooms.firstWhere((r) => r.t.id == id), combo = s.bumpCombo(), c = iso(rm.x + 2, rm.y + 2.5, 20);
    rm.pop = 1; rm.glow = math.min(1.0, rm.glow + 0.5);
    final hot = Color.lerp(const Color(0xFF7CFFB2), const Color(0xFFFFE27A), math.min(1.0, combo / 10))!;
    for (var i = 0; i < 6 + math.min(combo, 10); i++) { parts.add(Particle('arrow', c.dx + rr(-110, 110), c.dy + rr(-20, 70), 0, rr(-170, -110), 0, rr(0.6, 1.1), 14, const Color(0xFF3FD46B))); }
    burst(c, 16 + math.min(combo * 2, 30), ['spark', 'coin'], 300 + math.min(combo, 10) * 18.0);
    ring(c, hot);
    floatTxt(rm.x + 2, rm.y + 2.5, 'NÍVEL $b', hot, 34 + math.min(combo, 10) * 1.6, 70);
    if (combo >= 2) floatTxt(rm.x + 2, rm.y + 1.2, 'COMBO x${combo + 1}', Color.lerp(const Color(0xFFFFE27A), const Color(0xFFFF6FB5), math.min(1.0, combo / 12))!, 26 + math.min(combo, 12) * 1.5, 120);
    if (combo > 0 && (combo + 1) % 10 == 0) { s.gold += 1; fx.flyGold(1); fx.toast('Combo x${combo + 1}! +1 ouro'); }
    final lines = <String>[];
    if (GameState.slots(b) > GameState.slots(a)) lines.add('Nova vaga de atendimento!');
    if (b ~/ 25 > a ~/ 25) lines.add('Renda x2!');
    if (GameState.tier(b) > GameState.tier(a)) lines.add('Sala evoluiu: ${GameState.tierNames[GameState.tier(b)]}');
    if (lines.isNotEmpty) {
      fx.banner(lines.first.contains('x2') ? 'RENDA x2!' : lines.first.contains('vaga') ? 'NOVA VAGA!' : 'EVOLUIU!', '${rm.t.name} • ${lines.join(' • ')}');
      burst(c, 70, ['conf', 'spark', 'coin'], 480); ring(c, const Color(0xFFFFE27A), 3); beam(iso(rm.x + 2, rm.y + 2.5), const Color(0xFFFFE27A));
      shake = 0.45; rm.glow = 1; fx.sfx('level'); fx.buzz(35); fx.confetti(50);
    } else { fx.sfx('up', pitch: math.pow(1.06, math.min(combo, 14)).toDouble()); fx.buzz(8); if (combo >= 4) shake = math.max(shake, 0.08); }
  }
  void resetWorld() {
    for (final p in people.whereType<Patient>().toList()) { people.remove(p); }
    queue.clear(); checkin = 0;
    for (final r in rooms) { r.reset(); r.lastBuilt = null; r.buildAnim = 0; for (final st in r.staff) { people.remove(st); } r.staff.clear(); if (r.mgrFig != null) { people.remove(r.mgrFig); r.mgrFig = null; } }
    for (final c in carriers) { people.remove(c); }
    carriers.clear();
  }
}
