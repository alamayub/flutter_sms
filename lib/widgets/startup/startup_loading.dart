



import 'package:flutter/material.dart';

import '../generic/loader_widget.dart';
import 'startup_widget.dart';

class StartupLoading extends StatelessWidget {
  const StartupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return StartupWidget(
      widget: Center(child: LoaderWidget(color: Colors.white)),
    );
  }
}