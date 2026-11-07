import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/save.dart';
import '../core/state.dart';
import 'kit.dart';

/// Interface comum que o painel usa para falar com a tela do jogo.
abstract class PanelHost {
  void closePanel();
  void openPanel(String p);
  void openWheel();
  void toast(String msg);
}

const _roomIcon = {'consultorio': 'cross', 'laboratorio': 'micro', 'farmacia': 'pill', 'enfermaria': 'heart', 'radiologia': 'building', 'centro': 'scalpel', 'uti': 'heart', 'maternidade': 'ribbon'};

Widget buildPanel(String key, GameState s, PanelHost host) {
  final parts = key.split(':');
  switch (parts[0]) {
    case 'room': return _RoomPanel(s: s, host: host, id: parts[1]);
    case 'reception': return _InfraPanel(s: s, host: host, kind: 'rl');
    case 'treasury': return _InfraPanel(s: s, host: host, kind: 'trl');
    case 'upgrades': return _UpgradesPanel(s: s, host: host);
    case 'managers': return _ManagersPanel(s: s, host: host);
    case 'missions': return _MissionsPanel(s: s, host: host);
    case 'expansion': return _ExpansionPanel(s: s, host: host);
    case 'events': return _EventsPanel(s: s, host: host);
    default: return _SettingsPanel(s: s, host: host);
  }
}

class _Live extends StatelessWidget {
  final GameState s;
  final Widget Function() builder;
  const _Live({required this.s, required this.builder});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: s, builder: (_, __) => builder());
}

// ======================================================= sala
class _RoomPanel extends StatelessWidget {
  final GameState s; final PanelHost host; final String id;
  const _RoomPanel({required this.s, required this.host, required this.id});
  @override
  Widget build(BuildContext context) {
    final t = roomById(id);
    return Sheet(title: t.name, icon: _roomIcon[id] ?? 'cross', color: t.accent, onClose: host.closePanel, child: _Live(s: s, builder: () {
      if (!s.built(id)) {
        final why = s.lockReason(t);
        return Column(children: [
          GCard(child: Column(children: [
            Row(children: [Ico(why == null ? 'hammer' : 'lock', size: 54), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(why == null ? 'Terreno disponível!' : 'Bloqueado', style: body(18, w: FontWeight.w900)),
              Text(why ?? 'Construa para atender mais pacientes e ganhar muito mais.', style: body(13.5, color: K.muted, w: FontWeight.w700)),
            ]))]),
            const SizedBox(height: 8),
            InfoRow('Renda por paciente', '\$${fmt(s.income(t, 1))}'),
            InfoRow('Tempo de atendimento', '${s.serviceTime(t, 1).toStringAsFixed(1)}s'),
            if (s.repNeed(t) > 0) InfoRow('Reputação necessária', '${s.repNeed(t).toInt()} (você: ${s.rep.floor()})'),
          ])),
          SizedBox(width: double.infinity, child: GBtn(enabled: s.canBuild(t), pulse: s.canBuild(t), onTap: () { if (s.buildRoom(id)) host.closePanel(); }, padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('CONSTRUIR  ', style: display(22)), Price(fmt(t.build), size: 22)]))),
        ]);
      }
      final l = s.lvlOf(id), tier = GameState.tier(l), nx = GameState.nextMs(l), max = l >= GameState.maxL;
      final prev = [0, 10, 20, 25, 30, 50, 75, 100].where((m) => m <= l).last;
      final eff = nx % 25 == 0 ? 'renda x2' : '+1 vaga';
      final m = s.activeMgr(id);
      return Column(children: [
        GCard(child: Column(children: [
          Row(children: [
            TweenAnimationBuilder<double>(key: ValueKey(l), tween: Tween(begin: 1.7, end: 1), duration: const Duration(milliseconds: 650), curve: Curves.elasticOut,
              builder: (_, v, c) => Transform.scale(scale: v, alignment: Alignment.centerLeft, child: c),
              child: Text('Nível $l', style: display(30, color: Color.lerp(K.ink, t.accent, 0.35)!, outline: false))),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Text(GameState.tierNames[tier], style: body(13, color: t.accent, w: FontWeight.w900))),
            const Spacer(),
            for (var k = 0; k < 3; k++) Opacity(opacity: k < tier ? 1 : 0.25, child: const Ico('star', size: 28)),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(tween: Tween(end: max ? 1 : (l - prev) / (nx - prev)), duration: const Duration(milliseconds: 450), curve: Curves.easeOutBack,
            builder: (_, v, __) => GBar(value: v, color: t.accent, height: 22, label: max ? 'MÁXIMO' : 'Nível $nx: $eff')),
          const SizedBox(height: 8),
          InfoRow('Renda por paciente', '\$${fmt(s.income(t, l))}', next: max ? null : '→ \$${fmt(s.income(t, l + 1))}'),
          InfoRow('Tempo de atendimento', '${s.serviceTime(t, l).toStringAsFixed(2)}s', next: max ? null : '→ ${s.serviceTime(t, l + 1).toStringAsFixed(2)}s'),
          InfoRow('Vagas simultâneas', '${GameState.slots(l)}/4'),
          InfoRow('Gerente', m == null ? 'nenhum' : '${m.name} (Nv ${s.mgr[m.id]})'),
        ])),
        if (!max) Row(children: [
          for (final n in [1, 10, -1]) ...[
            Expanded(child: Builder(builder: (_) {
              final (c, k) = s.upPreview(t, n);
              return GBtn(
                color: n < 0 ? K.purple : K.green, enabled: k > 0 && c <= s.money, pulse: s.tut == 2 && n == 1,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                onTap: () => s.upgradeRoom(id, n),
                child: Column(children: [Text(n < 0 ? 'MÁX +$k' : '+$k', style: display(20)), FittedBox(child: Price(fmt(c), size: 15))]),
              );
            })),
            if (n != -1) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Ico('bolt', size: 22), const SizedBox(width: 4), Text('Toque na sala para acelerar os atendimentos', style: body(12.5, color: K.muted))]),
      ]);
    }));
  }
}

