import 'package:flutter/material.dart';

import '../../core/economy.dart';
import '../../core/game_state.dart';
import '../../core/models.dart';
import '../theme.dart';

class ManagersPanel extends StatelessWidget {
  final GameState s;
  const ManagersPanel({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => PanelFrame(
        title: 'Gerentes',
        icon: '👔',
        color: const Color(0xFF3F8CFF),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const GameCard(
            color: Color(0xFFE8F1FF),
            child: Text(
              'Gerentes aceleram setores (até nível 10). O de Tesouraria coleta sozinho e garante 100% dos ganhos offline. Exclusivos ★ vêm dos desafios semanais.',
              style: mutedText,
            ),
          ),
          for (final m in managerDefs) _ManagerCard(s: s, m: m),
        ]),
      ),
    );
  }
}

class _ManagerCard extends StatelessWidget {
  final GameState s;
  final ManagerDef m;
  const _ManagerCard({required this.s, required this.m});

  @override
  Widget build(BuildContext context) {
    final owned = s.ownedManagers.contains(m.id);
    final lvl = s.managerLevels[m.id] ?? 1;
    final active = s.activeManager(m.area)?.id == m.id;
    Widget action;
    if (!owned) {
      action = m.exclusive
          ? const Text('Desafio\nsemanal', textAlign: TextAlign.center, style: mutedText)
          : GameButton(
              color: GameColors.gold,
              enabled: s.gold >= m.hireGold,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onTap: () => s.hireManager(m),
              child: Text('Contratar\n◆${m.hireGold}', textAlign: TextAlign.center, style: gameText(12)),
            );
    } else if (lvl >= Eco.maxManagerLevel) {
      action = Text('MÁX', style: darkTitle.copyWith(color: GameColors.goldDark));
    } else {
      final cost = Eco.managerUpgradeGold(m, lvl);
      action = GameButton(
        color: GameColors.purple,
        enabled: s.gold >= cost,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onTap: () => s.upgradeManager(m),
        child: Text('Nv ${lvl + 1}\n◆$cost', textAlign: TextAlign.center, style: gameText(12)),
      );
    }
    final bonus = m.exclusive ? 1.5 + 0.15 * lvl : 1 + 0.1 * lvl;
    return Opacity(
      opacity: owned || !m.exclusive ? 1.0 : 0.65,
      child: GameCard(
        color: m.exclusive ? const Color(0xFFFFF8E1) : Colors.white,
        child: Row(children: [
          _Avatar(color: m.color, exclusive: m.exclusive),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: darkText),
              Text('${areaNames[m.area]} • ${m.desc}', style: mutedText),
              if (owned) ...[
                const SizedBox(height: 4),
                Row(children: [
                  for (int i = 1; i <= 10; i++)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: i <= lvl ? m.color : GameColors.navy.withAlpha(30),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text('x${bonus.toStringAsFixed(2)}${active ? '' : ' (reserva)'}',
                      style: mutedText.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ],
            ]),
          ),
          action,
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Color color;
  final bool exclusive;
  const _Avatar({required this.color, required this.exclusive});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        height: 48,
        child: CustomPaint(painter: _AvatarPainter(color, exclusive)),
      );
}

class _AvatarPainter extends CustomPainter {
  final Color color;
  final bool exclusive;
  _AvatarPainter(this.color, this.exclusive);
  @override
  void paint(Canvas c, Size size) {
    final p = Paint();
    final center = Offset(size.width / 2, size.height / 2);
    p.color = exclusive ? const Color(0xFFFFD54F) : const Color(0xFFE3F2FD);
    c.drawCircle(center, size.width / 2, p);
    p.color = color;
    c.drawRRect(RRect.fromLTRBR(10, 30, 38, 52, const Radius.circular(10)), p);
    p.color = Colors.white;
    c.drawPath(Path()..moveTo(20, 30)..lineTo(28, 30)..lineTo(24, 37)..close(), p);
    p.color = const Color(0xFFF1C27D);
    c.drawCircle(Offset(24, 21), 9, p);
    p.color = const Color(0xFF4E342E);
    c.drawArc(Rect.fromCircle(center: const Offset(24, 19), radius: 9.5), 3.1, 3.2, true, p);
    p.color = Colors.black;
    c.drawCircle(const Offset(21, 22), 1.3, p);
    c.drawCircle(const Offset(27, 22), 1.3, p);
    if (exclusive) {
      p.color = const Color(0xFFFF6F00);
      c.drawPath(
          Path()
            ..moveTo(16, 10)
            ..lineTo(18, 4)
            ..lineTo(21, 8)
            ..lineTo(24, 2)
            ..lineTo(27, 8)
            ..lineTo(30, 4)
            ..lineTo(32, 10)
            ..close(),
          p);
    }
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF23314D);
    c.drawCircle(center, size.width / 2 - 1.2, p);
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.color != color;
}
