import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio.dart';
import 'core/data.dart';
import 'core/save.dart';
import 'core/state.dart';
import 'game/art.dart';
import 'game/world.dart' show iso, colX, rowY;
import 'ui/game_screen.dart';
import 'ui/kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HospitalEmpireApp());
}

class HospitalEmpireApp extends StatelessWidget {
  const HospitalEmpireApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Hospital Empire',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Fredoka', colorScheme: ColorScheme.fromSeed(seedColor: K.teal)),
        home: const TitleScreen(),
      );
}

/// Tela de abertura: carrega a arte, mostra o logo e o botão JOGAR.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with TickerProviderStateMixin {
  double progress = 0;
  GameState? s;
  double offline = 0;
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { a.dispose(); clock.dispose(); intro.dispose(); super.dispose(); }

  Future<void> _load() async {
    final st = await Save.load();
    offline = st.ls > 0 ? (nowMs() - st.ls) / 1000 : 0;
    Sfx.music = st.music; Sfx.sound = st.sound; Sfx.vibration = st.vibration;
    await Art.load((k) { if (mounted) setState(() => progress = k); });
    await Sfx.init();
    final q = Uri.base.queryParameters;
    if (q['demo'] == '1') {
      st..money = 5e9..rep = 3000..unit = 3..gold = 500..tut = 7..rl = 25..tl = 30..trl = 20;
      const lv = [12, 27, 55, 8, 30, 52, 3, 18];
      for (var i = 0; i < roomTypes.length; i++) { st.rooms[roomTypes[i].id] = RoomSave(b: true, l: lv[i]); }
      st.mgr = {'m_paulo': 3, 'm_lia': 2};
    }
    if (q['tut'] == '7') st.tut = 7;
    if (mounted) setState(() => s = st);
    if (q['auto'] == '1') _play(panel: q['panel']);
  }

  void _play({String? panel}) {
    Sfx.play('level'); Sfx.startMusic();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => GameScreen(s: s!, offlineSecs: offline, startPanel: panel),
      transitionsBuilder: (_, an, __, c) => FadeTransition(opacity: an, child: c),
    ));
  }

  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B3B4E),
        body: AnimatedBuilder(
          animation: Listenable.merge([clock, a, intro]),
          builder: (_, __) {
            final t = clock.value * 120, k = intro.value;
            double el(double from, double to) => Curves.elasticOut.transform(((k - from) / (to - from)).clamp(0.0, 1.0));
            return Stack(children: [
              // céu
              Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF52D6F0), Color(0xFF9BE7F2), Color(0xFF74C863)], stops: [0, 0.45, 0.5])))),
              // hospital renderizado ao fundo, com movimento lento de câmera
              Positioned.fill(child: AnimatedOpacity(opacity: Art.ready ? 1 : 0, duration: const Duration(milliseconds: 900), child: CustomPaint(painter: _Panorama(t)))),
              // vinheta para destacar o logo e o botão
              Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC0B3B4E), Color(0x330B3B4E), Color(0x000B3B4E), Color(0x990B2238)], stops: [0, 0.35, 0.6, 1])))),
              Positioned.fill(child: CustomPaint(painter: _Rays(t, Alignment(0, -0.42)))),
              Positioned.fill(child: CustomPaint(painter: _Floaters(t))),
              Align(alignment: const Alignment(0, -0.5), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.translate(offset: Offset(0, -a.value * 10), child: Transform.scale(scale: el(0, 0.55), child: Art.icons['icon_cross'] != null ? const Ico('cross', size: 120) : const SizedBox(height: 120))),
                const SizedBox(height: 4),
                Transform.scale(scale: el(0.12, 0.65), child: Text('HOSPITAL', style: display(60))),
                Transform.scale(scale: el(0.22, 0.75), child: Stack(children: [
                  Text('EMPIRE', style: display(78)),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4B0), Color(0xFFFFC531), Color(0xFFFF8F00)]).createShader(r),
                    blendMode: BlendMode.srcIn,
                    child: Text('EMPIRE', style: display(78, outline: false)),
                  ),
                ])),
                const SizedBox(height: 8),
                Transform.scale(scale: el(0.35, 0.85), child: Transform.rotate(angle: -0.04 + math.sin(t * 2) * 0.015, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8A8E), Color(0xFFE5383E)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: K.navy, width: 3.5), boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4))]),
                  child: Text('IDLE TYCOON', style: display(22)),
                ))),
              ])),
              Align(alignment: const Alignment(0, 0.62), child: s == null
                  ? SizedBox(width: 250, child: Column(mainAxisSize: MainAxisSize.min, children: [GBar(value: progress, height: 24, color: K.gold), const SizedBox(height: 8), Text('Abrindo o hospital... ${(progress * 100).round()}%', style: body(15, color: Colors.white))]))
                  : Transform.scale(scale: (1 + a.value * 0.06) * el(0.5, 1), child: _Shine(t: t, child: GBtn(color: K.gold, onTap: _play, padding: const EdgeInsets.symmetric(horizontal: 62, vertical: 16), child: Text('JOGAR', style: display(36)))))),
              Positioned(bottom: 14, left: 0, right: 0, child: Text('Modelos 3D: Kenney (CC0) • Fonte: Fredoka (OFL)', textAlign: TextAlign.center, style: body(11, color: Colors.white70))),
            ]);
          },
        ),
      );
}