// ======================================================= infraestrutura
Widget infraCard(GameState s, String k) {
  final lv = k == 'rl' ? s.rl : k == 'tl' ? s.tl : s.trl;
  final cost = k == 'rl' ? s.recCost : k == 'tl' ? s.traCost : s.treCost;
  final name = k == 'rl' ? 'Recepção' : k == 'tl' ? 'Transporte' : 'Cofre';
  final icon = k == 'rl' ? 'clock' : k == 'tl' ? 'person' : 'coin';
  final rows = k == 'rl'
      ? [InfoRow('Check-in', '${s.checkinTime.toStringAsFixed(2)}s'), InfoRow('Fila máxima', '${s.qmax} pacientes'), InfoRow('Chegada', 'a cada ${s.spawnInterval.toStringAsFixed(1)}s')]
      : k == 'tl'
          ? [InfoRow('Carregadores', '${s.carriers}/5', next: '+1 a cada 10 níveis'), InfoRow('Capacidade', '\$${fmt(s.carrierCap)}'), InfoRow('Velocidade', s.carrierSpeed.toStringAsFixed(2))]
          : [InfoRow('Capacidade', '\$${fmt(s.treMax)}'), InfoRow('Saldo', '\$${fmt(s.treasury)}'), InfoRow('Coleta automática', s.autoInterval.isFinite ? 'a cada ${s.autoInterval.toStringAsFixed(1)}s' : 'precisa de gerente')];
  return GCard(child: Column(children: [
    Row(children: [
      Ico(icon, size: 46), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: body(17, w: FontWeight.w900)), Text('Nível $lv', style: body(13, color: K.muted))])),
      GBtn(enabled: s.money >= cost && lv < GameState.maxI, onTap: () => s.infraUp(k), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: [const Ico('arrow', size: 22), const SizedBox(width: 2), Price(fmt(cost), size: 16)])),
    ]),
    const SizedBox(height: 6),
    ...rows,
  ]));
}

