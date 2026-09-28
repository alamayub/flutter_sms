import 'package:flutter/material.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../models/calendar_mode.dart';
import '../../utils/date_time_utils.dart';
import '../generic/avatar_widget.dart';
import '../generic/tag_widget.dart';

class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final String langCode;
  final CalendarMode calendarMode;
  final bool isNepali;
  final ValueChanged<Employee> onDelete;
  final ValueChanged<Employee> onEdit;

  const EmployeeCard({
    super.key,
    required this.employee,
    required this.langCode,
    required this.calendarMode,
    required this.isNepali,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isTeacher = employee.employeeType == EmployeeType.teacher;
    final roleColor = isTeacher ? Colors.indigo : Colors.teal;
    final hasEmergencyContact =
        (employee.emergencyContactName != null &&
            employee.emergencyContactName!.isNotEmpty) ||
        (employee.emergencyContactPhone != null &&
            employee.emergencyContactPhone!.isNotEmpty);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.color.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar / Photo, Name, Code, and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarWidget(
                  path: employee.photoPath,
                  color: roleColor,
                  name: employee.name,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee.name,
                              style: context.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Active status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  employee.isActive
                                      ? Colors.green.withAlpha(25)
                                      : Colors.grey.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              employee.isActive
                                  ? AppTranslations.text('active', langCode)
                                  : AppTranslations.text('inactive', langCode),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    employee.isActive
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTeacher
                                  ? AppTranslations.text('teachers', langCode)
                                  : AppTranslations.text('staff', langCode),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Employee Code Badge
                          if (employee.employeeCode != null &&
                              employee.employeeCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.color.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                employee.employeeCode!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: context.color.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Designation & Department
            Text(
              employee.designation,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.color.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (employee.department != null &&
                employee.department!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                employee.department!,
                style: context.text.bodySmall?.copyWith(
                  color: context.color.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Contacts (Phone & Email)
            if (employee.phone != null && employee.phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: context.color.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        employee.phone!,
                        style: context.theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (employee.email != null && employee.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 13,
                      color: context.color.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        employee.email!,
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Emergency Contact Card
            if (hasEmergencyContact) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emergency_outlined,
                          size: 13,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppTranslations.text('emergency_contact', langCode),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.emergencyContactName ?? "N/A"}${employee.emergencyContactRelation != null ? " (${employee.emergencyContactRelation})" : ""}: ${employee.emergencyContactPhone ?? ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.color.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),
            // Tags Row: Blood Group, Marital Status, Gender
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (employee.bloodGroup != null)
                  TagWidget(
                    icon: Icons.bloodtype_outlined,
                    text: employee.bloodGroup!,
                    color: Colors.redAccent,
                  ),
                if (employee.maritalStatus != null)
                  TagWidget(
                    icon: Icons.favorite_border,
                    text: employee.maritalStatus!,
                    color: Colors.purple,
                  ),
                if (employee.gender != null)
                  TagWidget(
                    icon:
                        employee.gender == 'Male'
                            ? Icons.male
                            : employee.gender == 'Female'
                            ? Icons.female
                            : Icons.transgender,
                    text: employee.gender!,
                    color: Colors.blueGrey,
                  ),
              ],
            ),

            const Spacer(),
            const Divider(height: 12),

            // Card Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (employee.joiningDate != null)
                  Text(
                    'Joined: ${DateTimeUtils.formatDateByMode(employee.joiningDate!, mode: calendarMode, inNepaliScript: isNepali)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.color.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: AppTranslations.text('edit_employee', langCode),
                      onPressed: () => onEdit(employee),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: context.color.error,
                      ),
                      tooltip: AppTranslations.text(
                        'delete_employee',
                        langCode,
                      ),
                      onPressed: () => onDelete(employee),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
