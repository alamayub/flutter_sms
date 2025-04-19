import 'package:flutter/material.dart';

import '../../config/theme.dart' show ColorConstants;

class LoaderWidget extends StatelessWidget {
  final Color? color;
  final double? value;
  const LoaderWidget({
    super.key,
    this.color = ColorConstants.primary,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.scale(
        scale: .5,
        child: CircularProgressIndicator(color: color, value: value),
      ),
    );
  }
}
