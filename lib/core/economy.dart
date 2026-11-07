import 'dart:math' as math;

import 'game_state.dart';
import 'models.dart';
import 'progression.dart';

/// Todas as fórmulas da economia em um só lugar, para facilitar o balanceamento.
class Eco {
  static const int maxRoomLevel = 100;
  static const int maxInfraLevel = 100;
  static const int maxManagerLevel = 10;
  static const double offlineCapSeconds = 8 * 3600;

  // ---------------- Multiplicadores globais ----------------
  static double prestigeMult(GameState s) => 1 + 0.75 * (s.unit - 1);

  static int completeSets(GameState s) {
    int n = 0;
    for (int set = 0; set < cardSetNames.length; set++) {
      if (cardDefs.where((c) => c.set == set).every((c) => s.cards.contains(c.id))) n++;
    }
    return n;
  }

  static double cardsMult(GameState s) => 1 + 0.02 * s.cards.length + 0.10 * completeSets(s);

  static double globalMult(GameState s, [RoomType? t]) {
    double m = prestigeMult(s) * cardsMult(s);
    if (s.plantaoActive) m *= 3;
    if (s.goldBoostActive) m *= 2;
    if (t != null && currentWeeklyEvent().rooms.contains(t.id)) m *= 1.5;
    return m;
  }

  // ---------------- Salas ----------------
  static double roomIncome(GameState s, RoomType t, int level) {
    final milestones = level ~/ 25; // x2 nos níveis 25, 50, 75, 100
    return t.baseIncome * math.pow(1.11, level - 1) * math.pow(2, milestones) * globalMult(s, t);
  }

  static double roomTime(GameState s, RoomType t, int level) =>
      t.baseTime / (1 + 0.025 * (level - 1)) / managerSpeed(s, t.id);

  static int roomSlots(int level) => math.min(4, 1 + level ~/ 10);

  static int tier(int level) => level >= 50 ? 3 : level >= 25 ? 2 : level >= 10 ? 1 : 0;

  static const tierNames = ['Básico', 'Moderno', 'Avançado', 'Luxo'];

  static double upgradeCost(RoomType t, int level) => t.upgradeBase * math.pow(1.14, level - 1);

  static int nextMilestone(int level) {
    for (final m in [10, 20, 25, 30, 50, 75, 100]) {
      if (level < m) return m;
    }
    return maxRoomLevel;
  }

  // ---------------- Recepção ----------------
  static double checkinTime(GameState s) =>
      2.2 / (1 + 0.07 * (s.receptionLevel - 1)) / managerSpeed(s, 'recepcao');

  static int queueMax(GameState s) => math.min(10, 4 + s.receptionLevel ~/ 5);

  static double receptionCost(GameState s) => 30.0 * math.pow(1.17, s.receptionLevel - 1);

  /// Intervalo entre chegadas de pacientes (segundos). Reputação atrai mais pacientes.
  static double spawnInterval(GameState s) {
    double v = 3.4 / (1 + s.rep / 350);
    v /= currentWeeklyEvent().spawnMult;
    if (s.epidemic) v /= 2.5;
    return math.max(0.45, v);
  }

  // ---------------- Transporte ----------------
  static int carriers(GameState s) => math.min(5, 1 + s.transportLevel ~/ 10);

  static double carrierCapacity(GameState s) {
    double cap = 40.0 * math.pow(1.22, s.transportLevel - 1);
    final m = s.activeManager('transporte');
    if (m != null) cap *= managerSpeed(s, 'transporte');
    return cap * prestigeMult(s);
  }

  static double carrierSpeed(GameState s) {
    final base = math.min(4.5, 2.2 + 0.04 * (s.transportLevel - 1));
    return s.activeManager('transporte') != null ? base * 1.25 : base;
  }

  static double transportCost(GameState s) => 40.0 * math.pow(1.19, s.transportLevel - 1);

  // ---------------- Tesouraria ----------------
  static double treasuryMax(GameState s) =>
      300.0 * math.pow(1.28, s.treasuryLevel - 1) * prestigeMult(s);

  static double treasuryCost(GameState s) => 50.0 * math.pow(1.21, s.treasuryLevel - 1);

  /// Intervalo da coleta automática (só com gerente de tesouraria).
  static double autoCollectInterval(GameState s) {
    final m = s.activeManager('tesouraria');
    if (m == null) return double.infinity;
    final lvl = s.managerLevels[m.id] ?? 1;
    return m.exclusive ? math.max(1.0, 5.0 - lvl * 0.4) : math.max(2.0, 12.0 - lvl * 0.9);
  }

  // ---------------- Gerentes ----------------
  static double managerSpeed(GameState s, String area) {
    final m = s.activeManager(area);
    if (m == null) return 1;
    final lvl = s.managerLevels[m.id] ?? 1;
    return m.exclusive ? 1.5 + 0.15 * lvl : 1 + 0.1 * lvl;
  }

  static int managerUpgradeGold(ManagerDef m, int level) => (m.exclusive ? 10 : 5) * level;

  // ---------------- Estimativas (offline / missões) ----------------
  /// Renda estimada por segundo: limitada pela capacidade das salas e pela chegada de pacientes.
  static double incomeRate(GameState s) {
    double roomRate = 0, avgIncome = 0;
    int n = 0;
    for (final t in roomTypes) {
      final r = s.room(t.id);
      if (!r.built) continue;
      final inc = roomIncome(s, t, r.level);
      roomRate += inc * roomSlots(r.level) / roomTime(s, t, r.level);
      avgIncome += inc;
      n++;
    }
    if (n == 0) return 0;
    avgIncome /= n;
    final arrivals = 1 / math.max(spawnInterval(s), checkinTime(s));
    return math.min(roomRate, arrivals * avgIncome * 1.4);
  }

  static double offlineEarnings(GameState s, double seconds) {
    final secs = math.min(seconds, offlineCapSeconds);
    final eff = s.activeManager('tesouraria') != null ? 1.0 : 0.5;
    // Sem plantão/boost temporários no cálculo offline
    final rate = incomeRate(s) / (s.plantaoActive ? 3 : 1) / (s.goldBoostActive ? 2 : 1);
    return rate * secs * eff;
  }

  // ---------------- Prestígio ----------------
  static double prestigeRequirement(GameState s) => 1e6 * math.pow(25, s.unit - 1);
  static int prestigeGold(GameState s) => 50 * s.unit;
}
