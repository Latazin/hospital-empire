import 'dart:ui';

/// Dados fixos do jogo: salas, gerentes, colecionáveis, missões, eventos.
class RoomType {
  final String id, name, kind;
  final double inc, time, build, up, rep;
  final int unit, plot;
  final Color accent;
  const RoomType(this.id, this.name, this.inc, this.time, this.build, this.up, this.rep, this.unit, this.plot, this.accent, this.kind);
}

const roomTypes = <RoomType>[
  // Salas liberadas em sequência: cada uma exige a anterior construída + reputação.
  RoomType('consultorio', 'Consultório', 10, 4, 0, 20, 0, 1, 0, Color(0xFF2E9BD6), 'chair'),
  RoomType('laboratorio', 'Laboratório', 40, 6, 400, 120, 15, 1, 1, Color(0xFF9B59D0), 'lab'),
  RoomType('farmacia', 'Farmácia', 160, 7, 3500, 1000, 70, 1, 2, Color(0xFF3E9E43), 'pharma'),
  RoomType('enfermaria', 'Enfermaria', 650, 9, 30000, 8000, 200, 1, 3, Color(0xFFF57C2A), 'bed'),
  RoomType('radiologia', 'Radiologia', 2800, 10, 2.5e5, 65000, 450, 1, 4, Color(0xFF5468A8), 'scan'),
  RoomType('centro', 'Centro Cirúrgico', 13000, 13, 2.2e6, 5.5e5, 900, 1, 5, Color(0xFF139C80), 'surgery'),
  RoomType('uti', 'UTI', 6e4, 15, 2e7, 5e6, 1600, 1, 6, Color(0xFFE0473A), 'icu'),
  RoomType('maternidade', 'Maternidade', 2.8e5, 17, 1.8e8, 5e7, 2800, 1, 7, Color(0xFFE9A800), 'baby'),
];
RoomType roomById(String id) => roomTypes.firstWhere((r) => r.id == id);

const plots = <List<double>>[
  [5, 2, 1], [9, 2, 1], [13, 2, 1], [17, 2, 1], [5, 9, 0], [9, 9, 0], [13, 9, 0], [17, 9, 0],
];

const unitNames = ['Unidade Centro', 'Unidade Litoral', 'Unidade Serra', 'Unidade Capital', 'Unidade Metrópole', 'Unidade Internacional', 'Unidade Orbital'];
String unitName(int u) => u <= unitNames.length ? unitNames[u - 1] : 'Unidade $u';

const areaNames = {
  'recepcao': 'Recepção', 'transporte': 'Transporte', 'tesouraria': 'Cofre',
  'consultorio': 'Consultório', 'laboratorio': 'Laboratório', 'farmacia': 'Farmácia', 'enfermaria': 'Enfermaria',
  'radiologia': 'Radiologia', 'centro': 'Centro Cirúrgico', 'uti': 'UTI', 'maternidade': 'Maternidade',
};

class ManagerDef {
  final String id, name, area, desc;
  final int gold;
  final Color color;
  final bool ex;
  final int sprite; // variante de sprite (0..2)
  const ManagerDef(this.id, this.name, this.area, this.desc, this.gold, this.color, this.sprite, {this.ex = false});
}

