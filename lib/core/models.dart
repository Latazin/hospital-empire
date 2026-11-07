import 'package:flutter/material.dart';

/// Tipo de equipamento desenhado em cada vaga de atendimento.
enum StationKind { desk, bench, shelf, bed, scanner, surgery, monitor, crib }

class RoomType {
  final String id;
  final String name;
  final double baseIncome; // $ por paciente no nível 1
  final double baseTime; // segundos de atendimento no nível 1
  final double buildCost;
  final double upgradeBase;
  final double repReq;
  final int unitReq; // unidade (prestígio) mínima
  final int plot; // terreno no mapa
  final Color floor;
  final Color accent;
  final StationKind station;

  const RoomType({
    required this.id,
    required this.name,
    required this.baseIncome,
    required this.baseTime,
    required this.buildCost,
    required this.upgradeBase,
    required this.repReq,
    required this.unitReq,
    required this.plot,
    required this.floor,
    required this.accent,
    required this.station,
  });
}

/// As 4 primeiras salas são desbloqueadas por reputação; as demais exigem
/// expansão para novas unidades (prestígio).
const roomTypes = <RoomType>[
  RoomType(
      id: 'consultorio', name: 'Consultório', baseIncome: 10, baseTime: 4,
      buildCost: 0, upgradeBase: 20, repReq: 0, unitReq: 1, plot: 0,
      floor: Color(0xFFBFE6F5), accent: Color(0xFF2E9BD6), station: StationKind.desk),
  RoomType(
      id: 'laboratorio', name: 'Laboratório', baseIncome: 40, baseTime: 6,
      buildCost: 500, upgradeBase: 120, repReq: 40, unitReq: 1, plot: 1,
      floor: Color(0xFFF0E1FF), accent: Color(0xFF9B59D0), station: StationKind.bench),
  RoomType(
      id: 'farmacia', name: 'Farmácia', baseIncome: 160, baseTime: 7,
      buildCost: 5000, upgradeBase: 1000, repReq: 180, unitReq: 1, plot: 2,
      floor: Color(0xFFE3F6D5), accent: Color(0xFF43A047), station: StationKind.shelf),
  RoomType(
      id: 'enfermaria', name: 'Enfermaria', baseIncome: 650, baseTime: 9,
      buildCost: 45000, upgradeBase: 8000, repReq: 600, unitReq: 1, plot: 3,
      floor: Color(0xFFFFE6D1), accent: Color(0xFFFF8A3D), station: StationKind.bed),
  RoomType(
      id: 'radiologia', name: 'Radiologia', baseIncome: 2800, baseTime: 10,
      buildCost: 400000, upgradeBase: 65000, repReq: 300, unitReq: 2, plot: 4,
      floor: Color(0xFFDDE4F2), accent: Color(0xFF5468A8), station: StationKind.scanner),
  RoomType(
      id: 'centro', name: 'Centro Cirúrgico', baseIncome: 13000, baseTime: 13,
      buildCost: 4e6, upgradeBase: 550000, repReq: 1200, unitReq: 2, plot: 5,
      floor: Color(0xFFD5F2EC), accent: Color(0xFF16A085), station: StationKind.surgery),
  RoomType(
      id: 'uti', name: 'UTI', baseIncome: 60000, baseTime: 15,
      buildCost: 4e7, upgradeBase: 5e6, repReq: 2500, unitReq: 3, plot: 6,
      floor: Color(0xFFFFDDE1), accent: Color(0xFFE74C3C), station: StationKind.monitor),
  RoomType(
      id: 'maternidade', name: 'Maternidade', baseIncome: 280000, baseTime: 17,
      buildCost: 4e8, upgradeBase: 5e7, repReq: 5000, unitReq: 3, plot: 7,
      floor: Color(0xFFFFF0C4), accent: Color(0xFFF4B400), station: StationKind.crib),
];

RoomType roomById(String id) => roomTypes.firstWhere((r) => r.id == id);

/// Terrenos de construção (coordenadas da grade isométrica).
class Plot {
  final double x, y;
  final bool top; // acima do corredor (porta na frente) ou abaixo (porta no fundo)
  const Plot(this.x, this.y, this.top);
}

const double plotW = 4, plotD = 5;
const plots = <Plot>[
  Plot(5, 2, true), Plot(9, 2, true), Plot(13, 2, true), Plot(17, 2, true),
  Plot(5, 9, false), Plot(9, 9, false), Plot(13, 9, false), Plot(17, 9, false),
];

const unitNames = [
  'Unidade Centro', 'Unidade Litoral', 'Unidade Serra', 'Unidade Capital',
  'Unidade Metrópole', 'Unidade Internacional', 'Unidade Orbital',
];
String unitName(int unit) =>
    unit <= unitNames.length ? unitNames[unit - 1] : 'Unidade $unit';

