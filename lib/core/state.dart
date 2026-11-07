import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'data.dart';
import 'format.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;
final _rnd = math.Random();

/// Efeitos visuais/sonoros que o estado pede para a camada de apresentação.
abstract class Fx {
  void banner(String title, String sub);
  void toast(String msg);
  void sfx(String name, {double pitch = 1});
  void confetti([int n = 60]);
  void flyMoney(double amount, {int coins = 12});
  void flyGold(int amount);
  void levelFx(String roomId, int from, int to);
  void buzz([int ms = 12]);
}

class RoomSave {
  bool b;
  int l;
  RoomSave({this.b = false, this.l = 1});
  Map<String, dynamic> toJson() => {'b': b, 'l': l};
}

/// Estado persistente + economia + ações do jogador.
class GameState extends ChangeNotifier {
  Fx? fx;

  double money = 60, rep = 0, treasury = 0, runEarned = 0, xp = 0;
  int gold = 15, unit = 1, rl = 1, tl = 1, trl = 1, lvl = 1, obj = 0, tut = 0;
  Map<String, RoomSave> rooms = {'consultorio': RoomSave(b: true)};
  Map<String, int> mgr = {};
  List<int> cardsOwned = [];
  Map<String, double> stats = {};
  List<String> ach = [];
  String dk = '';
  Map<String, double> db = {};
  List<String> di = [];
  List<int> dc = [];
  int wk = -1, pu = 0, pc = 0, gb = 0, spinAt = 0, ls = 0;
  double wb = 0;
  bool wc = false;
  bool music = true, sound = true, vibration = true;

  // transitório
  double epidemic = 0;
  double pending = 0; // dinheiro "voando" até o contador

  // ---------------- helpers ----------------
  double st(String k) => stats[k] ?? 0;
  void addSt(String k, [double v = 1]) => stats[k] = st(k) + v;
  bool built(String id) => rooms[id]?.b ?? false;
  int lvlOf(String id) => rooms[id]?.l ?? 0;
  bool get plantaoOn => nowMs() < pu;
  bool get plantaoReady => nowMs() >= pc;
  bool get boostOn => nowMs() < gb;
  void changed() => notifyListeners();

  // ---------------- economia ----------------
  static const maxL = 100, maxI = 100, maxM = 10;
  static const offCap = 8 * 3600.0;
  double get prestigeMult => 1 + 0.75 * (unit - 1);
  int get completeSets { var n = 0; for (var s = 0; s < 3; s++) { if (cards.where((c) => c.set == s).every((c) => cardsOwned.contains(c.id))) n++; } return n; }
  double get cardsMult => 1 + 0.02 * cardsOwned.length + 0.1 * completeSets;
  double get dirMult => 1 + 0.02 * (lvl - 1);
  double globalMult([RoomType? t]) {
    var m = prestigeMult * cardsMult * dirMult;
    if (plantaoOn) m *= 3;
    if (boostOn) m *= 2;
    if (t != null && weekly().rooms.contains(t.id)) m *= 1.5;
    return m;
  }
  double income(RoomType t, int l) => t.inc * math.pow(1.11, l - 1) * math.pow(2, l ~/ 25) * globalMult(t);
  double serviceTime(RoomType t, int l) => t.time / (1 + 0.025 * (l - 1)) / mspeed(t.id);
  static int slots(int l) => math.min(4, 1 + l ~/ 10);
  static int tier(int l) => l >= 50 ? 3 : l >= 25 ? 2 : l >= 10 ? 1 : 0;
  static const tierNames = ['Básico', 'Moderno', 'Avançado', 'Luxo'];
  double upCost(RoomType t, int l) => t.up * math.pow(1.14, l - 1);
  static int nextMs(int l) { for (final m in [10, 20, 25, 30, 50, 75, 100]) { if (l < m) return m; } return 100; }
  double get checkinTime => 2.2 / (1 + 0.07 * (rl - 1)) / mspeed('recepcao');
  int get qmax => math.min(10, 4 + rl ~/ 5);
  double get recCost => 30.0 * math.pow(1.17, rl - 1);
  double get spawnInterval { var v = 3.4 / (1 + rep / 350); v /= weekly().spawn; if (epidemic > 0) v /= 2.5; return math.max(0.45, v); }
  int get carriers => math.min(5, 1 + tl ~/ 10);
  double get carrierCap { var c = 40.0 * math.pow(1.22, tl - 1); if (activeMgr('transporte') != null) c *= mspeed('transporte'); return c * prestigeMult; }
  double get carrierSpeed { final b = math.min(4.5, 2.2 + 0.04 * (tl - 1)); return activeMgr('transporte') != null ? b * 1.25 : b; }
  double get traCost => 40.0 * math.pow(1.19, tl - 1);
  double get treMax => 300.0 * math.pow(1.28, trl - 1) * prestigeMult;
  double get treCost => 50.0 * math.pow(1.21, trl - 1);
  double get autoInterval { final m = activeMgr('tesouraria'); if (m == null) return double.infinity; final l = mgr[m.id] ?? 1; return m.ex ? math.max(1.0, 5 - l * 0.4) : math.max(2.0, 12 - l * 0.9); }
  ManagerDef? activeMgr(String area) { ManagerDef? best; for (final id in mgr.keys) { final m = managerById(id); if (m.area != area) continue; if (best == null || (m.ex && !best.ex)) best = m; } return best; }
  double mspeed(String area) { final m = activeMgr(area); if (m == null) return 1; final l = mgr[m.id] ?? 1; return m.ex ? 1.5 + 0.15 * l : 1 + 0.1 * l; }
  int mgrUpCost(ManagerDef m, int l) => (m.ex ? 10 : 5) * l;
  double get rate {
    double roomRate = 0, avg = 0; var n = 0;
    for (final t in roomTypes) { if (!built(t.id)) continue; final l = lvlOf(t.id), inc = income(t, l); roomRate += inc * slots(l) / serviceTime(t, l); avg += inc; n++; }
    if (n == 0) return 0;
    avg /= n;
    final arr = 1 / math.max(spawnInterval, checkinTime);
    return math.min(roomRate, arr * avg * 1.4);
  }
  double get baseRate { var r = rate; if (plantaoOn) r /= 3; if (boostOn) r /= 2; return r; }
  double offlineFor(double secs) => baseRate * math.min(secs, offCap) * (activeMgr('tesouraria') != null ? 1 : 0.5);
  double get presReq => 1e6 * math.pow(25, unit - 1);
  int get presGold => 50 * unit;
  int xpNeed(int l) => (18 * math.pow(1.3, l - 1) + l * 6).round();

