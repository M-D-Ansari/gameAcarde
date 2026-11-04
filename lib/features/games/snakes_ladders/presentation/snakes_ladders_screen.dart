import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';

class SnakesLaddersState {
  final Map<int, int> playerPositions; // Seat (0..3) -> Board Cell (1..100)
  final int currentTurnSeat;
  final int diceRoll;
  final int winnerSeat;
  final String lastEventMessage;

  const SnakesLaddersState({
    required this.playerPositions,
    required this.currentTurnSeat,
    required this.diceRoll,
    required this.winnerSeat,
    required this.lastEventMessage,
  });

  factory SnakesLaddersState.initial() => const SnakesLaddersState(
        playerPositions: {0: 1, 1: 1, 2: 1, 3: 1},
        currentTurnSeat: 0,
        diceRoll: 0,
        winnerSeat: -1,
        lastEventMessage: 'Roll the dice to begin!',
      );

  Map<String, dynamic> toMap() => {
        'positions': playerPositions.map((k, v) => MapEntry(k.toString(), v)),
        'currentTurnSeat': currentTurnSeat,
        'diceRoll': diceRoll,
        'winnerSeat': winnerSeat,
        'lastEvent': lastEventMessage,
      };

  factory SnakesLaddersState.fromMap(Map<dynamic, dynamic> map) {
    final posRaw = map['positions'] as Map<dynamic, dynamic>? ?? {};
    final Map<int, int> pos = {};
    for (int i = 0; i < 4; i++) {
      pos[i] = (posRaw[i.toString()] as num?)?.toInt() ?? 1;
    }
    return SnakesLaddersState(
      playerPositions: pos,
      currentTurnSeat: (map['currentTurnSeat'] as num?)?.toInt() ?? 0,
      diceRoll: (map['diceRoll'] as num?)?.toInt() ?? 0,
      winnerSeat: (map['winnerSeat'] as num?)?.toInt() ?? -1,
      lastEventMessage: map['lastEvent'] as String? ?? '',
    );
  }
}

class SnakesLaddersParams {
  final String roomId;
  final bool isSolo;

  const SnakesLaddersParams({required this.roomId, this.isSolo = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnakesLaddersParams &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          isSolo == other.isSolo;

  @override
  int get hashCode => roomId.hashCode ^ isSolo.hashCode;
}

final snakesLaddersProvider = StateNotifierProvider.autoDispose
    .family<SnakesLaddersController, SnakesLaddersState, SnakesLaddersParams>(
        (ref, params) {
  final controller =
      SnakesLaddersController(params.roomId, isSolo: params.isSolo);
  ref.onDispose(() => controller.dispose());
  return controller;
});

class SnakesLaddersController extends StateNotifier<SnakesLaddersState> {
  final String roomId;
  final bool isSolo;
  StreamSubscription<Map<String, dynamic>?>? _sub;
  Timer? _botTimer;

  static const Map<int, int> snakes = {
    99: 54,
    87: 24,
    62: 18,
    55: 26,
    43: 17,
    34: 12,
    17: 7,
  };

  static const Map<int, int> ladders = {
    4: 14,
    9: 31,
    20: 38,
    28: 84,
    40: 59,
    51: 67,
    63: 81,
    71: 91,
  };

  SnakesLaddersController(this.roomId, {this.isSolo = false})
      : super(SnakesLaddersState.initial()) {
    if (!isSolo && roomId != 'solo') {
      _sub = MultiplayerSyncService.watchGameState(roomId).listen((data) {
        if (data != null) {
          state = SnakesLaddersState.fromMap(data);
        }
      });
    }
  }

  void rollDice(int seat) {
    if (state.winnerSeat != -1 || state.currentTurnSeat != seat) return;

    final roll = Random().nextInt(6) + 1;
    final currentPos = state.playerPositions[seat] ?? 1;
    int target = currentPos + roll;
    String message = 'P${seat + 1} rolled a $roll!';

    if (target > 100) {
      target = currentPos; // Exact roll to reach 100
      message = 'P${seat + 1} needs an exact roll to reach 100!';
    } else if (target == 100) {
      message = 'P${seat + 1} REACHED 100 AND WON!';
    } else if (snakes.containsKey(target)) {
      final dropTo = snakes[target]!;
      message =
          'P${seat + 1} bitten by a snake at $target! Dropped to $dropTo.';
      target = dropTo;
    } else if (ladders.containsKey(target)) {
      final climbTo = ladders[target]!;
      message =
          'P${seat + 1} climbed a ladder at $target! Climbed to $climbTo.';
      target = climbTo;
    }

    final updatedPositions = Map<int, int>.from(state.playerPositions);
    updatedPositions[seat] = target;

    final int winner = target == 100 ? seat : -1;
    final int nextSeat =
        winner == -1 ? (roll == 6 ? seat : (seat + 1) % (isSolo ? 2 : 4)) : -1;

    final newState = SnakesLaddersState(
      playerPositions: updatedPositions,
      currentTurnSeat: nextSeat,
      diceRoll: roll,
      winnerSeat: winner,
      lastEventMessage: message,
    );

    state = newState;
    if (!isSolo && roomId != 'solo') {
      MultiplayerSyncService.updateGameState(roomId, newState.toMap());
    }

    // Solo Mode Bot Turn
    if (isSolo && winner == -1 && nextSeat != 0) {
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 700), () {
        rollDice(nextSeat);
      });
    }
  }