const managers = <ManagerDef>[
  ManagerDef('m_bia', 'Sra. Bia', 'recepcao', 'Check-in mais rápido', 15, Color(0xFFE91E63), 1),
  ManagerDef('m_davi', 'Sr. Davi', 'transporte', 'Carregadores fortes e velozes', 20, Color(0xFFFF9800), 2),
  ManagerDef('m_lucio', 'Sr. Lúcio', 'tesouraria', 'Coleta sozinho + offline 100%', 30, Color(0xFF8D6E63), 0),
  ManagerDef('m_paulo', 'Dr. Paulo', 'consultorio', 'Atendimento mais rápido', 10, Color(0xFF2E9BD6), 0),
  ManagerDef('m_lia', 'Dra. Lia', 'laboratorio', 'Atendimento mais rápido', 20, Color(0xFF9B59D0), 1),
  ManagerDef('m_rita', 'Farm. Rita', 'farmacia', 'Atendimento mais rápido', 30, Color(0xFF3E9E43), 2),
  ManagerDef('m_joao', 'Enf. João', 'enfermaria', 'Atendimento mais rápido', 40, Color(0xFFF57C2A), 0),
  ManagerDef('m_kenji', 'Dr. Kenji', 'radiologia', 'Atendimento mais rápido', 60, Color(0xFF5468A8), 0),
  ManagerDef('m_helena', 'Dra. Helena', 'centro', 'Atendimento mais rápido', 80, Color(0xFF139C80), 2),
  ManagerDef('m_otto', 'Dr. Otto', 'uti', 'Atendimento mais rápido', 100, Color(0xFFE0473A), 0),
  ManagerDef('m_sol', 'Dra. Sol', 'maternidade', 'Atendimento mais rápido', 120, Color(0xFFE9A800), 1),
  ManagerDef('x_aurora', 'Dra. Aurora', 'consultorio', 'Exclusiva: velocidade enorme', 0, Color(0xFFFF4081), 1, ex: true),
  ManagerDef('x_vulcano', 'Dr. Vulcano', 'transporte', 'Exclusivo: transporte turbinado', 0, Color(0xFFD84315), 2, ex: true),
  ManagerDef('x_fortuna', 'Sra. Fortuna', 'tesouraria', 'Exclusiva: coleta relâmpago', 0, Color(0xFFFFB300), 1, ex: true),
  ManagerDef('x_tita', 'Dr. Titã', 'enfermaria', 'Exclusivo: velocidade enorme', 0, Color(0xFF6D4C41), 0, ex: true),
];
ManagerDef managerById(String id) => managers.firstWhere((m) => m.id == id);

class CardDef {
  final int id;
  final String name, icon;
  const CardDef(this.id, this.name, this.icon);
  int get set => id ~/ 4;
}

const cardSets = ['Instrumentos Clássicos', 'Medalhas de Honra', 'Relíquias da Medicina'];
const cards = <CardDef>[
  CardDef(0, 'Estetoscópio', 'icon_steth'), CardDef(1, 'Termômetro', 'icon_thermo'), CardDef(2, 'Seringa', 'icon_syringe'), CardDef(3, 'Bisturi de Ouro', 'icon_scalpel'),
  CardDef(4, 'Medalha do Mérito', 'icon_medal'), CardDef(5, 'Troféu Saúde', 'icon_trophy'), CardDef(6, 'Fita Solidária', 'icon_ribbon'), CardDef(7, 'Coroa VIP', 'icon_crown'),
  CardDef(8, 'Microscópio Antigo', 'icon_micro'), CardDef(9, 'Cápsula Rara', 'icon_pill'), CardDef(10, 'DNA Dourado', 'icon_dna'), CardDef(11, 'Coração de Cristal', 'icon_heart'),
];

class WeeklyDef {
  final String name, desc, reward;
  final List<String> rooms;
  final double spawn;
  final Color color;
  const WeeklyDef(this.name, this.desc, this.rooms, this.spawn, this.color, this.reward);
}

const weeklies = <WeeklyDef>[
  WeeklyDef('Semana do Coração', '+50% de renda no Consultório e na UTI', ['consultorio', 'uti'], 1, Color(0xFFE53935), 'x_aurora'),
  WeeklyDef('Mutirão de Exames', '+50% no Laboratório e na Radiologia, +10% pacientes', ['laboratorio', 'radiologia'], 1.1, Color(0xFF8E24AA), 'x_vulcano'),
  WeeklyDef('Campanha de Vacinação', '+50% na Farmácia e +20% de pacientes', ['farmacia'], 1.2, Color(0xFF2E9E4A), 'x_fortuna'),
  WeeklyDef('Semana da Enfermagem', '+50% na Enfermaria, Centro Cirúrgico e Maternidade', ['enfermaria', 'centro', 'maternidade'], 1, Color(0xFFF57C2A), 'x_tita'),
];
int weekIndex() => DateTime.now().millisecondsSinceEpoch ~/ 86400000 ~/ 7;
WeeklyDef weekly() => weeklies[weekIndex() % weeklies.length];

class DailyDef {
  final String id, desc, stat;
  final double base;
  final int gold;
  const DailyDef(this.id, this.desc, this.stat, this.base, this.gold);
}

