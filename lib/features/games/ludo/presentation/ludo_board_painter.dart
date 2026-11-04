import 'package:flutter/material.dart';
import '../domain/ludo_game_state.dart';
import '../domain/ludo_rules_engine.dart';

class LudoBoardPainter extends CustomPainter {
  final LudoGameState gameState;
  final int localSeat;
  final Function(int tokenIndex)? onTokenTapped;

  LudoBoardPainter({
    required this.gameState,
    required this.localSeat,
    this.onTokenTapped,
  });

  static const Color greenColor = Color(0xFF10B981);
  static const Color yellowColor = Color(0xFFFBBF24);
  static const Color blueColor = Color(0xFF3B82F6);
  static const Color redColor = Color(0xFFEF4444);

  static const List<Color> seatColors = [
    greenColor,
    yellowColor,
    blueColor,
    redColor
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.width / 15.0;

    // Draw background board grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gridPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 1. Draw 4 Bases / Yards (6x6 cells each)
    _drawBase(canvas, 0, 0, cellSize, greenColor, 'Green Yard');
    _drawBase(canvas, 9 * cellSize, 0, cellSize, yellowColor, 'Yellow Yard');
    _drawBase(
        canvas, 9 * cellSize, 9 * cellSize, cellSize, blueColor, 'Blue Yard');
    _drawBase(canvas, 0, 9 * cellSize, cellSize, redColor, 'Red Yard');

    // 2. Draw Center Home Triangle
    final centerPath = Path();
    final double mid = size.width / 2.0;
    centerPath.moveTo(6 * cellSize, 6 * cellSize);
    centerPath.lineTo(9 * cellSize, 6 * cellSize);
    centerPath.lineTo(mid, mid);
    centerPath.close();
    canvas.drawPath(
        centerPath, Paint()..color = yellowColor.withValues(alpha: 0.8));

    final rightPath = Path();
    rightPath.moveTo(9 * cellSize, 6 * cellSize);
    rightPath.lineTo(9 * cellSize, 9 * cellSize);
    rightPath.lineTo(mid, mid);
    rightPath.close();
    canvas.drawPath(
        rightPath, Paint()..color = blueColor.withValues(alpha: 0.8));

    final bottomPath = Path();
    bottomPath.moveTo(9 * cellSize, 9 * cellSize);
    bottomPath.lineTo(6 * cellSize, 9 * cellSize);
    bottomPath.lineTo(mid, mid);
    bottomPath.close();
    canvas.drawPath(
        bottomPath, Paint()..color = redColor.withValues(alpha: 0.8));

    final leftPath = Path();
    leftPath.moveTo(6 * cellSize, 9 * cellSize);
    leftPath.lineTo(6 * cellSize, 6 * cellSize);
    leftPath.lineTo(mid, mid);
    leftPath.close();
    canvas.drawPath(
        leftPath, Paint()..color = greenColor.withValues(alpha: 0.8));

    // 3. Draw grid lines for cross tracks
    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        // Skip yard bases and center home
        if ((r < 6 && c < 6) ||
            (r < 6 && c >= 9) ||
            (r >= 9 && c < 6) ||
            (r >= 9 && c >= 9)) continue;
        if (r >= 6 && r < 9 && c >= 6 && c < 9) continue;

        final cellRect =
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);

        // Highlight home columns
        if (r == 7 && c >= 1 && c <= 5) {
          canvas.drawRect(
              cellRect, Paint()..color = greenColor.withValues(alpha: 0.5));
        } else if (c == 7 && r >= 1 && r <= 5) {
          canvas.drawRect(
              cellRect, Paint()..color = yellowColor.withValues(alpha: 0.5));
        } else if (r == 7 && c >= 9 && c <= 13) {
          canvas.drawRect(
              cellRect, Paint()..color = blueColor.withValues(alpha: 0.5));
        } else if (c == 7 && r >= 9 && r <= 13) {
          canvas.drawRect(
              cellRect, Paint()..color = redColor.withValues(alpha: 0.5));
        }