  // ---------------- XP ----------------
  void addXP(double n) {
    if (n <= 0) return;
    xp += n; var up = false;
    while (xp >= xpNeed(lvl)) { xp -= xpNeed(lvl); lvl++; up = true; }
    if (up) { final g = 3 + lvl ~/ 2; gold += g; fx?.banner('NÍVEL $lvl!', 'Diretor • +$g ouro • renda +2%'); fx?.confetti(); fx?.sfx('level'); fx?.buzz(40); }
  }

  // ---------------- salas ----------------
  String? lockReason(RoomType t) { if (unit < t.unit) return 'Requer a ${t.unit}ª unidade'; if (rep < t.rep) return 'Requer ${t.rep.toInt()} de reputação'; return null; }
  bool canBuild(RoomType t) => !built(t.id) && lockReason(t) == null && money >= t.build;
  bool buildRoom(String id) {
    final t = roomById(id); if (!canBuild(t)) { fx?.sfx('nope'); return false; }
    money -= t.build; rooms[id] = RoomSave(b: true); addSt('builds'); addXP(25); changed(); return true;
  }
  (double, int) upPreview(RoomType t, int n) {
    final r = rooms[t.id]!; double total = 0; var lv = r.l, k = 0;
    while (lv < maxL && (n < 0 || k < n)) { final c = upCost(t, lv); if (n < 0 && total + c > money) break; total += c; lv++; k++; }
    if (n < 0 && k == 0 && lv < maxL) return (upCost(t, lv), 1);
    return (total, k);
  }
  bool upgradeRoom(String id, int n) {
    final t = roomById(id), r = rooms[id]; if (r == null || !r.b) return false;
    final (cost, k) = upPreview(t, n);
    if (k == 0 || cost > money) { fx?.sfx('nope'); return false; }
    final a = r.l; money -= cost; r.l += k; addSt('upgrades', k.toDouble()); addXP(2.0 * k);
    fx?.levelFx(id, a, r.l);
    if (tut == 2) tut = 3;
    changed(); return true;
  }
  int _combo = 0, _comboT = 0;
  int bumpCombo() { final t = nowMs(); _combo = t - _comboT < 1600 ? _combo + 1 : 0; _comboT = t; return _combo; }
  bool infraUp(String k) {
    final cost = k == 'rl' ? recCost : k == 'tl' ? traCost : treCost;
    final lv = k == 'rl' ? rl : k == 'tl' ? tl : trl;
    if (lv >= maxI || money < cost) { fx?.sfx('nope'); return false; }
    money -= cost;
    if (k == 'rl') { rl++; } else if (k == 'tl') { tl++; } else { trl++; }
    addSt('upgrades'); addXP(2); fx?.sfx('up', pitch: math.pow(1.06, math.min(bumpCombo(), 14)).toDouble()); fx?.buzz(8);
    if (k == 'tl' && tl % 10 == 0) { fx?.banner('NOVO CARREGADOR!', 'Transporte nível $tl'); fx?.sfx('level'); }
    if (k == 'rl' && rl % 5 == 0) fx?.toast('A fila da recepção aumentou!');
    changed(); return true;
  }

