import 'package:flutter/material.dart';

class TableActionWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Function()? onPressed;
  final String? tooltip;
  const TableActionWidget({
    super.key,
    required this.icon,
    required this.color,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 14, color: color),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: color.withAlpha(40),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
