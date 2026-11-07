import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_empire/core/data.dart';
import 'package:hospital_empire/core/format.dart';
import 'package:hospital_empire/core/state.dart';

void main() {
  test('formatação', () { expect(fmt(999), '999'); expect(fmt(1500), '1.50K'); });
  test('começa com o Consultório', () { final s = GameState(); expect(s.built('consultorio'), isTrue); expect(s.built('laboratorio'), isFalse); });
  test('melhoria gasta dinheiro', () { final s = GameState()..money = 1000; expect(s.upgradeRoom('consultorio', 1), isTrue); expect(s.lvlOf('consultorio'), 2); expect(s.money, lessThan(1000)); });
  test('laboratório exige reputação', () { final s = GameState()..money = 1e9; expect(s.buildRoom('laboratorio'), isFalse); s.rep = 100; expect(s.buildRoom('laboratorio'), isTrue); });
  test('cofre e coleta', () { final s = GameState()..treasury = 200; final v = s.collect(); expect(v, 200); expect(s.treasury, 0); });
  test('salvar e carregar', () {
    final s = GameState()..money = 1234..gold = 77..unit = 2; s.rooms['consultorio']!.l = 15;
    final c = GameState()..loadJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(c.money, 1234); expect(c.gold, 77); expect(c.unit, 2); expect(c.lvlOf('consultorio'), 15);
  });
  test('vagas e marcos', () { expect(GameState.slots(1), 1); expect(GameState.slots(10), 2); final s = GameState(); final t = roomById('consultorio'); expect(s.income(t, 25) / s.income(t, 24), greaterThan(2)); });
  test('offline limitado a 8h', () { final s = GameState(); expect(s.offlineFor(8 * 3600), closeTo(s.offlineFor(30 * 3600), 1e-6)); });
  test('roleta sorteia prêmio válido', () { final s = GameState(); final i = s.spinWheel(); expect(i, isNotNull); expect(i! >= 0 && i < wheelPrizes.length, isTrue); });
}