class _InfraPanel extends StatelessWidget {
  final GameState s; final PanelHost host; final String kind;
  const _InfraPanel({required this.s, required this.host, required this.kind});
  @override
  Widget build(BuildContext context) => Sheet(
        title: kind == 'rl' ? 'Recepção' : 'Cofre', icon: kind == 'rl' ? 'clock' : 'coin', color: kind == 'rl' ? const Color(0xFFE84A7F) : const Color(0xFFB98A4E), onClose: host.closePanel,
        child: _Live(s: s, builder: () => Column(children: [
          infraCard(s, kind),
          if (kind == 'trl') infraCard(s, 'tl'),
          GCard(color: const Color(0xFFFFF9EC), child: Text(kind == 'rl' ? 'Mais reputação traz mais pacientes. Com a fila cheia, pacientes vão embora e a reputação cai.' : 'Os carregadores levam o dinheiro das salas até o cofre. Cofre cheio trava o transporte: colete sempre!', style: body(13, color: K.muted, w: FontWeight.w700))),
        ])),
      );
}

// ======================================================= melhorias
class _UpgradesPanel extends StatelessWidget {
  final GameState s; final PanelHost host;
  const _UpgradesPanel({required this.s, required this.host});
  @override
  Widget build(BuildContext context) => Sheet(title: 'Melhorias', icon: 'arrow', color: K.green, onClose: host.closePanel, child: _Live(s: s, builder: () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Infraestrutura'),
        infraCard(s, 'rl'), infraCard(s, 'tl'), infraCard(s, 'trl'),
        const SectionTitle('Salas'),
        for (final t in roomTypes.where((t) => s.built(t.id) || t == s.nextRoom)) _roomRow(t),
        if (roomTypes.length - s.builtCount > 1) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text('+${roomTypes.length - s.builtCount - 1} salas misteriosas para descobrir', style: body(13, color: K.muted, w: FontWeight.w800))),
        const SectionTitle('Loja de ouro'),
        _shopRow('bolt', 'Renda x2 por 30 min', s.boostOn ? 'Ativo: ${fmtTime((s.gb - nowMs()) / 1000)} (acumula)' : 'Dobra toda a produção', 20, s.goldBoost),
        _shopRow('coin', 'Maleta de dinheiro', 'Vale 30 min de produção: \$${fmt(math.max(100.0, s.baseRate * 1800))}', 10, s.moneyPack),
      ])));
  Widget _roomRow(RoomType t) {
    final why = s.lockReason(t);
    Widget act; String sub;
    if (s.built(t.id)) {
      final l = s.lvlOf(t.id), c = s.upCost(t, l); sub = 'Nv $l • \$${fmt(s.income(t, l))} por paciente';
      act = GBtn(enabled: s.money >= c && l < GameState.maxL, onTap: () => s.upgradeRoom(t.id, 1), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: [const Ico('arrow', size: 20), Price(fmt(c), size: 15)]));
    } else if (why != null) { sub = why; act = const Ico('lock', size: 38); }
    else { sub = 'Pronto para construir'; act = GBtn(color: K.teal, enabled: s.money >= t.build, onTap: () { if (s.buildRoom(t.id)) host.closePanel(); }, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: [const Ico('hammer', size: 20), Price(fmt(t.build), size: 15)])); }
    return GCard(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)), child: Padding(padding: const EdgeInsets.all(3), child: Ico(_roomIcon[t.id] ?? 'cross'))),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(onTap: () => host.openPanel('room:${t.id}'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: body(16, w: FontWeight.w900)), Text(sub, style: body(12.5, color: K.muted, w: FontWeight.w700))]))),
      act,
    ]));
  }
  Widget _shopRow(String icon, String title, String sub, int price, VoidCallback buy) => GCard(child: Row(children: [
        Ico(icon, size: 46), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: body(16, w: FontWeight.w900)), Text(sub, style: body(12.5, color: K.muted, w: FontWeight.w700))])),
        GBtn(color: K.gold, enabled: s.gold >= price, onTap: buy, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Price('$price', icon: 'gem', size: 17)),
      ]));
}

