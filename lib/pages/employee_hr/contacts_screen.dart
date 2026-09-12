import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/contact_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_input.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final allContactsAsync = ref.watch(allContactsStreamProvider);
    final filteredContactsAsync = ref.watch(filteredContactsProvider);
    final selectedSourceType = ref.watch(
      selectedContactSourceTypeFilterProvider,
    );
    final isEmergencyOnly = ref.watch(emergencyOnlyFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: ResponsiveScaffoldWrapper(
        child: CustomScrollView(
          slivers: [
            // App Bar / Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.contacts_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.text('contacts', lang),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppTranslations.text('all_contacts', lang),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showContactFormDialog(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(AppTranslations.text('add_contact', lang)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Metric Summary Cards
            SliverToBoxAdapter(
              child: allContactsAsync.when(
                data: (allContacts) {
                  final total = allContacts.length;
                  final studentCount =
                      allContacts
                          .where(
                            (c) => c.sourceType == ContactSourceType.student,
                          )
                          .length;
                  final employeeCount =
                      allContacts
                          .where(
                            (c) => c.sourceType == ContactSourceType.employee,
                          )
                          .length;
                  final emergencyCount =
                      allContacts.where((c) => c.isEmergency).length;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 650;
                        if (isCompact) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      title: AppTranslations.text(
                                        'total_contacts',
                                        lang,
                                      ),
                                      value: total.toString(),
                                      icon: Icons.contact_phone_outlined,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetricCard(
                                      title: AppTranslations.text(
                                        'student_contacts',
                                        lang,
                                      ),
                                      value: studentCount.toString(),
                                      icon: Icons.school_outlined,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      title: AppTranslations.text(
                                        'employee_contacts',
                                        lang,
                                      ),
                                      value: employeeCount.toString(),
                                      icon: Icons.badge_outlined,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetricCard(
                                      title: AppTranslations.text(
                                        'emergency_contacts',
                                        lang,
                                      ),
                                      value: emergencyCount.toString(),
                                      icon: Icons.health_and_safety_outlined,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: AppTranslations.text(
                                  'total_contacts',
                                  lang,
                                ),
                                value: total.toString(),
                                icon: Icons.contact_phone_outlined,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: AppTranslations.text(
                                  'student_contacts',
                                  lang,
                                ),
                                value: studentCount.toString(),
                                icon: Icons.school_outlined,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: AppTranslations.text(
                                  'employee_contacts',
                                  lang,
                                ),
                                value: employeeCount.toString(),
                                icon: Icons.badge_outlined,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: AppTranslations.text(
                                  'emergency_contacts',
                                  lang,
                                ),
                                value: emergencyCount.toString(),
                                icon: Icons.health_and_safety_outlined,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ),

            // Search & Filter Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        AppSearchField(
                          controller: _searchController,
                          hintText:
                              '${AppTranslations.text('search', lang)} (Name, Phone, Relation, Linked...)',
                          onChanged: (val) {
                            ref
                                .read(contactSearchQueryProvider.notifier)
                                .setQuery(val);
                          },
                          onClear: () {
                            ref
                                .read(contactSearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        ),
                        const SizedBox(height: 10),

                        // Filter Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // All
                            FilterChip(
                              label: Text(
                                AppTranslations.text('all_contacts', lang),
                              ),
                              selected: selectedSourceType == null,
                              onSelected: (_) {
                                ref
                                    .read(
                                      selectedContactSourceTypeFilterProvider
                                          .notifier,
                                    )
                                    .setType(null);
                              },
                            ),
                            // Students
                            FilterChip(
                              avatar: const Icon(Icons.school, size: 16),
                              label: Text(
                                AppTranslations.text('student_contacts', lang),
                              ),
                              selected:
                                  selectedSourceType ==
                                  ContactSourceType.student,
                              onSelected: (_) {
                                ref
                                    .read(
                                      selectedContactSourceTypeFilterProvider
                                          .notifier,
                                    )
                                    .setType(ContactSourceType.student);
                              },
                            ),
                            // Employees
                            FilterChip(
                              avatar: const Icon(Icons.badge, size: 16),
                              label: Text(
                                AppTranslations.text('employee_contacts', lang),
                              ),
                              selected:
                                  selectedSourceType ==
                                  ContactSourceType.employee,
                              onSelected: (_) {
                                ref
                                    .read(
                                      selectedContactSourceTypeFilterProvider
                                          .notifier,
                                    )
                                    .setType(ContactSourceType.employee);
                              },
                            ),
                            // General / Other
                            FilterChip(
                              avatar: const Icon(
                                Icons.corporate_fare,
                                size: 16,
                              ),
                              label: Text(
                                AppTranslations.text('other_contacts', lang),
                              ),
                              selected:
                                  selectedSourceType == ContactSourceType.other,
                              onSelected: (_) {
                                ref
                                    .read(
                                      selectedContactSourceTypeFilterProvider
                                          .notifier,
                                    )
                                    .setType(ContactSourceType.other);
                              },
                            ),
                            // Emergency Toggle
                            FilterChip(
                              avatar: Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color:
                                    isEmergencyOnly ? Colors.white : Colors.red,
                              ),
                              label: Text(
                                AppTranslations.text(
                                  'emergency_contacts',
                                  lang,
                                ),
                              ),
                              selected: isEmergencyOnly,
                              selectedColor: Colors.red.shade600,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isEmergencyOnly ? Colors.white : null,
                                fontWeight:
                                    isEmergencyOnly ? FontWeight.bold : null,
                              ),
                              onSelected: (_) {
                                ref
                                    .read(emergencyOnlyFilterProvider.notifier)
                                    .toggle();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Contacts List / Grid
            filteredContactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contact_phone_outlined,
                            size: 64,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.text('no_contacts', lang),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => _showContactFormDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              AppTranslations.text('add_contact', lang),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          constraints.crossAxisExtent > 900
                              ? 3
                              : (constraints.crossAxisExtent > 600 ? 2 : 1);

                      if (crossAxisCount == 1) {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final contact = contacts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ContactCard(
                                contact: contact,
                                lang: lang,
                                onView:
                                    () => _showContactDetailsDialog(
                                      context,
                                      contact,
                                      lang,
                                    ),
                                onEdit:
                                    () => _showContactFormDialog(
                                      context,
                                      contact: contact,
                                    ),
                                onDelete:
                                    () => _confirmDeleteContact(
                                      context,
                                      contact,
                                      lang,
                                    ),
                              ),
                            );
                          }, childCount: contacts.length),
                        );
                      }

                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final contact = contacts[index];
                          return _ContactCard(
                            contact: contact,
                            lang: lang,
                            onView:
                                () => _showContactDetailsDialog(
                                  context,
                                  contact,
                                  lang,
                                ),
                            onEdit:
                                () => _showContactFormDialog(
                                  context,
                                  contact: contact,
                                ),
                            onDelete:
                                () => _confirmDeleteContact(
                                  context,
                                  contact,
                                  lang,
                                ),
                          );
                        }, childCount: contacts.length),
                      );
                    },
                  ),
                );
              },
              loading:
                  () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (err, stack) => SliverFillRemaining(
                    child: Center(child: Text('Error loading contacts: $err')),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Dialogs & Actions ====================

  void _showContactFormDialog(BuildContext context, {Contact? contact}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ContactFormModal(contact: contact),
    );
  }

  void _showContactDetailsDialog(
    BuildContext context,
    Contact contact,
    String lang,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _ContactDetailsModal(contact: contact, lang: lang),
    );
  }

  void _confirmDeleteContact(
    BuildContext context,
    Contact contact,
    String lang,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppTranslations.text('delete_contact', lang)),
            content: Text(
              'Are you sure you want to delete contact "${contact.name}" (${contact.phone})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppTranslations.text('cancel', lang)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final service = ref.read(contactServiceProvider);
                    await service.deleteContact(contact.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted contact "${contact.name}"'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                },
                child: Text(AppTranslations.text('delete', lang)),
              ),
            ],
          ),
    );
  }
}

