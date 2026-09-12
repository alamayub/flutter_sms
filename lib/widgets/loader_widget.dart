import 'package:flutter/material.dart';

class LoaderWidget extends StatelessWidget {
  final Color? color;
  final Color? valueColor;
  final double? strokeWidth;
  const LoaderWidget({
    super.key,
    this.color = Colors.white,
    this.valueColor,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: color,
        valueColor:
            valueColor != null
                ? AlwaysStoppedAnimation<Color>(valueColor!)
                : null,
        strokeWidth: strokeWidth,
      ),
    );
  }
}
