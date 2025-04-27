import 'package:flutter/material.dart';

class TableActionWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Function() onPressed;
  const TableActionWidget({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
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