const dailies = <DailyDef>[
  DailyDef('d_pat', 'Atenda {n} pacientes', 'patients', 60, 8),
  DailyDef('d_up', 'Faça {n} melhorias', 'upgrades', 15, 6),
  DailyDef('d_col', 'Colete o cofre {n} vezes', 'collects', 12, 5),
  DailyDef('d_vip', 'Atenda {n} pacientes VIP', 'vip', 3, 10),
  DailyDef('d_emg', 'Salve {n} emergências', 'emergencies', 2, 10),
  DailyDef('d_earn', 'Arrecade \${n}', 'earned', 2000, 8),
  DailyDef('d_gift', 'Abra {n} presentes', 'gifts', 4, 7),
  DailyDef('d_tap', 'Acelere atendimentos {n} vezes', 'taps', 40, 6),
];
DailyDef dailyById(String id) => dailies.firstWhere((d) => d.id == id);

class AchDef {
  final String id, name, desc, stat;
  final double target;
  final int gold;
  const AchDef(this.id, this.name, this.desc, this.stat, this.target, this.gold);
}

const achievements = <AchDef>[
  AchDef('a_p10', 'Primeiros Passos', 'Atenda 10 pacientes', 'patients', 10, 3),
  AchDef('a_p100', 'Clínica Movimentada', 'Atenda 100 pacientes', 'patients', 100, 5),
  AchDef('a_p1k', 'Referência Regional', 'Atenda 1.000 pacientes', 'patients', 1000, 15),
  AchDef('a_p10k', 'Lenda da Saúde', 'Atenda 10.000 pacientes', 'patients', 1e4, 50),
  AchDef('a_e1k', 'Primeiro Mil', 'Arrecade \$1.000', 'earned', 1000, 3),
  AchDef('a_e1m', 'Milionário', 'Arrecade \$1M', 'earned', 1e6, 20),
  AchDef('a_e1b', 'Bilionário', 'Arrecade \$1B', 'earned', 1e9, 60),
  AchDef('a_up50', 'Reformista', 'Faça 50 melhorias', 'upgrades', 50, 5),
  AchDef('a_up500', 'Obra Sem Fim', 'Faça 500 melhorias', 'upgrades', 500, 25),
  AchDef('a_vip10', 'Tapete Vermelho', 'Atenda 10 VIPs', 'vip', 10, 10),
  AchDef('a_emg10', 'Herói do Plantão', 'Salve 10 emergências', 'emergencies', 10, 15),
  AchDef('a_insA', 'Nota Máxima', 'Tire nota A em 3 inspeções', 'inspectionsA', 3, 15),
  AchDef('a_b4', 'Complexo Hospitalar', 'Construa 4 salas', 'builds', 4, 10),
  AchDef('a_pres1', 'Expansionista', 'Abra uma nova unidade', 'prestiges', 1, 30),
  AchDef('a_gift20', 'Caçador de Presentes', 'Abra 20 presentes', 'gifts', 20, 10),
  AchDef('a_tap500', 'Dedo Rápido', 'Acelere 500 atendimentos', 'taps', 500, 10),
  AchDef('a_play1h', 'Diretor Dedicado', 'Jogue por 1 hora', 'play', 3600, 10),
];

class WheelPrize {
  final String label, kind;
  final double v;
  final Color color;
  final int weight;
  const WheelPrize(this.label, this.kind, this.v, this.color, this.weight);
}

const wheelPrizes = <WheelPrize>[
  WheelPrize('5 min', 'money', 300, Color(0xFF3FD46B), 22),
  WheelPrize('5 ouro', 'gold', 5, Color(0xFF3E8BFF), 18),
  WheelPrize('15 min', 'money', 900, Color(0xFF17B3A3), 16),
  WheelPrize('x2 10min', 'boost', 600, Color(0xFF8F62F8), 12),
  WheelPrize('15 ouro', 'gold', 15, Color(0xFF2F74E8), 8),
  WheelPrize('Carta', 'card', 1, Color(0xFFFF6FB5), 10),
  WheelPrize('30 min', 'money', 1800, Color(0xFFFF9F1C), 9),
  WheelPrize('JACKPOT', 'money', 7200, Color(0xFFFF5A5F), 5),
];
