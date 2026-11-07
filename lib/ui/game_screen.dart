import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/economy.dart';
import '../core/format.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/progression.dart';
import '../core/save_service.dart';
import '../game/hospital_game.dart';
import 'panels/events_panel.dart';
import 'panels/expansion_panel.dart';
import 'panels/managers_panel.dart';
import 'panels/missions_panel.dart';
import 'panels/room_sheet.dart';
import 'panels/settings_panel.dart';
import 'panels/upgrades_panel.dart';
import 'theme.dart';

class GameScreen extends StatefulWidget {
  final GameState state;
  const GameScreen({super.key, required this.state});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final HospitalGame game;
  double _startZoom = 1;
  Offset _lastFocal = Offset.zero;
  int _pausedAt = 0;
  bool _dialogOpen = false;
  bool _sheetOpen = false;

  GameState get s => widget.state;

  @override
  void initState() {
    super.initState();
    game = HospitalGame(s);
    game.onTapTarget = _openTarget;
    WidgetsBinding.instance.addObserver(this);
    s.addListener(_onState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onState());
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused || st == AppLifecycleState.inactive || st == AppLifecycleState.detached) {
      if (_pausedAt == 0) {
        _pausedAt = nowMs();
        SaveService.save(s);
        Sfx.pauseMusic();
      }
    } else if (st == AppLifecycleState.resumed) {
      Sfx.resumeMusic();
      if (_pausedAt > 0) s.applyOffline(_pausedAt);
      _pausedAt = 0;
      s.changed();
    }
  }

  void _onState() {
    if (_dialogOpen || s.dialogs.isEmpty || !mounted) return;
    final d = s.dialogs.removeAt(0);
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black45,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => _GameDialogView(d: d, s: s),
        transitionBuilder: (_, a, __, child) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: child,
        ),
      );
      _dialogOpen = false;
      _onState();
    });
  }

  Future<void> _openPanel(Widget panel) async {
    if (_sheetOpen) Navigator.of(context).pop();
    _sheetOpen = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => SafeArea(child: panel),
    );
    _sheetOpen = false;
  }

  void _openTarget(String target) {
    game.focusArea(target);
    if (target.startsWith('room:')) {
      final id = target.substring(5);
      _openPanel(RoomSheet(s: s, type: roomById(id)));
    } else if (target == 'reception') {
      _openPanel(InfraSheet(s: s, kind: 'recepcao'));
    } else if (target == 'treasury') {
      _openPanel(InfraSheet(s: s, kind: 'tesouraria'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) {
              _startZoom = game.zoom;
              _lastFocal = d.localFocalPoint;
            },
            onScaleUpdate: (d) {
              if (d.pointerCount > 1) game.zoom = _startZoom * d.scale;
              game.panBy(d.localFocalPoint - _lastFocal);
              _lastFocal = d.localFocalPoint;
            },
            onTapUp: (d) => game.tapAt(d.localPosition),
            child: GameWidget(game: game),
          ),
        ),
        Positioned.fill(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => _Hud(s: s, game: game, open: _openPanel, openTarget: _openTarget),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _ToastLayer(s: s))),
      ]),
    );
  }
}

// ======================================================================= HUD
class _Hud extends StatelessWidget {
  final GameState s;
  final HospitalGame game;
  final Future<void> Function(Widget) open;
  final void Function(String) openTarget;
  const _Hud({required this.s, required this.game, required this.open, required this.openTarget});

