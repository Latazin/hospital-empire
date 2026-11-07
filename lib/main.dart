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
        theme: ThemeData(useMaterial3: true, fontFamily: 'Nunito', colorScheme: ColorScheme.fromSeed(seedColor: K.teal)),
        home: const TitleScreen(),
      );
}

/// Tela de abertura: carrega a arte, mostra o logo e o botão JOGAR.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  double progress = 0;
  GameState? s;
  double offline = 0;
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { a.dispose(); super.dispose(); }

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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.1, colors: [Color(0xFF3FD1C1), Color(0xFF0F8E83), Color(0xFF0B3B4E)])),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _Dots())),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(animation: a, builder: (_, c) => Transform.translate(offset: Offset(0, -a.value * 10), child: c), child: Art.icons['icon_cross'] != null ? const Ico('cross', size: 110) : const SizedBox(height: 110)),
              const SizedBox(height: 8),
              Text('HOSPITAL', style: display(64)),
              Text('EMPIRE', style: display(76, color: K.gold)),
              const SizedBox(height: 10),
              Transform.rotate(angle: -0.04, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8A8E), Color(0xFFE5383E)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: K.navy, width: 3)),
                child: Text('IDLE TYCOON', style: display(22)),
              )),
              const SizedBox(height: 40),
              if (s == null)
                SizedBox(width: 240, child: Column(children: [GBar(value: progress, height: 22, color: K.gold), const SizedBox(height: 8), Text('Carregando o hospital...', style: body(14, color: Colors.white70))]))
              else
                AnimatedBuilder(animation: a, builder: (_, c) => Transform.scale(scale: 1 + a.value * 0.06, child: c), child: GBtn(color: K.gold, onTap: _play, padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 14), child: Text('JOGAR', style: display(32)))),
            ])),
            Positioned(bottom: 18, left: 0, right: 0, child: Text('Modelos 3D: Kenney (CC0) • Fontes: Lilita One e Nunito (OFL)', textAlign: TextAlign.center, style: body(11, color: Colors.white54))),
          ]),
        ),
      );
}

class _Dots extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0x14FFFFFF);
    for (var y = 0.0; y < s.height; y += 36) { for (var x = (y ~/ 36).isEven ? 0.0 : 18.0; x < s.width; x += 36) { c.drawCircle(Offset(x, y), 3, p); } }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
