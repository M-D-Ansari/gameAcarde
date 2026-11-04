import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';

class StickFootballScreen extends StatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const StickFootballScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  State<StickFootballScreen> createState() => _StickFootballScreenState();
}

class _StickFootballScreenState extends State<StickFootballScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _physicsTicker;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;

  // Ball
  Offset ballPos = const Offset(0.5, 0.5);
  Offset ballVel = Offset.zero;

  // Team Cyan (Bottom, Seat 0) - 5 Pucks
  List<Offset> teamCyan = [
    const Offset(0.5, 0.88),
    const Offset(0.25, 0.75),
    const Offset(0.75, 0.75),
    const Offset(0.35, 0.60),
    const Offset(0.65, 0.60),
  ];
  List<Offset> teamCyanVel = List.filled(5, Offset.zero);

  // Team Magenta (Top, Seat 1) - 5 Pucks
  List<Offset> teamMagenta = [
    const Offset(0.5, 0.12),
    const Offset(0.25, 0.25),
    const Offset(0.75, 0.25),
    const Offset(0.35, 0.40),
    const Offset(0.65, 0.40),
  ];
  List<Offset> teamMagentaVel = List.filled(5, Offset.zero);

  int? activePuckIndex;
  Offset? dragVector;

  int scoreCyan = 0;
  int scoreMagenta = 0;
  bool isCyanTurn = true;

  bool get isMyTurn {
    if (widget.isSolo) return isCyanTurn;
    return (widget.localSeat == 0 && isCyanTurn) || (widget.localSeat == 1 && !isCyanTurn);
  }

  @override
  void initState() {
    super.initState();
    _physicsTicker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_stepPhysics)
      ..repeat();

    if (!widget.isSolo && widget.roomId != 'solo') {
      _syncSubscription = MultiplayerSyncService.watchGameState(widget.roomId).listen((data) {
        if (data == null || !mounted) return;
        _applyRemoteShot(data);
      });
    }
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _stepPhysics() {
    setState(() {
      // 1. Move Ball
      ballPos += ballVel;
      ballVel *= 0.985; // Drag

      // Wall reflections
      if (ballPos.dx <= 0.05 || ballPos.dx >= 0.95) {
        ballVel = Offset(-ballVel.dx, ballVel.dy);
        ballPos = Offset(ballPos.dx.clamp(0.05, 0.95), ballPos.dy);
        AudioManager.instance.playPuckHit();
      }

      // Goal detection
      if (ballPos.dy <= 0.03) {
        if (ballPos.dx >= 0.35 && ballPos.dx <= 0.65) {
          scoreCyan++;
          AudioManager.instance.playVictoryFanfare();
          _resetPitch();
          _broadcastGoal();
          return;
        } else {
          ballVel = Offset(ballVel.dx, -ballVel.dy);
          AudioManager.instance.playPuckHit();
        }
      } else if (ballPos.dy >= 0.97) {
        if (ballPos.dx >= 0.35 && ballPos.dx <= 0.65) {
          scoreMagenta++;
          AudioManager.instance.playVictoryFanfare();
          _resetPitch();
          _broadcastGoal();
          return;
        } else {
          ballVel = Offset(ballVel.dx, -ballVel.dy);
          AudioManager.instance.playPuckHit();
        }
      }

      // 2. Move Pucks & Collide with Ball
      for (int i = 0; i < 5; i++) {
        teamCyan[i] += teamCyanVel[i];
        teamCyanVel[i] *= 0.96;
        _collideBall(teamCyan[i]);

        teamMagenta[i] += teamMagentaVel[i];
        teamMagentaVel[i] *= 0.96;
        _collideBall(teamMagenta[i]);
      }
    });
  }

  void _collideBall(Offset puck) {
    final dist = (puck - ballPos).distance;
    const minDist = 0.07;
    if (dist < minDist && dist > 0.001) {
      final normal = (ballPos - puck) / dist;
      ballVel = normal * 0.025;
      ballPos = puck + normal * minDist;
      AudioManager.instance.playPuckHit();
    }
  }

  void _resetPitch() {
    ballPos = const Offset(0.5, 0.5);
    ballVel = Offset.zero;
  }

  void _broadcastGoal() {
    if (widget.isSolo || widget.roomId == 'solo') return;
    MultiplayerSyncService.updateGameState(widget.roomId, {
      'scoreCyan': scoreCyan,
      'scoreMagenta': scoreMagenta,
      'isCyanTurn': isCyanTurn,
    });
  }

  void _applyRemoteShot(Map<String, dynamic> data) {
    if (data.containsKey('shot')) {
      final shot = data['shot'] as Map<dynamic, dynamic>;
      final isCyan = shot['isCyan'] as bool? ?? false;
      final int idx = (shot['puckIndex'] as num?)?.toInt() ?? 0;
      final double ix = (shot['impulseX'] as num?)?.toDouble() ?? 0.0;
      final double iy = (shot['impulseY'] as num?)?.toDouble() ?? 0.0;

      // Only apply if it's the opponent's shot
      if ((isCyan && widget.localSeat != 0) || (!isCyan && widget.localSeat != 1)) {
        setState(() {
          if (isCyan) {
            teamCyanVel[idx] = Offset(ix, iy);
          } else {
            teamMagentaVel[idx] = Offset(ix, iy);
          }
          isCyanTurn = !isCyan;
        });
      }
    }
    if (data.containsKey('scoreCyan')) {
      setState(() {
        scoreCyan = data['scoreCyan'] as int? ?? scoreCyan;
        scoreMagenta = data['scoreMagenta'] as int? ?? scoreMagenta;
      });
    }
  }

  void _onPanStart(DragStartDetails details, RenderBox box) {
    if (!isMyTurn) return;
    final normPos = Offset(
      details.localPosition.dx / box.size.width,
      details.localPosition.dy / box.size.height,
    );

    final targetTeam = isCyanTurn ? teamCyan : teamMagenta;
    for (int i = 0; i < targetTeam.length; i++) {
      if ((targetTeam[i] - normPos).distance < 0.08) {
        setState(() {
          activePuckIndex = i;
          dragVector = Offset.zero;
        });
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox box) {
    if (activePuckIndex == null) return;
    setState(() {
      dragVector = (dragVector ?? Offset.zero) -
          Offset(details.delta.dx / box.size.width, details.delta.dy / box.size.height);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (activePuckIndex == null || dragVector == null) return;

    final impulse = (dragVector! * 0.12);
    final shotTurn = isCyanTurn;
    final shotIdx = activePuckIndex!;

    setState(() {
      if (shotTurn) {
        teamCyanVel[shotIdx] = impulse;
      } else {
        teamMagentaVel[shotIdx] = impulse;
      }
      activePuckIndex = null;
      dragVector = null;
      isCyanTurn = !shotTurn;
    });

    if (!widget.isSolo && widget.roomId != 'solo') {
      MultiplayerSyncService.updateGameState(widget.roomId, {
        'shot': {
          'isCyan': shotTurn,
          'puckIndex': shotIdx,
          'impulseX': impulse.dx,
          'impulseY': impulse.dy,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'isCyanTurn': isCyanTurn,
        'scoreCyan': scoreCyan,
        'scoreMagenta': scoreMagenta,
      });
    }

    // AI bot turn in Solo Mode
    if (widget.isSolo) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _simulateBotTurn();
      });
    }
  }

  void _simulateBotTurn() {
    final botPuckIdx = Random().nextInt(5);
    final toBall = (ballPos - teamMagenta[botPuckIdx]);
    final impulse = (toBall / toBall.distance) * 0.022;

    setState(() {
      teamMagentaVel[botPuckIdx] = impulse;
      isCyanTurn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidSlate,
      appBar: AppBar(
        title: Text(widget.isSolo ? 'Stick Football (Solo vs AI)' : 'Stick Football: 1v1 Arena'),
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
              // Score HUD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CYAN (HOST): $scoreCyan',
                        style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isMyTurn ? AppColors.laserGreen.withOpacity(0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isMyTurn ? 'YOUR TURN' : 'OPPONENT AIMING...',
                        style: TextStyle(
                            color: isMyTurn ? AppColors.laserGreen : Colors.white54,
                            fontWeight: FontWeight.w900,
                            fontSize: 10),
                      ),
                    ),
                    Text(widget.isSolo ? 'AI: $scoreMagenta' : 'MAGENTA: $scoreMagenta',
                        style: const TextStyle(
                            color: AppColors.arcadeMagenta,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ),

              // Pitch
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanStart: (d) => _onPanStart(d, context.findRenderObject() as RenderBox),
                        onPanUpdate: (d) => _onPanUpdate(d, context.findRenderObject() as RenderBox),
                        onPanEnd: _onPanEnd,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4D2E), // Turf green
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: CustomPaint(
                            painter: _PitchPainter(
                              ball: ballPos,
                              cyan: teamCyan,
                              magenta: teamMagenta,
                              activeIdx: activePuckIndex,
                              dragVec: dragVector,
                              isCyanTurn: isCyanTurn,
                            ),
                            size: Size.infinite,
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
}

class _PitchPainter extends CustomPainter {
  final Offset ball;
  final List<Offset> cyan;
  final List<Offset> magenta;
  final int? activeIdx;
  final Offset? dragVec;
  final bool isCyanTurn;

  _PitchPainter({
    required this.ball,
    required this.cyan,
    required this.magenta,
    this.activeIdx,
    this.dragVec,
    required this.isCyanTurn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Center Line & Circle
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), linePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.18, linePaint);

    // Goal Boxes
    canvas.drawRect(Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height * 0.12), linePaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.3, size.height * 0.88, size.width * 0.4, size.height * 0.12), linePaint);

    // Ball
    final bOffset = Offset(ball.dx * size.width, ball.dy * size.height);
    canvas.drawCircle(bOffset, 10, Paint()..color = Colors.white);
    canvas.drawCircle(bOffset, 10, linePaint..strokeWidth = 1.5..color = Colors.black);

    // Cyan Pucks
    for (int i = 0; i < cyan.length; i++) {
      final offset = Offset(cyan[i].dx * size.width, cyan[i].dy * size.height);
      canvas.drawCircle(offset, 14, Paint()..color = AppColors.neonCyan);
      canvas.drawCircle(offset, 6, Paint()..color = Colors.white);

      if (isCyanTurn && activeIdx == i && dragVec != null) {
        final aimEnd = offset + Offset(dragVec!.dx * size.width * 0.8, dragVec!.dy * size.height * 0.8);
        canvas.drawLine(
          offset,
          aimEnd,
          Paint()..color = Colors.yellowAccent..strokeWidth = 3.0,
        );
      }
    }

    // Magenta Pucks
    for (int i = 0; i < magenta.length; i++) {
      final offset = Offset(magenta[i].dx * size.width, magenta[i].dy * size.height);
      canvas.drawCircle(offset, 14, Paint()..color = AppColors.arcadeMagenta);
      canvas.drawCircle(offset, 6, Paint()..color = Colors.white);

      if (!isCyanTurn && activeIdx == i && dragVec != null) {
        final aimEnd = offset + Offset(dragVec!.dx * size.width * 0.8, dragVec!.dy * size.height * 0.8);
        canvas.drawLine(
          offset,
          aimEnd,
          Paint()..color = Colors.yellowAccent..strokeWidth = 3.0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