/// Faixa de brilho que atravessa o botão de tempos em tempos.
class _Shine extends StatelessWidget {
  final double t; final Widget child;
  const _Shine({required this.t, required this.child});
  @override
  Widget build(BuildContext context) {
    final ph = (t % 2.6) / 2.6;
    return Stack(children: [
      child,
      Positioned.fill(child: IgnorePointer(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: FractionalTranslation(
        translation: Offset(-1.2 + ph * 3.2, 0),
        child: Transform.rotate(angle: 0.35, child: Container(width: 34, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x00FFFFFF), Color(0x88FFFFFF), Color(0x00FFFFFF)])))),
      )))),
    ]);
  }
}

/// Raios de sol girando atrás do logo.
class _Rays extends CustomPainter {
  final double t; final Alignment at;
  _Rays(this.t, this.at);
  @override
  void paint(Canvas c, Size s) {
    final o = at.alongSize(s), r = s.longestSide * 0.7;
    c.save(); c.translate(o.dx, o.dy); c.rotate(t * 0.12);
    final p = Paint()..shader = RadialGradient(colors: const [Color(0x55FFF4B0), Color(0x00FFF4B0)]).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    for (var i = 0; i < 16; i++) {
      final a0 = i * math.pi / 8, a1 = a0 + math.pi / 18;
      c.drawPath(Path()..moveTo(0, 0)..lineTo(math.cos(a0) * r, math.sin(a0) * r)..lineTo(math.cos(a1) * r, math.sin(a1) * r)..close(), p);
    }
    c.restore();
    c.drawCircle(o, 170, Paint()..shader = RadialGradient(colors: const [Color(0x66FFF4B0), Color(0x00FFF4B0)]).createShader(Rect.fromCircle(center: o, radius: 170)));
  }
  @override
  bool shouldRepaint(covariant _Rays old) => old.t != t;
}

/// Moedas subindo devagar pela tela.
class _Floaters extends CustomPainter {
  final double t;
  _Floaters(this.t);
  @override
  void paint(Canvas c, Size s) {
    final sp = Art.spr['coin']; if (sp == null) return;
    final p = Paint()..filterQuality = FilterQuality.medium;
    for (var i = 0; i < 9; i++) {
      final sp0 = 0.05 + (i * 37 % 11) / 220, ph = (t * sp0 + i * 0.137) % 1;
      final x = s.width * ((i * 0.618) % 1) + math.sin(t + i) * 14, y = s.height * (1.05 - ph * 1.2);
      final sc = 0.22 + (i % 3) * 0.06, sq = math.cos(t * 3 + i).abs() * 0.8 + 0.2;
      p.color = Color.fromRGBO(255, 255, 255, (math.sin(ph * math.pi)).clamp(0.0, 1.0) * 0.9);
      c.save(); c.translate(x, y); c.scale(sc * sq, sc);
      c.drawImageRect(sp.img, sp.src, Rect.fromLTWH(-sp.src.width / 2, -sp.src.height / 2, sp.src.width, sp.src.height), p);
      c.restore();
    }
  }
  @override
  bool shouldRepaint(covariant _Floaters old) => old.t != t;
}

/// O hospital completo, montado com os mesmos sprites do jogo.
class _Panorama extends CustomPainter {
  final double t;
  _Panorama(this.t);
  static final _p = Paint()..filterQuality = FilterQuality.medium;
  void _spr(Canvas c, String n, double gx, double gy) {
    final sp = Art.spr[n]; if (sp == null) return;
    final o = iso(gx, gy);
    c.drawImageRect(sp.img, sp.src, Rect.fromLTWH(o.dx - sp.ax, o.dy - sp.ay, sp.src.width, sp.src.height), _p);
  }
  @override
  void paint(Canvas c, Size s) {
    if (!Art.ready) return;
    final k = math.max(s.width / 1250, s.height / 2300);
    final ctr = iso(10.5 + math.sin(t * 0.09) * 2.5, 8 + math.cos(t * 0.07) * 1.5);
    c.save(); c.translate(s.width / 2, s.height * 0.66); c.scale(k); c.translate(-ctr.dx, -ctr.dy);
    for (final b in Art.bg) { c.drawImageRect(b.img, Rect.fromLTWH(0, 0, b.img.width.toDouble(), b.img.height.toDouble()), Rect.fromLTWH(-b.ax, -b.ay, b.img.width.toDouble(), b.img.height.toDouble()), _p); }
    _spr(c, 'rec_2', 0, 0); _spr(c, 'tre_2', 0, 0);
    final items = <(double, String, double, double)>[];
    for (final rt in roomTypes) {
      final pl = plots[rt.plot];
      _spr(c, 'room_${rt.id}_2', pl[0], pl[1]);
      for (var i = 0; i < 4; i++) { final x = pl[0] + colX[i % 2], y = pl[1] + rowY[i >> 1]; items.add((x + y, 'st_${rt.id}_2', x, y)); }
    }
    items..add((5.65, 'rec_counter', 0, 0))..add((7.55, 'rec_chairs1', 0, 0))..add((8.55, 'rec_chairs2', 0, 0));
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) { _spr(c, it.$2, it.$3, it.$4); }
    _spr(c, 'ov_front', 0, 0); _spr(c, 'ov_over', 0, 0);
    c.restore();
  }
  @override
  bool shouldRepaint(covariant _Panorama old) => old.t != t;
}
