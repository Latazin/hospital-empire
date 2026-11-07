import 'package:flutter/material.dart';

import '../core/audio.dart';

class GameColors {
  static const teal = Color(0xFF19B5A5);
  static const tealDark = Color(0xFF0D7F74);
  static const navy = Color(0xFF23314D);
  static const navyLight = Color(0xFF34476E);
  static const cream = Color(0xFFFFF6E5);
  static const gold = Color(0xFFFFC83D);
  static const goldDark = Color(0xFFC98A00);
  static const green = Color(0xFF2ECC71);
  static const greenDark = Color(0xFF1E9E55);
  static const red = Color(0xFFFF5A5F);
  static const purple = Color(0xFF8E5CF7);
  static const grey = Color(0xFF9AA5B8);
}

TextStyle gameText(double size, {Color color = Colors.white, bool shadow = true}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: color,
      letterSpacing: 0.2,
      height: 1.1,
      shadows: shadow
          ? const [Shadow(color: Color(0xAA000000), offset: Offset(0, 2), blurRadius: 0)]
          : null,
    );

/// Botão "cartoon" com volume, gradiente e animação de pressionar.
class GameButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final EdgeInsets padding;
  final bool enabled;
  const GameButton({
    super.key,
    required this.child,
    this.onTap,
    this.color = GameColors.green,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.enabled = true,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    final base = on ? widget.color : GameColors.grey;
    final dark = Color.lerp(base, Colors.black, 0.32)!;
    final light = Color.lerp(base, Colors.white, 0.25)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: on
          ? () {
              Sfx.click();
              widget.onTap!();
            }
          : () => Sfx.haptic(),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          decoration: BoxDecoration(
            color: dark,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: GameColors.navy, width: 2.5),
          ),
          padding: EdgeInsets.only(bottom: _down ? 1 : 4),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [light, base],
              ),
              borderRadius: BorderRadius.circular(widget.radius - 3),
            ),
            child: DefaultTextStyle(style: gameText(15), child: Center(widthFactor: 1, child: widget.child)),
          ),
        ),
      ),
    );
  }
}

/// Moldura padrão dos painéis (sobe de baixo, deixa o hospital visível acima).
class PanelFrame extends StatelessWidget {
  final String title;
  final String icon;
  final Widget child;
  final Color color;
  const PanelFrame(
      {super.key, required this.title, required this.icon, required this.child, this.color = GameColors.teal});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.66),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: GameColors.cream,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: GameColors.navy, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: gameText(20))),
              GestureDetector(
                onTap: () {
                  Sfx.click();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: GameColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: GameColors.navy, width: 2.5),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const GameCard({super.key, required this.child, this.color});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GameColors.navy.withAlpha(60), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x22000000), offset: Offset(0, 3))],
        ),
        child: child,
      );
}

class GameProgress extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final String? label;
  const GameProgress(
      {super.key, required this.value, this.color = GameColors.green, this.height = 14, this.label});
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: GameColors.navy.withAlpha(40),
          borderRadius: BorderRadius.circular(height),
          border: Border.all(color: GameColors.navy, width: 1.5),
        ),
        child: Stack(children: [
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0).toDouble(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          if (label != null)
            Center(child: Text(label!, style: gameText(height * 0.62))),
        ]),
      );
}

const darkText = TextStyle(color: GameColors.navy, fontWeight: FontWeight.w800, fontSize: 14);
const darkTitle = TextStyle(color: GameColors.navy, fontWeight: FontWeight.w900, fontSize: 17);
const mutedText = TextStyle(color: Color(0xFF66708A), fontWeight: FontWeight.w600, fontSize: 12.5);
