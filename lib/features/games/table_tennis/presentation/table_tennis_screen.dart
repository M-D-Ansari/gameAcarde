import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';

class TableTennisScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const TableTennisScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<TableTennisScreen> createState() => _TableTennisScreenState();
}

class _TableTennisScreenState extends State<TableTennisScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  // Slower, human-reactable ball speeds
  double ballX = 0.5;
  double ballY = 0.5;
  double ballZ = 0.2;
  double vx = 0.005; // Slowed down for comfortable rallies
  double vy = 0.008; // Slowed down for comfortable rallies
  double vz = 0.012; // Gentle parabolic bounce

  // Paddles
  double bottomPaddleX = 0.5;
  double topPaddleX = 0.5;

  int scoreBottom = 0; // Seat 0 (Host / Player)
  int scoreTop = 0;    // Seat 1 (Guest / AI)

  int _lastNetworkWrite = 0;
  int _lastPaddleWrite = 0;
  bool get isHostOrSolo => widget.isSolo || widget.localSeat == 0;

  StreamSubscription<Map<String, dynamic>?>? _physicsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _paddleSubscription;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_gameLoop)
      ..repeat();

    if (!widget.isSolo && widget.roomId != 'solo') {
      final oppSeat = widget.localSeat == 0 ? 1 : 0;

      // Real-time listener for opponent's dedicated paddle channel
      _paddleSubscription = MultiplayerSyncService.watchSeatStream(widget.roomId, oppSeat).listen((data) {
        if (data == null || !mounted) return;
        final px = (data['paddleX'] as num?)?.toDouble();
        if (px != null) {
          setState(() {
            if (widget.localSeat == 0) {
              topPaddleX = px;
            } else {
              bottomPaddleX = px;
            }
          });
        }
      });

      // Guest listens to authoritative physics channel from Host
      if (!isHostOrSolo) {
        _physicsSubscription = MultiplayerSyncService.watchPhysicsStream(widget.roomId).listen((data) {
          if (data == null || !mounted) return;
          final targetX = (data['ballX'] as num?)?.toDouble() ?? ballX;
          final targetY = (data['ballY'] as num?)?.toDouble() ?? ballY;
          final targetZ = (data['ballZ'] as num?)?.toDouble() ?? ballZ;

          setState(() {
            // Smoothly reconcile dead reckoning with authoritative packet
            ballX += (targetX - ballX) * 0.55;
            ballY += (targetY - ballY) * 0.55;
            ballZ += (targetZ - ballZ) * 0.55;
            vx = (data['vx'] as num?)?.toDouble() ?? vx;
            vy = (data['vy'] as num?)?.toDouble() ?? vy;
            vz = (data['vz'] as num?)?.toDouble() ?? vz;
            scoreBottom = (data['scoreBottom'] as num?)?.toInt() ?? scoreBottom;
            scoreTop = (data['scoreTop'] as num?)?.toInt() ?? scoreTop;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _physicsSubscription?.cancel();
    _paddleSubscription?.cancel();
    super.dispose();
  }

  void _gameLoop() {
    if (!mounted) return;

    setState(() {
      if (isHostOrSolo) {
        // Authoritative ball simulation on Host or Solo
        ballX += vx;
        ballY += vy;
        ballZ += vz;
        vz -= 0.0007; // Gravity

        // Table surface bounce
        if (ballZ <= 0.0) {
          ballZ = 0.0;
          vz = 0.016; // Upward bounce
          AudioManager.instance.playPuckHit();
        }

        // Side wall / edge bounces
        if (ballX <= 0.12 || ballX >= 0.88) {
          vx = -vx;
          ballX = ballX.clamp(0.12, 0.88);
        }

        // Bottom paddle return (Y >= 0.86)
        if (ballY >= 0.86 && ballY <= 0.92) {
          if ((ballX - bottomPaddleX).abs() <= 0.20) {
            vy = -vy.abs();
            vx += (ballX - bottomPaddleX) * 0.015; // Paddle angle control
            AudioManager.instance.playPuckHit();
          } else if (ballY > 0.90) {
            scoreTop++;
            AudioManager.instance.playVictoryFanfare();
            _resetBall(servesToBottom: false);
          }
        }

        // Top paddle return (Y <= 0.14)
        if (ballY <= 0.14 && ballY >= 0.08) {
          final paddle = topPaddleX;
          if ((ballX - paddle).abs() <= 0.20) {
            vy = vy.abs();
            vx += (ballX - paddle) * 0.015;
            AudioManager.instance.playPuckHit();
          } else if (ballY < 0.10) {
            scoreBottom++;
            AudioManager.instance.playVictoryFanfare();
            _resetBall(servesToBottom: true);
          }
        }

        // In Solo mode, AI gently tracks the ball
        if (widget.isSolo) {
          topPaddleX += (ballX - topPaddleX) * 0.06;
          topPaddleX = topPaddleX.clamp(0.18, 0.82);
        }

        _broadcastHostSync();
      } else {
        // Dead reckoning for Guest: smooth 60fps trajectory simulation
        ballX += vx;
        ballY += vy;
        ballZ += vz;
        vz -= 0.0007;

        if (ballZ <= 0.0) {
          ballZ = 0.0;
          vz = 0.016;
        }
        if (ballX <= 0.12 || ballX >= 0.88) {
          vx = -vx;
          ballX = ballX.clamp(0.12, 0.88);
        }
      }
    });
  }

  void _resetBall({required bool servesToBottom}) {
    ballX = 0.5;
    ballY = 0.5;
    ballZ = 0.22;
    vx = (Random().nextBool() ? 1 : -1) * 0.004;
    vy = servesToBottom ? 0.007 : -0.007;
    vz = 0.014;
  }

  void _broadcastHostSync() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNetworkWrite < 35) return; // ~28Hz low-latency stream
    _lastNetworkWrite = now;

    MultiplayerSyncService.updatePhysicsStream(widget.roomId, {
      'ballX': ballX,
      'ballY': ballY,
      'ballZ': ballZ,
      'vx': vx,
      'vy': vy,
      'vz': vz,
      'scoreBottom': scoreBottom,
      'scoreTop': scoreTop,
      't': now,
    });
  }

  void _broadcastPaddle(int seat, double x) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPaddleWrite < 30) return;
    _lastPaddleWrite = now;

    MultiplayerSyncService.updateSeatStream(widget.roomId, seat, {
      'paddleX': x,
      't': now,
    });
  }

  void _onHorizontalDrag(DragUpdateDetails details, BoxConstraints constraints) {
    final double normalizedDelta = details.primaryDelta! / constraints.maxWidth;
    setState(() {
      if (widget.localSeat == 0 || widget.isSolo) {
        bottomPaddleX = (bottomPaddleX + normalizedDelta).clamp(0.18, 0.82);
        if (!widget.isSolo) _broadcastPaddle(0, bottomPaddleX);
      } else {
        topPaddleX = (topPaddleX + normalizedDelta).clamp(0.18, 0.82);
        _broadcastPaddle(1, topPaddleX);
      }
    });
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
        title: Text(widget.isSolo ? 'Table Tennis: Solo Rally' : 'Table Tennis: 2-Player Duel'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: SkeuomorphicDecorations.recessedSlot(radius: 12),
            child: Center(
              child: Text(
                '$scoreBottom  :  $scoreTop',
                style: const TextStyle(
                  color: AppColors.arcadeAmber,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
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
              // Player Match Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: SkeuomorphicDecorations.bentoCard(
                  surfaceColor: const Color(0xFF1B232E),
                  accentColor: widget.localSeat == 0 ? AppColors.electricCyan : AppColors.arcadeMagenta,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.electricCyan, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(widget.isSolo ? 'YOU (BOTTOM)' : 'P1 HOST (BOTTOM)', style: const TextStyle(color: AppColors.electricCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                      child: const Text('SLOW RALLY SPEED', style: TextStyle(color: AppColors.laserGreen, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                    Row(
                      children: [
                        Text(widget.isSolo ? 'BOT (TOP)' : 'P2 GUEST (TOP)', style: const TextStyle(color: AppColors.arcadeMagenta, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(width: 8),
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.arcadeMagenta, shape: BoxShape.circle)),
                      ],
                    ),
                  ],
                ),
              ),

              // 2.5D Isometric Table Tennis Court
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F151C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.consoleBevel, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onHorizontalDragUpdate: (d) => _onHorizontalDrag(d, constraints),
                          child: Stack(
                            children: [
                              // 2.5D Table Surface Painter
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TableTennisPainter(),
                                ),
                              ),

                              // Top Paddle (Guest / AI)
                              Positioned(
                                top: constraints.maxHeight * 0.08,
                                left: (constraints.maxWidth * topPaddleX) - 34,
                                child: Container(
                                  width: 68,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.arcadeMagenta,
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.arcadeMagenta.withOpacity(0.6),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Bottom Paddle (Host / Local Player)
                              Positioned(
                                top: constraints.maxHeight * 0.88,
                                left: (constraints.maxWidth * bottomPaddleX) - 38,
                                child: Container(
                                  width: 76,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppColors.electricCyan,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.electricCyan.withOpacity(0.6),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Ball Shadow
                              Positioned(
                                left: (constraints.maxWidth * ballX) - (8 * (1.0 - ballZ * 0.5)),
                                top: (constraints.maxHeight * ballY) - 4,
                                child: Container(
                                  width: 16 * (1.0 - ballZ * 0.5),
                                  height: 8 * (1.0 - ballZ * 0.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),

                              // 2.5D Floating Ball
                              Positioned(
                                left: (constraints.maxWidth * ballX) - 10,
                                top: (constraints.maxHeight * ballY) - (ballZ * constraints.maxHeight * 0.35) - 10,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      center: Alignment(-0.3, -0.3),
                                      colors: [
                                        Colors.white,
                                        Color(0xFFFFB300),
                                        Color(0xFFE65100),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.arcadeAmber.withOpacity(0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Touch drag hint
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Text(
                                    widget.localSeat == 0 ? 'DRAG TO MOVE CYAN PADDLE' : 'DRAG TO MOVE MAGENTA PADDLE',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableTennisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Green tournament tabletop
    final tablePaint = Paint()..color = const Color(0xFF1B5E20);
    final tableRect = Rect.fromLTWH(size.width * 0.12, size.height * 0.08, size.width * 0.76, size.height * 0.84);
    canvas.drawRRect(RRect.fromRectAndRadius(tableRect, const Radius.circular(8)), tablePaint);

    // White boundaries
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(tableRect, const Radius.circular(8)), borderPaint);

    // Center dividing line
    final centerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.08),
      Offset(size.width * 0.5, size.height * 0.92),
      centerLinePaint,
    );

    // Net across center
    final netPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5;
    canvas.drawLine(
      Offset(size.width * 0.10, size.height * 0.5),
      Offset(size.width * 0.90, size.height * 0.5),
      netPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
