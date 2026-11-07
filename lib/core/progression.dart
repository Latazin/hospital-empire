import 'package:flutter/material.dart';

import 'game_state.dart';
import 'models.dart';

/// ---------- Eventos semanais (rodízio pela semana do ano) ----------
class WeeklyEvent {
  final String name, desc, icon;
  final List<String> rooms; // salas com +50% de renda
  final double spawnMult;
  final Color color;
  final String rewardManager; // gerente exclusivo do desafio da semana
  const WeeklyEvent(this.name, this.desc, this.icon, this.rooms, this.spawnMult, this.color,
      this.rewardManager);
}

const weeklyEvents = <WeeklyEvent>[
  WeeklyEvent('Semana do Coração', '+50% de renda no Consultório e na UTI', '❤️',
      ['consultorio', 'uti'], 1.0, Color(0xFFE53935), 'x_aurora'),
  WeeklyEvent('Mutirão de Exames', '+50% no Laboratório e na Radiologia', '🔬',
      ['laboratorio', 'radiologia'], 1.1, Color(0xFF8E24AA), 'x_vulcano'),
  WeeklyEvent('Campanha de Vacinação', '+50% na Farmácia e +20% de pacientes', '💉',
      ['farmacia'], 1.2, Color(0xFF43A047), 'x_fortuna'),
  WeeklyEvent('Semana da Enfermagem', '+50% na Enfermaria, Centro Cirúrgico e Maternidade', '🩹',
      ['enfermaria', 'centro', 'maternidade'], 1.0, Color(0xFFFF8A3D), 'x_titan'),
];

int currentWeekIndex() {
  final days = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
  return days ~/ 7;
}

WeeklyEvent currentWeeklyEvent() => weeklyEvents[currentWeekIndex() % weeklyEvents.length];

/// ---------- Missões diárias ----------
class DailyDef {
  final String id, desc, stat;
  final double baseTarget;
  final int gold;
  const DailyDef(this.id, this.desc, this.stat, this.baseTarget, this.gold);
}

const dailyDefs = <DailyDef>[
  DailyDef('d_pat', 'Atenda {n} pacientes', 'patients', 60, 8),
  DailyDef('d_up', 'Faça {n} melhorias', 'upgrades', 15, 6),
  DailyDef('d_col', 'Colete a tesouraria {n} vezes', 'collects', 12, 5),
  DailyDef('d_vip', 'Atenda {n} pacientes VIP', 'vip', 3, 10),
  DailyDef('d_emg', 'Salve {n} emergências', 'emergencies', 2, 10),
  DailyDef('d_earn', 'Arrecade \${n}', 'earned', 2000, 8),
  DailyDef('d_insp', 'Passe por {n} inspeção', 'inspections', 1, 7),
];

DailyDef dailyById(String id) => dailyDefs.firstWhere((d) => d.id == id);

double dailyTarget(DailyDef d, GameState s) {
  if (d.stat == 'earned') {
    final m = s.unit * s.unit * (1 + s.builtCount * 2.0);
    return (d.baseTarget * m).roundToDouble();
  }
  if (d.stat == 'patients') return d.baseTarget * (1 + 0.5 * (s.unit - 1));
  return d.baseTarget;
}

/// ---------- Conquistas ----------
class AchievementDef {
  final String id, name, desc, stat;
  final double target;
  final int gold;
  const AchievementDef(this.id, this.name, this.desc, this.stat, this.target, this.gold);
}

