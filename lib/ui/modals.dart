import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/state.dart';
import '../game/hospital_game.dart';
import '../game/world.dart' show iso;
import 'kit.dart';

/// Caixa de diálogo com moldura de jogo.
class GameBox extends StatelessWidget {
  final Widget child;
  final String? icon;
  final String title;
  const GameBox({super.key, required this.child, required this.title, this.icon});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1), duration: const Duration(milliseconds: 420), curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 30, offset: Offset(0, 10))]),
            padding: const EdgeInsets.all(3.5),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(27), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.cream, Color(0xFFF7E3BC)])),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) Ico(icon!, size: 76),
                Text(title, textAlign: TextAlign.center, style: display(28, color: K.ink, outline: false)),
                const SizedBox(height: 10),
                child,
              ]),
            ),
          ),
        ),
      );
}

class OfflineModal extends StatelessWidget {
  final GameState s; final double secs, amount; final void Function(bool x2) onClaim;
  const OfflineModal({super.key, required this.s, required this.secs, required this.amount, required this.onClaim});
  @override
  Widget build(BuildContext context) => GameBox(title: 'Bem-vindo de volta!', icon: 'clock', child: Column(children: [
        Text('Seu hospital trabalhou por ${fmtTime(math.min(secs, GameState.offCap))}${secs > GameState.offCap ? ' (máximo de 8h)' : ''}.', textAlign: TextAlign.center, style: body(14.5, w: FontWeight.w700)),
        const SizedBox(height: 10),
        Price('\$${fmt(amount)}', size: 34),
        if (s.activeMgr('tesouraria') == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Contrate o gerente do Cofre para ganhar 100% offline.', textAlign: TextAlign.center, style: body(12, color: K.muted))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GBtn(color: K.teal, onTap: () => onClaim(false), child: const Text('Coletar'))),
          const SizedBox(width: 10),
          Expanded(child: GBtn(color: K.gold, enabled: s.gold >= 5, pulse: s.gold >= 5, onTap: () => onClaim(true), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('x2  ', style: display(18)), Price('5', icon: 'gem', size: 16)]))),
        ]),
      ]));
}