  // ---------------- gerentes ----------------
  bool hireMgr(String id) {
    final m = managerById(id); if (mgr.containsKey(id) || m.ex || gold < m.gold) { fx?.sfx('nope'); return false; }
    gold -= m.gold; mgr[id] = 1; fx?.sfx('level'); fx?.toast('${m.name} contratado(a)!'); fx?.confetti(30); changed(); return true;
  }
  bool upMgr(String id) {
    final m = managerById(id), l = mgr[id]; if (l == null || l >= maxM) return false;
    final c = mgrUpCost(m, l); if (gold < c) { fx?.sfx('nope'); return false; }
    gold -= c; mgr[id] = l + 1; fx?.sfx('up', pitch: math.pow(1.06, l).toDouble()); changed(); return true;
  }
  void grantMgr(String id) {
    if (mgr.containsKey(id)) { gold += 50; fx?.toast('Gerente repetido: +50 ouro'); }
    else { mgr[id] = 1; fx?.banner('GERENTE EXCLUSIVO!', managerById(id).name); fx?.confetti(); fx?.sfx('level'); }
  }

  // ---------------- colecionáveis ----------------
  void addCard(int id) {
    final c = cards[id];
    if (cardsOwned.contains(id)) { gold += 2; fx?.toast('${c.name} repetido: +2 ouro'); return; }
    cardsOwned.add(id); fx?.toast('Novo colecionável: ${c.name}!'); fx?.sfx('gift');
    if (cards.where((x) => x.set == c.set).every((x) => cardsOwned.contains(x.id))) { gold += 25; fx?.banner('COLEÇÃO COMPLETA!', '${cardSets[c.set]} • +25 ouro'); fx?.confetti(); }
  }

  // ---------------- boosts ----------------
  void activatePlantao() {
    if (!plantaoReady) { fx?.sfx('nope'); return; }
    pu = nowMs() + 45000; pc = nowMs() + 300000;
    fx?.banner('PLANTÃO RELÂMPAGO!', 'Renda x3 por 45 segundos'); fx?.sfx('alert'); fx?.buzz(40); changed();
  }
  void goldBoost() { if (gold < 20) { fx?.sfx('nope'); return; } gold -= 20; gb = math.max(gb, nowMs()) + 30 * 60000; fx?.banner('RENDA x2!', 'por 30 minutos'); fx?.sfx('level'); changed(); }
  void moneyPack() { if (gold < 10) { fx?.sfx('nope'); return; } gold -= 10; final v = math.max(100.0, baseRate * 1800); earn(v); fx?.flyMoney(v, coins: 14); fx?.sfx('cash'); changed(); }
  void earn(double v) { money += v; runEarned += v; addSt('earned', v); }

  // ---------------- cofre ----------------
  double collect({bool auto = false}) {
    final v = treasury;
    if (v < 1) { if (!auto) fx?.sfx('nope'); return 0; }
    treasury = 0; earn(v);
    fx?.flyMoney(v, coins: auto ? 4 : (5 + (math.log(v) / math.ln10) * 2).clamp(6, 18).round());
    if (!auto) { addSt('collects'); fx?.sfx('cash'); fx?.buzz(15); addXP(1); if (tut == 3 || tut == 4) tut = 5; }
    changed(); return v;
  }

