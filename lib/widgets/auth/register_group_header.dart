import 'package:flutter/material.dart';

import '../../config/extensions.dart';

class RegisterGroupHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const RegisterGroupHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 16, color: context.theme.colorScheme.primary),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: context.theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
