import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio.dart';
import 'core/game_state.dart';
import 'core/save_service.dart';
import 'ui/game_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Sfx.loadSettings();
  final state = await SaveService.load();
  state.applyOffline(state.lastSaveMs);
  runApp(HospitalEmpireApp(state: state));
  Sfx.init().then((_) => Sfx.startMusic());
}

class HospitalEmpireApp extends StatelessWidget {
  final GameState state;
  const HospitalEmpireApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hospital Empire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: GameColors.teal),
        scaffoldBackgroundColor: const Color(0xFF5FAE57),
      ),
      home: GameScreen(state: state),
    );
  }
}
