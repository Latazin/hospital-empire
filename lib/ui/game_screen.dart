import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/save.dart';
import '../core/state.dart';
import '../game/hospital_game.dart';
import '../game/world.dart' show iso;
import 'effects.dart';
import 'kit.dart';
import 'modals.dart';
import 'panels.dart';

class GameScreen extends StatefulWidget {
  final GameState s;
  final double offlineSecs;
  final String? startPanel;
  const GameScreen({super.key, required this.s, this.offlineSecs = 0, this.startPanel});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver implements Fx, PanelHost {
  GameState get s => widget.s;
  late final HospitalGame game;
  final fly = FlyController(), conf = ConfettiController();
  final moneyKey = GlobalKey(), goldKey = GlobalKey(), wheelKey = GlobalKey(), collectKey = GlobalKey();
  String? panel; // nome do painel aberto
  final List<(String, String)> _bq = [];
  (String, String)? _banner;
  final List<(int, String)> _toasts = [];
  int _tid = 0;
  Widget? _modal;
  double _startZoom = 1;
  Offset _lastFocal = Offset.zero;
  int _pausedAt = 0;
  Timer? _hudTimer;
  final Set<String> _achSeen = {};

  @override
  void initState() {
    super.initState();
    s.fx = this;
    game = HospitalGame(s);
    game.onTap = _onWorldTap;
    game.onAutosave = () => Save.save(s);
    game.w.onInspection = (g, m, c) => _showModal(InspectionModal(grade: g, msg: m, color: c, onClose: _closeModal));
    fly.onArrive = (gem, v) { if (!gem) s.pending = math.max(0, s.pending - v); _bumpKey = gem ? 'gold' : 'money'; _bumpN++; };
    for (final a in achievements) { if (s.achDone(a)) _achSeen.add(a.id); }
    s.ensureDaily(); s.ensureWeekly();
    WidgetsBinding.instance.addObserver(this);
    _hudTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _hudTick());
    if (widget.startPanel != null) Future.delayed(const Duration(seconds: 3), () { if (mounted) openPanel(widget.startPanel!); });
    if (widget.offlineSecs > 60) WidgetsBinding.instance.addPostFrameCallback((_) => _offerOffline(widget.offlineSecs));
  }

