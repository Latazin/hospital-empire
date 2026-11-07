import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'audio.dart';
import 'economy.dart';
import 'format.dart';
import 'models.dart';
import 'progression.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Estado persistente do jogo + todas as ações do jogador.
/// A cena (Flame) lê daqui; a interface (Flutter) escuta as mudanças.
class GameState extends ChangeNotifier {
  // ---------- Recursos ----------
  double money = 60;
  int gold = 10;
  double rep = 0;
  double treasury = 0;
  int unit = 1;
  double runEarned = 0;

  // ---------- Construções ----------
  Map<String, RoomSave> rooms = {};
  int receptionLevel = 1, transportLevel = 1, treasuryLevel = 1;

  // ---------- Meta ----------
  Set<String> ownedManagers = {};
  Map<String, int> managerLevels = {};
  Set<int> cards = {};
  Map<String, double> stats = {};
  Set<String> claimedAchievements = {};
  int objectiveIndex = 0;

  String dailyKey = '';
  Map<String, double> dailyBase = {};
  List<String> dailyIds = [];
  Set<int> dailyClaimed = {};

  int weekKey = -1;
  double weekBase = 0;
  bool weekClaimed = false;

  int plantaoUntil = 0, plantaoCooldownUntil = 0, goldBoostUntil = 0;
  int tutorialStep = 0;
  int lastSaveMs = 0;

  // ---------- Transitório (não salvo) ----------
  bool epidemic = false;
  double epidemicLeft = 0;
  final List<String> toasts = [];
  final List<GameDialog> dialogs = [];
  bool _dirty = false;

  /// A cena registra aqui como limpar o mundo após um prestígio.
  VoidCallback? onReset;

  GameState() {
    _ensureStart();
  }

  void _ensureStart() {
    final c = room('consultorio');
    if (!c.built) {
      c.built = true;
      c.level = 1;
    }
  }

  // ======================================================= helpers
  RoomSave room(String id) => rooms.putIfAbsent(id, () => RoomSave());
  double stat(String k) => stats[k] ?? 0;
  void addStat(String k, [double v = 1]) => stats[k] = stat(k) + v;
  int get builtCount => roomTypes.where((t) => room(t.id).built).length;

  bool get plantaoActive => nowMs() < plantaoUntil;
  bool get plantaoReady => nowMs() >= plantaoCooldownUntil;
  double get plantaoLeft => math.max(0, (plantaoUntil - nowMs()) / 1000);
  double get plantaoCooldownLeft => math.max(0, (plantaoCooldownUntil - nowMs()) / 1000);
  bool get goldBoostActive => nowMs() < goldBoostUntil;
  double get goldBoostLeft => math.max(0, (goldBoostUntil - nowMs()) / 1000);

  void markDirty() => _dirty = true;
  void flushIfDirty() {
    if (_dirty) {
      _dirty = false;
      notifyListeners();
    }
  }

  void changed() {
    _dirty = false;
    notifyListeners();
  }

  void toast(String msg) {
    toasts.add(msg);
    if (toasts.length > 4) toasts.removeAt(0);
    markDirty();
  }

  void dialog(GameDialog d) {
    dialogs.add(d);
    markDirty();
  }

  // ======================================================= salas
  String? lockReason(RoomType t) {
    if (unit < t.unitReq) return 'Requer a ${t.unitReq}ª unidade (Expansão)';
    if (rep < t.repReq) return 'Requer ${t.repReq.toInt()} de reputação';
    return null;
  }

  bool canBuild(RoomType t) =>
      !room(t.id).built && lockReason(t) == null && money >= t.buildCost;

  bool buildRoom(RoomType t) {
    if (!canBuild(t)) return false;
    money -= t.buildCost;
    final r = room(t.id);
    r.built = true;
    r.level = 1;
    addStat('builds');
    Sfx.play('build.wav');
    toast('🏗️ ${t.name} em construção!');
    if (tutorialStep == 3) tutorialStep = 4;
    changed();
    return true;
  }

  /// Retorna (custo total, níveis) para comprar até [count] níveis (-1 = máximo).
  (double, int) upgradePreview(RoomType t, int count) {
    final r = room(t.id);
    double total = 0, budget = money;
    int lv = r.level, n = 0;
    while (lv < Eco.maxRoomLevel && (count < 0 || n < count)) {
      final c = Eco.upgradeCost(t, lv);
      if (count < 0 && total + c > budget) break;
      total += c;
      lv++;
      n++;
    }
    if (count < 0 && n == 0 && lv < Eco.maxRoomLevel) return (Eco.upgradeCost(t, lv), 1);
    return (total, n);
  }

