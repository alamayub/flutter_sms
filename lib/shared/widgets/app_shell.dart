// lib/shared/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'local_mode_badge.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final List<String> allowedRoles;

  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    required this.allowedRoles,
  });
}

const List<NavItem> allNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    path: '/dashboard',
    allowedRoles: [
      UserRole.principal,
      UserRole.admin,
      UserRole.teacher,
      UserRole.accountant,
    ],
  ),
  NavItem(
    label: 'Academic Years',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    path: '/academic-years',
    allowedRoles: [UserRole.principal, UserRole.admin],
  ),
  NavItem(
    label: 'Classes & Sections',
    icon: Icons.meeting_room_outlined,
    selectedIcon: Icons.meeting_room,
    path: '/classes',
    allowedRoles: [UserRole.principal, UserRole.admin],
  ),
  NavItem(
    label: 'Subjects',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    path: '/subjects',
    allowedRoles: [UserRole.principal, UserRole.admin],
  ),
  NavItem(
    label: 'Teachers',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    path: '/teachers',
    allowedRoles: [UserRole.principal, UserRole.admin],
  ),
  NavItem(
    label: 'Students',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    path: '/students',
    allowedRoles: [
      UserRole.principal,
      UserRole.admin,
      UserRole.teacher,
      UserRole.accountant,
    ],
  ),
  NavItem(
    label: 'Timetable',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
    path: '/timetable',
    allowedRoles: [UserRole.principal, UserRole.admin, UserRole.teacher],
  ),
  NavItem(
    label: 'Attendance',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
    path: '/attendance',
    allowedRoles: [UserRole.principal, UserRole.admin, UserRole.teacher],
  ),
  NavItem(
    label: 'Examinations',
    icon: Icons.quiz_outlined,
    selectedIcon: Icons.quiz,
    path: '/exams',
    allowedRoles: [UserRole.principal, UserRole.admin, UserRole.teacher],
  ),
  NavItem(
    label: 'Database Backup',
    icon: Icons.storage_outlined,
    selectedIcon: Icons.storage,
    path: '/database',
    allowedRoles: [UserRole.principal, UserRole.admin],
  ),
  NavItem(
    label: 'Audit Trail',
    icon: Icons.history_edu_outlined,
    selectedIcon: Icons.history_edu,
    path: '/audit',
    allowedRoles: [UserRole.principal, UserRole.admin],
  ),
  NavItem(
    label: 'LAN Sync',
    icon: Icons.sync_outlined,
    selectedIcon: Icons.sync,
    path: '/sync-settings',
    allowedRoles: [
      UserRole.principal,
      UserRole.admin,
      UserRole.teacher,
      UserRole.accountant,
    ],
  ),
];

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.currentUser;
    final school = authState.currentSchool;
    final userRole = user?.role ?? UserRole.admin;

    final navItems =
        allNavItems
            .where((item) => item.allowedRoles.contains(userRole))
            .toList();

    final location = GoRouterState.of(context).uri.toString();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Navigation Sidebar
            Container(
              width: 260,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // School Branding Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.school,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                school?.name ?? 'School System',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                school?.principalName != null
                                    ? 'Head: ${school!.principalName}'
                                    : 'Local-First SMS',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Offline Local Mode Indicator
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: LocalModeBadge(),
                  ),

                  const Divider(height: 24),

                  // Nav list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        final isSelected = location.startsWith(item.path);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.primaryLight
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            leading: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                              size: 20,
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                              ),
                            ),
                            onTap: () {
                              if (!isSelected) {
                                context.go(item.path);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // User Profile & Logout Area
                  Container(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                (user?.role ?? '').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      user?.role == UserRole.admin ||
                                              user?.role == UserRole.principal
                                          ? AppColors.primary
                                          : AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Logout',
                          onPressed: () {
                            ref.read(authControllerProvider.notifier).logout();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(child: child),
          ],
        ),
      );
    } else {
      // Mobile / Compact Layout
      return Scaffold(
        appBar: AppBar(
          title: Text(school?.name ?? 'School System'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: LocalModeBadge(compact: true),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primary),
                accountName: Text(user?.name ?? 'User'),
                accountEmail: Text('${school?.name} (${user?.role})'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children:
                      navItems.map((item) {
                        final isSelected = location.startsWith(item.path);
                        return ListTile(
                          leading: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected ? AppColors.primary : null,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : null,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onTap: () {
                            Navigator.pop(context);
                            context.go(item.path);
                          },
                        );
                      }).toList(),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        body: child,
      );
    }
  }
}
