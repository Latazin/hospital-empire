import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/format.dart';
import '../../core/game_state.dart';
import '../../core/models.dart';
import '../theme.dart';

/// Prestígio: abrir uma nova unidade reinicia salas e dinheiro, mas dá
/// multiplicador permanente, ouro e libera salas avançadas.
class ExpansionSheet extends StatelessWidget {
  final GameState s;
  const ExpansionSheet({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final req = Eco.prestigeRequirement(s);
        final nextMult = 1 + 0.75 * s.unit;
        final unlocks = roomTypes.where((t) => t.unitReq == s.unit + 1).map((t) => t.name).join(', ');
        return PanelFrame(
          title: 'Expansão',
          icon: '🏙️',
          color: GameColors.purple,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GameCard(
              child: Column(children: [
                Text(unitName(s.unit), style: darkTitle.copyWith(fontSize: 20)),
                Text('Multiplicador permanente atual: x${Eco.prestigeMult(s).toStringAsFixed(2)}', style: darkText),
              ]),
            ),
            GameCard(
              color: const Color(0xFFF3ECFF),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Próxima: ${unitName(s.unit + 1)}', style: darkTitle),
                const SizedBox(height: 8),
                GameProgress(
                  value: s.runEarned / req,
                  height: 20,
                  color: GameColors.purple,
                  label: '\$${fmt(s.runEarned)} / \$${fmt(req)}',
                ),
                const SizedBox(height: 10),
                Text('✅ Renda permanente x${nextMult.toStringAsFixed(2)}', style: darkText),
                Text('✅ +${Eco.prestigeGold(s)} ouro', style: darkText),
                if (unlocks.isNotEmpty) Text('✅ Libera: $unlocks', style: darkText),
                const Text('✅ Mantém gerentes, ouro, colecionáveis e conquistas', style: darkText),
                const SizedBox(height: 4),
                const Text('⚠️ Reinicia dinheiro, salas e infraestrutura. Mantém 25% da reputação.',
                    style: mutedText),
              ]),
            ),
            GameButton(
              color: GameColors.purple,
              enabled: s.canPrestige,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: GameColors.cream,
                    title: const Text('Abrir nova unidade?', style: darkTitle),
                    content: const Text('Seu hospital atual será reiniciado em troca de bônus permanentes.',
                        style: darkText),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('EXPANDIR!')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  s.prestige();
                  Navigator.of(context).pop();
                }
              },
              child: Text(s.canPrestige ? 'ABRIR NOVA UNIDADE' : 'Arrecade mais para expandir', style: gameText(16)),
            ),
            const SizedBox(height: 12),
            const Text('SUAS UNIDADES', style: mutedText),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (int u = 1; u <= s.unit + 1; u++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: u < s.unit ? GameColors.grey : u == s.unit ? GameColors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GameColors.navy, width: 2),
                  ),
                  child: Text('${u <= s.unit ? '🏥' : '🔒'} ${unitName(u)}',
                      style: u <= s.unit ? gameText(12) : darkText.copyWith(fontSize: 12)),
                ),
            ]),
          ]),
        );
      },
    );
  }
}