// ==================== Contact Metric Card ====================

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final MaterialColor color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.shade50.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color.shade800, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Contact Card Widget ====================

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final String lang;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.lang,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color sourceColor;
    IconData sourceIcon;
    String sourceLabel;

    switch (contact.sourceType) {
      case ContactSourceType.student:
        sourceColor = Colors.teal;
        sourceIcon = Icons.school_outlined;
        sourceLabel = AppTranslations.text('student_contacts', lang);
        break;
      case ContactSourceType.employee:
        sourceColor = Colors.indigo;
        sourceIcon = Icons.badge_outlined;
        sourceLabel = AppTranslations.text('employee_contacts', lang);
        break;
      case ContactSourceType.other:
        sourceColor = Colors.purple;
        sourceIcon = Icons.corporate_fare_outlined;
        sourceLabel = AppTranslations.text('other_contacts', lang);
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              contact.isEmergency
                  ? Colors.red.shade300
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: contact.isEmergency ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name, Primary badge, Emergency Chip, Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: sourceColor.withValues(alpha: 0.15),
                    child: Icon(sourceIcon, size: 20, color: sourceColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                contact.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (contact.isPrimary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.amber.shade400,
                                  ),
                                ),
                                child: Text(
                                  'Primary',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (contact.relation != null &&
                            contact.relation!.isNotEmpty)
                          Text(
                            contact.relation!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (contact.isEmergency)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Emergency',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'view') onView();
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                      if (val == 'copy') {
                        Clipboard.setData(ClipboardData(text: contact.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied ${contact.phone} to clipboard',
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder:
                        (ctx) => [
                          PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(AppTranslations.text('view', lang)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'copy',
                            child: const Row(
                              children: [
                                Icon(Icons.copy_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Copy Phone'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(AppTranslations.text('edit', lang)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppTranslations.text('delete', lang),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const Spacer(),

              // Phone & Call Action
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      contact.phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: contact.phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied ${contact.phone} to clipboard'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.call,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppTranslations.text('call', lang),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Linked Entity Badge (Source)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sourceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: sourceColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (contact.sourceName != null &&
                      contact.sourceName!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        contact.sourceName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Contact Details Modal ====================

class _ContactDetailsModal extends StatelessWidget {
  final Contact contact;
  final String lang;

  const _ContactDetailsModal({required this.contact, required this.lang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (contact.relation != null)
                  Text(
                    contact.relation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(
                context,
                Icons.phone,
                'Phone',
                contact.phone,
                isPhone: true,
              ),
              if (contact.email != null && contact.email!.isNotEmpty)
                _detailRow(
                  context,
                  Icons.email_outlined,
                  'Email',
                  contact.email!,
                ),
              if (contact.address != null && contact.address!.isNotEmpty)
                _detailRow(
                  context,
                  Icons.location_on_outlined,
                  'Address',
                  contact.address!,
                ),
              if (contact.occupation != null && contact.occupation!.isNotEmpty)
                _detailRow(
                  context,
                  Icons.work_outline,
                  'Occupation',
                  contact.occupation!,
                ),
              _detailRow(
                context,
                Icons.category_outlined,
                'Source Type',
                contact.sourceType.displayName,
              ),
              if (contact.sourceName != null && contact.sourceName!.isNotEmpty)
                _detailRow(
                  context,
                  Icons.link,
                  'Linked Person / Entity',
                  contact.sourceName!,
                ),
              _detailRow(
                context,
                Icons.star_outline,
                'Primary Contact',
                contact.isPrimary ? 'Yes' : 'No',
              ),
              _detailRow(
                context,
                Icons.health_and_safety_outlined,
                'Emergency Contact',
                contact.isEmergency ? 'Yes' : 'No',
                highlight: contact.isEmergency,
              ),
              if (contact.notes != null && contact.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Notes / Remarks:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(contact.notes!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: contact.phone));
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied ${contact.phone} to clipboard')),
            );
          },
          child: const Text('Copy Phone'),
        ),
        FilledButton(
          onPressed: () => context.pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isPhone = false,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? Colors.red : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isPhone ? FontWeight.bold : FontWeight.w500,
                color: highlight ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Contact Form Modal ====================

class _ContactFormModal extends ConsumerStatefulWidget {
  final Contact? contact;

  const _ContactFormModal({this.contact});

  @override
  ConsumerState<_ContactFormModal> createState() => _ContactFormModalState();
}

class _ContactFormModalState extends ConsumerState<_ContactFormModal> {
  final _formKey = GlobalKey<FormState>();

  late ContactSourceType _sourceType;
  int? _sourceId;
  String? _sourceName;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _relationController;
  late TextEditingController _customRelationController;
  String? _selectedRelation;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _occupationController;
  late TextEditingController _notesController;

  bool _isEmergency = false;
  bool _isPrimary = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _sourceType = c?.sourceType ?? ContactSourceType.student;
    _sourceId = c?.sourceId;
    _sourceName = c?.sourceName;

    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');

    final initialRelation = c?.relation?.trim();
    if (initialRelation != null && initialRelation.isNotEmpty) {
      final matched = ContactRelationOptions.match(initialRelation);
      if (matched != null) {
        _selectedRelation = matched;
        _customRelationController = TextEditingController();
      } else {
        _selectedRelation = 'Other';
        _customRelationController = TextEditingController(
          text: initialRelation,
        );
      }
      _relationController = TextEditingController(text: initialRelation);
    } else {
      _selectedRelation =
          _sourceType == ContactSourceType.employee
              ? 'Spouse'
              : (_sourceType == ContactSourceType.other
                  ? 'Emergency Contact'
                  : 'Father');
      _customRelationController = TextEditingController();
      _relationController = TextEditingController(text: _selectedRelation);
    }

    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _occupationController = TextEditingController(text: c?.occupation ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');

    _isEmergency = c?.isEmergency ?? false;
    _isPrimary = c?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    _customRelationController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final isEditing = widget.contact != null;
    final studentsAsync = ref.watch(studentsListProvider);
    final employeesAsync = ref.watch(employeesListForContactsProvider);

    return AlertDialog(
      title: Text(
        isEditing
            ? AppTranslations.text('edit_contact', lang)
            : AppTranslations.text('add_contact', lang),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Source Type Selector
                Text(
                  AppTranslations.text('source_type', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SegmentedButton<ContactSourceType>(
                  segments: const [
                    ButtonSegment(
                      value: ContactSourceType.student,
                      label: Text('Student'),
                      icon: Icon(Icons.school, size: 16),
                    ),
                    ButtonSegment(
                      value: ContactSourceType.employee,
                      label: Text('Employee'),
                      icon: Icon(Icons.badge, size: 16),
                    ),
                    ButtonSegment(
                      value: ContactSourceType.other,
                      label: Text('General'),
                      icon: Icon(Icons.corporate_fare, size: 16),
                    ),
                  ],
                  selected: {_sourceType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _sourceType = set.first;
                      _sourceId = null;
                      _sourceName = null;
                      if (_sourceType == ContactSourceType.student) {
                        _selectedRelation = 'Father';
                      } else if (_sourceType == ContactSourceType.employee) {
                        _selectedRelation = 'Spouse';
                      } else {
                        _selectedRelation = 'Emergency Contact';
                      }
                      _relationController.text = _selectedRelation!;
                      _customRelationController.clear();
                    });
                  },
                ),
                const SizedBox(height: 14),

                // 2. Select Linked Student / Employee
                if (_sourceType == ContactSourceType.student) ...[
                  studentsAsync.when(
                    data: (students) {
                      return AppSearchableSelect<int>(
                        label: 'Linked Student (Optional)',
                        prefixIcon: const Icon(Icons.person_search_outlined),
                        value: _sourceId,
                        isClearable: true,
                        hint: 'None / General Student Contact',
                        items:
                            students
                                .map(
                                  (s) => SearchableSelectItem<int>(
                                    value: s.id,
                                    label: '${s.name} (ID: ${s.id})',
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          setState(() {
                            _sourceId = val;
                            if (val != null) {
                              final student = students.firstWhere(
                                (s) => s.id == val,
                              );
                              _sourceName = '${student.name} (Student)';
                            } else {
                              _sourceName = null;
                            }
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                ] else if (_sourceType == ContactSourceType.employee) ...[
                  employeesAsync.when(
                    data: (employees) {
                      return AppSearchableSelect<int>(
                        label: 'Linked Employee (Optional)',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        value: _sourceId,
                        isClearable: true,
                        hint: 'None / General Employee Contact',
                        items:
                            employees
                                .map(
                                  (e) => SearchableSelectItem<int>(
                                    value: e.id,
                                    label:
                                        '${e.name} (${e.employeeCode ?? "EMP"})',
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          setState(() {
                            _sourceId = val;
                            if (val != null) {
                              final emp = employees.firstWhere(
                                (e) => e.id == val,
                              );
                              _sourceName =
                                  '${emp.name} (${emp.employeeCode ?? "EMP"})';
                            } else {
                              _sourceName = null;
                            }
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  TextFormField(
                    initialValue: _sourceName,
                    decoration: const InputDecoration(
                      labelText: 'Department / Organization (Optional)',
                      hintText: 'e.g. Health Clinic, Transport Dept, Red Cross',
                      prefixIcon: Icon(Icons.domain),
                    ),
                    onChanged: (val) => _sourceName = val,
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Name & Phone (Required)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Person Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Contact name is required';
                    }
                    if (val.trim().length < 2) {
                      return 'Must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: 'e.g. 9841223344 or +977-9851011223',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final phoneRegex = RegExp(r'^\+?[0-9\s\-]{3,25}$');
                    if (!phoneRegex.hasMatch(val.trim())) {
                      return 'Please enter a valid phone number (3-25 digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 4. Relationship (Searchable Select)
                AppSearchableSelect<String>(
                  items: ContactRelationOptions.items,
                  value: _selectedRelation,
                  label: 'Relationship / Role',
                  hint: 'Select or search relationship',
                  searchHint:
                      'Search relation (e.g. Father, Mother, Uncle, डाक्टर)...',
                  prefixIcon: const Icon(Icons.people_outline, size: 20),
                  isSearchable: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Relationship is required';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    setState(() {
                      _selectedRelation = val;
                      if (val != null && val != 'Other') {
                        _relationController.text = val;
                      } else if (val == 'Other') {
                        _relationController.text =
                            _customRelationController.text.trim();
                      }
                    });
                  },
                ),
                if (_selectedRelation == 'Other') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customRelationController,
                    decoration: const InputDecoration(
                      labelText: 'Specify Relationship',
                      hintText:
                          'Enter specific relationship (e.g. Mentor, Landlord)',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    validator: (val) {
                      if (_selectedRelation == 'Other' &&
                          (val == null || val.trim().isEmpty)) {
                        return 'Please enter the specific relationship';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      _relationController.text = val.trim();
                    },
                  ),
                ],
                const SizedBox(height: 14),

                // 5. Email & Occupation
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final emailRegex = RegExp(
                              r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(val.trim())) {
                              return 'Invalid email';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _occupationController,
                        decoration: const InputDecoration(
                          labelText: 'Occupation',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 6. Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                // 7. Emergency & Primary Switches
                Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Emergency Contact'),
                          subtitle: const Text(
                            'Flag as critical contact in emergencies',
                          ),
                          secondary: const Icon(
                            Icons.health_and_safety,
                            color: Colors.red,
                          ),
                          value: _isEmergency,
                          onChanged:
                              (val) => setState(() => _isEmergency = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Primary Contact'),
                          subtitle: const Text(
                            'Mark as main guardian or representative',
                          ),
                          secondary: const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          value: _isPrimary,
                          onChanged: (val) => setState(() => _isPrimary = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 8. Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          child: Text(AppTranslations.text('cancel', lang)),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _saveContact,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(AppTranslations.text('save', lang)),
        ),
      ],
    );
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final effectiveRelation =
        _selectedRelation == 'Other'
            ? (_customRelationController.text.trim().isNotEmpty
                ? _customRelationController.text.trim()
                : 'Other')
            : (_selectedRelation ?? _relationController.text.trim());
    _relationController.text = effectiveRelation;

    try {
      final service = ref.read(contactServiceProvider);

      if (widget.contact != null) {
        await service.updateContact(
          id: widget.contact!.id,
          sourceType: _sourceType,
          sourceId: _sourceId,
          sourceName: _sourceName,
          name: _nameController.text,
          phone: _phoneController.text,
          relation: _relationController.text,
          email: _emailController.text,
          address: _addressController.text,
          occupation: _occupationController.text,
          isEmergency: _isEmergency,
          isPrimary: _isPrimary,
          notes: _notesController.text,
        );
      } else {
        await service.createContact(
          sourceType: _sourceType,
          sourceId: _sourceId,
          sourceName: _sourceName,
          name: _nameController.text,
          phone: _phoneController.text,
          relation: _relationController.text,
          email: _emailController.text,
          address: _addressController.text,
          occupation: _occupationController.text,
          isEmergency: _isEmergency,
          isPrimary: _isPrimary,
          notes: _notesController.text,
        );
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.contact != null
                  ? 'Contact updated successfully'
                  : 'Contact created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving contact: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
