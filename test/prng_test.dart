import 'package:flutter_test/flutter_test.dart';
import 'package:mini_arcade_hub/core/utils/prng_generator.dart';

void main() {
  group('SeededPRNG Determinism Tests', () {
    test('Two PRNG instances with identical seeds produce identical sequence', () {
      const seed = 987654321;
      final prng1 = SeededPRNG(seed);
      final prng2 = SeededPRNG(seed);

      final seq1 = List.generate(50, (_) => prng1.nextDouble());
      final seq2 = List.generate(50, (_) => prng2.nextDouble());

      expect(seq1, equals(seq2));
    });

    test('Resetting PRNG reproduces the same sequence', () {
      final prng = SeededPRNG(42);
      final firstPass = List.generate(20, (_) => prng.nextIntInRange(10, 100));

      prng.reset();
      final secondPass = List.generate(20, (_) => prng.nextIntInRange(10, 100));

      expect(firstPass, equals(secondPass));
    });

    test('Different seeds produce different sequences', () {
      final prng1 = SeededPRNG(1111);
      final prng2 = SeededPRNG(2222);

      final seq1 = List.generate(10, (_) => prng1.nextDouble());
      final seq2 = List.generate(10, (_) => prng2.nextDouble());

      expect(seq1, isNot(equals(seq2)));
    });
  });
}