// ======================================================= gerentes
class _ManagersPanel extends StatelessWidget {
  final GameState s; final PanelHost host;
  const _ManagersPanel({required this.s, required this.host});
  @override
  Widget build(BuildContext context) => Sheet(title: 'Gerentes', icon: 'person', color: K.blue, onClose: host.closePanel, child: _Live(s: s, builder: () => Column(children: [
        GCard(color: const Color(0xFFEAF2FF), child: Text('Gerentes aceleram setores até o nível 10. O do Cofre coleta sozinho e garante 100% dos ganhos offline. Os exclusivos vêm do desafio semanal.', style: body(13, color: K.muted, w: FontWeight.w700))),
        for (final m in managers) _card(m),
      ])));
  Widget _card(ManagerDef m) {
    final own = s.mgr.containsKey(m.id), l = s.mgr[m.id] ?? 0, active = s.activeMgr(m.area)?.id == m.id;
    Widget act;
    if (!own) { act = m.ex ? Text('Desafio\nsemanal', textAlign: TextAlign.center, style: body(12, color: K.muted)) : GBtn(color: K.gold, enabled: s.gold >= m.gold, onTap: () => s.hireMgr(m.id), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Column(children: [Text('Contratar', style: display(14)), Price('${m.gold}', icon: 'gem', size: 14)])); }
    else if (l >= GameState.maxM) { act = Text('MÁX', style: display(20, color: K.goldD, outline: false)); }
    else { final c = s.mgrUpCost(m, l); act = GBtn(color: K.purple, enabled: s.gold >= c, onTap: () => s.upMgr(m.id), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Column(children: [Text('Nv ${l + 1}', style: display(15)), Price('$c', icon: 'gem', size: 14)])); }
    final bonus = m.ex ? 1.5 + 0.15 * math.max(1, l) : 1 + 0.1 * math.max(1, l);
    return Opacity(opacity: !own && m.ex ? 0.6 : 1, child: GCard(color: m.ex ? const Color(0xFFFFF8E1) : null, child: Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: m.color.withValues(alpha: 0.2), border: Border.all(color: m.color, width: 3)), child: const Padding(padding: EdgeInsets.all(4), child: Ico('person'))),
        if (m.ex) const Positioned(right: -8, top: -8, child: Ico('star', size: 26)),
      ]),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.name, style: body(16, w: FontWeight.w900)),
        Text('${areaNames[m.area]} • ${m.desc}', style: body(12.5, color: K.muted, w: FontWeight.w700)),
        if (own) ...[
          const SizedBox(height: 4),
          Row(children: [for (var i = 1; i <= 10; i++) Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: i <= l ? m.color : const Color(0x22000000), borderRadius: BorderRadius.circular(3)))]),
          Text('x${bonus.toStringAsFixed(2)} • ${active ? 'ativo' : 'reserva'}', style: body(12, color: K.muted, w: FontWeight.w900)),
        ],
      ])),
      act,
    ])));
  }
}