class InspectionModal extends StatelessWidget {
  final String grade, msg; final Color color; final VoidCallback onClose;
  const InspectionModal({super.key, required this.grade, required this.msg, required this.color, required this.onClose});
  @override
  Widget build(BuildContext context) => GameBox(title: 'Inspeção sanitária', icon: 'target', child: Column(children: [
        TweenAnimationBuilder<double>(tween: Tween(begin: 3, end: 1), duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack,
            builder: (_, v, c) => Transform.rotate(angle: (v - 1) * -0.2, child: Transform.scale(scale: v, child: c)),
            child: Text(grade, style: display(100, color: color))),
        Text(msg, textAlign: TextAlign.center, style: body(14.5, w: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: GBtn(color: K.teal, onTap: onClose, child: const Text('OK'))),
      ]));
}

class WheelModal extends StatefulWidget {
  final GameState s; final VoidCallback onClose;
  const WheelModal({super.key, required this.s, required this.onClose});
  @override
  State<WheelModal> createState() => _WheelModalState();
}

class _WheelModalState extends State<WheelModal> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  double from = 0, to = 0, angle = 0;
  int? idx;
  String? result;
  int lastSeg = -1;
  @override
  void initState() {
    super.initState();
    a.addListener(() {
      final e = Curves.easeOutQuart.transform(a.value); setState(() => angle = from + (to - from) * e);
      final seg = ((angle + math.pi / 8) / (math.pi / 4)).floor(); if (seg != lastSeg) { lastSeg = seg; Sfx.play('tick', volume: 0.3, rate: 1.4); }
    });
    a.addStatusListener((st) { if (st == AnimationStatus.completed && idx != null) setState(() => result = widget.s.applyWheel(idx!)); });
  }
  @override
  void dispose() { a.dispose(); super.dispose(); }
  void spin() {
    if (a.isAnimating) return;
    final i = widget.s.spinWheel(); if (i == null) return;
    idx = i; result = null;
    const seg = math.pi * 2 / 8;
    final target = -i * seg + (math.Random().nextDouble() - 0.5) * seg * 0.7;
    from = angle; to = target + math.pi * 2 * (6 + ((from - target) / (math.pi * 2)).ceil());
    a.forward(from: 0);
  }
  @override
  Widget build(BuildContext context) {
    final s = widget.s, free = s.wheelFree;
    return GameBox(title: 'Roleta da Sorte', child: Column(children: [
      SizedBox(width: 280, height: 290, child: Stack(alignment: Alignment.center, children: [
        Transform.rotate(angle: angle, child: CustomPaint(size: const Size(270, 270), painter: _WheelPainter())),
        Positioned(top: 0, child: CustomPaint(size: const Size(34, 40), painter: _PtrPainter())),
        Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.navy, width: 4), gradient: const RadialGradient(colors: [Color(0xFFFFF1A0), K.gold, K.goldD])), child: const Padding(padding: EdgeInsets.all(8), child: Ico('star'))),
      ])),
      SizedBox(height: 40, child: Center(child: result != null ? Text(result!, style: display(26, color: K.greenD, outline: false)) : Text(free ? 'Seu giro grátis está pronto!' : 'Próximo giro grátis em ${fmtTime((s.spinAt - nowMs()) / 1000)}', style: body(14)))),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(flex: 3, child: GBtn(color: K.orange, enabled: !a.isAnimating && (free || s.gold >= 10), pulse: free && !a.isAnimating, onTap: spin, child: free ? const Text('GIRAR GRÁTIS') : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('GIRAR  ', style: display(17)), const Price('10', icon: 'gem', size: 16)]))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: GBtn(color: const Color(0xFF8E9AB4), enabled: !a.isAnimating, onTap: widget.onClose, child: const Text('Fechar'))),
      ]),
    ]));
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2), r = s.width / 2;
    c.drawCircle(ctr, r, Paint()..color = K.navy);
    const seg = math.pi * 2 / 8;
    for (var i = 0; i < 8; i++) {
      final a0 = i * seg - math.pi / 2 - seg / 2, p = wheelPrizes[i];
      final path = Path()..moveTo(ctr.dx, ctr.dy)..arcTo(Rect.fromCircle(center: ctr, radius: r - 6), a0, seg, false)..close();
      c.drawPath(path, Paint()..shader = ui.Gradient.radial(ctr, r, [Color.lerp(p.color, Colors.white, 0.35)!, p.color]));
      c.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
      c.save(); c.translate(ctr.dx, ctr.dy); c.rotate(a0 + seg / 2); c.translate(r * 0.6, 0); c.rotate(math.pi / 2);
      final tp = TextPainter(text: TextSpan(text: p.label, style: display(p.label.length > 6 ? 14 : 17)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2)); c.restore();
    }
    for (var i = 0; i < 8; i++) { final a = i * seg - math.pi / 2 - seg / 2; c.drawCircle(ctr + Offset(math.cos(a), math.sin(a)) * (r - 10), 5, Paint()..color = const Color(0xFFFFE27A)); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PtrPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()..moveTo(0, 0)..lineTo(s.width, 0)..lineTo(s.width / 2, s.height)..close();
    c.drawPath(p.shift(const Offset(0, 3)), Paint()..color = const Color(0x66000000));
    c.drawPath(p, Paint()..color = K.red);
    c.drawPath(p, Paint()..color = K.navy..style = PaintingStyle.stroke..strokeWidth = 3);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tutorial guiado com mãozinha apontando o próximo passo.
class TutorialView extends StatefulWidget {
  final GameState s; final HospitalGame game; final GlobalKey wheelKey, collectKey; final bool panelOpen; final VoidCallback onNext;
  const TutorialView({super.key, required this.s, required this.game, required this.wheelKey, required this.collectKey, required this.panelOpen, required this.onNext});
  @override
  State<TutorialView> createState() => _TutorialViewState();
}

class _TutorialViewState extends State<TutorialView> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() { a.dispose(); super.dispose(); }
  Offset? _keyPos(GlobalKey k) { final b = k.currentContext?.findRenderObject() as RenderBox?; if (b == null) return null; return b.localToGlobal(Offset(b.size.width / 2, b.size.height / 2)); }
  @override
  Widget build(BuildContext context) {
    final s = widget.s, t = s.tut, pad = MediaQuery.of(context).padding;
    String title, text; String? btn; Offset? target;
    switch (t) {
      case 0: title = 'Bem-vindo, Diretor(a)!'; text = 'Pacientes chegam, passam pela recepção, são atendidos nas salas e pagam. Os carregadores levam o dinheiro até o cofre.'; btn = 'Vamos lá!'; break;
      case 1: title = 'Toque no Consultório'; text = 'Abra a sala para ver detalhes e comprar melhorias.'; target = widget.game.worldToScreen(iso(7, 4.5, 60)); break;
      case 2: title = 'Compre uma melhoria'; text = 'Salas melhores rendem mais e atendem mais rápido.'; break;
      case 3: case 4: title = s.treasury >= 1 ? 'Colete o dinheiro!' : 'Aguarde os carregadores'; text = s.treasury >= 1 ? 'Toque em COLETAR para guardar o dinheiro do cofre.' : 'Eles estão levando o dinheiro das salas até o cofre.'; if (s.treasury >= 1 && !widget.panelOpen) target = _keyPos(widget.collectKey); break;
      case 5: title = 'Gire a roleta grátis!'; text = 'Toda hora tem prêmio: dinheiro, ouro, colecionáveis e bônus.'; if (!widget.panelOpen) target = _keyPos(widget.wheelKey); break;
      default: title = 'Pronto para crescer!'; text = 'Ganhe reputação para liberar salas, contrate gerentes e pegue os presentes que caem do céu.'; btn = 'Pegar +10 ouro';
    }
    return Stack(children: [
      Positioned(top: pad.top + 158, left: 16, right: 92, child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
        decoration: BoxDecoration(color: K.cream, borderRadius: BorderRadius.circular(20), border: Border.all(color: K.navy, width: 3), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 5))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: Text(title, style: display(19, color: K.ink, outline: false))), if (t < 6) GestureDetector(onTap: () { s.tut = 7; widget.onNext(); }, child: Text('pular', style: body(12, color: K.muted)))]),
          const SizedBox(height: 3),
          Text(text, style: body(13.5, w: FontWeight.w700)),
          if (btn != null) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: GBtn(color: t == 0 ? K.teal : K.gold, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), onTap: () { if (t == 0) { s.tut = 1; } else { s.tut = 7; s.gold += 10; s.fx?.flyGold(10); } widget.onNext(); }, child: Text(btn, style: display(16))))],
        ]),
      )),
      if (target != null) Positioned(left: target.dx - 12, top: target.dy - 4, child: IgnorePointer(child: AnimatedBuilder(animation: a, builder: (_, __) => Transform.translate(offset: Offset(0, a.value * 12), child: CustomPaint(size: const Size(46, 56), painter: _HandPainter()))))),
    ]);
  }
}

class _HandPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(14, 2)..quadraticBezierTo(20, 0, 22, 6)..lineTo(22, 22)..quadraticBezierTo(28, 18, 32, 23)..quadraticBezierTo(38, 20, 41, 26)..quadraticBezierTo(46, 25, 46, 32)
      ..lineTo(46, 44)..quadraticBezierTo(44, 54, 34, 55)..lineTo(20, 55)..quadraticBezierTo(12, 54, 8, 46)..lineTo(2, 34)..quadraticBezierTo(0, 28, 6, 28)..lineTo(10, 32)..lineTo(10, 6)..quadraticBezierTo(10, 2, 14, 2)..close();
    c.drawPath(p.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    c.drawPath(p, Paint()..color = Colors.white);
    c.drawPath(p, Paint()..color = K.navy..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
