import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../domain/ludo_game_state.dart';
import '../domain/ludo_rules_engine.dart';

class LudoParams {
  final String roomId;
  final bool isSolo;

  const LudoParams({required this.roomId, this.isSolo = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LudoParams &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          isSolo == other.isSolo;

  @override
  int get hashCode => roomId.hashCode ^ isSolo.hashCode;
}

final ludoControllerProvider = StateNotifierProvider.autoDispose
    .family<LudoController, AsyncValue<LudoGameState>, LudoParams>((ref, params) {
  String? uid;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {}
  final controller = LudoController(params.roomId, uid, isSolo: params.isSolo);
  ref.onDispose(() => controller.disposeController());
  return controller;
});

class LudoController extends StateNotifier<AsyncValue<LudoGameState>> {
  final String roomId;
  final String? localUid;
  final bool isSolo;
  StreamSubscription<Map<String, dynamic>?>? _roomSubscription;
  Timer? _turnTimer;
  Timer? _botTimer;

  LudoGameState _localState = LudoGameState.initial();

  LudoController(this.roomId, this.localUid, {this.isSolo = false})
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  void _initialize() {
    if (isSolo || roomId == 'solo') {
      _fallbackLocal();
      return;
    }

    _roomSubscription = MultiplayerSyncService.watchGameState(roomId).listen(
      (data) {
        if (data == null) {
          state = AsyncValue.data(LudoGameState.initial());
          return;
        }
        final newState = LudoGameState.fromRTDB(data);
        state = AsyncValue.data(newState);
        _evaluateTurnTimeout(newState);
      },
      onError: (err, stack) {
        _fallbackLocal();
      },
    );
  }

  void _fallbackLocal() {
    _localState = LudoGameState.initial().copyWith(
      turnDeadline: DateTime.now().millisecondsSinceEpoch + 15000,
    );
    state = AsyncValue.data(_localState);
  }

  void _evaluateTurnTimeout(LudoGameState gameState) {
    _turnTimer?.cancel();
    if (gameState.winnerSeat != -1) return;

    if (isSolo) {
      if (gameState.currentTurnSeat != 0) {
        _triggerBotTurn(gameState);
      }
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = gameState.turnDeadline - now;

    if (remaining <= 0 && gameState.turnDeadline > 0) {
      _autoPassTurn();
    } else if (remaining > 0) {
      _turnTimer = Timer(Duration(milliseconds: remaining), () {
        _autoPassTurn();
      });
    }
  }

  // Fast, snappy bot turns for great player UX
  void _triggerBotTurn(LudoGameState gameState) {
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 250), () async {
      final current = state.valueOrNull;
      if (current == null || current.currentTurnSeat == 0 || current.winnerSeat != -1) return;

      final botSeat = current.currentTurnSeat;

      if (!current.hasRolled) {
        await rollDice(botSeat);
        _botTimer = Timer(const Duration(milliseconds: 220), () async {
          final afterRoll = state.valueOrNull;
          if (afterRoll == null || afterRoll.currentTurnSeat != botSeat || !afterRoll.hasRolled) return;

          final tokens = afterRoll.playerTokens[botSeat]!;
          final roll = afterRoll.diceRoll;

          int bestIndex = -1;

          // 1. Prioritize exiting yard on 6
          if (roll == 6) {
            for (int i = 0; i < tokens.length; i++) {
              if (tokens[i].isInYard) {
                bestIndex = i;
                break;
              }
            }
          }

          // 2. Prioritize advancing active tokens
          if (bestIndex == -1) {
            for (int i = 0; i < tokens.length; i++) {
              if (LudoRulesEngine.canTokenMove(tokens[i], roll)) {
                bestIndex = i;
                break;
              }
            }
          }

          if (bestIndex != -1) {
            await moveToken(playerSeat: botSeat, tokenIndex: bestIndex);
          }
        });
      }
    });
  }

  Future<void> rollDice(int playerSeat) async {
    final current = state.valueOrNull;
    if (current == null || current.currentTurnSeat != playerSeat || current.hasRolled) return;

    final roll = Random().nextInt(6) + 1;
    final int consecutive = (roll == 6) ? current.consecutiveSixes + 1 : 0;

    if (consecutive >= 3) {
      await _commitUpdate({
        'turnState/diceRoll': 6,
        'turnState/hasRolled': false,
        'turnState/consecutiveSixes': 0,
        'turnState/currentTurnSeat': (current.currentTurnSeat + 1) % 4,
        'turnState/turnDeadline': DateTime.now().millisecondsSinceEpoch + 15000,
      }, current.copyWith(
        diceRoll: 6,
        hasRolled: false,
        consecutiveSixes: 0,
        currentTurnSeat: (current.currentTurnSeat + 1) % 4,
        turnDeadline: DateTime.now().millisecondsSinceEpoch + 15000,
      ));
      return;
    }

    final tokens = current.playerTokens[playerSeat]!;
    final bool canMove = LudoRulesEngine.hasAnyValidMove(tokens, roll);

    final updates = <String, dynamic>{
      'turnState/diceRoll': roll,
      'turnState/hasRolled': true,
      'turnState/consecutiveSixes': consecutive,
    };

    var updatedState = current.copyWith(
      diceRoll: roll,
      hasRolled: true,
      consecutiveSixes: consecutive,
    );

    if (!canMove) {
      updates['turnState/hasRolled'] = false;
      updates['turnState/consecutiveSixes'] = 0;
      updates['turnState/currentTurnSeat'] = (current.currentTurnSeat + 1) % 4;
      updates['turnState/turnDeadline'] = DateTime.now().millisecondsSinceEpoch + 15000;

      updatedState = updatedState.copyWith(
        hasRolled: false,
        consecutiveSixes: 0,
        currentTurnSeat: (current.currentTurnSeat + 1) % 4,
        turnDeadline: DateTime.now().millisecondsSinceEpoch + 15000,
      );
    }

    await _commitUpdate(updates, updatedState);
  }

  Future<void> moveToken({required int playerSeat, required int tokenIndex}) async {
    final current = state.valueOrNull;
    if (current == null || current.currentTurnSeat != playerSeat || !current.hasRolled) return;

    final tokens = List<LudoToken>.from(current.playerTokens[playerSeat]!);
    final targetToken = tokens[tokenIndex];
    final roll = current.diceRoll;

    if (!LudoRulesEngine.canTokenMove(targetToken, roll)) return;

    int newStep = targetToken.isInYard ? 0 : targetToken.stepIndex + roll;
    tokens[tokenIndex] = targetToken.copyWith(stepIndex: newStep);

    final updatedTokensMap = Map<int, List<LudoToken>>.from(current.playerTokens);
    updatedTokensMap[playerSeat] = tokens;

    // Check Capture
    bool didCapture = false;
    if (newStep <= 50) {
      final landingGlobal = LudoRulesEngine.getGlobalBoardTile(playerSeat, newStep);
      final isSafe = LudoRulesEngine.safeRelativeTiles.contains(newStep);

      if (!isSafe) {
        for (int otherSeat = 0; otherSeat < 4; otherSeat++) {
          if (otherSeat == playerSeat) continue;
          final opponentTokens = List<LudoToken>.from(updatedTokensMap[otherSeat]!);

          for (int t = 0; t < opponentTokens.length; t++) {
            final opToken = opponentTokens[t];
            if (opToken.isInYard || opToken.isHome || opToken.stepIndex > 50) continue;
            final opGlobal = LudoRulesEngine.getGlobalBoardTile(otherSeat, opToken.stepIndex);

            if (opGlobal == landingGlobal) {
              opponentTokens[t] = const LudoToken(stepIndex: -1);
              didCapture = true;
            }
          }
          updatedTokensMap[otherSeat] = opponentTokens;
        }
      }
    }

    final bool isWinner = tokens.every((t) => t.isHome);
    final int nextSeat = (roll == 6 || didCapture)
        ? playerSeat
        : (current.currentTurnSeat + 1) % 4;

    final updates = <String, dynamic>{
      'turnState/currentTurnSeat': isWinner ? -1 : nextSeat,
      'turnState/diceRoll': 0,
      'turnState/hasRolled': false,
      'turnState/consecutiveSixes': (roll == 6 && !didCapture) ? current.consecutiveSixes : 0,
      'turnState/winnerSeat': isWinner ? playerSeat : -1,
      'turnState/turnDeadline': DateTime.now().millisecondsSinceEpoch + 15000,
      'ludoData/tokens': updatedTokensMap.map(
        (seat, tList) => MapEntry(
          seat.toString(),
          tList.map((tk) => tk.stepIndex).toList(),
        ),
      ),
    };

    final newState = current.copyWith(
      currentTurnSeat: isWinner ? -1 : nextSeat,
      diceRoll: 0,
      hasRolled: false,
      consecutiveSixes: (roll == 6 && !didCapture) ? current.consecutiveSixes : 0,
      winnerSeat: isWinner ? playerSeat : -1,
      turnDeadline: DateTime.now().millisecondsSinceEpoch + 15000,
      playerTokens: updatedTokensMap,
    );

    await _commitUpdate(updates, newState);
  }

  Future<void> _autoPassTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.winnerSeat != -1) return;

    final nextSeat = (current.currentTurnSeat + 1) % 4;
    final updates = {
      'turnState/currentTurnSeat': nextSeat,
      'turnState/diceRoll': 0,
      'turnState/hasRolled': false,
      'turnState/consecutiveSixes': 0,
      'turnState/turnDeadline': DateTime.now().millisecondsSinceEpoch + 15000,
    };

    final newState = current.copyWith(
      currentTurnSeat: nextSeat,
      diceRoll: 0,
      hasRolled: false,
      consecutiveSixes: 0,
      turnDeadline: DateTime.now().millisecondsSinceEpoch + 15000,
    );

    await _commitUpdate(updates, newState);
  }

  Future<void> _commitUpdate(Map<String, dynamic> updates, LudoGameState localFallback) async {
    if (!isSolo && roomId != 'solo') {
      MultiplayerSyncService.updateGameState(roomId, localFallback.toMap());
    }
    _localState = localFallback;
    state = AsyncValue.data(_localState);
    _evaluateTurnTimeout(_localState);
  }

  void disposeController() {
    _turnTimer?.cancel();
    _botTimer?.cancel();
    _roomSubscription?.cancel();
  }
}
