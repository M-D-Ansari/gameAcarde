import 'dart:math';
import 'package:flutter/foundation.dart';

@immutable
class NormalizedPoint {
  final double x;
  final double y;

  const NormalizedPoint(this.x, this.y);

  NormalizedPoint clampTo({
    double minX = 0.0,
    double maxX = 1.0,
    double minY = 0.0,
    double maxY = 1.0,
  }) {
    return NormalizedPoint(
      x.clamp(minX, maxX),
      y.clamp(minY, maxY),
    );
  }

  NormalizedPoint lerpTo(NormalizedPoint target, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return NormalizedPoint(
      x + (target.x - x) * clampedT,
      y + (target.y - y) * clampedT,
    );
  }

  double distanceTo(NormalizedPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  Map<String, dynamic> toMap() => {'x': x, 'y': y};

  factory NormalizedPoint.fromMap(Map<dynamic, dynamic> map) {
    return NormalizedPoint(
      (map['x'] as num?)?.toDouble() ?? 0.0,
      (map['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() => 'NormalizedPoint($x, $y)';
}

