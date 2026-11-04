import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';

class BowlingScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const BowlingScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<BowlingScreen> createState() => _BowlingScreenState();
}

class _BowlingScreenState extends State<BowlingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rollController;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  // Game state
  int currentFrame = 1;
  int currentRoll = 1;
  int currentTurnSeat = 0; // 0: Player 1, 1: Player 2
  int scoreP1 = 0;
  int scoreP2 = 0;
  List<bool> pinsStanding = List.filled(10, true);

  // Ball rolling animation coordinates
  double ballStartX = 0.5;
  double ballTargetX = 0.5;
  double ballCurrentX = 0.5;
  double ballCurrentY = 0.85;
  double ballScale = 1.0;
  double ballRotation = 0.0;
  bool isRolling = false;

  Offset? _dragStart;
  String rollFeedback = 'Swipe forward to roll the ball!';

  bool get isMyTurn => widget.isSolo || widget.localSeat == currentTurnSeat;

  @override
  void initState() {
    super.initState();
    _rollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onRollTick)
     ..addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         _onRollFinished();
       }
     });

    if (!widget.isSolo && widget.roomId != 'solo') {
      _syncSubscription = MultiplayerSyncService.watchGameState(widget.roomId).listen((data) {
        if (data == null || !mounted) return;
        _applyRemoteState(data);
      });
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _onRollTick() {
    final t = _rollController.value;
    setState(() {
      ballCurrentY = 0.85 - (0.63 * t); // Moves from 0.85 to 0.22 (pins)
      ballCurrentX = ballStartX + ((ballTargetX - ballStartX) * t);
      ballScale = 1.0 - (0.55 * t); // 3D perspective scaling (1.0 -> 0.45)
      ballRotation = t * 6 * pi; // Rolling spin
    });
  }

  void _onRollFinished() {
    setState(() {
      isRolling = false;
    });

    // Knockdown calculation based on final ballCurrentX
    final double distFromCenter = (ballCurrentX - 0.5).abs();
    final List<bool> newPins = List.from(pinsStanding);
    int knockedThisRoll = 0;

    // Pin layout mapping from center
    // Pin 0 (head pin at center)
    // Pins 1,2 (second row)
    // Pins 3,4,5 (third row)
    // Pins 6,7,8,9 (back row)
    for (int i = 0; i < 10; i++) {
      if (!newPins[i]) continue;
      double pinX = 0.5;
      if (i == 1) pinX = 0.45;
      if (i == 2) pinX = 0.55;
      if (i == 3) pinX = 0.40;
      if (i == 4) pinX = 0.50;
      if (i == 5) pinX = 0.60;
      if (i == 6) pinX = 0.35;
      if (i == 7) pinX = 0.45;
      if (i == 8) pinX = 0.55;
      if (i == 9) pinX = 0.65;

      final double distance = (pinX - ballCurrentX).abs();
      final double hitChance = (1.0 - (distance * 3.5)).clamp(0.0, 1.0);
      if (Random().nextDouble() <= hitChance) {
        newPins[i] = false;
        knockedThisRoll++;
      }
    }

    if (distFromCenter < 0.05 && knockedThisRoll >= 8) {
      // Strike bonus if very close to center
      for (int i = 0; i < 10; i++) newPins[i] = false;
      knockedThisRoll = 10;
    }

    AudioManager.instance.playPuckHit();

    if (currentRoll == 1 && knockedThisRoll == 10) {
      rollFeedback = 'STRIKE! 🎳💥';
    } else if (currentRoll == 2 && newPins.every((p) => !p)) {
      rollFeedback = 'SPARE! 🎳✨';
    } else {
      rollFeedback = 'Knocked down $knockedThisRoll pins!';
    }

    pinsStanding = newPins;
    if (currentTurnSeat == 0) {
      scoreP1 += knockedThisRoll;
    } else {
      scoreP2 += knockedThisRoll;
    }

    // Switch roll / frame / turn
    if (currentRoll == 1 && !newPins.every((p) => !p)) {
      currentRoll = 2;
    } else {
      currentRoll = 1;
      pinsStanding = List.filled(10, true);
      if (widget.isSolo) {
        currentFrame = min(10, currentFrame + 1);
      } else {
        if (currentTurnSeat == 1) {
          currentFrame = min(10, currentFrame + 1);
        }
        currentTurnSeat = currentTurnSeat == 0 ? 1 : 0;
      }
    }

    // Reset ball position for next roll
    ballCurrentX = 0.5;
    ballCurrentY = 0.85;
    ballScale = 1.0;

    _broadcastState();
  }

  void _broadcastState() {
    if (widget.isSolo || widget.roomId == 'solo') return;
    MultiplayerSyncService.updateGameState(widget.roomId, {
      'currentFrame': currentFrame,
      'currentRoll': currentRoll,
      'currentTurnSeat': currentTurnSeat,
      'scoreP1': scoreP1,
      'scoreP2': scoreP2,
      'pinsStanding': pinsStanding,
      'rollFeedback': rollFeedback,
      'lastRoll': {
        'startX': ballStartX,
        'targetX': ballTargetX,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  void _applyRemoteState(Map<String, dynamic> data) {
    if (!mounted) return;
    final int remoteTurn = data['currentTurnSeat'] as int? ?? 0;
    final int remoteP1 = data['scoreP1'] as int? ?? 0;
    final int remoteP2 = data['scoreP2'] as int? ?? 0;
    final int remoteFrame = data['currentFrame'] as int? ?? 1;
    final int remoteRoll = data['currentRoll'] as int? ?? 1;
    final String remoteFeedback = data['rollFeedback'] as String? ?? '';
    final List<dynamic>? remotePins = data['pinsStanding'] as List<dynamic>?;

    final lastRoll = data['lastRoll'] as Map<dynamic, dynamic>?;
    if (lastRoll != null && !isMyTurn && !isRolling) {
      final double sX = (lastRoll['startX'] as num?)?.toDouble() ?? 0.5;
      final double tX = (lastRoll['targetX'] as num?)?.toDouble() ?? 0.5;
      _triggerRoll(sX, tX, isRemote: true);
    }

    setState(() {
      currentTurnSeat = remoteTurn;
      scoreP1 = remoteP1;
      scoreP2 = remoteP2;
      currentFrame = remoteFrame;
      currentRoll = remoteRoll;
      if (remoteFeedback.isNotEmpty) rollFeedback = remoteFeedback;
      if (remotePins != null) {
        pinsStanding = remotePins.map((e) => e == true).toList();
      }
    });
  }

  void _triggerRoll(double startX, double targetX, {bool isRemote = false}) {
    if (isRolling) return;
    isRolling = true;
    ballStartX = startX;
    ballTargetX = targetX;
    _rollController.forward(from: 0.0);
  }

  void _onPanStart(DragStartDetails details) {
    if (!isMyTurn || isRolling) return;
    _dragStart = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    if (!isMyTurn || isRolling || _dragStart == null) return;
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.dy >= -50) return; // Must swipe forward towards pins

    final double curve = (velocity.dx / 1200).clamp(-0.35, 0.35);
    final double targetX = (0.5 + curve).clamp(0.2, 0.8);

    _triggerRoll(0.5, targetX);
    if (!widget.isSolo) {
      _broadcastState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.chassisBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.isSolo ? 'Bowling: Solo Practice' : 'Bowling: 1v1 Alley Duel'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: SkeuomorphicDecorations.recessedSlot(radius: 10),
            child: Center(
              child: Text(
                'FRAME $currentFrame / 10',
                style: const TextStyle(
                  color: AppColors.arcadeAmber,
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
          maxWidth: 540,
          child: Column(
            children: [
              // 1. Dual Scoreboard Banner (Host vs Guest)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: SkeuomorphicDecorations.bentoCard(
                  surfaceColor: const Color(0xFF1B232E),
                  accentColor: isMyTurn ? AppColors.electricCyan : AppColors.arcadeMagenta,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPlayerScore(
                      label: widget.isSolo ? 'YOU' : 'P1 (HOST)',
                      score: scoreP1,
                      isActive: currentTurnSeat == 0,
                      color: AppColors.electricCyan,
                    ),
                    Column(
                      children: [
                        Text(
                          'ROLL $currentRoll',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMyTurn ? AppColors.laserGreen.withOpacity(0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isMyTurn ? AppColors.laserGreen : Colors.white24,
                            ),
                          ),
                          child: Text(
                            isMyTurn ? 'YOUR TURN' : 'OPPONENT ROLLING...',
                            style: TextStyle(
                              color: isMyTurn ? AppColors.laserGreen : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildPlayerScore(
                      label: widget.isSolo ? 'PINS' : 'P2 (GUEST)',
                      score: widget.isSolo ? (10 - pinsStanding.where((p) => p).length) : scoreP2,
                      isActive: currentTurnSeat == 1,
                      color: AppColors.arcadeMagenta,
                    ),
                  ],
                ),
              ),

              // Feedback Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  rollFeedback,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),

              // 2. Bowling Lane with Perspective Ball Rolling and Dynamic Pins
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131920),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.consoleBevel, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanEnd: _onPanEnd,
                      child: Stack(
                        children: [
                          // Bowling Lane Flooring CustomPainter (Wooden planks + perspective gutters)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _BowlingLanePainter(),
                            ),
                          ),

                          // 10 Bowling Pins at Top
                          Positioned(
                            top: 45,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _buildPinTriangle(),
                            ),
                          ),

                          // Animated Bowling Ball Rolling down the lane
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double xPos = constraints.maxWidth * ballCurrentX;
                                final double yPos = constraints.maxHeight * ballCurrentY;
                                final double radius = 28 * ballScale;

                                return Stack(
                                  children: [
                                    // Rolling Ball
                                    Positioned(
                                      left: xPos - radius,
                                      top: yPos - radius,
                                      child: Transform.rotate(
                                        angle: ballRotation,
                                        child: Container(
                                          width: radius * 2,
                                          height: radius * 2,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const RadialGradient(
                                              center: Alignment(-0.3, -0.3),
                                              colors: [
                                                Color(0xFFE53935),
                                                Color(0xFF8E0000),
                                                Color(0xFF2B0000),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.6),
                                                blurRadius: 10 * ballScale,
                                                offset: Offset(0, 6 * ballScale),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              // Three finger holes
                                              Positioned(
                                                top: radius * 0.5,
                                                left: radius * 0.7,
                                                child: _buildHole(radius * 0.16),
                                              ),
                                              Positioned(
                                                top: radius * 0.5,
                                                left: radius * 1.1,
                                                child: _buildHole(radius * 0.16),
                                              ),
                                              Positioned(
                                                top: radius * 0.95,
                                                left: radius * 0.9,
                                                child: _buildHole(radius * 0.18),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          // Swipe instruction overlay
                          if (isMyTurn && !isRolling)
                            Positioned(
                              bottom: 24,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.keyboard_double_arrow_up, color: AppColors.arcadeAmber, size: 28),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.arcadeAmber.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'SWIPE FORWARD TO ROLL',
                                      style: TextStyle(
                                        color: AppColors.arcadeAmber,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHole(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildPlayerScore({
    required String label,
    required int score,
    required bool isActive,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$score PTS',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildPinTriangle() {
    return SizedBox(
      width: 140,
      height: 90,
      child: Stack(
        children: [
          // Row 4 (Back, 4 pins: 6, 7, 8, 9)
          _buildPin(6, 10, 0),
          _buildPin(7, 46, 0),
          _buildPin(8, 82, 0),
          _buildPin(9, 118, 0),
          // Row 3 (3 pins: 3, 4, 5)
          _buildPin(3, 28, 26),
          _buildPin(4, 64, 26),
          _buildPin(5, 100, 26),
          // Row 2 (2 pins: 1, 2)
          _buildPin(1, 46, 52),
          _buildPin(2, 82, 52),
          // Row 1 (Head pin: 0)
          _buildPin(0, 64, 76),
        ],
      ),
    );
  }

  Widget _buildPin(int index, double left, double top) {
    final standing = pinsStanding[index];

    return Positioned(
      left: left,
      top: top,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: standing ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: standing ? 1.0 : 0.4,
          child: Container(
            width: 16,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.redAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BowlingLanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Gutters
    final gutterPaint = Paint()..color = const Color(0xFF0D1217);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.15, size.height), gutterPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.85, 0, size.width * 0.15, size.height), gutterPaint);

    // Hardwood lane
    final laneRect = Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height);
    final woodPaint = Paint()..color = const Color(0xFFE2A76F);
    canvas.drawRect(laneRect, woodPaint);

    // Lane boards striping
    final stripePaint = Paint()
      ..color = const Color(0xFFC98E56)
      ..strokeWidth = 1.0;
    for (double x = size.width * 0.15; x <= size.width * 0.85; x += size.width * 0.07) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stripePaint);
    }

    // Lane targeting arrows (triangles)
    final arrowPaint = Paint()..color = const Color(0xFF8B5A2B);
    final double arrowY = size.height * 0.55;
    for (int i = 0; i < 5; i++) {
      final double ax = size.width * (0.25 + (i * 0.125));
      final path = Path()
        ..moveTo(ax, arrowY)
        ..lineTo(ax - 6, arrowY + 12)
        ..lineTo(ax + 6, arrowY + 12)
        ..close();
      canvas.drawPath(path, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
