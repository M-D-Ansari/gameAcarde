import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';

class TicTacToeState {
  final List<String> board;
  final int currentTurnSeat;
  final int winnerSeat;
  final List<int>? winLine;

  const TicTacToeState({
    required this.board,
    required this.currentTurnSeat,
    required this.winnerSeat,
    this.winLine,
  });

  factory TicTacToeState.initial() => const TicTacToeState(
        board: ['', '', '', '', '', '', '', '', ''],
        currentTurnSeat: 0,
        winnerSeat: -1,
      );

  factory TicTacToeState.fromMap(Map<dynamic, dynamic> map) {
    final listRaw = map['board'] as List<dynamic>? ?? List.filled(9, '');
    return TicTacToeState(
      board: listRaw.map((e) => e.toString()).toList(),
      currentTurnSeat: (map['currentTurnSeat'] as num?)?.toInt() ?? 0,
      winnerSeat: (map['winnerSeat'] as num?)?.toInt() ?? -1,
    );
  }

  Map<String, dynamic> toMap() => {
        'board': board,
        'currentTurnSeat': currentTurnSeat,
        'winnerSeat': winnerSeat,
      };
}

class TicTacToeParams {
  final String roomId;
  final bool isSolo;

  const TicTacToeParams({required this.roomId, this.isSolo = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicTacToeParams &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          isSolo == other.isSolo;

  @override
  int get hashCode => roomId.hashCode ^ isSolo.hashCode;
}

final ticTacToeProvider = StateNotifierProvider.autoDispose
    .family<TicTacToeController, TicTacToeState, TicTacToeParams>((ref, params) {
  final controller = TicTacToeController(params.roomId, isSolo: params.isSolo);
  ref.onDispose(() => controller.dispose());
  return controller;
});

class TicTacToeController extends StateNotifier<TicTacToeState> {
  final String roomId;
  final bool isSolo;
  StreamSubscription<Map<String, dynamic>?>? _sub;

  TicTacToeController(this.roomId, {this.isSolo = false}) : super(TicTacToeState.initial()) {
    if (!isSolo && roomId != 'solo') {
      _sub = MultiplayerSyncService.watchGameState(roomId).listen((data) {
        if (data != null) {
          state = TicTacToeState.fromMap(data);
        }
      });
    }
  }

  void playMove(int index, int seat) {
    if (state.winnerSeat != -1 || state.currentTurnSeat != seat) return;
    if (state.board[index].isNotEmpty) return;

    final updated = List<String>.from(state.board);
    final symbol = seat == 0 ? 'X' : 'O';
    updated[index] = symbol;

    int winSeat = -1;
    List<int>? line;
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];

    for (final l in lines) {
      if (updated[l[0]].isNotEmpty &&
          updated[l[0]] == updated[l[1]] &&
          updated[l[1]] == updated[l[2]]) {
        winSeat = updated[l[0]] == 'X' ? 0 : 1;
        line = l;
        break;
      }
    }

    if (winSeat == -1 && updated.every((cell) => cell.isNotEmpty)) {
      winSeat = 2; // Draw
    }

    final nextSeat = winSeat == -1 ? (seat == 0 ? 1 : 0) : -1;
    final newState = TicTacToeState(
      board: updated,
      currentTurnSeat: nextSeat,
      winnerSeat: winSeat,
      winLine: line,
    );

    state = newState;
    if (!isSolo && roomId != 'solo') {
      MultiplayerSyncService.updateGameState(roomId, newState.toMap());
    }

    // Snappy AI Response in Solo Mode
    if (isSolo && winSeat == -1 && nextSeat == 1) {
      Future.delayed(const Duration(milliseconds: 220), () {
        _playAiMove();
      });
    }
  }

  void _playAiMove() {
    if (state.winnerSeat != -1 || state.currentTurnSeat != 1) return;

    final board = state.board;
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];

    // 1. Try to win
    for (final l in lines) {
      final cells = [board[l[0]], board[l[1]], board[l[2]]];
      if (cells.where((c) => c == 'O').length == 2 && cells.contains('')) {
        playMove(l[cells.indexOf('')], 1);
        return;
      }
    }

    // 2. Block player 'X'
    for (final l in lines) {
      final cells = [board[l[0]], board[l[1]], board[l[2]]];
      if (cells.where((c) => c == 'X').length == 2 && cells.contains('')) {
        playMove(l[cells.indexOf('')], 1);
        return;
      }
    }

    // 3. Take center
    if (board[4] == '') {
      playMove(4, 1);
      return;
    }

    // 4. Random available
    final available = <int>[];
    for (int i = 0; i < 9; i++) {
      if (board[i] == '') available.add(i);
    }
    if (available.isNotEmpty) {
      final pick = available[Random().nextInt(available.length)];
      playMove(pick, 1);
    }
  }

