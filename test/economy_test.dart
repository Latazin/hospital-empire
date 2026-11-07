import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_empire/core/economy.dart';
import 'package:hospital_empire/core/format.dart';
import 'package:hospital_empire/core/game_state.dart';
import 'package:hospital_empire/core/models.dart';

void main() {
  test('formatação de números', () {
    expect(fmt(999), '999');
    expect(fmt(1500), '1.50K');
    expect(fmt(2500000), '2.50M');
  });

  test('novo jogo começa com o Consultório construído', () {
    final s = GameState();
    expect(s.room('consultorio').built, isTrue);
    expect(s.room('laboratorio').built, isFalse);
  });

  test('melhoria gasta dinheiro e sobe o nível', () {
    final s = GameState()..money = 1000;
    final t = roomById('consultorio');
    expect(s.upgradeRoom(t, 1), isTrue);
    expect(s.room('consultorio').level, 2);
    expect(s.money, lessThan(1000));
  });

  test('laboratório exige reputação', () {
    final s = GameState()..money = 1e9;
    final lab = roomById('laboratorio');
    expect(s.buildRoom(lab), isFalse);
    s.rep = 100;
    expect(s.buildRoom(lab), isTrue);
  });

  test('tesouraria respeita o limite', () {
    final s = GameState();
    final max = Eco.treasuryMax(s);
    final d = s.deposit(max * 3);
    expect(d, closeTo(max, 0.001));
    expect(s.collect(), closeTo(max, 0.001));
    expect(s.treasury, 0);
  });

  test('salvar e carregar preserva o progresso', () {
    final s = GameState()
      ..money = 1234
      ..gold = 77
      ..unit = 2;
    s.room('consultorio').level = 15;
    final copy = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(copy.money, 1234);
    expect(copy.gold, 77);
    expect(copy.unit, 2);
    expect(copy.room('consultorio').level, 15);
  });

  test('vagas e marcos de renda', () {
    expect(Eco.roomSlots(1), 1);
    expect(Eco.roomSlots(10), 2);
    expect(Eco.roomSlots(45), 4);
    final s = GameState();
    final t = roomById('consultorio');
    expect(Eco.roomIncome(s, t, 25) / Eco.roomIncome(s, t, 24), greaterThan(2));
  });

  test('ganhos offline limitados a 8 horas', () {
    final s = GameState();
    final a = Eco.offlineEarnings(s, 8 * 3600);
    final b = Eco.offlineEarnings(s, 30 * 3600);
    expect(a, closeTo(b, 0.0001));
  });
}