  @override
  void dispose() { _hudTimer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  int _checkT = 0;
  void _hudTick() {
    if (!mounted) return;
    if (++_checkT % 8 == 0) {
      s.ensureDaily(); s.ensureWeekly(); s.refreshGoal();
      for (final a in achievements) { if (!_achSeen.contains(a.id) && s.achDone(a)) { _achSeen.add(a.id); toast('Conquista: ${a.name}! Pegue em Missões'); Sfx.play('coin', rate: 1.4); } }
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused || st == AppLifecycleState.inactive || st == AppLifecycleState.detached) {
      if (_pausedAt == 0) { _pausedAt = nowMs(); Save.save(s); Sfx.pauseMusic(); }
    } else if (st == AppLifecycleState.resumed) {
      Sfx.resumeMusic();
      if (_pausedAt > 0) { final secs = (nowMs() - _pausedAt) / 1000; if (secs > 60) _offerOffline(secs); }
      _pausedAt = 0;
    }
  }

  // ---------------- Fx ----------------
  String _bumpKey = ''; int _bumpN = 0;
  @override
  void banner(String title, String sub) { _bq.add((title, sub)); if (_banner == null) _nextBanner(); }
  void _nextBanner() { setState(() => _banner = _bq.isEmpty ? null : _bq.removeAt(0)); }
  @override
  void toast(String msg) { final id = ++_tid; setState(() { _toasts.add((id, msg)); if (_toasts.length > 3) _toasts.removeAt(0); }); Future.delayed(const Duration(milliseconds: 2600), () { if (mounted) setState(() => _toasts.removeWhere((t) => t.$1 == id)); }); }
  @override
  void sfx(String name, {double pitch = 1}) => Sfx.play(name, rate: pitch);
  @override
  void confetti([int n = 60]) => conf.burst(MediaQuery.of(context).size, n);
  @override
  void buzz([int ms = 12]) => Sfx.haptic(ms);
  Offset _center(GlobalKey k) { final b = k.currentContext?.findRenderObject() as RenderBox?; if (b == null) return Offset.zero; return b.localToGlobal(Offset(22, b.size.height / 2)); }
  @override
  void flyMoney(double amount, {int coins = 12}) {
    s.pending += amount;
    final from = game.worldToScreen(iso(2.5, 11.5, 30));
    final sz = MediaQuery.of(context).size;
    fly.launch(Offset(from.dx.clamp(20, sz.width - 20), from.dy.clamp(80, sz.height - 80)), _center(moneyKey), coins, amount);
  }
  @override
  void flyGold(int amount) { final sz = MediaQuery.of(context).size; fly.launch(Offset(sz.width / 2, sz.height * 0.55), _center(goldKey), math.min(10, 3 + amount), amount.toDouble(), gem: true); }
  @override
  void levelFx(String roomId, int from, int to) => game.w.levelFx(roomId, from, to);

  // ---------------- painéis ----------------
  @override
  void openPanel(String p) {
    Sfx.click();
    setState(() => panel = panel == p ? null : p);
    if (panel == null) return;
    if (p.startsWith('room:')) { game.focusArea(p, sheet: true); if (s.tut == 1 && p == 'room:consultorio') s.tut = 2; }
    if (p == 'reception' || p == 'treasury') game.focusArea(p, sheet: true);
  }
  @override
  void closePanel() => setState(() => panel = null);
  void _onWorldTap(String target) {
    if (target == 'none') { if (panel != null) closePanel(); return; }
    if (panel == target) return;
    Sfx.click(); openPanel(target);
  }
  void _showModal(Widget m) => setState(() => _modal = m);
  void _closeModal() => setState(() => _modal = null);
  void _offerOffline(double secs) {
    final v = s.offlineFor(secs); if (v < 1) return;
    _showModal(OfflineModal(s: s, secs: secs, amount: v, onClaim: (x2) { if (x2) { if (s.gold < 5) return; s.gold -= 5; } final a = x2 ? v * 2 : v; s.earn(a); flyMoney(a, coins: 18); Sfx.play('cash'); confetti(40); _closeModal(); }));
  }
  @override
  void openWheel() => _showModal(WheelModal(s: s, onClose: _closeModal));

  // ---------------- construção ----------------
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: const Color(0xFF74C863),
      body: Stack(children: [
        // O jogo redesenha a cada quadro; o HUD fica isolado para não ser repintado junto.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) { _startZoom = game.zoom; _lastFocal = d.localFocalPoint; game.dragging = true; game.vel.setZero(); },
            onScaleUpdate: (d) {
              if (d.pointerCount > 1) { game.zoomAt(d.localFocalPoint, _startZoom * d.scale / game.zoom); }
              final delta = d.localFocalPoint - _lastFocal; game.panBy(delta); _lastFocal = d.localFocalPoint;
              if (d.pointerCount == 1) game.vel.setValues(delta.dx * 60, delta.dy * 60);
            },
            onScaleEnd: (d) { game.dragging = false; final v = d.velocity.pixelsPerSecond; game.vel.setValues(v.dx.clamp(-2500.0, 2500.0), v.dy.clamp(-2500.0, 2500.0)); },
            onTapUp: (d) => game.tapAt(d.localPosition, openRoom: panel != null && panel!.startsWith('room:') ? panel!.substring(5) : null),
            child: RepaintBoundary(child: GameWidget(game: game)),
          ),
        ),
        if (s.plantaoOn) const RepaintBoundary(child: _Vignette(color: Color(0xFFFF8A00))),
        RepaintBoundary(child: Stack(children: [
          _topBar(pad),
          _sideButtons(pad),
          if (panel == null) _goalArea(pad),
          _bottomNav(pad),
        ])),
        Positioned(left: 0, right: 0, bottom: 0, child: RepaintBoundary(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: c),
          child: panel == null ? const SizedBox.shrink(key: ValueKey('none')) : SafeArea(key: ValueKey(panel!.split(':').first + (panel!.contains(':') ? panel!.split(':')[1] : '')), top: false, child: buildPanel(panel!, s, this)),
        ))),
        Positioned(top: pad.top + 70, left: 0, right: 0, child: IgnorePointer(child: Column(children: [for (final t in _toasts) _Toast(key: ValueKey(t.$1), text: t.$2)]))),
        Positioned.fill(child: RepaintBoundary(child: FlyLayer(c: fly))),
        Positioned.fill(child: RepaintBoundary(child: ConfettiLayer(c: conf))),
        if (_banner != null) Positioned.fill(child: RepaintBoundary(child: BannerView(key: ValueKey(_banner), title: _banner!.$1, sub: _banner!.$2, onDone: _nextBanner))),
        if (_modal != null) Positioned.fill(child: Container(color: const Color(0x99101828), alignment: Alignment.center, padding: const EdgeInsets.all(18), child: _modal)),
      ]),
    );
  }

  // HUD limpo: só dinheiro, ouro e ajustes no topo
  Widget _topBar(EdgeInsets pad) {
    final shown = math.max(0.0, s.money - s.pending);
    return Positioned(
      top: pad.top + 6, left: 8, right: 8,
      child: Row(children: [
        Expanded(flex: 6, child: _Res(key: moneyKey, icon: 'coin', value: '\$${fmt(shown)}', sub: '+\$${fmt(s.rate)}/s', bump: _bumpKey == 'money' ? _bumpN : 0)),
        const SizedBox(width: 6),
        Expanded(flex: 3, child: _Res(key: goldKey, icon: 'gem', value: '${s.gold}', bump: _bumpKey == 'gold' ? _bumpN : 0)),
        const SizedBox(width: 6),
        GestureDetector(onTap: () => openPanel('settings'), child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xE6182240), border: Border.all(color: const Color(0xFF0E1628), width: 2.5)),
          child: const Padding(padding: EdgeInsets.all(5), child: Ico('gear', size: 32)),
        )),
      ]),
    );
  }

  Widget _sideButtons(EdgeInsets pad) {
    final evReady = !s.wc && s.wProg >= s.wTarget;
    return Positioned(
      right: 8, top: pad.top + 64,
      child: Column(children: [
        _RoundBtn(icon: 'bolt', label: s.plantaoOn ? '${((s.pu - nowMs()) / 1000).ceil()}s' : s.plantaoReady ? 'x3' : fmtTime((s.pc - nowMs()) / 1000), glow: s.plantaoReady, dim: !s.plantaoReady && !s.plantaoOn, onTap: s.activatePlantao),
        if (s.wheelFree) ...[const SizedBox(height: 10), _RoundBtn(key: wheelKey, icon: 'wheel', label: 'GRÁTIS', glow: true, onTap: openWheel)],
        if (evReady) ...[const SizedBox(height: 10), _RoundBtn(icon: 'gift', label: 'PRÊMIO', glow: true, onTap: () => openPanel('events'))],
      ]),
    );
  }

  /// Objetivo atual (sempre um próximo passo claro) + botão de coletar o cofre.
  Widget _goalArea(EdgeInsets pad) {
    final g = s.goal, has = s.treasury >= 1, full = s.treasury >= s.treMax * 0.999;
    return Positioned(
      left: 8, right: 8, bottom: pad.bottom + 92,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (has) Padding(padding: const EdgeInsets.only(bottom: 8), child: _Pulse(active: full, child: GestureDetector(
          key: collectKey,
          onTap: () { s.collect(); setState(() {}); },
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: full ? K.red : K.navy, width: 3), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0A8), K.gold, Color(0xFFF7B200)]), boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Ico('coin', size: 30), const SizedBox(width: 4), Text('COLETAR \$${fmt(s.treasury)}', style: display(17))]),
          ),
        ))),
        Center(child: _GoalCard(title: g.$1, sub: g.$2, progress: g.$3, done: g.$5, gems: s.goalGems,
          onGo: () {
            if (g.$5) { if (s.gk == 'prestige') { openPanel('expansion'); } else { s.claimGoal(); } setState(() {}); return; }
            openPanel(g.$4);
          })),
      ]),
    );
  }

  Widget _bottomNav(EdgeInsets pad) {
    final anyUp = roomTypes.any((t) => s.built(t.id) && s.lvlOf(t.id) < GameState.maxL && s.money >= s.upCost(t, s.lvlOf(t.id))) || roomTypes.any(s.canBuild);
    final mgrAv = managers.any((m) => !m.ex && !s.mgr.containsKey(m.id) && s.gold >= m.gold);
    return Positioned(
      left: 6, right: 6, bottom: pad.bottom + 6,
      child: Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 5),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF41588F), K.navy]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF0E1628), width: 3)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _NavBtn(icon: 'arrow', label: 'Melhorar', badge: anyUp ? '!' : null, active: panel == 'upgrades', onTap: () => openPanel('upgrades')),
          _NavBtn(icon: 'person', label: 'Gerentes', badge: mgrAv ? '!' : null, active: panel == 'managers', onTap: () => openPanel('managers')),
          _NavBtn(icon: 'target', label: 'Missões', badge: s.claimable > 0 ? '${s.claimable}' : null, active: panel == 'missions', onTap: () => openPanel('missions')),
          _NavBtn(icon: 'building', label: 'Expansão', badge: s.canPrestige ? '!' : null, active: panel == 'expansion', onTap: () => openPanel('expansion')),
        ]),
      )),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title, sub;
  final double progress;
  final bool done;
  final int gems;
  final VoidCallback onGo;
  const _GoalCard({required this.title, required this.sub, required this.progress, required this.done, required this.gems, required this.onGo});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () { Sfx.click(); onGo(); },
        child: _Pulse(active: done, child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: done ? const [Color(0xFF9CF7B4), Color(0xFF34C463)] : const [Color(0xFFFFFDF6), Color(0xFFF3E6C8)]),
            borderRadius: BorderRadius.circular(20), border: Border.all(color: K.navy, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 5))],
          ),
          child: Row(children: [
            Ico(done ? 'trophy' : 'target', size: 40),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: done ? display(17) : body(16.5, color: K.ink, w: FontWeight.w900)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: done ? Colors.white : K.muted)),
              const SizedBox(height: 4),
              GBar(value: progress, height: 12, color: done ? K.gold : K.green),
            ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: K.navy, width: 2.5), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: done ? const [Color(0xFFFFF0A8), K.gold] : const [Color(0xFF8CF5A6), K.greenD])),
              child: done
                  ? Row(mainAxisSize: MainAxisSize.min, children: [Text('PEGAR', style: display(16)), const SizedBox(width: 2), const Ico('gem', size: 20), Text('$gems', style: display(15))])
                  : Text('IR', style: display(18)),
            ),
          ]),
        )),
      );
}

