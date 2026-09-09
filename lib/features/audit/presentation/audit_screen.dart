// lib/features/audit/presentation/audit_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/audit_repository.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(authControllerProvider).currentSchool;
    if (school == null) {
      return const Scaffold(body: Center(child: Text('No school selected')));
    }

    final repo = ref.watch(auditRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('System Audit Trail')),
      body: StreamBuilder<List<AuditLog>>(
        stream: repo.watchLogs(schoolId: school.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const EmptyState(
              icon: Icons.history_edu_outlined,
              title: 'No Audit Records',
              message:
                  'Operational events (logins, creates, updates, attendance, backups) will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            itemBuilder: (context, idx) {
              final item = logs[idx];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        item.action,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.entityType,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    item.metadata != null && item.metadata!.isNotEmpty
                        ? '${item.metadata}'
                        : 'No additional metadata',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    DateHelpers.formatDisplayDateTime(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
