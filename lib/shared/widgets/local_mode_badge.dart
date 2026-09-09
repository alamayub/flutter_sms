// lib/shared/widgets/local_mode_badge.dart
import 'package:flutter/material.dart';

import '../../features/sync/presentation/sync_status_badge.dart';

class LocalModeBadge extends StatelessWidget {
  final bool compact;

  const LocalModeBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SyncStatusBadge(compact: compact);
  }
}
