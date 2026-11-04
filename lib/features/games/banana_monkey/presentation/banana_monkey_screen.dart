import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';

class FallingItem {
  double x;
  double y;
  final String type; // 'banana', 'golden', 'anvil'
  final int points;

  FallingItem({
    required this.x,
    required this.y,
    required this.type,
    required this.points,
  });
}

class BananaMonkeyScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const BananaMonkeyScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<BananaMonkeyScreen> createState() => _BananaMonkeyScreenState();
}

class _BananaMonkeyScreenState extends State<BananaMonkeyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  double monkeyX = 0.5;
  int score = 0;
  int opponentScore = 0;
  int timeLeft = 45;
  Timer? _countdown;
  final List<FallingItem> items = [];
  int spawnTick = 0;
  int _lastNetworkWrite = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_gameStep)
      ..repeat();

    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        t.cancel();
      }
    });

    if (!widget.isSolo && widget.roomId != 'solo') {
      final oppSeat = widget.localSeat == 0 ? 1 : 0;
      _syncSubscription = MultiplayerSyncService.watchSeatStream(widget.roomId, oppSeat).listen((data) {
        if (data == null || !mounted) return;
        setState(() {
          opponentScore = (data['score'] as num?)?.toInt() ?? opponentScore;
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _countdown?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _gameStep() {
    if (timeLeft <= 0) return;

    setState(() {
      spawnTick++;
      if (spawnTick % 30 == 0) {
        final rand = Random().nextDouble();
        if (rand < 0.65) {
          items.add(FallingItem(
              x: Random().nextDouble() * 0.8 + 0.1, y: 0.0, type: 'banana', points: 10));
        } else if (rand < 0.85) {
          items.add(FallingItem(
              x: Random().nextDouble() * 0.8 + 0.1, y: 0.0, type: 'golden', points: 50));
        } else {
          items.add(FallingItem(
              x: Random().nextDouble() * 0.8 + 0.1, y: 0.0, type: 'anvil', points: -30));
        }
      }

      // Move items down
      for (int i = items.length - 1; i >= 0; i--) {
        items[i].y += 0.014;

        // Catch check by monkey
        if (items[i].y >= 0.82 && items[i].y <= 0.90) {
          if ((items[i].x - monkeyX).abs() < 0.10) {
            score = max(0, score + items[i].points);
            if (items[i].points > 0) {
              AudioManager.instance.playPuckHit();
            }
            items.removeAt(i);
            _broadcastScore();
            continue;
          }
        }

        // Offscreen removal
        if (i < items.length && items[i].y > 1.0) {
          items.removeAt(i);
        }
      }
    });
  }

  void _broadcastScore() {
    if (widget.isSolo || widget.roomId == 'solo') return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNetworkWrite < 80) return;
    _lastNetworkWrite = now;

    MultiplayerSyncService.updateSeatStream(widget.roomId, widget.localSeat, {
      'score': score,
      'monkeyX': monkeyX,
      't': now,
    });
  }

  void _reset() {
    setState(() {
      items.clear();
      score = 0;
      timeLeft = 45;
      spawnTick = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidSlate,
      appBar: AppBar(
        title: Text(widget.isSolo ? 'Banana Monkey (Solo)' : 'Banana Monkey: 1v1 Duel'),
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
                '00:${timeLeft.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.laserGreen,
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
              // Dual Score HUD (Host vs Guest)
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
                        Text('$score PTS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace')),
                      ],
                    ),
                    if (!widget.isSolo)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('OPPONENT', style: TextStyle(color: AppColors.arcadeMagenta, fontWeight: FontWeight.bold, fontSize: 11)),
                          Text('$opponentScore PTS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace')),
                        ],
                      ),
                  ],
                ),
              ),

              // Game Arena
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            monkeyX += details.primaryDelta! / constraints.maxWidth;
                            monkeyX = monkeyX.clamp(0.1, 0.9);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B281B), // Jungle canopy
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neonCyan.withOpacity(0.4)),
                          ),
                          child: Stack(
                            children: [
                              // Falling Items
                              for (final item in items)
                                Positioned(
                                  left: (item.x * constraints.maxWidth) - 16,
                                  top: item.y * constraints.maxHeight,
                                  child: _buildItemWidget(item.type),
                                ),

                              // Player Monkey Basket at bottom
                              Positioned(
                                left: (monkeyX * constraints.maxWidth) - 24,
                                top: constraints.maxHeight * 0.85,
                                child: Container(
                                  width: 48,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8D6E63),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber, width: 2),
                                  ),
                                  child: const Center(
                                    child: Text('🐵', style: TextStyle(fontSize: 22)),
                                  ),
                                ),
                              ),

                              // Time Up Overlay
                              if (timeLeft <= 0)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.solGold),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('TIME UP! ⏰',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22)),
                                        const SizedBox(height: 8),
                                        Text('Your Catch: $score Points',
                                            style: const TextStyle(
                                                color: AppColors.solGold, fontSize: 16)),
                                        if (!widget.isSolo)
                                          Text('Opponent: $opponentScore Points',
                                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                        const SizedBox(height: 16),
                                        TactileArcadeButton(
                                          baseColor: AppColors.solGold,
                                          onPressed: _reset,
                                          child: const Text('PLAY AGAIN',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemWidget(String type) {
    if (type == 'banana') {
      return const Text('🍌', style: TextStyle(fontSize: 24));
    } else if (type == 'golden') {
      return const Text('⭐', style: TextStyle(fontSize: 24));
    } else {
      return const Text('💣', style: TextStyle(fontSize: 24));
    }
  }
}
