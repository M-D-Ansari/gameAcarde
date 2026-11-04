import 'ludo_game_state.dart';

class LudoRulesEngine {
  // Safe relative tile steps where tokens cannot be captured
  static const Set<int> safeRelativeTiles = {0, 8, 13, 21, 26, 34, 39, 47};

  // Convert player's relative track index (0..50) to the shared 52-tile board coordinate
  static int getGlobalBoardTile(int seatIndex, int stepIndex) {
    if (stepIndex < 0 || stepIndex > 50) return -1;
    final int baseOffset = seatIndex * 13;
    return (baseOffset + stepIndex) % 52;
  }

  static bool canTokenMove(LudoToken token, int diceRoll) {
    if (diceRoll <= 0 || diceRoll > 6) return false;
    if (token.isInYard) return diceRoll == 6;
    if (token.isHome) return false;
    return (token.stepIndex + diceRoll) <= 56;
  }

  static bool hasAnyValidMove(List<LudoToken> tokens, int diceRoll) {
    return tokens.any((t) => canTokenMove(t, diceRoll));
  }
}