  // ---------------- missões ----------------
  void ensureDaily() {
    final d = DateTime.now(), key = '${d.year}-${d.month}-${d.day}';
    if (key == dk && di.length == 3) return;
    dk = key;
    final r = math.Random(d.year * 1000 + d.month * 40 + d.day);
    final pool = [...dailies]..shuffle(r);
    di = pool.take(3).map((e) => e.id).toList(); db = {for (final id in di) id: st(dailyById(id).stat)}; dc = [];
  }
  double dTarget(DailyDef d) {
    if (d.stat == 'earned') return (d.base * unit * unit * (1 + rooms.length * 2)).roundToDouble();
    if (d.stat == 'patients') return (d.base * (1 + 0.5 * (unit - 1))).roundToDouble();
    return d.base;
  }
  double dProg(int i) => st(dailyById(di[i]).stat) - (db[di[i]] ?? 0);
  bool dDone(int i) => dProg(i) >= dTarget(dailyById(di[i]));
  void claimDaily(int i) { if (dc.contains(i) || !dDone(i)) return; dc.add(i); final g = dailyById(di[i]).gold; gold += g; fx?.sfx('cash'); fx?.flyGold(g); changed(); }
  void ensureWeekly() { final w = weekIndex(); if (w == wk) return; wk = w; wb = st('patients'); wc = false; }
  double get wTarget => 600.0 * unit;
  double get wProg => st('patients') - wb;
  void claimWeekly() { if (wc || wProg < wTarget) return; wc = true; grantMgr(weekly().reward); changed(); }
  bool achDone(AchDef a) => st(a.stat) >= a.target;
  void claimAch(String id) { final a = achievements.firstWhere((x) => x.id == id); if (ach.contains(id) || !achDone(a)) return; ach.add(id); gold += a.gold; fx?.sfx('cash'); fx?.flyGold(a.gold); changed(); }
  int get claimable { var n = achievements.where((a) => !ach.contains(a.id) && achDone(a)).length; for (var i = 0; i < di.length; i++) { if (!dc.contains(i) && dDone(i)) n++; } return n; }

  // objetivos sequenciais
  static double _r(double v, double t) => (v / t).clamp(0.0, 1.0).toDouble();
  List<(String, double Function(GameState), int)> get objectives => [
        ('Melhore o Consultório ao nível 5', (s) => _r(s.lvlOf('consultorio').toDouble(), 5), 3),
        ('Atenda 25 pacientes', (s) => _r(s.st('patients'), 25), 3),
        ('Abra 1 presente que cai do céu', (s) => _r(s.st('gifts'), 1), 3),
        ('Alcance 40 de reputação', (s) => _r(s.rep, 40), 4),
        ('Construa o Laboratório', (s) => s.built('laboratorio') ? 1 : 0, 5),
        ('Melhore o Transporte ao nível 5', (s) => _r(s.tl.toDouble(), 5), 4),
        ('Consultório nível 10 (ganha vaga)', (s) => _r(s.lvlOf('consultorio').toDouble(), 10), 5),
        ('Contrate seu primeiro gerente', (s) => s.mgr.isNotEmpty ? 1 : 0, 5),
        ('Construa a Farmácia', (s) => s.built('farmacia') ? 1 : 0, 8),
        ('Cofre nível 10', (s) => _r(s.trl.toDouble(), 10), 6),
        ('Laboratório nível 25 (renda x2)', (s) => _r(s.lvlOf('laboratorio').toDouble(), 25), 10),
        ('Construa a Enfermaria', (s) => s.built('enfermaria') ? 1 : 0, 12),
        ('Recepção nível 20', (s) => _r(s.rl.toDouble(), 20), 10),
        ('Chegue ao nível 10 de Diretor', (s) => _r(s.lvl.toDouble(), 10), 12),
        ('Abra a segunda unidade', (s) => s.unit >= 2 ? 1 : 0, 30),
        ('Construa a Radiologia', (s) => s.built('radiologia') ? 1 : 0, 20),
        ('Construa o Centro Cirúrgico', (s) => s.built('centro') ? 1 : 0, 30),
        ('Abra a terceira unidade', (s) => s.unit >= 3 ? 1 : 0, 50),
        ('Construa a UTI', (s) => s.built('uti') ? 1 : 0, 40),
        ('Construa a Maternidade', (s) => s.built('maternidade') ? 1 : 0, 60),
      ];
  (String, double, int)? get curObj { final o = objectives; if (obj >= o.length) return null; final x = o[obj]; return (x.$1, x.$2(this), x.$3); }
  bool get objDone => (curObj?.$2 ?? 0) >= 1;
  void claimObj() { final o = curObj; if (o == null || o.$2 < 1) return; obj++; gold += o.$3; fx?.sfx('cash'); fx?.flyGold(o.$3); fx?.confetti(24); fx?.toast('Objetivo concluído! +${o.$3} ouro'); changed(); }

  // ---------------- prestígio ----------------
  bool get canPrestige => runEarned >= presReq;
  VoidCallback? onReset;
  void prestige() {
    if (!canPrestige) return;
    gold += presGold; unit++; addSt('prestiges');
    money = 60; treasury = 0; runEarned = 0; rep *= 0.25; rooms = {'consultorio': RoomSave(b: true)}; rl = 1; tl = 1; trl = 1;
    onReset?.call();
    fx?.banner('NOVA UNIDADE!', '${unitName(unit)} • renda x${prestigeMult.toStringAsFixed(2)}'); fx?.confetti(80); fx?.sfx('level');
    changed();
  }

