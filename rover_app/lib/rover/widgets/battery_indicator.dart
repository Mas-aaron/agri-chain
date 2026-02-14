import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int level;
  final double size;

  const BatteryIndicator({
    super.key,
    required this.level,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    if (level > 60) {
      color = Colors.green;
    } else if (level > 20) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 0.6,
          height: size * 0.3,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: (level.clamp(0, 100)) / 100,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: size * 0.1,
          height: size * 0.1,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(2),
              bottomRight: Radius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: size * 0.4,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
