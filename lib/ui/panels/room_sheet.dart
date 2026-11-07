import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/format.dart';
import '../../core/game_state.dart';
import '../../core/models.dart';
import '../theme.dart';

/// Painel de uma sala: construir, melhorar (x1/x10/MÁX), ver estatísticas.
class RoomSheet extends StatelessWidget {
  final GameState s;
  final RoomType type;
  const RoomSheet({super.key, required this.s, required this.type});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final r = s.room(type.id);
        return PanelFrame(
          title: type.name,
          icon: _icon(type.station),
          color: type.accent,
          child: r.built ? _built(context, r) : _locked(context),
        );
      },
    );
  }

  static String _icon(StationKind k) => const {
        StationKind.desk: '🩺',
        StationKind.bench: '🔬',
        StationKind.shelf: '💊',
        StationKind.bed: '🛏️',
        StationKind.scanner: '🩻',
        StationKind.surgery: '🔪',
        StationKind.monitor: '📟',
        StationKind.crib: '👶',
      }[k]!;

  Widget _locked(BuildContext context) {
    final reason = s.lockReason(type);
    return Column(children: [
      GameCard(
        child: Column(children: [
          Text(reason == null ? 'Terreno disponível!' : '🔒 Bloqueado', style: darkTitle),
          const SizedBox(height: 6),
          Text(reason ?? 'Construa esta sala para atender novos pacientes.',
              textAlign: TextAlign.center, style: darkText),
          const SizedBox(height: 10),
          _statRow('Renda por paciente', '\$${fmt(Eco.roomIncome(s, type, 1))}'),
          _statRow('Tempo de atendimento', '${Eco.roomTime(s, type, 1).toStringAsFixed(1)}s'),
          if (type.repReq > 0) _statRow('Reputação necessária', '${type.repReq.toInt()} (você: ${s.rep.toInt()})'),
          if (type.unitReq > 1) _statRow('Unidade necessária', '${type.unitReq}ª (você: ${s.unit}ª)'),
        ]),
      ),
      SizedBox(
        width: double.infinity,
        child: GameButton(
          enabled: s.canBuild(type),
          onTap: () {
            if (s.buildRoom(type)) Navigator.of(context).pop();
          },
          child: Text('CONSTRUIR  \$${fmt(type.buildCost)}', style: gameText(17)),
        ),
      ),
    ]);
  }

  Widget _built(BuildContext context, RoomSave r) {
    final lvl = r.level;
    final tier = Eco.tier(lvl);
    final next = Eco.nextMilestone(lvl);
    final prevM = [0, 10, 20, 25, 30, 50, 75, 100].lastWhere((m) => m <= lvl, orElse: () => 0);
    final maxed = lvl >= Eco.maxRoomLevel;
    final mgr = s.activeManager(type.id);
    return Column(children: [
      GameCard(
        child: Column(children: [
          Row(children: [
            Text('Nível $lvl', style: darkTitle.copyWith(fontSize: 22)),
            const Spacer(),
            Text('${'★' * tier}${'☆' * (3 - tier)}  ${Eco.tierNames[tier]}',
                style: darkText.copyWith(color: GameColors.goldDark)),
          ]),
          const SizedBox(height: 8),
          GameProgress(
            value: maxed ? 1.0 : (lvl - prevM) / (next - prevM),
            color: type.accent,
            label: maxed ? 'MÁXIMO' : 'Próximo marco: nível $next',
            height: 18,
          ),
          const SizedBox(height: 8),
          _statRow('Renda por paciente', '\$${fmt(Eco.roomIncome(s, type, lvl))}',
              maxed ? null : '→ \$${fmt(Eco.roomIncome(s, type, lvl + 1))}'),
          _statRow('Tempo de atendimento', '${Eco.roomTime(s, type, lvl).toStringAsFixed(2)}s',
              maxed ? null : '→ ${Eco.roomTime(s, type, lvl + 1).toStringAsFixed(2)}s'),
          _statRow('Vagas simultâneas', '${Eco.roomSlots(lvl)}/4',
              Eco.roomSlots(lvl) < 4 ? '+1 no nível ${(lvl ~/ 10 + 1) * 10}' : null),
          _statRow('Gerente', mgr == null ? 'nenhum' : '${mgr.name} (Nv ${s.managerLevels[mgr.id] ?? 1})'),
          const SizedBox(height: 4),
          const Text('Marcos: nível 10/20/30 abrem vagas • níveis 25/50/75/100 dobram a renda',
              textAlign: TextAlign.center, style: mutedText),
        ]),
      ),
      if (!maxed)
        Row(children: [
          for (final n in [1, 10, -1]) ...[
            Expanded(child: _UpgradeButton(s: s, type: type, count: n)),
            if (n != -1) const SizedBox(width: 8),
          ],
        ]),
    ]);
  }
}

