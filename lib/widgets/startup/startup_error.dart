import 'package:flutter/material.dart';

import '../../config/typo_config.dart';
import 'startup_widget.dart';

class StartupError extends StatelessWidget {
  final Object error;
  final Function() onRetry;
  const StartupError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return StartupWidget(
      widget: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              width: 100,
              child: ElevatedButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: typoConfig.textStyle.smallCaptionSubtitle1.copyWith(
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
