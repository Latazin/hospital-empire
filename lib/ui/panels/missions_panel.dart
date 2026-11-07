import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/format.dart';
import '../../core/game_state.dart';
import '../../core/progression.dart';
import '../theme.dart';

class MissionsPanel extends StatefulWidget {
  final GameState s;
  const MissionsPanel({super.key, required this.s});
  @override
  State<MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends State<MissionsPanel> {
  int tab = 0;
  GameState get s => widget.s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => PanelFrame(
        title: 'Missões',
        icon: '🎯',
        color: GameColors.red,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            for (final (i, label) in [(0, 'Diárias'), (1, 'Objetivos'), (2, 'Conquistas'), (3, 'Estatísticas')])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: tab == i ? GameColors.navy : GameColors.navy.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          style: tab == i ? gameText(12) : darkText.copyWith(fontSize: 12)),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          if (tab == 0) ..._daily(),
          if (tab == 1) ..._objectives(),
          if (tab == 2) ..._achievements(),
          if (tab == 3) ..._stats(),
        ]),
      ),
    );
  }

  List<Widget> _daily() {
    s.ensureDaily();
    final now = DateTime.now();
    final mid = DateTime(now.year, now.month, now.day + 1);
    return [
      Text('Renovam em ${fmtTime(mid.difference(now).inSeconds.toDouble())}', style: mutedText, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      for (int i = 0; i < s.dailyIds.length; i++)
        _missionCard(
          dailyById(s.dailyIds[i]).desc.replaceAll('{n}', fmt(dailyTarget(dailyById(s.dailyIds[i]), s))),
          s.dailyProgress(i),
          dailyTarget(dailyById(s.dailyIds[i]), s),
          dailyById(s.dailyIds[i]).gold,
          s.dailyClaimed.contains(i),
          () => s.claimDaily(i),
        ),
    ];
  }

  List<Widget> _objectives() {
    final o = s.currentObjective;
    return [
      if (o != null)
        _missionCard(o.desc, o.progress(s), 1, o.gold, false, s.claimObjective, percent: true)
      else
        const GameCard(child: Text('Todos os objetivos concluídos! Você é uma lenda. 🏆', style: darkText)),
      const SizedBox(height: 4),
      Text('Próximos objetivos', style: mutedText.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      for (int i = s.objectiveIndex + 1; i < objectiveDefs.length && i < s.objectiveIndex + 4; i++)
        Opacity(
          opacity: 0.6,
          child: GameCard(child: Row(children: [
            const Text('🔒  '),
            Expanded(child: Text(objectiveDefs[i].desc, style: darkText)),
            Text('◆${objectiveDefs[i].gold}', style: darkText),
          ])),
        ),
    ];
  }

  List<Widget> _achievements() => [
        for (final a in achievementDefs)
          _missionCard('${a.name} — ${a.desc}', s.stat(a.stat), a.target, a.gold,
              s.claimedAchievements.contains(a.id), () => s.claimAchievement(a)),
      ];

  List<Widget> _stats() {
    final rows = <(String, String)>[
      ('Pacientes atendidos', fmt(s.stat('patients'))),
      ('Dinheiro total arrecadado', '\$${fmt(s.stat('earned'))}'),
      ('Arrecadado nesta unidade', '\$${fmt(s.runEarned)}'),
      ('Renda estimada', '\$${fmt(Eco.incomeRate(s))}/s'),
      ('Pacientes VIP', fmt(s.stat('vip'))),
      ('Emergências salvas', fmt(s.stat('emergencies'))),
      ('Pacientes que desistiram', fmt(s.stat('turnedAway'))),
      ('Inspeções (nota A)', '${fmt(s.stat('inspections'))} (${fmt(s.stat('inspectionsA'))})'),
      ('Melhorias compradas', fmt(s.stat('upgrades'))),
      ('Salas construídas', fmt(s.stat('builds'))),
      ('Coletas', fmt(s.stat('collects'))),
      ('Unidades abertas', '${s.unit}'),
      ('Colecionáveis', '${s.cards.length}/12'),
      ('Tempo de jogo', fmtTime(s.stat('playSeconds'))),
    ];
    return [
      GameCard(
        child: Column(children: [
          for (final (a, b) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(a, style: mutedText.copyWith(fontSize: 13.5))),
                Text(b, style: darkText),
              ]),
            ),
        ]),
      ),
    ];
  }

  Widget _missionCard(String title, double prog, double target, int gold, bool claimed,
      bool Function() claim, {bool percent = false}) {
    final done = prog >= target;
    return GameCard(
      color: claimed ? const Color(0xFFEDEFF3) : done ? const Color(0xFFE8FBEF) : Colors.white,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: darkText.copyWith(fontSize: 13.5)),
            const SizedBox(height: 6),
            GameProgress(
              value: prog / target,
              height: 14,
              color: done ? GameColors.green : GameColors.gold,
              label: percent ? '${(prog * 100).clamp(0, 100).toInt()}%' : '${fmt(prog.clamp(0, target))}/${fmt(target)}',
            ),
          ]),
        ),
        const SizedBox(width: 10),
        claimed
            ? const Text('✅', style: TextStyle(fontSize: 24))
            : GameButton(
                color: GameColors.gold,
                enabled: done,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onTap: claim,
                child: Text('◆$gold', style: gameText(14)),
              ),
      ]),
    );
  }
}
