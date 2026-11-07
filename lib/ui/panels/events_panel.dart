import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/format.dart';
import '../../core/game_state.dart';
import '../../core/models.dart';
import '../../core/progression.dart';
import '../theme.dart';

class EventsPanel extends StatelessWidget {
  final GameState s;
  const EventsPanel({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        s.ensureWeekly();
        final ev = currentWeeklyEvent();
        final reward = managerById(ev.rewardManager);
        final now = DateTime.now();
        final daysLeft = 7 - ((now.millisecondsSinceEpoch ~/ 86400000) % 7);
        return PanelFrame(
          title: 'Eventos',
          icon: '🎉',
          color: const Color(0xFFFF9F1C),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GameCard(
              color: ev.color.withAlpha(40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(ev.icon, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ev.name, style: darkTitle)),
                  Text('$daysLeft dia(s)', style: mutedText),
                ]),
                const SizedBox(height: 4),
                Text(ev.desc, style: darkText),
              ]),
            ),
            GameCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🏁 Desafio da semana', style: darkTitle),
                Text('Atenda ${fmt(s.weeklyTarget)} pacientes e ganhe o gerente exclusivo ${reward.name}',
                    style: darkText),
                const SizedBox(height: 8),
                GameProgress(
                  value: s.weeklyProgress / s.weeklyTarget,
                  height: 18,
                  color: ev.color,
                  label: '${fmt(s.weeklyProgress.clamp(0, s.weeklyTarget))}/${fmt(s.weeklyTarget)}',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: s.weekClaimed
                      ? const Text('✅ Recompensa recebida', style: darkText)
                      : GameButton(
                          color: GameColors.gold,
                          enabled: s.weeklyProgress >= s.weeklyTarget,
                          onTap: s.claimWeekly,
                          child: const Text('Receber gerente ★'),
                        ),
                ),
              ]),
            ),
            GameCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('⚡ Plantão Relâmpago', style: darkTitle),
                const Text('Renda x3 por 45 segundos. Recarrega em 5 minutos.', style: mutedText),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GameButton(
                    color: const Color(0xFFFF6D00),
                    enabled: s.plantaoReady,
                    onTap: s.activatePlantao,
                    child: Text(s.plantaoActive
                        ? 'Ativo: ${s.plantaoLeft.ceil()}s'
                        : s.plantaoReady
                            ? 'ATIVAR'
                            : 'Recarga: ${fmtTime(s.plantaoCooldownLeft)}'),
                  ),
                ),
              ]),
            ),
            GameCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Acontecimentos aleatórios', style: darkTitle),
                SizedBox(height: 4),
                Text('🚑 Emergências: chegam de ambulância, pagam x5 e dão ouro se atendidas a tempo.', style: mutedText),
                Text('👑 Pacientes VIP: pagam x10, dão ouro e podem trazer colecionáveis.', style: mutedText),
                Text('🦠 Epidemias: chegam muito mais pacientes. Tenha a recepção preparada!', style: mutedText),
                Text('📋 Inspeções: nota A dá ouro, reputação e colecionáveis.', style: mutedText),
              ]),
            ),
            Text('COLECIONÁVEIS  ${s.cards.length}/12  •  bônus x${Eco.cardsMult(s).toStringAsFixed(2)}',
                style: mutedText),
            const SizedBox(height: 6),
            for (int set = 0; set < cardSetNames.length; set++) _CardSet(s: s, set: set),
          ]),
        );
      },
    );
  }
}

class _CardSet extends StatelessWidget {
  final GameState s;
  final int set;
  const _CardSet({required this.s, required this.set});
  @override
  Widget build(BuildContext context) {
    final cards = cardDefs.where((c) => c.set == set).toList();
    final complete = cards.every((c) => s.cards.contains(c.id));
    return GameCard(
      color: complete ? const Color(0xFFFFF8E1) : Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${complete ? '🏆 ' : ''}${cardSetNames[set]}', style: darkText),
        const SizedBox(height: 8),
        Row(children: [
          for (final c in cards)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: s.cards.contains(c.id) ? const Color(0xFFE3F2FD) : const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GameColors.navy.withAlpha(80), width: 1.5),
                ),
                child: Column(children: [
                  Text(s.cards.contains(c.id) ? c.icon : '❔', style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 2),
                  FittedBox(child: Text(s.cards.contains(c.id) ? c.name : '???', style: mutedText.copyWith(fontSize: 10))),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}
