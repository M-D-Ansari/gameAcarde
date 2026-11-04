import 'package:flutter/material.dart';
import '../services/audio_manager.dart';
import '../theme/app_theme.dart';

class TactileArcadeButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color baseColor;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;

  const TactileArcadeButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.baseColor = AppColors.electricCyan,
    this.height = 46.0,
    this.radius = 14.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<TactileArcadeButton> createState() => _TactileArcadeButtonState();
}

class _TactileArcadeButtonState extends State<TactileArcadeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled
          ? (_) {
              setState(() => _isPressed = true);
              AudioManager.instance.playPuckHit();
            }
          : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOutQuad,
        height: widget.height,
        padding: widget.padding,
        transform: Matrix4.translationValues(0, _isPressed ? 3.0 : 0.0, 0),
        decoration: SkeuomorphicDecorations.arcadeButton(
          baseColor: isEnabled ? widget.baseColor : Colors.white24,
          isPressed: _isPressed,
          radius: widget.radius,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

