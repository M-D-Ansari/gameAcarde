import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../engine/flappy_bird_flame_game.dart';

class FlappyBirdScreen extends StatefulWidget {
  final String roomId;
  final int seed;
  final int localSeat;
  final bool isSolo;

  const FlappyBirdScreen({
    super.key,
    required this.roomId,
    required this.seed,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<FlappyBirdScreen> createState() => _FlappyBirdScreenState();
}

class _FlappyBirdScreenState extends State<FlappyBirdScreen> {
  late FlappyBirdFlameGame _game;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _game = FlappyBirdFlameGame(
      roomId: widget.roomId,
      seed: widget.seed,
      localSeat: widget.localSeat,
      onGameOver: () {
        if (mounted) {
          setState(() {
            _isGameOver = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ResponsiveArcadeContainer(
          child: Stack(
            children: [
              GameWidget(game: _game),

              // Top HUD
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => context.pop(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.onyxNavy.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Dist: ${(_game.distanceTravelled * 10).toInt()}m',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.carbonCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.isSolo ? 'SOLO RUN' : 'DUEL',
                        style: const TextStyle(
                            color: AppColors.solGold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isGameOver)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.onyxNavy.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.crimsonFlare, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CRASHED!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.crimsonFlare,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Final Distance: ${(_game.distanceTravelled * 10).toInt()} meters',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonCyan,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => context.pop(),
                          child: const Text('BACK TO ARCADE',
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
      ),
    );
  }
}
