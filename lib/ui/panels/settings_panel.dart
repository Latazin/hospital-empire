import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/game_state.dart';
import '../../core/save_service.dart';
import '../theme.dart';

class SettingsPanel extends StatefulWidget {
  final GameState s;
  const SettingsPanel({super.key, required this.s});
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  Widget _toggle(String icon, String label, bool value, ValueChanged<bool> onChanged) => GameCard(
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: darkText)),
          Switch(value: value, activeColor: GameColors.teal, onChanged: (v) {
            Sfx.click();
            setState(() => onChanged(v));
            Sfx.saveSettings();
          }),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return PanelFrame(
      title: 'Ajustes',
      icon: '⚙️',
      color: GameColors.navyLight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _toggle('🎵', 'Música ambiente', Sfx.music, (v) {
          Sfx.music = v;
          v ? Sfx.startMusic() : Sfx.stopMusic();
        }),
        _toggle('🔊', 'Efeitos sonoros', Sfx.sound, (v) => Sfx.sound = v),
        _toggle('📳', 'Vibração leve', Sfx.vibration, (v) => Sfx.vibration = v),
        GameButton(
          color: GameColors.teal,
          onTap: () async {
            await SaveService.save(s);
            s.toast('💾 Progresso salvo!');
            s.changed();
          },
          child: const Text('Salvar agora'),
        ),
        const SizedBox(height: 10),
        GameButton(
          color: GameColors.purple,
          onTap: () {
            s.tutorialStep = 0;
            s.changed();
            Navigator.of(context).pop();
          },
          child: const Text('Rever tutorial'),
        ),
        const SizedBox(height: 10),
        GameButton(
          color: GameColors.red,
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                backgroundColor: GameColors.cream,
                title: const Text('Apagar todo o progresso?', style: darkTitle),
                content: const Text('Isso não pode ser desfeito. O jogo será fechado para recomeçar.', style: darkText),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('APAGAR')),
                ],
              ),
            );
            if (ok == true) {
              await SaveService.wipe();
              s.toast('Progresso apagado. Feche e abra o jogo.');
              s.changed();
            }
          },
          child: const Text('Apagar progresso'),
        ),
        const SizedBox(height: 14),
        const Text('Hospital Empire v1.0.0\nSalvamento automático a cada 15s e ao sair do app.',
            textAlign: TextAlign.center, style: mutedText),
      ]),
    );
  }
}
