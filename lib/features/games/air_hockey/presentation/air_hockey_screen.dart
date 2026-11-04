import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../engine/air_hockey_flame_game.dart';

class AirHockeyScreen extends StatefulWidget {
  final String roomId;
  final int seatIndex;
  final bool isHost;
  final bool isSolo;

  const AirHockeyScreen({
    super.key,
    required this.roomId,
    required this.seatIndex,
    required this.isHost,
    this.isSolo = false,
  });

  @override
  State<AirHockeyScreen> createState() => _AirHockeyScreenState();
}

class _AirHockeyScreenState extends State<AirHockeyScreen> {
  late AirHockeyFlameGame _game;

  @override
  void initState() {
    super.initState();
    _game = AirHockeyFlameGame(
      roomId: widget.roomId,
      localSeatIndex: widget.seatIndex,
      isHost: widget.isHost,
      isSolo: widget.isSolo,
      onGoalScored: () {
        if (mounted) setState(() {});
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
                top: 12,
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
                        '${_game.scoreHost}  :  ${_game.scoreGuest}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
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
                        widget.isSolo
                            ? 'SOLO (VS AI)'
                            : (widget.isHost ? 'HOST' : 'GUEST'),
                        style: const TextStyle(
                            color: AppColors.solGold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
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