        canvas.drawRect(cellRect, borderPaint);
      }
    }

    // 4. Draw Tokens
    gameState.playerTokens.forEach((seat, tokens) {
      final color = seatColors[seat];
      for (int t = 0; t < tokens.length; t++) {
        final token = tokens[t];
        final Offset pos = _getTokenCoordinates(seat, t, token, cellSize, size);

        // Draw shadow / glow
        canvas.drawCircle(
            pos, cellSize * 0.38, Paint()..color = Colors.black45);
        canvas.drawCircle(pos, cellSize * 0.34, Paint()..color = color);
        canvas.drawCircle(
            pos, cellSize * 0.22, Paint()..color = Colors.white70);

        // If it's local player's turn and can move, add pulsating ring
        if (seat == localSeat &&
            gameState.currentTurnSeat == localSeat &&
            gameState.hasRolled) {
          if (LudoRulesEngine.canTokenMove(token, gameState.diceRoll)) {
            final activeRingPaint = Paint()
              ..color = Colors.amberAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0;
            canvas.drawCircle(pos, cellSize * 0.44, activeRingPaint);
          }
        }
      }
    });
  }

  void _drawBase(Canvas canvas, double x, double y, double cellSize,
      Color color, String label) {
    final rect = Rect.fromLTWH(x, y, 6 * cellSize, 6 * cellSize);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    final innerRect =
        Rect.fromLTWH(x + cellSize, y + cellSize, 4 * cellSize, 4 * cellSize);
    canvas.drawRect(innerRect, Paint()..color = const Color(0xFF0F172A));

    // Draw 4 token base spots
    final spotOffsets = [
      Offset(x + 2 * cellSize, y + 2 * cellSize),
      Offset(x + 4 * cellSize, y + 2 * cellSize),
      Offset(x + 2 * cellSize, y + 4 * cellSize),
      Offset(x + 4 * cellSize, y + 4 * cellSize),
    ];
    for (final spot in spotOffsets) {
      canvas.drawCircle(
          spot, cellSize * 0.45, Paint()..color = color.withValues(alpha: 0.4));
      canvas.drawCircle(
          spot,
          cellSize * 0.45,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  Offset _getTokenCoordinates(
      int seat, int tokenIdx, LudoToken token, double cellSize, Size size) {
    if (token.isInYard) {
      // Return fixed base spot
      final double baseX = (seat == 0 || seat == 3) ? 0 : 9 * cellSize;
      final double baseY = (seat == 0 || seat == 1) ? 0 : 9 * cellSize;
      final spots = [
        Offset(baseX + 2 * cellSize, baseY + 2 * cellSize),
        Offset(baseX + 4 * cellSize, baseY + 2 * cellSize),
        Offset(baseX + 2 * cellSize, baseY + 4 * cellSize),
        Offset(baseX + 4 * cellSize, baseY + 4 * cellSize),
      ];
      return spots[tokenIdx];
    }

    if (token.isHome) {
      return Offset(size.width / 2.0, size.height / 2.0);
    }

    // Mapping step (0..55) to 2D board coordinates
    final int cell = LudoRulesEngine.getGlobalBoardTile(seat, token.stepIndex);
    return _mapGlobalTileToOffset(cell, cellSize, size);
  }

  Offset _mapGlobalTileToOffset(int tileIndex, double cellSize, Size size) {
    if (tileIndex < 0) return Offset(size.width / 2, size.height / 2);

    // Coordinate table for 52-tile track [col, row]
    const track = [
      [1, 6],
      [2, 6],
      [3, 6],
      [4, 6],
      [5, 6],
      [6, 5],
      [6, 4],
      [6, 3],
      [6, 2],
      [6, 1],
      [6, 0],
      [7, 0],
      [8, 0],
      [8, 1],
      [8, 2],
      [8, 3],
      [8, 4],
      [8, 5],
      [9, 6],
      [10, 6],
      [11, 6],
      [12, 6],
      [13, 6],
      [14, 6],
      [14, 7],
      [14, 8],
      [13, 8],
      [12, 8],
      [11, 8],
      [10, 8],
      [9, 8],
      [8, 9],
      [8, 10],
      [8, 11],
      [8, 12],
      [8, 13],
      [8, 14],
      [7, 14],
      [6, 14],
      [6, 13],
      [6, 12],
      [6, 11],
      [6, 10],
      [6, 9],
      [5, 8],
      [4, 8],
      [3, 8],
      [2, 8],
      [1, 8],
      [0, 8],
      [0, 7],
      [0, 6],
    ];

    final coord = track[tileIndex % track.length];
    return Offset(
      (coord[0] + 0.5) * cellSize,
      (coord[1] + 0.5) * cellSize,
    );
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter oldDelegate) => true;
}