// ======================================================= missões
class _MissionsPanel extends StatefulWidget {
  final GameState s; final PanelHost host;
  const _MissionsPanel({required this.s, required this.host});
  @override
  State<_MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends State<_MissionsPanel> {
  int tab = 0;
  GameState get s => widget.s;
  @override
  Widget build(BuildContext context) => Sheet(title: 'Missões', icon: 'target', color: K.red, onClose: widget.host.closePanel, child: _Live(s: s, builder: () {
        s.ensureDaily();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [for (final (i, t) in [(0, 'Diárias'), (1, 'Conquistas'), (2, 'Estatísticas')]) Expanded(child: GestureDetector(
            onTap: () { Sfx.click(); setState(() => tab = i); },
            child: AnimatedContainer(duration: const Duration(milliseconds: 160), margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: tab == i ? K.navy : const Color(0x14000000), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(t, style: tab == i ? display(15) : body(14, w: FontWeight.w900)))),
          ))]),
          const SizedBox(height: 10),
          ...(tab == 0 ? _daily() : tab == 1 ? _ach() : _stats()),
        ]);
      }));
  Widget _mc(String title, double pr, double tg, int gold, bool claimed, VoidCallback claim, {bool percent = false}) {
    final done = pr >= tg;
    return GCard(color: claimed ? const Color(0xFFEDEFF3) : done ? const Color(0xFFE6FBEC) : null, child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: body(14.5, w: FontWeight.w900)),
        const SizedBox(height: 6),
        GBar(value: pr / tg, height: 18, color: done ? K.green : K.gold, label: percent ? '${(pr * 100).clamp(0, 100).toInt()}%' : '${fmt(math.min(pr, tg))}/${fmt(tg)}'),
      ])),
      const SizedBox(width: 10),
      claimed ? const Ico('arrow', size: 34) : GBtn(color: K.gold, enabled: done, pulse: done, onTap: claim, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Price('$gold', icon: 'gem', size: 16)),
    ]));
  }
  List<Widget> _daily() {
    final now = DateTime.now(), mid = DateTime(now.year, now.month, now.day + 1), o = s.curObj;
    return [
      Center(child: Text('Novas missões em ${fmtTime(mid.difference(now).inSeconds.toDouble())}', style: body(12.5, color: K.muted))),
      const SizedBox(height: 8),
      for (var i = 0; i < s.di.length; i++) Builder(builder: (_) { final d = dailyById(s.di[i]), tg = s.dTarget(d); return _mc(d.desc.replaceAll('{n}', fmt(tg)), s.dProg(i), tg, d.gold, s.dc.contains(i), () => s.claimDaily(i)); }),
      if (o != null) ...[const SectionTitle('Objetivo atual'), _mc(o.$1, o.$2, 1, o.$3, false, s.claimObj, percent: true)],
    ];
  }
  List<Widget> _ach() {
    final list = [...achievements]..sort((a, b) { final ca = s.ach.contains(a.id) ? 1 : 0, cb = s.ach.contains(b.id) ? 1 : 0; if (ca != cb) return ca - cb; return (s.achDone(b) ? 1 : 0) - (s.achDone(a) ? 1 : 0); });
    return [for (final a in list) _mc('${a.name} — ${a.desc}', s.st(a.stat), a.target, a.gold, s.ach.contains(a.id), () => s.claimAch(a.id))];
  }
  List<Widget> _stats() => [GCard(child: Column(children: [
        InfoRow('Pacientes atendidos', fmt(s.st('patients'))), InfoRow('Dinheiro arrecadado', '\$${fmt(s.st('earned'))}'), InfoRow('Arrecadado nesta unidade', '\$${fmt(s.runEarned)}'),
        InfoRow('Renda estimada', '\$${fmt(s.rate)}/s'), InfoRow('Pacientes VIP', fmt(s.st('vip'))), InfoRow('Emergências salvas', fmt(s.st('emergencies'))),
        InfoRow('Pacientes que desistiram', fmt(s.st('turned'))), InfoRow('Inspeções (nota A)', '${fmt(s.st('inspections'))} (${fmt(s.st('inspectionsA'))})'),
        InfoRow('Melhorias compradas', fmt(s.st('upgrades'))), InfoRow('Presentes abertos', fmt(s.st('gifts'))), InfoRow('Toques de aceleração', fmt(s.st('taps'))),
        InfoRow('Nível do diretor', '${s.lvl} (renda +${(s.lvl - 1) * 2}%)'), InfoRow('Colecionáveis', '${s.cardsOwned.length}/12'), InfoRow('Tempo de jogo', fmtTime(s.st('play'))),
      ]))];
}

// ======================================================= expansão
class _ExpansionPanel extends StatefulWidget {
  final GameState s; final PanelHost host;
  const _ExpansionPanel({required this.s, required this.host});
  @override
  State<_ExpansionPanel> createState() => _ExpansionPanelState();
}

