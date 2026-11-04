import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';

class StackAnimalsScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const StackAnimalsScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<StackAnimalsScreen> createState() => _StackAnimalsScreenState();
}

class _StackAnimalsScreenState extends State<StackAnimalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _craneTicker;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  double craneX = 0.5;
  double craneDir = 1.0;
  final List<Rect> stackedBlocks = [];
  int score = 0;
  int currentTurnSeat = 0; // 0: Player 1, 1: Player 2
  bool isGameOver = false;

  bool get isMyTurn => widget.isSolo || widget.localSeat == currentTurnSeat;

  @override
  void initState() {
    super.initState();
    // Base platform at bottom
    stackedBlocks.add(const Rect.fromLTWH(0.25, 0.88, 0.5, 0.05));

    _craneTicker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_moveCrane)
          ..repeat();

    if (!widget.isSolo && widget.roomId != 'solo') {
      _syncSubscription = MultiplayerSyncService.watchGameState(widget.roomId).listen((data) {
        if (data == null || !mounted) return;
        _applyRemoteDrop(data);
      });
    }
  }

  @override
  void dispose() {
    _craneTicker.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _moveCrane() {
    if (isGameOver) return;
    setState(() {
      craneX += craneDir * 0.012;
      if (craneX <= 0.15 || craneX >= 0.85) {
        craneDir = -craneDir;
      }
    });
  }

  void _dropAnimal() {
    if (isGameOver || !isMyTurn) return;

    final topBlock = stackedBlocks.last;
    const blockWidth = 0.22;
    const blockHeight = 0.045;
    final dropX = craneX - blockWidth / 2;

    final overlapLeft = max(dropX, topBlock.left);
    final overlapRight = min(dropX + blockWidth, topBlock.right);

    bool landed = false;
    if (overlapRight > overlapLeft) {
      landed = true;
      final newY = topBlock.top - blockHeight;
      setState(() {
        score++;
        stackedBlocks.add(Rect.fromLTWH(
            overlapLeft, newY, overlapRight - overlapLeft, blockHeight));
        currentTurnSeat = currentTurnSeat == 0 ? 1 : 0;
      });
      AudioManager.instance.playPuckHit();
    } else {
      setState(() {
        isGameOver = true;
      });
      AudioManager.instance.playVictoryFanfare();
    }

    if (!widget.isSolo && widget.roomId != 'solo') {
      MultiplayerSyncService.updateGameState(widget.roomId, {
        'drop': {
          'craneX': craneX,
          'landed': landed,
          'overlapLeft': overlapLeft,
          'overlapRight': overlapRight,
          'score': score,
          'currentTurnSeat': currentTurnSeat,
          'isGameOver': isGameOver,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });
    }
  }

  void _applyRemoteDrop(Map<String, dynamic> data) {
    if (!data.containsKey('drop') || isMyTurn) return;
    final drop = data['drop'] as Map<dynamic, dynamic>;
    final bool landed = drop['landed'] as bool? ?? false;
    final int newScore = (drop['score'] as num?)?.toInt() ?? score;
    final int nextSeat = (drop['currentTurnSeat'] as num?)?.toInt() ?? 0;
    final bool remoteGameOver = drop['isGameOver'] as bool? ?? false;

    if (landed) {
      final topBlock = stackedBlocks.last;
      const blockHeight = 0.045;
      final double oLeft = (drop['overlapLeft'] as num).toDouble();
      final double oRight = (drop['overlapRight'] as num).toDouble();
      final newY = topBlock.top - blockHeight;

      setState(() {
        score = newScore;
        currentTurnSeat = nextSeat;
        isGameOver = remoteGameOver;
        stackedBlocks.add(Rect.fromLTWH(oLeft, newY, oRight - oLeft, blockHeight));
      });
      AudioManager.instance.playPuckHit();
    } else {
      setState(() {
        isGameOver = true;
      });
    }
  }

  void _reset() {
    setState(() {
      stackedBlocks.clear();
      stackedBlocks.add(const Rect.fromLTWH(0.25, 0.88, 0.5, 0.05));
      score = 0;
      currentTurnSeat = 0;
      isGameOver = false;
    });
    if (!widget.isSolo && widget.roomId != 'solo') {
      MultiplayerSyncService.updateGameState(widget.roomId, {
        'drop': {
          'landed': true,
          'score': 0,
          'currentTurnSeat': 0,
          'isGameOver': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidSlate,
      appBar: AppBar(
        title: Text(widget.isSolo ? 'Stack Animals (Solo)' : 'Stack Animals: 1v1 Tower Duel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: SkeuomorphicDecorations.recessedSlot(radius: 8),
            child: Center(
              child: Text(
                'TOWER: $score',
                style: const TextStyle(
                  color: AppColors.solGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveArcadeContainer(
          maxWidth: 480,
          child: Column(
            children: [
              // Turn Indicator Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: SkeuomorphicDecorations.bentoCard(
                  surfaceColor: const Color(0xFF1B232E),
                  accentColor: isMyTurn ? AppColors.laserGreen : AppColors.arcadeMagenta,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isSolo ? 'SOLO TOWER' : (currentTurnSeat == 0 ? 'P1 (HOST) TURN' : 'P2 (GUEST) TURN'),
                      style: TextStyle(
                        color: isMyTurn ? AppColors.laserGreen : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMyTurn ? AppColors.laserGreen.withOpacity(0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isMyTurn ? 'YOUR TURN TO DROP' : 'WAITING FOR DROP...',
                        style: TextStyle(
                          color: isMyTurn ? AppColors.laserGreen : Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Game Arena
              Expanded(
                child: Stack(
                  children: [
                    // Canvas Stack
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StackAnimalsPainter(
                          craneX: craneX,
                          stackedBlocks: stackedBlocks,
                          isGameOver: isGameOver,
                        ),
                      ),
                    ),

                    // Game Over Overlay
                    if (isGameOver)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neonCyan),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('TOWER COLLAPSED! 💥',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              const SizedBox(height: 8),
                              Text('Final Height: $score Animals Stacked',
                                  style: const TextStyle(
                                      color: AppColors.solGold, fontSize: 14)),
                              const SizedBox(height: 16),
                              TactileArcadeButton(
                                baseColor: AppColors.neonCyan,
                                onPressed: _reset,
                                child: const Text('RETRY TOWER',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Drop Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: TactileArcadeButton(
                  height: 52,
                  baseColor: isMyTurn && !isGameOver ? AppColors.solGold : Colors.white24,
                  onPressed: isMyTurn && !isGameOver ? _dropAnimal : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_downward, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        isMyTurn ? 'DROP BLOCK ON TOWER' : 'WAIT FOR OPPONENT...',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0),
                      ),
                    ],
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

class _StackAnimalsPainter extends CustomPainter {
  final double craneX;
  final List<Rect> stackedBlocks;
  final bool isGameOver;

  _StackAnimalsPainter({
    required this.craneX,
    required this.stackedBlocks,
    required this.isGameOver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Crane Swinger at top
    final cranePx = Offset(craneX * w, h * 0.12);
    final ropePaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(craneX * w, 0), cranePx, ropePaint);

    // Swinging animal block
    if (!isGameOver) {
      final blockRect = Rect.fromCenter(
          center: cranePx + const Offset(0, 16), width: w * 0.22, height: h * 0.045);
      final blockPaint = Paint()..color = const Color(0xFFFF9100);
      canvas.drawRRect(
          RRect.fromRectAndRadius(blockRect, const Radius.circular(8)), blockPaint);
      canvas.drawCircle(blockRect.center - const Offset(12, 0), 3, Paint()..color = Colors.black);
      canvas.drawCircle(blockRect.center + const Offset(12, 0), 3, Paint()..color = Colors.black);
    }

    // 2. Draw Stacked Blocks (The Tower)
    for (int i = 0; i < stackedBlocks.length; i++) {
      final r = stackedBlocks[i];
      final pxRect = Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
      final color = i == 0
          ? Colors.grey.shade700
          : [
              const Color(0xFF00E5FF),
              const Color(0xFFFF4081),
              const Color(0xFF76FF03),
              const Color(0xFFFFD600)
            ][i % 4];

      canvas.drawRRect(
        RRect.fromRectAndRadius(pxRect, const Radius.circular(6)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