  bool upgradeRoom(RoomType t, int count) {
    final r = room(t.id);
    if (!r.built) return false;
    final (cost, n) = upgradePreview(t, count);
    if (n == 0 || cost > money) return false;
    final oldTier = Eco.tier(r.level);
    money -= cost;
    r.level += n;
    addStat('upgrades', n.toDouble());
    if (Eco.tier(r.level) > oldTier) {
      Sfx.play('build.wav');
      toast('✨ ${t.name} evoluiu para ${Eco.tierNames[Eco.tier(r.level)]}!');
    } else {
      Sfx.play('upgrade.wav');
    }
    if (tutorialStep == 1) tutorialStep = 2;
    changed();
    return true;
  }

  // ======================================================= infraestrutura
  bool _infra(double cost, void Function() apply) {
    if (money < cost) return false;
    money -= cost;
    apply();
    addStat('upgrades');
    Sfx.play('upgrade.wav');
    changed();
    return true;
  }

  bool upgradeReception() => receptionLevel < Eco.maxInfraLevel &&
      _infra(Eco.receptionCost(this), () => receptionLevel++);
  bool upgradeTransport() => transportLevel < Eco.maxInfraLevel &&
      _infra(Eco.transportCost(this), () => transportLevel++);
  bool upgradeTreasury() => treasuryLevel < Eco.maxInfraLevel &&
      _infra(Eco.treasuryCost(this), () => treasuryLevel++);

  // ======================================================= dinheiro
  /// Deposita na tesouraria, respeitando o limite. Retorna o que coube.
  double deposit(double amount) {
    final space = math.max(0.0, Eco.treasuryMax(this) - treasury);
    final d = math.min(space, amount);
    treasury += d;
    markDirty();
    return d;
  }

  double collect({bool auto = false}) {
    if (treasury <= 0) return 0;
    final v = treasury;
    money += v;
    runEarned += v;
    addStat('earned', v);
    treasury = 0;
    if (!auto) {
      addStat('collects');
      Sfx.play('cash.wav');
      if (tutorialStep == 2) tutorialStep = 3;
    }
    changed();
    return v;
  }

  void onPatientServed({required bool vip, required bool emergency}) {
    addStat('patients');
    rep += vip ? 4 : emergency ? 6 : 1;
    if (vip) {
      addStat('vip');
      gold += 1;
    }
    markDirty();
  }

  void onTurnedAway() {
    addStat('turnedAway');
    rep = math.max(0, rep - 0.5);
    markDirty();
  }

  // ======================================================= gerentes
  ManagerDef? activeManager(String area) {
    ManagerDef? best;
    for (final id in ownedManagers) {
      final m = managerById(id);
      if (m.area != area) continue;
      if (best == null || (m.exclusive && !best.exclusive)) best = m;
    }
    return best;
  }

  bool hireManager(ManagerDef m) {
    if (ownedManagers.contains(m.id) || m.exclusive || gold < m.hireGold) return false;
    gold -= m.hireGold;
    ownedManagers.add(m.id);
    managerLevels[m.id] = 1;
    Sfx.play('upgrade.wav');
    toast('🤝 ${m.name} contratado(a)!');
    changed();
    return true;
  }

  bool upgradeManager(ManagerDef m) {
    final lvl = managerLevels[m.id] ?? 1;
    if (!ownedManagers.contains(m.id) || lvl >= Eco.maxManagerLevel) return false;
    final cost = Eco.managerUpgradeGold(m, lvl);
    if (gold < cost) return false;
    gold -= cost;
    managerLevels[m.id] = lvl + 1;
    Sfx.play('upgrade.wav');
    changed();
    return true;
  }

  void grantManager(String id) {
    if (ownedManagers.contains(id)) {
      gold += 50;
      toast('Gerente repetido: +50 ouro');
    } else {
      ownedManagers.add(id);
      managerLevels[id] = 1;
      toast('⭐ Gerente exclusivo: ${managerById(id).name}!');
    }
    markDirty();
  }

  // ======================================================= boosts
  bool activatePlantao() {
    if (!plantaoReady) return false;
    plantaoUntil = nowMs() + 45000;
    plantaoCooldownUntil = nowMs() + 300000;
    Sfx.play('alert.wav');
    toast('⚡ PLANTÃO RELÂMPAGO! Renda x3 por 45s');
    changed();
    return true;
  }

  bool buyGoldBoost() {
    if (gold < 20) return false;
    gold -= 20;
    goldBoostUntil = math.max(goldBoostUntil, nowMs()) + 30 * 60000;
    Sfx.play('upgrade.wav');
    toast('🚀 Renda x2 por 30 minutos!');
    changed();
    return true;
  }