class _ExpansionPanelState extends State<_ExpansionPanel> {
  bool confirm = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Sheet(title: 'Expansão', icon: 'building', color: K.purple, onClose: widget.host.closePanel, child: _Live(s: s, builder: () {
      final n = s.builtCount, tot = roomTypes.length;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GCard(child: Row(children: [const Ico('building', size: 54), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(unitName(s.unit), style: display(22, color: K.ink, outline: false)), Text('Multiplicador permanente: x${s.prestigeMult.toStringAsFixed(2)}', style: body(13, color: K.muted))]))])),
        GCard(color: const Color(0xFFF4EEFF), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Próxima: ${unitName(s.unit + 1)}', style: body(17, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Complete o hospital construindo todas as salas.', style: body(13, color: K.muted)),
          const SizedBox(height: 6),
          GBar(value: n / tot, height: 24, color: K.purple, label: 'Salas $n / $tot'),
          const SizedBox(height: 10),
          for (final line in ['Renda permanente x${(1 + 0.75 * s.unit).toStringAsFixed(2)}', '+${s.presGold} ouro', 'Reputação exigida ${((1 - 1 / (1 + 0.6 * s.unit)) * 100).round()}% menor', 'Mantém gerentes, ouro, nível, colecionáveis e conquistas'])
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [const Ico('arrow', size: 18), const SizedBox(width: 4), Expanded(child: Text(line, style: body(13.5, w: FontWeight.w800)))])),
          const SizedBox(height: 4),
          Text('Reinicia dinheiro, salas e infraestrutura (mantém 25% da reputação).', style: body(12.5, color: K.red, w: FontWeight.w800)),
        ])),
        GBtn(color: confirm ? K.red : K.purple, enabled: s.canPrestige, padding: const EdgeInsets.symmetric(vertical: 12),
          onTap: () { if (confirm) { s.prestige(); Save.save(s); widget.host.closePanel(); } else { setState(() => confirm = true); Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() => confirm = false); }); } },
          child: Text(confirm ? 'TOQUE DE NOVO PARA CONFIRMAR' : s.canPrestige ? 'ABRIR NOVA UNIDADE' : 'Faltam ${tot - n} salas', style: display(19))),
      ]);
    }));
  }
}

// ======================================================= eventos
class _EventsPanel extends StatelessWidget {
  final GameState s; final PanelHost host;
  const _EventsPanel({required this.s, required this.host});
  @override
  Widget build(BuildContext context) => Sheet(title: 'Eventos', icon: 'gift', color: K.orange, onClose: host.closePanel, child: _Live(s: s, builder: () {
        s.ensureWeekly();
        final ev = weekly(), rw = managerById(ev.reward), days = 7 - (nowMs() ~/ 86400000) % 7;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GCard(color: ev.color.withValues(alpha: 0.12), child: Row(children: [const Ico('star', size: 46), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ev.name, style: body(17, w: FontWeight.w900)), Text('${ev.desc} • termina em $days dia(s)', style: body(12.5, color: K.muted, w: FontWeight.w700))]))])),
          GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Desafio da semana', style: body(17, w: FontWeight.w900)),
            Text('Atenda ${fmt(s.wTarget)} pacientes e ganhe o gerente exclusivo ${rw.name}', style: body(13, color: K.muted, w: FontWeight.w700)),
            const SizedBox(height: 8),
            GBar(value: s.wProg / s.wTarget, height: 20, color: ev.color, label: '${fmt(math.min(s.wProg, s.wTarget))}/${fmt(s.wTarget)}'),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: s.wc ? Text('Recebido!', style: body(14, color: K.greenD, w: FontWeight.w900)) : GBtn(color: K.gold, enabled: s.wProg >= s.wTarget, onTap: s.claimWeekly, child: const Text('Receber gerente'))),
          ])),
          GCard(child: Row(children: [const Ico('wheel', size: 50), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Roleta da sorte', style: body(17, w: FontWeight.w900)), Text(s.wheelFree ? 'Giro grátis disponível!' : 'Grátis em ${fmtTime((s.spinAt - nowMs()) / 1000)} • ou 10 ouro', style: body(12.5, color: K.muted, w: FontWeight.w700))])), GBtn(color: K.orange, pulse: s.wheelFree, onTap: host.openWheel, child: const Text('GIRAR'))])),
          GCard(child: Row(children: [const Ico('bolt', size: 50), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Plantão Relâmpago', style: body(17, w: FontWeight.w900)), Text('Renda x3 por 45s. Recarrega em 5 min.', style: body(12.5, color: K.muted, w: FontWeight.w700))])), GBtn(color: K.orange, enabled: s.plantaoReady, onTap: s.activatePlantao, child: Text(s.plantaoOn ? 'Ativo' : s.plantaoReady ? 'ATIVAR' : fmtTime((s.pc - nowMs()) / 1000)))])),
          SectionTitle('Colecionáveis ${s.cardsOwned.length}/12 • bônus x${s.cardsMult.toStringAsFixed(2)}'),
          for (var set = 0; set < 3; set++) Builder(builder: (_) {
            final cs = cards.where((c) => c.set == set).toList(), full = cs.every((c) => s.cardsOwned.contains(c.id));
            return GCard(color: full ? const Color(0xFFE6FBEC) : null, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cardSets[set], style: body(14, w: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [for (final c in cs) Expanded(child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: s.cardsOwned.contains(c.id) ? const Color(0xFFE3F2FF) : const Color(0xFFECEFF3), borderRadius: BorderRadius.circular(12), border: Border.all(color: s.cardsOwned.contains(c.id) ? K.blue : const Color(0x22000000), width: 2)),
                child: Column(children: [Opacity(opacity: s.cardsOwned.contains(c.id) ? 1 : 0.18, child: Ico(c.icon.substring(5), size: 40)), FittedBox(child: Text(s.cardsOwned.contains(c.id) ? c.name : '???', style: body(10.5, color: K.muted, w: FontWeight.w900)))]),
              ))]),
            ]));
          }),
        ]);
      }));
}