  @override
  Widget build(BuildContext context) {
    final ev = currentWeeklyEvent();
    return SafeArea(
      child: Stack(children: [
        // ---------- Topo: recursos ----------
        Positioned(
          top: 6,
          left: 8,
          right: 8,
          child: Column(children: [
            Row(children: [
              Expanded(flex: 5, child: _ResourcePill(symbol: '\$', color: GameColors.green, value: fmt(s.money))),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: _ResourcePill(symbol: '◆', color: GameColors.gold, value: '${s.gold}')),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: _ResourcePill(symbol: '★', color: GameColors.purple, value: fmt(s.rep))),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: [
              _Chip('🏥 ${unitName(s.unit)}', GameColors.navy),
              if (s.unit > 1) _Chip('x${Eco.prestigeMult(s).toStringAsFixed(2)}', GameColors.tealDark),
              if (s.plantaoActive) _Chip('⚡ x3 ${s.plantaoLeft.ceil()}s', const Color(0xFFFF6D00)),
              if (s.goldBoostActive) _Chip('🚀 x2 ${fmtTime(s.goldBoostLeft)}', GameColors.purple),
              if (s.epidemic) _Chip('🦠 Epidemia ${s.epidemicLeft.ceil()}s', const Color(0xFF558B2F)),
              _Chip('${ev.icon} ${ev.name}', ev.color),
            ]),
            const SizedBox(height: 6),
            if (s.currentObjective != null) _ObjectiveBanner(s: s),
          ]),
        ),
        // ---------- Lateral direita ----------
        Positioned(
          right: 8,
          top: 150,
          child: Column(children: [
            _PlantaoButton(s: s),
            const SizedBox(height: 10),
            _SideButton(icon: Icons.zoom_in_rounded, onTap: () => game.zoom = game.zoom * 1.25),
            const SizedBox(height: 8),
            _SideButton(icon: Icons.zoom_out_rounded, onTap: () => game.zoom = game.zoom / 1.25),
            const SizedBox(height: 8),
            _SideButton(icon: Icons.my_location_rounded, onTap: () => game.focusArea('reception')),
          ]),
        ),
        // ---------- Tutorial ----------
        if (s.tutorialStep < 4) Positioned(left: 12, right: 84, top: 150, child: _Tutorial(s: s, openTarget: openTarget)),
        // ---------- Botão de coleta ----------
        Positioned(right: 10, bottom: 92, child: _CollectButton(s: s, game: game)),
        // ---------- Barra inferior ----------
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [GameColors.navyLight, GameColors.navy],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF111A2E), width: 2.5),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _NavButton('📈', 'Melhorias', GameColors.green, () => open(UpgradesPanel(s: s, game: game))),
              _NavButton('👔', 'Gerentes', const Color(0xFF3F8CFF), () => open(ManagersPanel(s: s))),
              _NavButton('🎯', 'Missões', GameColors.red, () => open(MissionsPanel(s: s)), badge: s.claimableCount),
              _NavButton('🏙️', 'Expansão', GameColors.purple, () => open(ExpansionPanel(s: s)), badge: s.canPrestige ? 1 : 0),
              _NavButton('🎉', 'Eventos', const Color(0xFFFF9F1C), () => open(EventsPanel(s: s)),
                  badge: (!s.weekClaimed && s.weeklyProgress >= s.weeklyTarget) ? 1 : 0),
              _NavButton('⚙️', 'Ajustes', GameColors.grey, () => open(SettingsPanel(s: s))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ResourcePill extends StatelessWidget {
  final String symbol;
  final Color color;
  final String value;
  const _ResourcePill({required this.symbol, required this.color, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xDD23314D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(200), width: 2),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              shape: BoxShape.circle,
              border: Border.all(color: GameColors.navy, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(symbol, style: gameText(16)),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(value, style: gameText(18)),
              ),
            ),
          ),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(225),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(170), width: 1.5),
        ),
        child: Text(text, style: gameText(11)),
      );
}

