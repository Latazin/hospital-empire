import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/format.dart';
import '../../core/game_state.dart';
import '../../core/models.dart';
import '../../game/hospital_game.dart';
import '../theme.dart';
import 'room_sheet.dart';

class UpgradesPanel extends StatelessWidget {
  final GameState s;
  final HospitalGame game;
  const UpgradesPanel({super.key, required this.s, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => PanelFrame(
        title: 'Melhorias',
        icon: '📈',
        color: GameColors.green,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('INFRAESTRUTURA', style: mutedText),
          const SizedBox(height: 6),
          InfraCard(s: s, kind: 'recepcao'),
          InfraCard(s: s, kind: 'transporte'),
          InfraCard(s: s, kind: 'tesouraria'),
          const SizedBox(height: 4),
          const Text('SALAS', style: mutedText),
          const SizedBox(height: 6),
          for (final t in roomTypes) _RoomRow(s: s, t: t, game: game),
          const SizedBox(height: 4),
          const Text('LOJA DE OURO', style: mutedText),
          const SizedBox(height: 6),
          GameCard(
            child: Column(children: [
              _shopRow('🚀', 'Renda x2 por 30 min', s.goldBoostActive ? 'Ativo: ${fmtTime(s.goldBoostLeft)} (acumula)' : 'Multiplica toda a produção', 20, s.buyGoldBoost),
              const Divider(),
              _shopRow('💰', 'Maleta de dinheiro', 'Equivale a 30 min de produção', 10, s.buyMoneyPack),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _shopRow(String icon, String title, String sub, int price, bool Function() buy) => Row(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: darkText),
            Text(sub, style: mutedText),
          ]),
        ),
        GameButton(
          color: GameColors.gold,
          enabled: s.gold >= price,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onTap: buy,
          child: Text('◆$price', style: gameText(14)),
        ),
      ]);
}

class _RoomRow extends StatelessWidget {
  final GameState s;
  final RoomType t;
  final HospitalGame game;
  const _RoomRow({required this.s, required this.t, required this.game});

  @override
  Widget build(BuildContext context) {
    final r = s.room(t.id);
    final lock = s.lockReason(t);
    Widget action;
    String sub;
    if (r.built) {
      final cost = Eco.upgradeCost(t, r.level);
      sub = 'Nv ${r.level} • \$${fmt(Eco.roomIncome(s, t, r.level))}/paciente';
      action = GameButton(
        enabled: s.money >= cost && r.level < Eco.maxRoomLevel,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onTap: () => s.upgradeRoom(t, 1),
        child: Text('▲ \$${fmt(cost)}', style: gameText(13)),
      );
    } else if (lock != null) {
      sub = lock;
      action = const Text('🔒', style: TextStyle(fontSize: 22));
    } else {
      sub = 'Pronto para construir';
      action = GameButton(
        color: GameColors.teal,
        enabled: s.money >= t.buildCost,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onTap: () {
          if (s.buildRoom(t)) Navigator.of(context).pop();
        },
        child: Text('🏗️ \$${fmt(t.buildCost)}', style: gameText(13)),
      );
    }
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        game.focusArea('room:${t.id}');
      },
      child: GameCard(
        child: Row(children: [
          Container(
            width: 10,
            height: 40,
            decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: darkText),
              Text(sub, style: mutedText),
            ]),
          ),
          action,
        ]),
      ),
    );
  }
}