const achievementDefs = <AchievementDef>[
  AchievementDef('a_p10', 'Primeiros Passos', 'Atenda 10 pacientes', 'patients', 10, 3),
  AchievementDef('a_p100', 'Clínica Movimentada', 'Atenda 100 pacientes', 'patients', 100, 5),
  AchievementDef('a_p1k', 'Referência Regional', 'Atenda 1.000 pacientes', 'patients', 1000, 15),
  AchievementDef('a_p10k', 'Lenda da Saúde', 'Atenda 10.000 pacientes', 'patients', 10000, 50),
  AchievementDef('a_e1k', 'Primeiro Mil', 'Arrecade \$1.000', 'earned', 1000, 3),
  AchievementDef('a_e1m', 'Milionário', 'Arrecade \$1M', 'earned', 1e6, 20),
  AchievementDef('a_e1b', 'Bilionário', 'Arrecade \$1B', 'earned', 1e9, 60),
  AchievementDef('a_up50', 'Reformista', 'Faça 50 melhorias', 'upgrades', 50, 5),
  AchievementDef('a_up500', 'Obra Sem Fim', 'Faça 500 melhorias', 'upgrades', 500, 25),
  AchievementDef('a_vip10', 'Tapete Vermelho', 'Atenda 10 VIPs', 'vip', 10, 10),
  AchievementDef('a_emg10', 'Herói do Plantão', 'Salve 10 emergências', 'emergencies', 10, 15),
  AchievementDef('a_insA', 'Nota Máxima', 'Tire nota A em 3 inspeções', 'inspectionsA', 3, 15),
  AchievementDef('a_b4', 'Complexo Hospitalar', 'Construa 4 salas', 'builds', 4, 10),
  AchievementDef('a_pres1', 'Expansionista', 'Abra uma nova unidade', 'prestiges', 1, 30),
  AchievementDef('a_col50', 'Mão na Massa', 'Colete 50 vezes', 'collects', 50, 5),
  AchievementDef('a_play1h', 'Diretor Dedicado', 'Jogue por 1 hora', 'playSeconds', 3600, 10),
];

/// ---------- Objetivos de expansão (sequenciais) ----------
class ObjectiveDef {
  final String desc;
  final double Function(GameState s) progress; // 0..1
  final int gold;
  const ObjectiveDef(this.desc, this.progress, this.gold);
}

double _ratio(double v, double t) => (v / t).clamp(0.0, 1.0).toDouble();

final objectiveDefs = <ObjectiveDef>[
  ObjectiveDef('Melhore o Consultório ao nível 5', (s) => _ratio(s.room('consultorio').level.toDouble(), 5), 3),
  ObjectiveDef('Atenda 25 pacientes', (s) => _ratio(s.stat('patients'), 25), 3),
  ObjectiveDef('Alcance 40 de reputação', (s) => _ratio(s.rep, 40), 4),
  ObjectiveDef('Construa o Laboratório', (s) => s.room('laboratorio').built ? 1 : 0, 5),
  ObjectiveDef('Melhore o Transporte ao nível 5', (s) => _ratio(s.transportLevel.toDouble(), 5), 4),
  ObjectiveDef('Consultório nível 10 (2 vagas)', (s) => _ratio(s.room('consultorio').level.toDouble(), 10), 5),
  ObjectiveDef('Contrate seu primeiro gerente', (s) => s.ownedManagers.isNotEmpty ? 1 : 0, 5),
  ObjectiveDef('Construa a Farmácia', (s) => s.room('farmacia').built ? 1 : 0, 8),
  ObjectiveDef('Tesouraria nível 10', (s) => _ratio(s.treasuryLevel.toDouble(), 10), 6),
  ObjectiveDef('Laboratório nível 25 (renda x2)', (s) => _ratio(s.room('laboratorio').level.toDouble(), 25), 10),
  ObjectiveDef('Construa a Enfermaria', (s) => s.room('enfermaria').built ? 1 : 0, 12),
  ObjectiveDef('Recepção nível 20', (s) => _ratio(s.receptionLevel.toDouble(), 20), 10),
  ObjectiveDef('Abra a segunda unidade', (s) => s.unit >= 2 ? 1 : 0, 30),
  ObjectiveDef('Construa a Radiologia', (s) => s.room('radiologia').built ? 1 : 0, 20),
  ObjectiveDef('Construa o Centro Cirúrgico', (s) => s.room('centro').built ? 1 : 0, 30),
  ObjectiveDef('Abra a terceira unidade', (s) => s.unit >= 3 ? 1 : 0, 50),
  ObjectiveDef('Construa a UTI', (s) => s.room('uti').built ? 1 : 0, 40),
  ObjectiveDef('Construa a Maternidade', (s) => s.room('maternidade').built ? 1 : 0, 60),
  ObjectiveDef('Todas as salas no nível 50', (s) {
    double sum = 0;
    for (final t in roomTypes) {
      sum += (s.room(t.id).built ? s.room(t.id).level : 0).clamp(0, 50);
    }
    return _ratio(sum, 50.0 * roomTypes.length);
  }, 100),
];
