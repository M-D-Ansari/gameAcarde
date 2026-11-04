import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';

class ColorRushScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const ColorRushScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<ColorRushScreen> createState() => _ColorRushScreenState();
}

class _ColorRushScreenState extends State<ColorRushScreen> {
  static const Map<String, Color> colorOptions = {
    'CYAN': Color(0xFF00F2FE),
    'MAGENTA': Color(0xFFF355DA),
    'YELLOW': Color(0xFFFFD200),
    'GREEN': Color(0xFF00E676),
    'RED': Color(0xFFFF1744),
    'BLUE': Color(0xFF3B82F6),
  };

  int currentRound = 1;
  int totalScore = 0;
  int opponentScore = 0;
  late String promptWord;
  late Color promptColor;
  late List<Color> gridColors;
  int roundStartTime = 0;
  bool isGameOver = false;

  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _nextRound();

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
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _nextRound() {
    final rng = Random();
    final keys = colorOptions.keys.toList();
    promptWord = keys[rng.nextInt(keys.length)];
    promptColor = colorOptions[keys[rng.nextInt(keys.length)]]!;

    final correctColor = colorOptions[promptWord]!;
    final list = <Color>[correctColor];
    while (list.length < 4) {
      final pick = colorOptions.values.toList()[rng.nextInt(colorOptions.length)];
      if (!list.contains(pick)) list.add(pick);
    }
    list.shuffle();
    gridColors = list;
    roundStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _selectColor(Color color) {
    if (isGameOver) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - roundStartTime;
    final correctColor = colorOptions[promptWord];

    if (color == correctColor) {
      final roundPoints = max(100, 1000 - elapsed);
      totalScore += roundPoints;
      AudioManager.instance.playPuckHit();
    }

    if (!widget.isSolo && widget.roomId != 'solo') {
      MultiplayerSyncService.updateSeatStream(widget.roomId, widget.localSeat, {
        'score': totalScore,
        'round': currentRound,
        't': DateTime.now().millisecondsSinceEpoch,
      });
    }

    if (currentRound >= 10) {
      setState(() {
        isGameOver = true;
      });
      AudioManager.instance.playVictoryFanfare();
    } else {
      setState(() {
        currentRound++;
        _nextRound();
      });
    }
  }

  void _reset() {
    setState(() {
      currentRound = 1;
      totalScore = 0;
      isGameOver = false;
      _nextRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidSlate,
      appBar: AppBar(
        title: Text(widget.isSolo ? 'Color Rush (Solo)' : 'Color Rush: 1v1 Reflex Duel'),
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
                'ROUND $currentRound / 10',
                style: const TextStyle(
                  color: AppColors.solGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
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
              // Score HUD
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                        Text('$totalScore PTS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace')),
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

              // Game Area
              Expanded(
                child: isGameOver
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neonCyan),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('ROUNDS COMPLETE! ⚡',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 12),
                              Text('Your Score: $totalScore Points',
                                  style: const TextStyle(color: AppColors.solGold, fontSize: 16)),
                              if (!widget.isSolo)
                                Text('Opponent: $opponentScore Points',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 20),
                              TactileArcadeButton(
                                baseColor: AppColors.neonCyan,
                                onPressed: _reset,
                                child: const Text('PLAY AGAIN',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('TAP THE MEANING COLOR (IGNORE INK):',
                              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          // Stroop Word Prompt
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.carbonCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              promptWord,
                              style: TextStyle(
                                color: promptColor,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // 2x2 Color Choices
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.5,
                              physics: const NeverScrollableScrollPhysics(),
                              children: gridColors.map((color) {
                                return GestureDetector(
                                  onTap: () => _selectColor(color),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.5),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
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