// ======================================================= widgets do HUD
class _Res extends StatefulWidget {
  final String icon, value;
  final String? sub;
  final int bump;
  const _Res({super.key, required this.icon, required this.value, this.sub, this.bump = 0});
  @override
  State<_Res> createState() => _ResState();
}

class _ResState extends State<_Res> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  @override
  void didUpdateWidget(covariant _Res old) { super.didUpdateWidget(old); if (widget.bump != old.bump && widget.bump > 0) a.forward(from: 0); }
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        builder: (_, child) => Transform.scale(scale: 1 + math.sin(a.value * math.pi) * 0.22, child: child),
        child: SizedBox(
          height: 46,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(left: 16, top: 4, bottom: 4, child: Container(
              padding: const EdgeInsets.only(left: 24, right: 8),
              decoration: BoxDecoration(color: const Color(0xE6182240), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF0E1628), width: 2.5), boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3))]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.value, style: display(widget.sub != null ? 18 : 19))),
                if (widget.sub != null) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.sub!, style: body(10.5, color: const Color(0xFF9CF5B5), w: FontWeight.w900))),
              ]),
            )),
            Positioned(left: -2, top: 0, bottom: 0, child: Ico(widget.icon, size: 44)),
          ]),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  final String icon, label;
  final bool glow, dim;
  final VoidCallback onTap;
  const _RoundBtn({super.key, required this.icon, required this.label, required this.onTap, this.glow = false, this.dim = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () { Sfx.click(); onTap(); },
        child: _Pulse(
          active: glow,
          child: SizedBox(width: 68, height: 74, child: Stack(alignment: Alignment.topCenter, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.navy, width: 3), gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: dim ? const [Color(0xFFDDE3EC), Color(0xFF8E98AE)] : const [Color(0xFFFFFFFF), Color(0xFFBFE6FF), Color(0xFF5BA8E8)]), boxShadow: [const BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 4), if (glow) const BoxShadow(color: Color(0x99FFE27A), blurRadius: 18, spreadRadius: 2)]),
              child: Padding(padding: const EdgeInsets.all(6), child: Opacity(opacity: dim ? 0.55 : 1, child: Ico(icon, size: 48))),
            ),
            Positioned(bottom: 0, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5)),
              child: Text(label, style: display(11.5)),
            )),
          ])),
        ),
      );
}