  bool buyMoneyPack() {
    if (gold < 10) return false;
    final v = math.max(100.0, Eco.incomeRate(this) * 1800);
    gold -= 10;
    money += v;
    Sfx.play('cash.wav');
    toast('💰 +\$${fmt(v)}');
    changed();
    return true;
  }

  // ======================================================= colecionáveis
  void addCard(int id) {
    final c = cardDefs[id];
    if (cards.contains(id)) {
      gold += 2;
      toast('${c.icon} ${c.name} repetido: +2 ouro');
    } else {
      cards.add(id);
      toast('${c.icon} Novo colecionável: ${c.name}!');
      final set = c.set;
      if (cardDefs.where((x) => x.set == set).every((x) => cards.contains(x.id))) {
        gold += 25;
        toast('🎉 Coleção "${cardSetNames[set]}" completa! +25 ouro');
      }
    }
    markDirty();
  }

  // ======================================================= prestígio
  bool get canPrestige => runEarned >= Eco.prestigeRequirement(this);

  bool prestige() {
    if (!canPrestige) return false;
    gold += Eco.prestigeGold(this);
    unit++;
    addStat('prestiges');
    money = 60;
    treasury = 0;
    runEarned = 0;
    rep = rep * 0.25;
    rooms = {};
    receptionLevel = 1;
    transportLevel = 1;
    treasuryLevel = 1;
    _ensureStart();
    onReset?.call();
    Sfx.play('build.wav');
    dialog(GameDialog('Nova unidade aberta!',
        'Bem-vindo à ${unitName(unit)}.\nRenda permanente x${Eco.prestigeMult(this).toStringAsFixed(2)}.',
        icon: '🏙️'));
    changed();
    return true;
  }

  // ======================================================= missões diárias
  void ensureDaily() {
    final d = DateTime.now();
    final key = '${d.year}-${d.month}-${d.day}';
    if (key == dailyKey) return;
    dailyKey = key;
    final rnd = math.Random(d.year * 1000 + d.month * 40 + d.day);
    final pool = [...dailyDefs]..shuffle(rnd);
    dailyIds = pool.take(3).map((e) => e.id).toList();
    dailyBase = {for (final id in dailyIds) id: stat(dailyById(id).stat)};
    dailyClaimed = {};
  }

  double dailyProgress(int i) {
    final def = dailyById(dailyIds[i]);
    return stat(def.stat) - (dailyBase[def.id] ?? 0);
  }

  bool dailyDone(int i) => dailyProgress(i) >= dailyTarget(dailyById(dailyIds[i]), this);

  bool claimDaily(int i) {
    if (dailyClaimed.contains(i) || !dailyDone(i)) return false;
    dailyClaimed.add(i);
    gold += dailyById(dailyIds[i]).gold;
    Sfx.play('coin.wav');
    changed();
    return true;
  }

  // ======================================================= desafio semanal
  double get weeklyTarget => 600.0 * unit;

  void ensureWeekly() {
    final wk = currentWeekIndex();
    if (wk == weekKey) return;
    weekKey = wk;
    weekBase = stat('patients');
    weekClaimed = false;
  }

  double get weeklyProgress => stat('patients') - weekBase;

  bool claimWeekly() {
    if (weekClaimed || weeklyProgress < weeklyTarget) return false;
    weekClaimed = true;
    grantManager(currentWeeklyEvent().rewardManager);
    Sfx.play('build.wav');
    changed();
    return true;
  }

  // ======================================================= conquistas / objetivos
  bool achievementDone(AchievementDef a) => stat(a.stat) >= a.target;

  bool claimAchievement(AchievementDef a) {
    if (claimedAchievements.contains(a.id) || !achievementDone(a)) return false;
    claimedAchievements.add(a.id);
    gold += a.gold;
    Sfx.play('coin.wav');
    changed();
    return true;
  }

  int get claimableCount {
    int n = achievementDefs
        .where((a) => !claimedAchievements.contains(a.id) && achievementDone(a))
        .length;
    for (int i = 0; i < dailyIds.length; i++) {
      if (!dailyClaimed.contains(i) && dailyDone(i)) n++;
    }
    if (objectiveDone) n++;
    return n;
  }

  ObjectiveDef? get currentObjective =>
      objectiveIndex < objectiveDefs.length ? objectiveDefs[objectiveIndex] : null;
  bool get objectiveDone => (currentObjective?.progress(this) ?? 0) >= 1;

