import 'dart:math';

/// A deterministic pseudo-random number generator utilizing a shared seed.
/// Used for deterministic procedural generation across multiple clients
/// (e.g., Flappy Bird pipe layouts, Street Dash obstacle lanes, Stack Animals queues).
class SeededPRNG {
  late Random _random;
  final int seed;

  SeededPRNG(this.seed) {
    _random = Random(seed);
  }

  void reset() {
    _random = Random(seed);
  }

  /// Returns a double in the range [0.0, 1.0)
  double nextDouble() => _random.nextDouble();

  /// Returns an integer in range [min, max] inclusive
  int nextIntInRange(int min, int max) {
    if (min >= max) return min;
    return min + _random.nextInt(max - min + 1);
  }

  /// Returns a boolean with the specified probability of being true
  bool nextBool([double chanceOfTrue = 0.5]) {
    return _random.nextDouble() < chanceOfTrue;
  }

  /// Selects a deterministic item from a list
  T choice<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('Items list cannot be empty');
    return items[_random.nextInt(items.length)];
  }
}

