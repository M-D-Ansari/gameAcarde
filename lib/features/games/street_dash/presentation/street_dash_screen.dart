import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';

class Obstacle {
  final int lane; // 0, 1, 2
  double y;

  Obstacle({required this.lane, required this.y});
}

class StreetDashScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const StreetDashScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<StreetDashScreen> createState() => _StreetDashScreenState();
}

class _StreetDashScreenState extends State<StreetDashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  int currentLane = 1; // 0: Left, 1: Center, 2: Right
  double distance = 0.0;
  double opponentDistance = 0.0;
  bool opponentAlive = true;

  final List<Obstacle> obstacles = [];
  bool isGameOver = false;
  int tickCounter = 0;
  int _lastNetworkWrite = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_gameLoop)
      ..repeat();

    if (!widget.isSolo && widget.roomId != 'solo') {
      final oppSeat = widget.localSeat == 0 ? 1 : 0;
      _syncSubscription = MultiplayerSyncService.watchSeatStream(widget.roomId, oppSeat).listen((data) {
        if (data == null || !mounted) return;
        setState(() {
          opponentDistance = (data['dist'] as num?)?.toDouble() ?? opponentDistance;
          opponentAlive = data['alive'] as bool? ?? opponentAlive;
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _gameLoop() {
    if (isGameOver) return;

    setState(() {
      distance += 0.4;
      tickCounter++;

      if (tickCounter % 40 == 0) {
        obstacles.add(Obstacle(lane: Random().nextInt(3), y: -0.1));
      }

      for (int i = obstacles.length - 1; i >= 0; i--) {
        obstacles[i].y += 0.015;

        // Collision check at Y = 0.82
        if (obstacles[i].y >= 0.78 && obstacles[i].y <= 0.86) {
          if (obstacles[i].lane == currentLane) {
            isGameOver = true;
            AudioManager.instance.playPuckHit();
            _broadcastProgress();
            return;
          }
        }

        if (obstacles[i].y > 1.0) {
          obstacles.removeAt(i);
        }
      }
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNetworkWrite > 100) {
      _lastNetworkWrite = now;
      _broadcastProgress();
    }
  }

  void _broadcastProgress() {
    if (widget.isSolo || widget.roomId == 'solo') return;
    MultiplayerSyncService.updateSeatStream(widget.roomId, widget.localSeat, {
      'dist': distance,
      'alive': !isGameOver,
      'lane': currentLane,
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _moveLeft() {
    if (currentLane > 0) {
      setState(() => currentLane--);
      AudioManager.instance.playPuckHit();
    }
  }

  void _moveRight() {
    if (currentLane < 2) {
      setState(() => currentLane++);
      AudioManager.instance.playPuckHit();
    }
  }

  void _restart() {
    setState(() {
      currentLane = 1;
      distance = 0.0;
      obstacles.clear();
      isGameOver = false;
    });
    _broadcastProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidSlate,
      appBar: AppBar(
        title: Text(widget.isSolo ? 'Street Dash (Solo)' : 'Street Dash: 1v1 Runner Duel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: SkeuomorphicDecorations.recessedSlot(radius: 8),
            child: Center(
              child: Text(
                '${distance.toInt()} M',
                style: const TextStyle(
                  color: AppColors.solGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'monospace',
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
              // Dual Racer Progress HUD
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: SkeuomorphicDecorations.bentoCard(
                  surfaceColor: const Color(0xFF1B232E),
                  accentColor: AppColors.arcadeAmber,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YOU', style: TextStyle(color: AppColors.electricCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('${distance.toInt()} M ${isGameOver ? '(CRASH)' : ''}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'monospace')),
                      ],
                    ),
                    if (!widget.isSolo)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('OPPONENT', style: TextStyle(color: AppColors.arcadeMagenta, fontWeight: FontWeight.bold, fontSize: 11)),
                          Text('${opponentDistance.toInt()} M ${!opponentAlive ? '(CRASH)' : ''}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'monospace')),
                        ],
                      ),
                  ],
                ),
              ),

              // 3-Lane Track
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final laneWidth = constraints.maxWidth / 3;

                      return GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity! < 0) {
                            _moveLeft();
                          } else if (details.primaryVelocity! > 0) {
                            _moveRight();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neonCyan.withOpacity(0.4)),
                          ),
                          child: Stack(
                            children: [
                              // Lane Divider Markings
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _StreetLanePainter(),
                                ),
                              ),

                              // Obstacles
                              for (final obs in obstacles)
                                Positioned(
                                  left: (obs.lane * laneWidth) + (laneWidth - 36) / 2,
                                  top: obs.y * constraints.maxHeight,
                                  child: Container(
                                    width: 36,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Center(
                                      child: Text('⚠️', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ),

                              // Player Runner Car
                              Positioned(
                                left: (currentLane * laneWidth) + (laneWidth - 40) / 2,
                                top: constraints.maxHeight * 0.82,
                                child: Container(
                                  width: 40,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.neonCyan,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.neonCyan.withOpacity(0.6),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text('🏎️', style: TextStyle(fontSize: 22)),
                                  ),
                                ),
                              ),

                              // Crash Overlay
                              if (isGameOver)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.redAccent),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('CRASHED! 💥',
                                            style: TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22)),
                                        const SizedBox(height: 8),
                                        Text('Distance: ${distance.toInt()} Meters',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 16)),
                                        const SizedBox(height: 16),
                                        TactileArcadeButton(
                                          baseColor: AppColors.neonCyan,
                                          onPressed: _restart,
                                          child: const Text('RESTART',
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
                      );
                    },
                  ),
                ),
              ),

              // Left/Right Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TactileArcadeButton(
                        height: 50,
                        baseColor: AppColors.carbonCard,
                        onPressed: _moveLeft,
                        child: const Icon(Icons.arrow_back, color: AppColors.neonCyan),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TactileArcadeButton(
                        height: 50,
                        baseColor: AppColors.carbonCard,
                        onPressed: _moveRight,
                        child: const Icon(Icons.arrow_forward, color: AppColors.neonCyan),
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
}

class _StreetLanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final laneW = size.width / 3;
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2.0;

    for (int i = 1; i <= 2; i++) {
      final x = i * laneW;
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 15), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
