import 'package:flutter/foundation.dart';

@immutable
class LudoToken {
  /// -1: In Yard, 0-50: Main Board track, 51-55: Home Stretch, 56: Finished
  final int stepIndex;

  const LudoToken({required this.stepIndex});

  bool get isInYard => stepIndex == -1;
  bool get isHome => stepIndex >= 56;
  bool get isInHomeStretch => stepIndex >= 51 && stepIndex < 56;

  LudoToken copyWith({int? stepIndex}) =>
      LudoToken(stepIndex: stepIndex ?? this.stepIndex);

  Map<String, dynamic> toMap() => {'stepIndex': stepIndex};

  factory LudoToken.fromMap(dynamic val) {
    if (val is int) return LudoToken(stepIndex: val);
    if (val is Map) return LudoToken(stepIndex: (val['stepIndex'] as num?)?.toInt() ?? -1);
    return const LudoToken(stepIndex: -1);
  }
}

@immutable
class LudoGameState {
  final int currentTurnSeat;
  final int diceRoll;
  final bool hasRolled;
  final int consecutiveSixes;
  final int winnerSeat;
  final int turnDeadline;
  final Map<int, List<LudoToken>> playerTokens; // 0: Green, 1: Yellow, 2: Blue, 3: Red

  const LudoGameState({
    required this.currentTurnSeat,
    required this.diceRoll,
    required this.hasRolled,
    required this.consecutiveSixes,
    required this.winnerSeat,
    required this.turnDeadline,
    required this.playerTokens,
  });

  factory LudoGameState.initial() {
    return LudoGameState(
      currentTurnSeat: 0,
      diceRoll: 0,
      hasRolled: false,
      consecutiveSixes: 0,
      winnerSeat: -1,
      turnDeadline: 0,
      playerTokens: {
        for (int i = 0; i < 4; i++)
          i: List.generate(4, (_) => const LudoToken(stepIndex: -1)),
      },
    );
  }

  LudoGameState copyWith({
    int? currentTurnSeat,
    int? diceRoll,
    bool? hasRolled,
    int? consecutiveSixes,
    int? winnerSeat,
    int? turnDeadline,
    Map<int, List<LudoToken>>? playerTokens,
  }) {
    return LudoGameState(
      currentTurnSeat: currentTurnSeat ?? this.currentTurnSeat,
      diceRoll: diceRoll ?? this.diceRoll,
      hasRolled: hasRolled ?? this.hasRolled,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      winnerSeat: winnerSeat ?? this.winnerSeat,
      turnDeadline: turnDeadline ?? this.turnDeadline,
      playerTokens: playerTokens ?? this.playerTokens,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'turnState': {
        'currentTurnSeat': currentTurnSeat,
        'diceRoll': diceRoll,
        'hasRolled': hasRolled,
        'consecutiveSixes': consecutiveSixes,
        'winnerSeat': winnerSeat,
        'turnDeadline': turnDeadline,
      },
      'ludoData': {
        'tokens': playerTokens.map(
          (seat, tokens) => MapEntry(
            seat.toString(),
            tokens.map((t) => t.stepIndex).toList(),
          ),
        ),
      },
    };
  }

  factory LudoGameState.fromRTDB(Map<dynamic, dynamic> data) {
    final turnMap = data['turnState'] as Map<dynamic, dynamic>? ?? {};
    final ludoData = data['ludoData'] as Map<dynamic, dynamic>? ?? {};
    final tokensMapRaw = ludoData['tokens'] as Map<dynamic, dynamic>? ?? {};

    final Map<int, List<LudoToken>> parsedTokens = {};
    for (int i = 0; i < 4; i++) {
      final listRaw = tokensMapRaw[i.toString()] as List<dynamic>?;
      if (listRaw != null) {
        parsedTokens[i] = listRaw.map((v) => LudoToken.fromMap(v)).toList();
      } else {
        parsedTokens[i] = List.generate(4, (_) => const LudoToken(stepIndex: -1));
      }
    }

    return LudoGameState(
      currentTurnSeat: (turnMap['currentTurnSeat'] as num?)?.toInt() ?? 0,
      diceRoll: (turnMap['diceRoll'] as num?)?.toInt() ?? 0,
      hasRolled: turnMap['hasRolled'] as bool? ?? false,
      consecutiveSixes: (turnMap['consecutiveSixes'] as num?)?.toInt() ?? 0,
      winnerSeat: (turnMap['winnerSeat'] as num?)?.toInt() ?? -1,
      turnDeadline: (turnMap['turnDeadline'] as num?)?.toInt() ?? 0,
      playerTokens: parsedTokens,
    );
  }
}

