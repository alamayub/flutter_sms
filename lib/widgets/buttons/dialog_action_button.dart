import 'package:flutter/material.dart';

import '../../config/typo_config.dart';

class DialogActionButton extends StatelessWidget {
  final Color color;
  final String title;
  final Function() onPressed;
  const DialogActionButton({
    super.key,
    required this.color,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: color.withAlpha(40),
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
            color: color,
          ),
        ),
      ),
    );
  }
}