  bool claimObjective() {
    final o = currentObjective;
    if (o == null || o.progress(this) < 1) return false;
    gold += o.gold;
    objectiveIndex++;
    Sfx.play('coin.wav');
    toast('🎯 Objetivo concluído! +${o.gold} ouro');
    changed();
    return true;
  }

  // ======================================================= persistência
  Map<String, dynamic> toJson() => {
        'v': 1,
        'money': money,
        'gold': gold,
        'rep': rep,
        'treasury': treasury,
        'unit': unit,
        'runEarned': runEarned,
        'rooms': rooms.map((k, v) => MapEntry(k, v.toJson())),
        'rl': receptionLevel,
        'tl': transportLevel,
        'trl': treasuryLevel,
        'mgr': ownedManagers.toList(),
        'mgrL': managerLevels,
        'cards': cards.toList(),
        'stats': stats,
        'ach': claimedAchievements.toList(),
        'obj': objectiveIndex,
        'dk': dailyKey,
        'db': dailyBase,
        'di': dailyIds,
        'dc': dailyClaimed.toList(),
        'wk': weekKey,
        'wb': weekBase,
        'wc': weekClaimed,
        'pu': plantaoUntil,
        'pc': plantaoCooldownUntil,
        'gb': goldBoostUntil,
        'tut': tutorialStep,
        'ls': nowMs(),
      };

  static double _d(dynamic v, double def) => (v as num?)?.toDouble() ?? def;
  static int _i(dynamic v, int def) => (v as num?)?.toInt() ?? def;

  factory GameState.fromJson(Map<String, dynamic> j) {
    final s = GameState();
    s.money = _d(j['money'], 60);
    s.gold = _i(j['gold'], 10);
    s.rep = _d(j['rep'], 0);
    s.treasury = _d(j['treasury'], 0);
    s.unit = _i(j['unit'], 1);
    s.runEarned = _d(j['runEarned'], 0);
    final rm = j['rooms'];
    if (rm is Map) {
      s.rooms = rm.map((k, v) =>
          MapEntry(k as String, RoomSave.fromJson(Map<String, dynamic>.from(v as Map))));
    }
    s._ensureStart();
    s.receptionLevel = _i(j['rl'], 1);
    s.transportLevel = _i(j['tl'], 1);
    s.treasuryLevel = _i(j['trl'], 1);
    s.ownedManagers = ((j['mgr'] as List?) ?? []).map((e) => e as String).toSet()
      ..removeWhere((id) => !managerDefs.any((m) => m.id == id));
    s.managerLevels = ((j['mgrL'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    s.cards = ((j['cards'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
    s.stats = ((j['stats'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    s.claimedAchievements = ((j['ach'] as List?) ?? []).map((e) => e as String).toSet();
    s.objectiveIndex = _i(j['obj'], 0);
    s.dailyKey = (j['dk'] as String?) ?? '';
    s.dailyBase = ((j['db'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    s.dailyIds = ((j['di'] as List?) ?? []).map((e) => e as String).toList()
      ..removeWhere((id) => !dailyDefs.any((d) => d.id == id));
    if (s.dailyIds.length != 3) s.dailyKey = '';
    s.dailyClaimed = ((j['dc'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
    s.weekKey = _i(j['wk'], -1);
    s.weekBase = _d(j['wb'], 0);
    s.weekClaimed = j['wc'] == true;
    s.plantaoUntil = _i(j['pu'], 0);
    s.plantaoCooldownUntil = _i(j['pc'], 0);
    s.goldBoostUntil = _i(j['gb'], 0);
    s.tutorialStep = _i(j['tut'], 0);
    s.lastSaveMs = _i(j['ls'], 0);
    return s;
  }

  /// Ganhos offline (até 8h). Chamado ao abrir o jogo ou voltar do segundo plano.
  void applyOffline(int sinceMs) {
    if (sinceMs <= 0) return;
    final secs = (nowMs() - sinceMs) / 1000;
    if (secs < 60) return;
    final earned = Eco.offlineEarnings(this, secs);
    if (earned <= 0) return;
    final shown = math.min(secs, Eco.offlineCapSeconds);
    dialog(GameDialog(
      'Bem-vindo de volta!',
      'Seu hospital trabalhou por ${fmtTime(shown)}${secs > Eco.offlineCapSeconds ? ' (máx. 8h)' : ''}.',
      offlineAmount: earned,
      icon: '🌙',
    ));
  }

  void claimOffline(double amount, {bool doubled = false}) {
    if (doubled) {
      if (gold < 5) return;
      gold -= 5;
      amount *= 2;
    }
    money += amount;
    runEarned += amount;
    addStat('earned', amount);
    Sfx.play('cash.wav');
    changed();
  }
}