class ManagerDef {
  final String id, name, area, desc;
  final bool exclusive;
  final int hireGold;
  final Color color;
  const ManagerDef(this.id, this.name, this.area, this.desc, this.hireGold, this.color,
      {this.exclusive = false});
}

const areaNames = {
  'recepcao': 'Recepção',
  'transporte': 'Transporte',
  'tesouraria': 'Tesouraria',
  'consultorio': 'Consultório',
  'laboratorio': 'Laboratório',
  'farmacia': 'Farmácia',
  'enfermaria': 'Enfermaria',
  'radiologia': 'Radiologia',
  'centro': 'Centro Cirúrgico',
  'uti': 'UTI',
  'maternidade': 'Maternidade',
};

const managerDefs = <ManagerDef>[
  ManagerDef('m_bia', 'Sra. Bia', 'recepcao', 'Acelera o check-in', 15, Color(0xFFE91E63)),
  ManagerDef('m_davi', 'Sr. Davi', 'transporte', 'Carregadores mais rápidos e fortes', 20, Color(0xFFFF9800)),
  ManagerDef('m_lucio', 'Sr. Lúcio', 'tesouraria', 'Coleta automática + offline 100%', 30, Color(0xFF795548)),
  ManagerDef('m_paulo', 'Dr. Paulo', 'consultorio', 'Atendimento mais rápido', 10, Color(0xFF2E9BD6)),
  ManagerDef('m_lia', 'Dra. Lia', 'laboratorio', 'Atendimento mais rápido', 20, Color(0xFF9B59D0)),
  ManagerDef('m_rita', 'Farm. Rita', 'farmacia', 'Atendimento mais rápido', 30, Color(0xFF43A047)),
  ManagerDef('m_joao', 'Enf. João', 'enfermaria', 'Atendimento mais rápido', 40, Color(0xFFFF8A3D)),
  ManagerDef('m_kenji', 'Dr. Kenji', 'radiologia', 'Atendimento mais rápido', 60, Color(0xFF5468A8)),
  ManagerDef('m_helena', 'Dra. Helena', 'centro', 'Atendimento mais rápido', 80, Color(0xFF16A085)),
  ManagerDef('m_otto', 'Dr. Otto', 'uti', 'Atendimento mais rápido', 100, Color(0xFFE74C3C)),
  ManagerDef('m_sol', 'Dra. Sol', 'maternidade', 'Atendimento mais rápido', 120, Color(0xFFF4B400)),
  // Exclusivos: recompensas de desafios semanais / coleções
  ManagerDef('x_aurora', 'Dra. Aurora ★', 'consultorio', 'EXCLUSIVA: bônus enorme de velocidade', 0, Color(0xFFFF4081), exclusive: true),
  ManagerDef('x_vulcano', 'Dr. Vulcano ★', 'transporte', 'EXCLUSIVO: transporte turbinado', 0, Color(0xFFD84315), exclusive: true),
  ManagerDef('x_fortuna', 'Sra. Fortuna ★', 'tesouraria', 'EXCLUSIVA: coleta relâmpago', 0, Color(0xFFFFB300), exclusive: true),
  ManagerDef('x_titan', 'Dr. Titã ★', 'enfermaria', 'EXCLUSIVO: bônus enorme de velocidade', 0, Color(0xFF6D4C41), exclusive: true),
];

ManagerDef managerById(String id) => managerDefs.firstWhere((m) => m.id == id);

class CardDef {
  final int id;
  final String name;
  final String icon;
  const CardDef(this.id, this.name, this.icon);
  int get set => id ~/ 4;
}

const cardSetNames = ['Instrumentos Clássicos', 'Medalhas de Honra', 'Relíquias da Medicina'];
const cardDefs = <CardDef>[
  CardDef(0, 'Estetoscópio', '🩺'), CardDef(1, 'Termômetro', '🌡️'),
  CardDef(2, 'Seringa', '💉'), CardDef(3, 'Bisturi de Ouro', '🔪'),
  CardDef(4, 'Medalha do Mérito', '🏅'), CardDef(5, 'Troféu Saúde', '🏆'),
  CardDef(6, 'Fita Solidária', '🎗️'), CardDef(7, 'Coroa VIP', '👑'),
  CardDef(8, 'Microscópio Antigo', '🔬'), CardDef(9, 'Cápsula Rara', '💊'),
  CardDef(10, 'DNA Dourado', '🧬'), CardDef(11, 'Coração de Cristal', '💎'),
];

class RoomSave {
  bool built;
  int level;
  RoomSave({this.built = false, this.level = 1});
  Map<String, dynamic> toJson() => {'b': built, 'l': level};
  factory RoomSave.fromJson(Map<String, dynamic> j) =>
      RoomSave(built: j['b'] == true, level: (j['l'] as num?)?.toInt() ?? 1);
}

class GameDialog {
  final String title;
  final String message;
  final double offlineAmount;
  final String icon;
  GameDialog(this.title, this.message, {this.offlineAmount = 0, this.icon = '🏥'});
}