  // ---------------- roleta ----------------
  bool get wheelFree => nowMs() >= spinAt;
  int? spinWheel() {
    if (!wheelFree) { if (gold < 10) { fx?.sfx('nope'); return null; } gold -= 10; } else { spinAt = nowMs() + 4 * 3600 * 1000; }
    final tot = wheelPrizes.fold<int>(0, (a, b) => a + b.weight);
    var r = _rnd.nextInt(tot), idx = 0;
    while (r >= wheelPrizes[idx].weight) { r -= wheelPrizes[idx].weight; idx++; }
    changed(); return idx;
  }
  String applyWheel(int i) {
    final p = wheelPrizes[i]; String msg;
    switch (p.kind) {
      case 'money': final v = math.max(100.0, baseRate * p.v); earn(v); fx?.flyMoney(v, coins: 16); msg = '+\$${fmt(v)}'; break;
      case 'gold': gold += p.v.toInt(); fx?.flyGold(p.v.toInt()); msg = '+${p.v.toInt()} ouro'; break;
      case 'boost': gb = math.max(gb, nowMs()) + (p.v * 1000).toInt(); msg = 'Renda x2 por 10 min'; break;
      default: final id = _rnd.nextInt(cards.length); addCard(id); msg = cards[id].name;
    }
    fx?.sfx('level'); fx?.buzz(40); fx?.confetti(p.label == 'JACKPOT' ? 120 : 50);
    if (tut == 5) tut = 6;
    changed(); return msg;
  }

  // ---------------- persistência ----------------
  Map<String, dynamic> toJson() => {
        'v': 3, 'money': money, 'gold': gold, 'rep': rep, 'treasury': treasury, 'unit': unit, 'runEarned': runEarned,
        'rooms': rooms.map((k, v) => MapEntry(k, v.toJson())), 'rl': rl, 'tl': tl, 'trl': trl, 'mgr': mgr, 'cards': cardsOwned,
        'stats': stats, 'ach': ach, 'obj': obj, 'dk': dk, 'db': db, 'di': di, 'dc': dc, 'wk': wk, 'wb': wb, 'wc': wc,
        'pu': pu, 'pc': pc, 'gb': gb, 'tut': tut, 'xp': xp, 'lvl': lvl, 'spinAt': spinAt, 'ls': nowMs(),
        'music': music, 'sound': sound, 'vibration': vibration,
      };
  static double _d(dynamic v, double d) => (v as num?)?.toDouble() ?? d;
  static int _i(dynamic v, int d) => (v as num?)?.toInt() ?? d;
  void loadJson(Map<String, dynamic> j) {
    money = _d(j['money'], 60); gold = _i(j['gold'], 15); rep = _d(j['rep'], 0); treasury = _d(j['treasury'], 0); unit = _i(j['unit'], 1);
    runEarned = _d(j['runEarned'], 0); rl = _i(j['rl'], 1); tl = _i(j['tl'], 1); trl = _i(j['trl'], 1);
    final rm = j['rooms']; if (rm is Map) { rooms = rm.map((k, v) => MapEntry(k as String, RoomSave(b: (v as Map)['b'] == true || v['b'] == 1, l: _i(v['l'], 1)))); rooms.removeWhere((k, v) => !roomTypes.any((t) => t.id == k)); }
    rooms.putIfAbsent('consultorio', () => RoomSave(b: true));
    mgr = ((j['mgr'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt()))..removeWhere((k, v) => !managers.any((m) => m.id == k));
    cardsOwned = ((j['cards'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    stats = ((j['stats'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    ach = ((j['ach'] as List?) ?? []).map((e) => e as String).toList();
    obj = _i(j['obj'], 0); dk = (j['dk'] as String?) ?? '';
    db = ((j['db'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    di = ((j['di'] as List?) ?? []).map((e) => e as String).where((id) => dailies.any((d) => d.id == id)).toList();
    dc = ((j['dc'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    wk = _i(j['wk'], -1); wb = _d(j['wb'], 0); wc = j['wc'] == true;
    pu = _i(j['pu'], 0); pc = _i(j['pc'], 0); gb = _i(j['gb'], 0); tut = _i(j['tut'], 0); xp = _d(j['xp'], 0); lvl = _i(j['lvl'], 1);
    spinAt = _i(j['spinAt'], 0); ls = _i(j['ls'], 0);
    music = j['music'] != false; sound = j['sound'] != false; vibration = j['vibration'] != false;
  }
}