Widget _statRow(String a, String b, [String? c]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(a, style: mutedText.copyWith(fontSize: 13.5))),
        Text(b, style: darkText),
        if (c != null) ...[
          const SizedBox(width: 6),
          Text(c, style: darkText.copyWith(color: GameColors.greenDark, fontSize: 12.5)),
        ],
      ]),
    );

class _UpgradeButton extends StatelessWidget {
  final GameState s;
  final RoomType type;
  final int count;
  const _UpgradeButton({required this.s, required this.type, required this.count});
  @override
  Widget build(BuildContext context) {
    final (cost, n) = s.upgradePreview(type, count);
    final ok = n > 0 && cost <= s.money;
    return GameButton(
      enabled: ok,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      color: count == -1 ? GameColors.purple : GameColors.green,
      onTap: () => s.upgradeRoom(type, count),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(count == -1 ? 'MÁX +$n' : '+$n', style: gameText(15)),
        FittedBox(child: Text('\$${fmt(cost)}', style: gameText(12))),
      ]),
    );
  }
}

/// Painel da Recepção / Transporte / Tesouraria.
class InfraSheet extends StatelessWidget {
  final GameState s;
  final String kind; // recepcao | transporte | tesouraria
  const InfraSheet({super.key, required this.s, required this.kind});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return PanelFrame(
          title: areaNames[kind]!,
          icon: kind == 'recepcao' ? '🛎️' : kind == 'transporte' ? '🛒' : '🏦',
          color: kind == 'recepcao' ? const Color(0xFFE91E63) : kind == 'transporte' ? const Color(0xFFFF9800) : const Color(0xFF8D6E63),
          child: Column(children: [
            InfraCard(s: s, kind: kind),
            if (kind == 'tesouraria') InfraCard(s: s, kind: 'transporte'),
            if (kind == 'recepcao')
              const GameCard(
                child: Text(
                  'Mais reputação = mais pacientes chegando. Fila cheia faz pacientes desistirem e derruba a reputação.',
                  style: mutedText,
                ),
              ),
          ]),
        );
      },
    );
  }
}

class InfraCard extends StatelessWidget {
  final GameState s;
  final String kind;
  const InfraCard({super.key, required this.s, required this.kind});

  @override
  Widget build(BuildContext context) {
    late int lvl;
    late double cost;
    late List<Widget> rows;
    late VoidCallback onUp;
    switch (kind) {
      case 'recepcao':
        lvl = s.receptionLevel;
        cost = Eco.receptionCost(s);
        onUp = s.upgradeReception;
        rows = [
          _statRow('Tempo de check-in', '${Eco.checkinTime(s).toStringAsFixed(2)}s'),
          _statRow('Fila máxima', '${Eco.queueMax(s)} pacientes'),
          _statRow('Chegada de pacientes', 'a cada ${Eco.spawnInterval(s).toStringAsFixed(1)}s'),
        ];
        break;
      case 'transporte':
        lvl = s.transportLevel;
        cost = Eco.transportCost(s);
        onUp = s.upgradeTransport;
        rows = [
          _statRow('Carregadores', '${Eco.carriers(s)}/5', '+1 a cada 10 níveis'),
          _statRow('Capacidade', '\$${fmt(Eco.carrierCapacity(s))}'),
          _statRow('Velocidade', Eco.carrierSpeed(s).toStringAsFixed(2)),
        ];
        break;
      default:
        lvl = s.treasuryLevel;
        cost = Eco.treasuryCost(s);
        onUp = s.upgradeTreasury;
        rows = [
          _statRow('Capacidade do cofre', '\$${fmt(Eco.treasuryMax(s))}'),
          _statRow('Saldo atual', '\$${fmt(s.treasury)}'),
          _statRow('Coleta automática',
              Eco.autoCollectInterval(s).isFinite ? 'a cada ${Eco.autoCollectInterval(s).toStringAsFixed(1)}s' : 'precisa de gerente'),
        ];
    }
    return GameCard(
      child: Column(children: [
        Row(children: [
          Text('${areaNames[kind]}  ', style: darkTitle),
          Text('Nv $lvl', style: darkText.copyWith(color: GameColors.tealDark)),
          const Spacer(),
          GameButton(
            enabled: s.money >= cost && lvl < Eco.maxInfraLevel,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onTap: onUp,
            child: Text('▲ \$${fmt(cost)}', style: gameText(13)),
          ),
        ]),
        const SizedBox(height: 6),
        ...rows,
      ]),
    );
  }
}
