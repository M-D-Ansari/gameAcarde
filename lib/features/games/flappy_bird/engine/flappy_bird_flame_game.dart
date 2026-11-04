import 'dart:async';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/multiplayer_sync_service.dart';
import '../../../../core/utils/prng_generator.dart';

class FlappyBirdFlameGame extends FlameGame with TapCallbacks, KeyboardEvents {
  final String roomId;
  final int seed;
  final int localSeat;
  final VoidCallback? onGameOver;

  FlappyBirdFlameGame({
    required this.roomId,
    required this.seed,
    required this.localSeat,
    this.onGameOver,
  });

  late SeededPRNG _prng;
  StreamSubscription<Map<String, dynamic>?>? _opponentSub;

  // Local Bird Physics
  double birdY = 0.5;
  double birdVelocity = 0.0;
  static const double gravity = 1.8;
  static const double jumpImpulse = -0.65;
  bool isAlive = true;
  double distanceTravelled = 0.0;

  // Remote Ghost Bird
  double ghostY = 0.5;
  double ghostDistance = 0.0;
  bool ghostAlive = true;

  // Pipes generated deterministically via PRNG
  final List<Rect> topPipes = [];
  final List<Rect> btmPipes = [];
  double nextPipeX = 1.2;

  int _lastNetworkWrite = 0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _prng = SeededPRNG(seed);

    for (int i = 0; i < 5; i++) {
      _spawnPipe();
    }

    if (roomId != 'solo') {
      final opponentSeat = localSeat == 0 ? 1 : 0;

      // Listen directly to opponent's dedicated seat channel with 0 lock contention
      _opponentSub = MultiplayerSyncService.watchSeatStream(roomId, opponentSeat).listen((data) {
        if (data == null) return;
        ghostY = (data['y'] as num?)?.toDouble() ?? ghostY;
        ghostDistance = (data['dist'] as num?)?.toDouble() ?? ghostDistance;
        ghostAlive = data['alive'] as bool? ?? true;
      });
    }
  }

  @override
  void onRemove() {
    _opponentSub?.cancel();
    super.onRemove();
  }

  void _spawnPipe() {
    final gapY = _prng.nextDouble() * 0.35 + 0.3;
    const gapSize = 0.28;

    topPipes.add(
        Rect.fromLTRB(nextPipeX, 0.0, nextPipeX + 0.14, gapY - gapSize / 2));
    btmPipes.add(
        Rect.fromLTRB(nextPipeX, gapY + gapSize / 2, nextPipeX + 0.14, 1.0));
    nextPipeX += 0.45;
  }

  void _flap() {
    if (!isAlive) return;
    birdVelocity = jumpImpulse;
  }

  @override
  void onTapDown(TapDownEvent event) {
    _flap();
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        _flap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isAlive) return;

    birdVelocity += gravity * dt;
    birdY += birdVelocity * dt;
    distanceTravelled += dt * 0.4;

    for (int i = 0; i < topPipes.length; i++) {
      topPipes[i] = topPipes[i].translate(-dt * 0.4, 0);
      btmPipes[i] = btmPipes[i].translate(-dt * 0.4, 0);
    }
    nextPipeX -= dt * 0.4;

    if (topPipes.isNotEmpty && topPipes.first.right < 0) {
      topPipes.removeAt(0);
      btmPipes.removeAt(0);
      _spawnPipe();
    }

    if (birdY <= 0.03 || birdY >= 0.97) {
      _die();
      return;
    }

    final birdRect =
        Rect.fromCircle(center: Offset(0.25, birdY), radius: 0.035);
    for (int i = 0; i < topPipes.length; i++) {
      if (topPipes[i].overlaps(birdRect) || btmPipes[i].overlaps(birdRect)) {
        _die();
        return;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNetworkWrite > 35 && roomId != 'solo') {
      _lastNetworkWrite = now;
      MultiplayerSyncService.updateSeatStream(roomId, localSeat, {
        'y': birdY,
        'dist': distanceTravelled,
        'alive': isAlive,
        't': now,
      });
    }
  }

  void _die() {
    isAlive = false;
    if (roomId != 'solo') {
      MultiplayerSyncService.updateSeatStream(roomId, localSeat, {
        'y': birdY,
        'dist': distanceTravelled,
        'alive': false,
        't': DateTime.now().millisecondsSinceEpoch,
      });
    }
    onGameOver?.call();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;

    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final pipePaint = Paint()..color = const Color(0xFF10B981);
    for (int i = 0; i < topPipes.length; i++) {
      canvas.drawRect(
        Rect.fromLTRB(
          topPipes[i].left * w,
          topPipes[i].top * h,
          topPipes[i].right * w,
          topPipes[i].bottom * h,
        ),
        pipePaint,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          btmPipes[i].left * w,
          btmPipes[i].top * h,
          btmPipes[i].right * w,
          btmPipes[i].bottom * h,
        ),
        pipePaint,
      );
    }

    // Remote Ghost
    if (ghostAlive) {
      final ghostPaint = Paint()
        ..color = const Color(0xFFF355DA).withValues(alpha: 0.5);
      canvas.drawCircle(Offset(0.25 * w, ghostY * h), 0.035 * w, ghostPaint);
    }

    // Local Bird
    if (isAlive) {
      final localPaint = Paint()..color = const Color(0xFF00F2FE);
      canvas.drawCircle(Offset(0.25 * w, birdY * h), 0.035 * w, localPaint);
      canvas.drawCircle(Offset(0.25 * w, birdY * h), 0.015 * w,
          Paint()..color = Colors.white);
    }
  }
}