// ======================================================= ajustes
class _SettingsPanel extends StatefulWidget {
  final GameState s; final PanelHost host;
  const _SettingsPanel({required this.s, required this.host});
  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  bool confirm = false;
  Widget _toggle(String icon, String label, bool v, ValueChanged<bool> on) => GCard(padding: const EdgeInsets.fromLTRB(10, 6, 10, 6), child: Row(children: [
        Ico(icon, size: 38), const SizedBox(width: 10), Expanded(child: Text(label, style: body(16, w: FontWeight.w900))),
        GestureDetector(onTap: () { Sfx.click(); setState(() => on(!v)); Save.save(widget.s); }, child: AnimatedContainer(
          duration: const Duration(milliseconds: 160), width: 62, height: 34,
          decoration: BoxDecoration(color: v ? K.teal : const Color(0xFFC9CFDB), borderRadius: BorderRadius.circular(18), border: Border.all(color: K.navy, width: 2.5)),
          child: AnimatedAlign(duration: const Duration(milliseconds: 160), alignment: v ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.all(2), width: 26, height: 26, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: K.navy, width: 2)))),
        )),
      ]));
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Sheet(title: 'Ajustes', icon: 'gear', color: const Color(0xFF7F8BA6), onClose: widget.host.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _toggle('clock', 'Música', s.music, (v) { s.music = v; Sfx.music = v; v ? Sfx.startMusic() : Sfx.stopMusic(); }),
      _toggle('bolt', 'Efeitos sonoros', s.sound, (v) { s.sound = v; Sfx.sound = v; }),
      _toggle('heart', 'Vibração', s.vibration, (v) { s.vibration = v; Sfx.vibration = v; }),
      const SizedBox(height: 4),
      GBtn(color: K.teal, onTap: () { Save.save(s); widget.host.toast('Progresso salvo!'); }, child: const Text('Salvar agora')),
      const SizedBox(height: 10),
      GBtn(color: K.purple, onTap: () { s.tut = 0; widget.host.closePanel(); }, child: const Text('Rever tutorial')),
      const SizedBox(height: 10),
      GBtn(color: K.red, onTap: () async { if (confirm) { await Save.wipe(); widget.host.toast('Progresso apagado. Feche e abra o jogo.'); } else { setState(() => confirm = true); } }, child: Text(confirm ? 'TOQUE DE NOVO PARA APAGAR' : 'Apagar progresso')),
      const SizedBox(height: 14),
      Center(child: Text('Hospital Empire 1.0 • modelos 3D: Kenney (CC0)', style: body(12, color: K.muted))),
    ]));
  }
}
