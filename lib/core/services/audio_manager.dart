import 'package:flutter/services.dart';

class AudioManager {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal();

  bool isMuted = false;

  void toggleMute() {
    isMuted = !isMuted;
  }

  void playDiceRoll() {
    if (isMuted) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void playPuckHit() {
    if (isMuted) return;
    HapticFeedback.lightImpact();
  }

  void playGoalScored() {
    if (isMuted) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void playTokenCapture() {
    if (isMuted) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void playVictoryFanfare() {
    if (isMuted) return;
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
  }
}

