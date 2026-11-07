import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio.dart';
import 'core/data.dart';
import 'core/save.dart';
import 'core/state.dart';
import 'game/art.dart';
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
            double ease(double from, double to) => Curves.easeOutCubic.transform(((k - from) / (to - from)).clamp(0.0, 1.0));
            return Stack(children: [
              // arte do hospital com zoom lento
              Positioned.fill(child: RepaintBoundary(child: Transform.scale(scale: 1.04 + 0.04 * math.sin(t * 0.08), child: Image.asset('assets/images/keyart.jpg', fit: BoxFit.cover, filterQuality: FilterQuality.medium)))),
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xF20B2A3E), const Color(0x990B2A3E), const Color(0x000B2A3E), const Color(0x000B2A3E), const Color(0xE60B1A2E)], stops: const [0, 0.28, 0.45, 0.62, 1])))),
              Align(alignment: const Alignment(0, -0.62), child: Opacity(opacity: ease(0, 0.3), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.translate(offset: Offset(0, -a.value * 6), child: Transform.scale(scale: el(0.05, 0.6), child: Art.icons['icon_cross'] != null ? const Ico('cross', size: 96) : const SizedBox(height: 96))),
                Transform.scale(scale: el(0.12, 0.65), child: Text('HOSPITAL', style: display(58))),
                Transform.scale(scale: el(0.2, 0.75), child: Stack(children: [
                  Text('EMPIRE', style: display(74)),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4B0), Color(0xFFFFC531), Color(0xFFFF8F00)]).createShader(r),
                    blendMode: BlendMode.srcIn,
                    child: Text('EMPIRE', style: display(74, outline: false)),
                  ),
                ])),
                const SizedBox(height: 6),
                Transform.scale(scale: el(0.3, 0.85), child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFE5383E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2.5)),
                  child: Text('IDLE TYCOON', style: display(18)),
                )),
              ]))),
              Align(alignment: const Alignment(0, 0.78), child: s == null
                  ? SizedBox(width: 240, child: Column(mainAxisSize: MainAxisSize.min, children: [GBar(value: progress, height: 18, color: K.gold), const SizedBox(height: 8), Text('Carregando... ${(progress * 100).round()}%', style: body(14, color: Colors.white))]))
                  : Transform.scale(scale: (1 + a.value * 0.05) * el(0.45, 1), child: _Shine(t: t, child: GBtn(color: K.green, onTap: _play, padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 16), child: Text('JOGAR', style: display(36)))))),
              Positioned(bottom: 10, left: 0, right: 0, child: Text('v1.2', textAlign: TextAlign.center, style: body(11, color: Colors.white38))),
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
