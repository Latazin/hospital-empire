import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/services.dart';

/// Sprite pré-renderizado: imagem, recorte e âncora (ponto do mundo).
class Spr {
  final ui.Image img;
  final ui.Rect src;
  final double ax, ay;
  const Spr(this.img, this.src, this.ax, this.ay);
}

class BgTile {
  final ui.Image img;
  final double ax, ay;
  const BgTile(this.img, this.ax, this.ay);
}

/// Banco de arte: sprites renderizados em 3D e exportados pelo estúdio.
class Art {
  static final Map<String, Spr> spr = {};
  static final Map<String, Map<String, Map<String, Spr>>> chars = {};
  static final List<BgTile> bg = [];
  static final Map<String, ui.Image> icons = {};
  static bool ready = false;

  static Future<void> load(void Function(double) progress) async {
    final meta = jsonDecode(await rootBundle.loadString('assets/images/art/meta.json')) as Map<String, dynamic>;
    final sprites = (meta['sprites'] as Map<String, dynamic>);
    final bgs = (meta['bg'] as List);
    final pages = (meta['pages'] as List).cast<String>();
    final iconNames = ((meta['icons'] as List?) ?? []).cast<String>();
    final total = sprites.length + bgs.length + pages.length + iconNames.length;
    var done = 0;
    void tick() => progress(++done / total);
    await Future.wait([
      for (final e in sprites.entries)
        Flame.images.load('art/sprites/${e.key}.png').then((img) {
          final m = e.value as Map<String, dynamic>;
          spr[e.key] = Spr(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), (m['ax'] as num).toDouble(), (m['ay'] as num).toDouble());
          tick();
        }),
      for (final b in bgs)
        Flame.images.load('art/bg/${b['file']}').then((img) { bg.add(BgTile(img, (b['ax'] as num).toDouble(), (b['ay'] as num).toDouble())); tick(); }),
      for (final n in iconNames)
        Flame.images.load('art/icons/$n.png').then((img) { icons[n] = img; tick(); }),
    ]);
    final pageImgs = <ui.Image>[];
    for (final p in pages) { pageImgs.add(await Flame.images.load('art/chars/$p')); tick(); }
    final ch = meta['chars'] as Map<String, dynamic>;
    for (final v in ch.entries) {
      final dirs = <String, Map<String, Spr>>{};
      for (final d in (v.value as Map<String, dynamic>).entries) {
        final frames = <String, Spr>{};
        for (final f in (d.value as Map<String, dynamic>).entries) {
          final a = (f.value as List).map((e) => (e as num).toDouble()).toList();
          frames[f.key] = Spr(pageImgs[a[0].toInt()], ui.Rect.fromLTWH(a[1], a[2], a[3], a[4]), a[5], a[6]);
        }
        dirs[d.key] = frames;
      }
      chars[v.key] = dirs;
    }
    ready = true;
  }
}