  void reset() {
    state = TicTacToeState.initial();
    if (!isSolo && roomId != 'solo') {
      MultiplayerSyncService.updateGameState(roomId, state.toMap());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class TicTacToeScreen extends ConsumerWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const TicTacToeScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TicTacToeParams(roomId: roomId, isSolo: isSolo);
    final game = ref.watch(ticTacToeProvider(params));
    final controller = ref.read(ticTacToeProvider(params).notifier);
    final isMyTurn = game.currentTurnSeat == localSeat && game.winnerSeat == -1;

    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.chassisBlack,
        elevation: 0,
        title: Text(isSolo ? 'Tic Tac Toe (vs Bot)' : 'Tic Tac Toe: $roomId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveArcadeContainer(
          maxWidth: 480,
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Skeuomorphic Inset Status Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: SkeuomorphicDecorations.recessedSlot(radius: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      game.winnerSeat != -1 ? Icons.emoji_events : Icons.adjust,
                      color: isMyTurn ? AppColors.electricCyan : AppColors.arcadeAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      game.winnerSeat == -1
                          ? (isMyTurn ? 'YOUR TURN (${localSeat == 0 ? 'X' : 'O'})' : (isSolo ? 'BOT IS CALCULATING...' : 'OPPONENT TURN'))
                          : (game.winnerSeat == 2
                              ? 'MATCH DRAW!'
                              : (game.winnerSeat == localSeat ? 'VICTORY!' : (isSolo ? 'BOT WON!' : 'DEFEAT!'))),
                      style: TextStyle(
                        color: isMyTurn ? AppColors.electricCyan : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Skeuomorphic 3D 3x3 Grid
              Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: SkeuomorphicDecorations.bentoCard(
                        surfaceColor: const Color(0xFF161E28),
                        accentColor: isMyTurn ? AppColors.electricCyan : AppColors.consoleBevel,
                        radius: 24,
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          final val = game.board[index];
                          final isWinningTile = game.winLine?.contains(index) ?? false;

                          return GestureDetector(
                            onTap: () {
                              if (val.isEmpty && isMyTurn) {
                                AudioManager.instance.playPuckHit();
                                controller.playMove(index, localSeat);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              decoration: BoxDecoration(
                                color: isWinningTile
                                    ? AppColors.laserGreen.withOpacity(0.2)
                                    : (val.isEmpty ? const Color(0xFF1E2734) : const Color(0xFF141C25)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  top: BorderSide(color: Colors.white.withOpacity(val.isEmpty ? 0.15 : 0.05), width: 1.5),
                                  bottom: BorderSide(color: Colors.black.withOpacity(0.6), width: 3),
                                  left: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                                  right: BorderSide(color: Colors.black.withOpacity(0.4), width: 1),
                                ),
                                boxShadow: val.isEmpty
                                    ? [
                                        BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(0, 3), blurRadius: 3),
                                      ]
                                    : [
                                        BoxShadow(color: Colors.black.withOpacity(0.6), offset: const Offset(0, 1), blurRadius: 2),
                                      ],
                              ),
                              child: Center(
                                child: Text(
                                  val,
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: val == 'X'
                                        ? AppColors.electricCyan
                                        : AppColors.arcadeMagenta,
                                    shadows: [
                                      Shadow(
                                        color: (val == 'X' ? AppColors.electricCyan : AppColors.arcadeMagenta).withOpacity(0.6),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              if (game.winnerSeat != -1)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: TactileArcadeButton(
                    baseColor: AppColors.electricCyan,
                    height: 52,
                    onPressed: () {
                      AudioManager.instance.playDiceRoll();
                      controller.reset();
                    },
                    child: const Text(
                      'PLAY REMATCH',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
