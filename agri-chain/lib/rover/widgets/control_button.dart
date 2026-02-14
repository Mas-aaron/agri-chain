import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final bool isPressed;
  final Color color;
  final double size;

  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTapDown,
    required this.onTapUp,
    required this.isPressed,
    required this.color,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPressed
                ? [color.withOpacity(0.8), color]
                : [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: isPressed ? 5 : 10,
              offset: Offset(0, isPressed ? 2 : 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: size * 0.4,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
