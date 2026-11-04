import 'package:flutter_test/flutter_test.dart';
import 'package:mini_arcade_hub/features/games/ludo/domain/ludo_game_state.dart';
import 'package:mini_arcade_hub/features/games/ludo/domain/ludo_rules_engine.dart';

void main() {
  group('LudoRulesEngine Tests', () {
    test('Token in yard can ONLY move if roll is 6', () {
      const yardToken = LudoToken(stepIndex: -1);

      expect(LudoRulesEngine.canTokenMove(yardToken, 1), isFalse);
      expect(LudoRulesEngine.canTokenMove(yardToken, 5), isFalse);
      expect(LudoRulesEngine.canTokenMove(yardToken, 6), isTrue);
    });

    test('Token on track can advance up to step 56 (Home)', () {
      const tokenAt50 = LudoToken(stepIndex: 50);
      expect(LudoRulesEngine.canTokenMove(tokenAt50, 4), isTrue);
      expect(LudoRulesEngine.canTokenMove(tokenAt50, 6), isTrue); // reaches 56

      const tokenAt53 = LudoToken(stepIndex: 53);
      expect(LudoRulesEngine.canTokenMove(tokenAt53, 3), isTrue); // reaches 56
      expect(LudoRulesEngine.canTokenMove(tokenAt53, 4), isFalse); // exceeds 56
    });

    test('Finished home token cannot move', () {
      const homeToken = LudoToken(stepIndex: 56);
      expect(LudoRulesEngine.canTokenMove(homeToken, 1), isFalse);
      expect(LudoRulesEngine.canTokenMove(homeToken, 6), isFalse);
    });

    test('Global board tile offsets are distinct per seat', () {
      // Seat 0 (Green) enters board at tile 0
      expect(LudoRulesEngine.getGlobalBoardTile(0, 0), equals(0));
      // Seat 1 (Yellow) enters board at tile 13
      expect(LudoRulesEngine.getGlobalBoardTile(1, 0), equals(13));
      // Seat 2 (Blue) enters board at tile 26
      expect(LudoRulesEngine.getGlobalBoardTile(2, 0), equals(26));
      // Seat 3 (Red) enters board at tile 39
      expect(LudoRulesEngine.getGlobalBoardTile(3, 0), equals(39));
    });

    test('Safe tiles set contains 0, 8, 13, 21, 26, 34, 39, 47', () {
      expect(LudoRulesEngine.safeRelativeTiles.contains(0), isTrue);
      expect(LudoRulesEngine.safeRelativeTiles.contains(8), isTrue);
      expect(LudoRulesEngine.safeRelativeTiles.contains(5), isFalse);
    });
  });
}