  void reset() {
    state = SnakesLaddersState.initial();
    if (!isSolo && roomId != 'solo') {
      MultiplayerSyncService.updateGameState(roomId, state.toMap());
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

class SnakesLaddersScreen extends ConsumerWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const SnakesLaddersScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = SnakesLaddersParams(roomId: roomId, isSolo: isSolo);
    final game = ref.watch(snakesLaddersProvider(params));
    final controller = ref.read(snakesLaddersProvider(params).notifier);
    final isMyTurn = game.currentTurnSeat == localSeat && game.winnerSeat == -1;

    return Scaffold(
      backgroundColor: AppColors.voidSlate,
      appBar: AppBar(
        title: Text(
            isSolo ? 'Snakes & Ladders (vs Bot)' : 'Snakes & Ladders: $roomId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveArcadeContainer(
          maxWidth: 580,
          child: Column(
            children: [
              // Event Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.onyxNavy,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isMyTurn ? AppColors.neonCyan : Colors.white24),
                ),
                child: Row(
                  children: [
                    Icon(
                      game.winnerSeat != -1
                          ? Icons.emoji_events
                          : (isMyTurn ? Icons.touch_app : Icons.smart_toy),
                      color: isMyTurn ? AppColors.neonCyan : AppColors.solGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        game.lastEventMessage,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // 10x10 Board Grid
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.carbonCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.mutedSilver, width: 2),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 10,
                          ),
                          itemCount: 100,
                          itemBuilder: (context, index) {
                            // Calculate serpentine cell number [100 down to 1]
                            final row = index ~/ 10;
                            final col = index % 10;
                            final int cellNum = (row % 2 == 0)
                                ? 100 - (row * 10 + col)
                                : 100 - (row * 10 + (9 - col));

                            final isSnakeHead = SnakesLaddersController.snakes
                                .containsKey(cellNum);
                            final isLadderBase = SnakesLaddersController.ladders
                                .containsKey(cellNum);

                            return Container(
                              decoration: BoxDecoration(
                                color: (row + col) % 2 == 0
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF0F172A),
                                border: Border.all(
                                    color: Colors.white10, width: 0.5),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 2,
                                    left: 2,
                                    child: Text(
                                      '$cellNum',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: isSnakeHead
                                            ? AppColors.crimsonFlare
                                            : isLadderBase
                                                ? AppColors.emeraldGreen
                                                : Colors.white38,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isSnakeHead)
                                    const Center(
                                        child: Text('🐍',
                                            style: TextStyle(fontSize: 12))),
                                  if (isLadderBase)
                                    const Center(
                                        child: Text('🪜',
                                            style: TextStyle(fontSize: 12))),

                                  // Draw Player Tokens on this cell
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (game.playerPositions[0] == cellNum)
                                        _buildTokenChip(AppColors.neonCyan),
                                      if (game.playerPositions[1] == cellNum)
                                        _buildTokenChip(AppColors.cyberMagenta),
                                      if (!isSolo &&
                                          game.playerPositions[2] == cellNum)
                                        _buildTokenChip(AppColors.solGold),
                                      if (!isSolo &&
                                          game.playerPositions[3] == cellNum)
                                        _buildTokenChip(AppColors.emeraldGreen),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Roll Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.onyxNavy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You: Cell ${game.playerPositions[localSeat]}',
                          style: const TextStyle(
                              color: AppColors.neonCyan,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isSolo
                              ? 'Bot: Cell ${game.playerPositions[1]}'
                              : 'Next: P${game.currentTurnSeat + 1}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isMyTurn ? AppColors.neonCyan : Colors.white24,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isMyTurn
                          ? () => controller.rollDice(localSeat)
                          : null,
                      icon: const Icon(Icons.casino, color: Colors.black),
                      label: Text(
                        game.diceRoll > 0
                            ? 'ROLLED ${game.diceRoll}'
                            : 'ROLL DICE',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenChip(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4),
        ],
      ),
    );
  }
}
