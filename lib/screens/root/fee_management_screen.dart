import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/student_provider.dart';

class FeeManagementScreen extends HookConsumerWidget {
  const FeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentListProvider);
    return Column(children: [
        
      ],
    );
  }
}
