import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import '../theme/app_theme.dart';

class PhysicalModeSwitch extends StatelessWidget {
  final bool isMultiplayer;
  final ValueChanged<bool> onChanged;

  const PhysicalModeSwitch({
    super.key,
    required this.isMultiplayer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.recessedSlot,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.consoleBevel, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            offset: const Offset(0, 3),
            blurRadius: 4,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.04),
            offset: const Offset(0, -1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Solo Button (Default)
          Expanded(
            child: _buildThumb(
              title: 'SOLO ARCADE',
              icon: Icons.sports_esports,
              isActive: !isMultiplayer,
              activeColor: AppColors.electricCyan,
              onTap: () {
                if (isMultiplayer) {
                  AudioManager.instance.playDiceRoll();
                  onChanged(false);
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          // Multiplayer Button
          Expanded(
            child: _buildThumb(
              title: 'MULTIPLAYER',
              icon: Icons.wifi_tethering,
              isActive: isMultiplayer,
              activeColor: AppColors.arcadeMagenta,
              onTap: () {
                if (!isMultiplayer) {
                  AudioManager.instance.playDiceRoll();
                  onChanged(true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb({
    required String title,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    activeColor.withOpacity(0.9),
                    activeColor.withRed((activeColor.red - 20).clamp(0, 255)),
                  ],
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.4),
                    offset: const Offset(0, 1),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.black : Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white54,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

