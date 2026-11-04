import 'dart:async';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/services/multiplayer_sync_service.dart';

class AirHockeyFlameGame extends FlameGame with PanDetector, MouseMovementDetector {
  final String roomId;
  final int localSeatIndex; // 0: Bottom (Local), 1: Top (Remote)
  final bool isHost;
  final bool isSolo;
  final VoidCallback? onGoalScored;

  AirHockeyFlameGame({
    required this.roomId,
    required this.localSeatIndex,
    required this.isHost,
    this.isSolo = false,
    this.onGoalScored,
  });

  StreamSubscription<Map<String, dynamic>?>? _remotePaddleSub;
  StreamSubscription<Map<String, dynamic>?>? _physicsSub;

  Vector2 localPaddle = Vector2(0.5, 0.85);
  Vector2 remotePaddleTarget = Vector2(0.5, 0.15);
  Vector2 remotePaddleRender = Vector2(0.5, 0.15);

  Vector2 puckPosition = Vector2(0.5, 0.5);
  Vector2 puckVelocity = Vector2(0.0, 0.0);

  int scoreHost = 0;
  int scoreGuest = 0;

  int _lastNetworkWrite = 0;
  int _lastPaddleWrite = 0;
  static const int kNetworkIntervalMs = 35; // ~28Hz smooth stream

  @override
  Future<void> onLoad() async {
    super.onLoad();
    if (!isSolo && roomId != 'solo') {
      final int remoteSeat = (localSeatIndex == 0) ? 1 : 0;

      // Stream remote paddle in real-time from opponent's seat channel
      _remotePaddleSub = MultiplayerSyncService.watchSeatStream(roomId, remoteSeat).listen((data) {
        if (data == null) return;
        final double rx = (data['x'] as num?)?.toDouble() ?? 0.5;
        final double ry = (data['y'] as num?)?.toDouble() ?? 0.15;

        remotePaddleTarget = Vector2(
          localSeatIndex == 0 ? rx : 1.0 - rx,
          localSeatIndex == 0 ? ry : 1.0 - ry,
        );
      });

      // Stream authoritative puck physics & scores (Host -> Guest)
      if (!isHost) {
        _physicsSub = MultiplayerSyncService.watchPhysicsStream(roomId).listen((data) {
          if (data == null) return;
          final double px = (data['x'] as num?)?.toDouble() ?? 0.5;
          final double py = (data['y'] as num?)?.toDouble() ?? 0.5;
          final double pvx = (data['vx'] as num?)?.toDouble() ?? 0.0;
          final double pvy = (data['vy'] as num?)?.toDouble() ?? 0.0;

          final targetPos = Vector2(
            localSeatIndex == 0 ? px : 1.0 - px,
            localSeatIndex == 0 ? py : 1.0 - py,
          );

          // Smooth interpolation & dead reckoning velocity update
          puckPosition.lerp(targetPos, 0.55);
          puckVelocity = Vector2(
            localSeatIndex == 0 ? pvx : -pvx,
            localSeatIndex == 0 ? pvy : -pvy,
          );

          scoreHost = (data['scoreHost'] as num?)?.toInt() ?? scoreHost;
          scoreGuest = (data['scoreGuest'] as num?)?.toInt() ?? scoreGuest;
          onGoalScored?.call();
        });
      }
    }
  }

  @override
  void onRemove() {
    _remotePaddleSub?.cancel();
    _physicsSub?.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isSolo) {
      // Dynamic AI paddle in Solo
      double targetX = puckPosition.x;
      double targetY = (puckPosition.y < 0.5)
          ? (puckPosition.y - 0.07).clamp(0.08, 0.44)
          : 0.16;
      remotePaddleRender.x += (targetX - remotePaddleRender.x) * (dt * 7.5).clamp(0.0, 1.0);
      remotePaddleRender.y += (targetY - remotePaddleRender.y) * (dt * 6.5).clamp(0.0, 1.0);
    } else {
      remotePaddleRender.lerp(remotePaddleTarget, (dt * 30.0).clamp(0.0, 1.0));
    }