class _ObjectiveBanner extends StatelessWidget {
  final GameState s;
  const _ObjectiveBanner({required this.s});
  @override
  Widget build(BuildContext context) {
    final o = s.currentObjective!;
    final p = o.progress(s);
    final done = p >= 1;
    return GestureDetector(
      onTap: done ? s.claimObjective : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: done ? const Color(0xEE2ECC71) : const Color(0xDDFFF6E5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GameColors.navy, width: 2),
        ),
        child: Row(children: [
          const Text('🎯', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: done ? gameText(12) : darkText.copyWith(fontSize: 12)),
              const SizedBox(height: 3),
              GameProgress(value: p, height: 8, color: GameColors.gold),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: done ? GameColors.gold : GameColors.navy.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(done ? 'PEGAR ◆${o.gold}' : '◆${o.gold}',
                style: done ? gameText(11) : darkText.copyWith(fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  const _NavButton(this.emoji, this.label, this.color, this.onTap, {this.badge = 0});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.click();
        onTap();
      },
      child: SizedBox(
        width: 56,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 44,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF111A2E), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            if (badge > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: GameColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('$badge', textAlign: TextAlign.center, style: gameText(10, shadow: false)),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          FittedBox(child: Text(label, style: gameText(10))),
        ]),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SideButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          Sfx.click();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xDD23314D),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(200), width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
}

class _PlantaoButton extends StatelessWidget {
  final GameState s;
  const _PlantaoButton({required this.s});
  @override
  Widget build(BuildContext context) {
    final ready = s.plantaoReady;
    final active = s.plantaoActive;
    final cd = s.plantaoCooldownLeft;
    return GestureDetector(
      onTap: ready ? s.activatePlantao : () => Sfx.haptic(),
      child: SizedBox(
        width: 62,
        height: 62,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: ready ? 1.0 : 1.0 - cd / 300,
              strokeWidth: 5,
              backgroundColor: Colors.black26,
              color: active ? Colors.white : GameColors.gold,
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ready
                    ? [const Color(0xFFFFE57F), const Color(0xFFFF9100)]
                    : [const Color(0xFF90A4AE), const Color(0xFF607D8B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: GameColors.navy, width: 2.5),
            ),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚡', style: TextStyle(fontSize: 18)),
              Text(active ? '${s.plantaoLeft.ceil()}s' : ready ? 'x3' : fmtTime(cd), style: gameText(9)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CollectButton extends StatelessWidget {
  final GameState s;
  final HospitalGame game;
  const _CollectButton({required this.s, required this.game});
  @override
  Widget build(BuildContext context) {
    final max = Eco.treasuryMax(s);
    final ratio = (s.treasury / max).clamp(0.0, 1.0).toDouble();
    final full = ratio >= 0.999;
    final has = s.treasury >= 1;
    return TweenAnimationBuilder<double>(
      key: ValueKey(full),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (context, t, child) {
        final pulse = full ? 1 + 0.06 * math.sin(t * math.pi * 2) : 1.0;
        return Transform.scale(scale: pulse, child: child);
      },
      child: GestureDetector(
        onTap: () {
          if (!has) {
            Sfx.haptic();
            return;
          }
          final v = s.collect();
          game.floatText(game.treasuryCenter, '+\$${fmt(v)}', const Color(0xFF9CFF6B), size: 14);
          Sfx.haptic();
        },
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: has ? [const Color(0xFFFFE07A), GameColors.gold] : [const Color(0xFFCFD8DC), const Color(0xFF90A4AE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: full ? GameColors.red : GameColors.navy, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 5))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('COLETAR', style: gameText(14)),
            FittedBox(child: Text('\$${fmt(s.treasury)}', style: gameText(18))),
            const SizedBox(height: 4),
            GameProgress(value: ratio, height: 8, color: full ? GameColors.red : GameColors.green),
            if (full) Padding(padding: const EdgeInsets.only(top: 3), child: Text('CHEIA!', style: gameText(10))),
          ]),
        ),
      ),
    );
  }
}

// ======================================================================= Tutorial
class _Tutorial extends StatelessWidget {
  final GameState s;
  final void Function(String) openTarget;
  const _Tutorial({required this.s, required this.openTarget});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('👋 Bem-vindo, Diretor(a)!',
          'Você comanda o Hospital Empire. Pacientes chegam, passam pela recepção, são atendidos nas salas e pagam. Arraste para mover e use dois dedos para zoom.',
          'Vamos lá!'),
      ('🩺 Melhore o Consultório',
          'Toque no Consultório (no hospital) e compre uma melhoria. Salas melhores rendem mais e atendem mais rápido.',
          'Abrir Consultório'),
      ('💰 Colete o dinheiro',
          'Os carregadores levam o dinheiro das salas até a Tesouraria. Toque em COLETAR quando houver saldo.',
          null),
      ('🏗️ Cresça!',
          'Ganhe reputação para liberar novas salas, contrate gerentes e cumpra objetivos para ganhar ouro ◆.',
          'Entendi!'),
    ];
    final i = math.min(3, math.max(0, s.tutorialStep));
    final (title, text, btn) = steps[i];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameColors.navy, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(title, style: darkTitle)),
          GestureDetector(
            onTap: () {
              s.tutorialStep = 4;
              s.changed();
            },
            child: const Text('pular', style: mutedText),
          ),
        ]),
        const SizedBox(height: 4),
        Text(text, style: darkText.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        if (btn != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GameButton(
              color: GameColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              onTap: () {
                if (i == 1) {
                  openTarget('room:consultorio');
                } else {
                  s.tutorialStep = i == 0 ? 1 : 4;
                  s.changed();
                }
              },
              child: Text(btn, style: gameText(13)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ======================================================================= Toasts
class _ToastLayer extends StatefulWidget {
  final GameState s;
  const _ToastLayer({required this.s});
  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer> {
  String? _current;
  int _id = 0;

  @override
  void initState() {
    super.initState();
    widget.s.addListener(_pump);
  }

  @override
  void dispose() {
    widget.s.removeListener(_pump);
    super.dispose();
  }

  void _pump() {
    if (_current != null || widget.s.toasts.isEmpty) return;
    setState(() {
      _current = widget.s.toasts.removeAt(0);
      _id++;
    });
    final my = _id;
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (!mounted || my != _id) return;
      setState(() => _current = null);
      Future.delayed(const Duration(milliseconds: 250), _pump);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: 96),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: _current == null
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(_id),
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xF023314D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GameColors.gold, width: 2),
                    ),
                    child: Text(_current!, textAlign: TextAlign.center, style: gameText(13)),
                  ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================= Diálogos
class _GameDialogView extends StatelessWidget {
  final GameDialog d;
  final GameState s;
  const _GameDialogView({required this.d, required this.s});

  @override
  Widget build(BuildContext context) {
    final offline = d.offlineAmount > 0;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GameColors.cream,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: GameColors.navy, width: 3),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(d.icon, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 6),
            Text(d.title, textAlign: TextAlign.center, style: darkTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(d.message, textAlign: TextAlign.center, style: darkText.copyWith(fontWeight: FontWeight.w600)),
            if (offline) ...[
              const SizedBox(height: 10),
              Text('+\$${fmt(d.offlineAmount)}', style: gameText(30, color: GameColors.green)),
              const SizedBox(height: 4),
              if (s.activeManager('tesouraria') == null)
                const Text('Contrate um gerente de Tesouraria para ganhar 100% offline.',
                    textAlign: TextAlign.center, style: mutedText),
            ],
            const SizedBox(height: 14),
            if (offline)
              Row(children: [
                Expanded(
                  child: GameButton(
                    color: GameColors.teal,
                    onTap: () {
                      s.claimOffline(d.offlineAmount);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Coletar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameButton(
                    color: GameColors.gold,
                    enabled: s.gold >= 5,
                    onTap: () {
                      s.claimOffline(d.offlineAmount, doubled: true);
                      Navigator.of(context).pop();
                    },
                    child: const Text('x2  ◆5'),
                  ),
                ),
              ])
            else
              GameButton(
                color: GameColors.teal,
                onTap: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
          ]),
        ),
      ),
    );
  }
}
