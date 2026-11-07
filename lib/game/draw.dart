import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

/// Projeção isométrica 2:1 e primitivas de desenho (caixas, pisos, cilindros).
class Iso {
  static const double tw = 64, th = 32;
  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0x40000000);

  static Offset p(double gx, double gy, [double h = 0]) =>
      Offset((gx - gy) * tw / 2, (gx + gy) * th / 2 - h);

  static Vector2 toGrid(double sx, double sy) {
    final a = sx / (tw / 2);
    final b = sy / (th / 2);
    return Vector2((a + b) / 2, (b - a) / 2);
  }

  static Color shade(Color c, double f) => f < 0
      ? Color.lerp(c, const Color(0xFF000000), -f)!
      : Color.lerp(c, const Color(0xFFFFFFFF), f)!;

  static void poly(Canvas c, List<Offset> pts, Color col, {bool outline = false}) {
    final path = Path()..addPolygon(pts, true);
    _fill.color = col;
    c.drawPath(path, _fill);
    if (outline) c.drawPath(path, _line);
  }

  static void floor(Canvas c, double x, double y, double w, double d, Color col,
          {double z = 0, bool outline = false}) =>
      poly(c, [p(x, y, z), p(x + w, y, z), p(x + w, y + d, z), p(x, y + d, z)], col,
          outline: outline);

  /// Caixa isométrica com 3 faces visíveis (topo, esquerda, direita).
  static void box(Canvas c, double x, double y, double w, double d, double h, Color col,
      {double z = 0, Color? top, bool outline = true}) {
    final a1 = p(x, y, z + h), b1 = p(x + w, y, z + h);
    final c1 = p(x + w, y + d, z + h), d1 = p(x, y + d, z + h);
    final b0 = p(x + w, y, z), c0 = p(x + w, y + d, z), d0 = p(x, y + d, z);
    poly(c, [d0, c0, c1, d1], shade(col, -0.08), outline: outline);
    poly(c, [b0, c0, c1, b1], shade(col, -0.24), outline: outline);
    poly(c, [a1, b1, c1, d1], top ?? shade(col, 0.15), outline: outline);
  }

  /// Retângulo pintado na face de uma parede que corre no eixo X (y fixo).
  static void faceX(Canvas c, double x0, double x1, double y, double z0, double z1, Color col) =>
      poly(c, [p(x0, y, z0), p(x1, y, z0), p(x1, y, z1), p(x0, y, z1)], col);

  /// Retângulo pintado na face de uma parede que corre no eixo Y (x fixo).
  static void faceY(Canvas c, double y0, double y1, double x, double z0, double z1, Color col) =>
      poly(c, [p(x, y0, z0), p(x, y1, z0), p(x, y1, z1), p(x, y0, z1)], col);

  static void ellipse(Canvas c, Offset center, double w, double h, Color col) {
    _fill.color = col;
    c.drawOval(Rect.fromCenter(center: center, width: w, height: h), _fill);
  }

  static void circle(Canvas c, Offset center, double r, Color col) {
    _fill.color = col;
    c.drawCircle(center, r, _fill);
  }

  static void rrect(Canvas c, Rect r, double radius, Color col) {
    _fill.color = col;
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), _fill);
  }

  /// Cilindro em pé (moedas, vasos, troncos).
  static void cylinder(Canvas c, double gx, double gy, double r, double h, Color col,
      {double z = 0}) {
    final base = p(gx, gy, z);
    final topC = p(gx, gy, z + h);
    final w = r * tw, eh = r * th;
    _fill.color = shade(col, -0.2);
    c.drawRect(Rect.fromLTRB(base.dx - w / 2, topC.dy, base.dx + w / 2, base.dy), _fill);
    ellipse(c, base, w, eh, shade(col, -0.2));
    ellipse(c, topC, w, eh, shade(col, 0.15));
  }

  /// Transformação para "pintar" texto numa parede do eixo X.
  static void paintOnWallX(Canvas c, Offset origin, void Function(Canvas c) draw) {
    c.save();
    c.transform(Float64List.fromList([
      1, 0.5, 0, 0, //
      0, 1, 0, 0, //
      0, 0, 1, 0, //
      origin.dx, origin.dy, 0, 1,
    ]));
    draw(c);
    c.restore();
  }
}

ui.Picture recordPicture(void Function(Canvas c) draw) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  draw(c);
  return rec.endRecording();
}

/// Cache de textos para não refazer layout a cada frame.
class TextCache {
  static final Map<String, TextPainter> _m = {};

  static TextPainter get(String text, double size, Color color, {Color? stroke}) {
    final key = '$text|$size|${color.hashCode}|${stroke?.hashCode}';
    var tp = _m[key];
    if (tp == null) {
      if (_m.length > 300) _m.clear();
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w900,
            height: 1.0,
            shadows: stroke == null
                ? null
                : [
                    Shadow(color: stroke, offset: const Offset(0, 1.6)),
                    Shadow(color: stroke, offset: const Offset(1.2, 0)),
                    Shadow(color: stroke, offset: const Offset(-1.2, 0)),
                    Shadow(color: stroke, offset: const Offset(0, -1.2)),
                  ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _m[key] = tp;
    }
    return tp;
  }

  static void draw(Canvas c, String text, Offset center, double size, Color color,
      {Color? stroke}) {
    final tp = get(text, size, color, stroke: stroke);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Etiqueta em "pílula" (placas das salas, balões de dinheiro).
  static void pill(Canvas c, String text, Offset center, double size, Color bg, Color fg,
      {Color border = const Color(0xFF23314D)}) {
    final tp = get(text, size, fg);
    final r = Rect.fromCenter(
        center: center, width: tp.width + size * 1.2, height: tp.height + size * 0.6);
    Iso.rrect(c, r.inflate(2), r.height, border);
    Iso.rrect(c, r, r.height, bg);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }
}