    if (isHost || isSolo) {
      _simulateAuthoritativePhysics(dt);
    } else {
      // Dead reckoning for guest: keep puck gliding smoothly between network ticks
      puckPosition += puckVelocity * dt;
      puckVelocity *= (1.0 - (0.45 * dt)).clamp(0.0, 1.0);
    }
  }

  void _simulateAuthoritativePhysics(double dt) {
    puckPosition += puckVelocity * dt;

    // Wall Bounces with audio impact
    if (puckPosition.x <= 0.05 || puckPosition.x >= 0.95) {
      puckVelocity.x = -puckVelocity.x * 0.98;
      puckPosition.x = puckPosition.x.clamp(0.05, 0.95);
      AudioManager.instance.playPuckHit();
    }

    // Goal Check or Top/Bottom Wall Bounce
    if (puckPosition.y <= 0.04) {
      if (puckPosition.x >= 0.35 && puckPosition.x <= 0.65) {
        // Goal scored on Guest/Top
        scoreHost++;
        AudioManager.instance.playVictoryFanfare();
        onGoalScored?.call();
        _resetPuck();
      } else {
        puckVelocity.y = -puckVelocity.y * 0.98;
        puckPosition.y = 0.05;
        AudioManager.instance.playPuckHit();
      }
    } else if (puckPosition.y >= 0.96) {
      if (puckPosition.x >= 0.35 && puckPosition.x <= 0.65) {
        // Goal scored on Host/Bottom
        scoreGuest++;
        AudioManager.instance.playVictoryFanfare();
        onGoalScored?.call();
        _resetPuck();
      } else {
        puckVelocity.y = -puckVelocity.y * 0.98;
        puckPosition.y = 0.95;
        AudioManager.instance.playPuckHit();
      }
    }

    // Friction
    puckVelocity *= (1.0 - (0.45 * dt)).clamp(0.0, 1.0);

    // Collisions with local & remote paddles
    _checkPaddleCollision(localPaddle);
    _checkPaddleCollision(remotePaddleRender);

    // Host broadcasts puck position and score directly to dedicated physics stream
    if (!isSolo && isHost) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastNetworkWrite > kNetworkIntervalMs) {
        _lastNetworkWrite = now;
        MultiplayerSyncService.updatePhysicsStream(roomId, {
          'x': puckPosition.x,
          'y': puckPosition.y,
          'vx': puckVelocity.x,
          'vy': puckVelocity.y,
          'scoreHost': scoreHost,
          'scoreGuest': scoreGuest,
          't': now,
        });
      }
    }
  }

  void _checkPaddleCollision(Vector2 paddle) {
    final double dist = puckPosition.distanceTo(paddle);
    const double radiusPuck = 0.05;
    const double radiusPaddle = 0.08;
    const double minDist = radiusPuck + radiusPaddle;

    if (dist < minDist && dist > 0.001) {
      final Vector2 normal = (puckPosition - paddle)..normalize();
      puckVelocity = normal * 1.1; // Punchy rebound
      puckPosition = paddle + normal * minDist;
      AudioManager.instance.playPuckHit();
    }
  }

  void _resetPuck() {
    puckPosition = Vector2(0.5, 0.5);
    puckVelocity = Vector2(0.0, 0.0);
  }

  void _processInput(Vector2 screenPosition) {
    final Vector2 gameSize = size;
    if (gameSize.x <= 0 || gameSize.y <= 0) return;

    final double rawNormX = (screenPosition.x / gameSize.x).clamp(0.08, 0.92);
    final double rawNormY = (screenPosition.y / gameSize.y);

    final double clampedY = (localSeatIndex == 0)
        ? rawNormY.clamp(0.53, 0.92)
        : rawNormY.clamp(0.08, 0.47);

    localPaddle = Vector2(rawNormX, clampedY);

    if (!isSolo) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPaddleWrite > kNetworkIntervalMs) {
        _lastPaddleWrite = now;
        MultiplayerSyncService.updateSeatStream(roomId, localSeatIndex, {
          'x': localPaddle.x,
          'y': localPaddle.y,
          't': now,
        });
      }
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _processInput(info.eventPosition.widget);
  }

  @override
  void onMouseMove(PointerHoverInfo info) {
    _processInput(info.eventPosition.widget);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final double w = size.x;
    final double h = size.y;

    // 1. Table Rink
    final rinkPaint = Paint()..color = const Color(0xFF101721);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(8, 8, w - 16, h - 16), const Radius.circular(24)),
      rinkPaint,
    );

    // Center divider & circle
    final linePaint = Paint()
      ..color = const Color(0xFF1E2C3D)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(8, h * 0.5), Offset(w - 8, h * 0.5), linePaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.18, linePaint..style = PaintingStyle.stroke);

    // Goals
    final goalPaintTop = Paint()..color = const Color(0xFFFF0055).withOpacity(0.5);
    final goalPaintBottom = Paint()..color = const Color(0xFF00F0FF).withOpacity(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.35, 8, w * 0.3, 10), const Radius.circular(4)),
      goalPaintTop,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.35, h - 18, w * 0.3, 10), const Radius.circular(4)),
      goalPaintBottom,
    );

    // Remote Paddle (Top - Magenta)
    final remoteX = (localSeatIndex == 0 ? remotePaddleRender.x : 1.0 - remotePaddleRender.x) * w;
    final remoteY = (localSeatIndex == 0 ? remotePaddleRender.y : 1.0 - remotePaddleRender.y) * h;
    _drawPaddle(canvas, Offset(remoteX, remoteY), const Color(0xFFFF0055), isLocal: false);

    // Local Paddle (Bottom - Cyan)
    final localX = localPaddle.x * w;
    final localY = localPaddle.y * h;
    _drawPaddle(canvas, Offset(localX, localY), const Color(0xFF00F0FF), isLocal: true);

    // Puck (Yellow Glowing Disc)
    final px = (localSeatIndex == 0 ? puckPosition.x : 1.0 - puckPosition.x) * w;
    final py = (localSeatIndex == 0 ? puckPosition.y : 1.0 - puckPosition.y) * h;
    final puckPaint = Paint()
      ..color = const Color(0xFFFFDD00)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawCircle(Offset(px, py), w * 0.05, puckPaint);
    canvas.drawCircle(Offset(px, py), w * 0.03, Paint()..color = Colors.white);
  }

  void _drawPaddle(Canvas canvas, Offset pos, Color color, {required bool isLocal}) {
    final double radius = size.x * 0.075;
    // Glow
    canvas.drawCircle(
      pos,
      radius + 4,
      Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Outer body
    canvas.drawCircle(
      pos,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0.7), Colors.black],
        ).createShader(Rect.fromCircle(center: pos, radius: radius)),
    );
    // Handle
    canvas.drawCircle(pos, radius * 0.45, Paint()..color = Colors.white70);
  }
}
