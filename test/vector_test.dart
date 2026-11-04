import 'package:flutter_test/flutter_test.dart';
import 'package:mini_arcade_hub/core/utils/vector_utils.dart';

void main() {
  group('NormalizedPoint Math & Interpolation Tests', () {
    test('Clamping enforces min and max coordinate bounds', () {
      const p = NormalizedPoint(-0.5, 1.8);
      final clamped = p.clampTo(minX: 0.0, maxX: 1.0, minY: 0.0, maxY: 1.0);

      expect(clamped.x, equals(0.0));
      expect(clamped.y, equals(1.0));
    });

    test('LERP interpolation produces expected midpoint at t=0.5', () {
      const start = NormalizedPoint(0.0, 0.0);
      const end = NormalizedPoint(1.0, 1.0);

      final mid = start.lerpTo(end, 0.5);
      expect(mid.x, closeTo(0.5, 0.0001));
      expect(mid.y, closeTo(0.5, 0.0001));
    });

    test('Map serialization and deserialization roundtrip', () {
      const original = NormalizedPoint(0.452, 0.891);
      final map = original.toMap();
      final restored = NormalizedPoint.fromMap(map);

      expect(restored.x, closeTo(original.x, 0.0001));
      expect(restored.y, closeTo(original.y, 0.0001));
    });
  });
}