class _NavBtn extends StatelessWidget {
  final String icon, label;
  final String? badge;
  final bool active;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.onTap, this.badge, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 62,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52, height: 48,
                transform: Matrix4.translationValues(0, active ? -6 : 0, 0),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF0E1628), width: 2.5), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: active ? const [Color(0xFFFFF0A8), K.gold] : const [Color(0xFF5B75B5), Color(0xFF34497E)]), boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3))]),
                child: Padding(padding: const EdgeInsets.all(3), child: Ico(icon, size: 40)),
              ),
              if (badge != null) Positioned(right: -6, top: -6, child: Container(
                constraints: const BoxConstraints(minWidth: 22), height: 22, padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: K.red, borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white, width: 2)),
                child: Center(child: Text(badge!, style: display(12))),
              )),
            ]),
            const SizedBox(height: 3),
            FittedBox(child: Text(label, style: display(11.5))),
          ]),
        ),
      );
}

class _Pulse extends StatefulWidget {
  final bool active;
  final Widget child;
  const _Pulse({required this.active, required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.active ? AnimatedBuilder(animation: a, builder: (_, c) => Transform.scale(scale: 1 + a.value * 0.06, child: c), child: widget.child) : widget.child;
}

class _Toast extends StatelessWidget {
  final String text;
  const _Toast({super.key, required this.text});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack,
        builder: (_, v, c) => Transform.translate(offset: Offset(0, (1 - v) * -20), child: Opacity(opacity: v.clamp(0, 1), child: c)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6), constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xF0182240), borderRadius: BorderRadius.circular(16), border: Border.all(color: K.gold, width: 2.5), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))]),
          child: Text(text, textAlign: TextAlign.center, style: display(14.5)),
        ),
      );
}

class _Vignette extends StatefulWidget {
  final Color color;
  const _Vignette({required this.color});
  @override
  State<_Vignette> createState() => _VignetteState();
}

class _VignetteState extends State<_Vignette> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
        animation: a,
        builder: (_, __) => Container(decoration: BoxDecoration(gradient: RadialGradient(radius: 1.0, colors: [Colors.transparent, Colors.transparent, widget.color.withValues(alpha: 0.12 + a.value * 0.1)], stops: const [0, 0.78, 1]))),
      )));
}
