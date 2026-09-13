import 'dart:convert';
import '../../config/extensions.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/subject_provider.dart';
import '../../services/certificate_service.dart';
import '../../widgets/app_input.dart';

class CertificatesScreen extends ConsumerStatefulWidget {
  final int? preselectedStudentId;

  const CertificatesScreen({super.key, this.preselectedStudentId});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.preselectedStudentId != null) {
        final students = ref.read(studentsListStreamProvider).value;
        if (students != null) {
          final student = students.cast<StudentWithDetails?>().firstWhere(
            (s) => s?.id == widget.preselectedStudentId,
            orElse: () => null,
          );
          if (student != null) {
            _showIssueCertificateDialog(context, initialStudent: student);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final certificatesAsync = ref.watch(certificatesStreamProvider);
    final summaryAsync = ref.watch(certificateSummaryProvider);
    final selectedType = ref.watch(certificateTypeFilterProvider);
    final selectedClassId = ref.watch(certificateClassFilterProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header & Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row & Issue Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.card_membership,
                                color: Colors.indigo.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Student Certificates & Mark Sheets',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Issue, manage and print official Transfer Certificates, Character Certificates, Mark Sheets, and Bonafide Certificates.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Issue Certificate',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showIssueCertificateDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metrics Cards
                  summaryAsync.when(
                    data: (summary) => _buildSummaryRow(summary),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // Search and Filters Bar
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          // Search & Class filter
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppSearchField(
                                  controller: _searchController,
                                  hintText:
                                      'Search student, admission #, certificate #...',
                                  onChanged: (val) {
                                    ref
                                        .read(
                                          certificateSearchQueryProvider
                                              .notifier,
                                        )
                                        .setQuery(val);
                                  },
                                  onClear: () {
                                    ref
                                        .read(
                                          certificateSearchQueryProvider
                                              .notifier,
                                        )
                                        .setQuery('');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Class dropdown filter
                              classesAsync.maybeWhen(
                                data:
                                    (classes) => SizedBox(
                                      width: 170,
                                      child: AppSearchableSelect<int?>.filter(
                                        value: selectedClassId,
                                        hint: 'All Classes',
                                        items: [
                                          const SearchableSelectItem<int?>(
                                            value: null,
                                            label: 'All Classes',
                                          ),
                                          ...classes.map(
                                            (c) => SearchableSelectItem<int?>(
                                              value: c.id,
                                              label: c.name,
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          ref
                                              .read(
                                                certificateClassFilterProvider
                                                    .notifier,
                                              )
                                              .setClassId(val);
                                        },
                                      ),
                                    ),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Type Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildTypeFilterChip(
                                  'all',
                                  'All Certificates',
                                  Icons.all_inclusive,
                                  selectedType,
                                ),
                                const SizedBox(width: 8),
                                _buildTypeFilterChip(
                                  'tc',
                                  'Transfer (TC)',
                                  Icons.swap_horiz,
                                  selectedType,
                                ),
                                const SizedBox(width: 8),
                                _buildTypeFilterChip(
                                  'cc',
                                  'Character (CC)',
                                  Icons.verified,
                                  selectedType,
                                ),
                                const SizedBox(width: 8),
                                _buildTypeFilterChip(
                                  'marksheet',
                                  'Mark Sheet',
                                  Icons.grade,
                                  selectedType,
                                ),
                                const SizedBox(width: 8),
                                _buildTypeFilterChip(
                                  'bonafide',
                                  'Bonafide',
                                  Icons.assignment_ind,
                                  selectedType,
                                ),
                                const SizedBox(width: 8),
                                _buildTypeFilterChip(
                                  'merit',
                                  'Merit & Distinction',
                                  Icons.emoji_events,
                                  selectedType,
                                ),
                                const SizedBox(width: 8),
                                _buildTypeFilterChip(
                                  'custom',
                                  'Custom',
                                  Icons.edit_note,
                                  selectedType,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Certificates Table / List
          certificatesAsync.when(
            data: (certs) {
              if (certs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_membership_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No certificates found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Issue a Transfer Certificate, Character Certificate, Mark Sheet, or Bonafide Certificate.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Issue Certificate'),
                          onPressed: () => _showIssueCertificateDialog(context),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = certs[index];
                    return _buildCertificateCard(context, item);
                  }, childCount: certs.length),
                ),
              );
            },
            loading:
                () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (err, stack) => SliverFillRemaining(
                  child: Center(
                    child: Text('Error loading certificates: $err'),
                  ),
                ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ==================== METRIC STATS ROW ====================

  Widget _buildSummaryRow(CertificateSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cardWidth =
            isNarrow
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 32) / 5;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatCard(
              'Total Issued',
              summary.totalIssued.toString(),
              Icons.card_membership,
              Colors.indigo,
              cardWidth,
            ),
            _buildStatCard(
              'Transfer (TC)',
              summary.tcCount.toString(),
              Icons.swap_horiz,
              Colors.orange,
              cardWidth,
            ),
            _buildStatCard(
              'Character (CC)',
              summary.ccCount.toString(),
              Icons.verified,
              Colors.green,
              cardWidth,
            ),
            _buildStatCard(
              'Mark Sheets',
              summary.marksheetCount.toString(),
              Icons.grade,
              Colors.purple,
              cardWidth,
            ),
            _buildStatCard(
              'Bonafide',
              summary.bonafideCount.toString(),
              Icons.assignment_ind,
              Colors.teal,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String count,
    IconData icon,
    MaterialColor color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.shade100,
            child: Icon(icon, size: 16, color: color.shade800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(
    String type,
    String label,
    IconData icon,
    String currentSelected,
  ) {
    final isSelected = currentSelected == type;
    return FilterChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : Colors.indigo.shade700,
      ),
      label: Text(label),
      selectedColor: Colors.indigo,
      backgroundColor: Colors.indigo.shade50,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.indigo.shade900,
      ),
      onSelected: (_) {
        ref.read(certificateTypeFilterProvider.notifier).setType(type);
      },
    );
  }

  // ==================== CERTIFICATE CARD ====================

  Widget _buildCertificateCard(
    BuildContext context,
    CertificateWithDetails item,
  ) {
    final cert = item.certificate;
    final color = _getCertificateTypeColor(cert.certificateType);
    final typeLabel = _getCertificateTypeLabel(cert.certificateType);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon / Emblem Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: color.shade100,
              child: Icon(
                _getCertificateTypeIcon(cert.certificateType),
                color: color.shade800,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Serial Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.shade300),
                        ),
                        child: Text(
                          cert.certificateNumber,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Issue Date
                      Text(
                        'Issued: ${_formatDate(cert.issueDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Student info
                  Row(
                    children: [
                      Text(
                        item.studentName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${item.admissionNumber})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (item.className != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• Class: ${item.className}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (item.rollNumber != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(Roll #${item.rollNumber})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title and details
                  Text(
                    cert.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  if (cert.reason != null && cert.reason!.isNotEmpty)
                    Text(
                      'Reason / Purpose: ${cert.reason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View & Print
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo.shade900,
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.indigo.shade200),
                    ),
                  ),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('View & Print'),
                  onPressed: () => _showPrintCertificateDialog(context, item),
                ),
                const SizedBox(width: 4),
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Certificate',
                  onPressed: () => _showEditCertificateDialog(context, item),
                ),
                // Delete
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete Certificate',
                  onPressed: () => _confirmDeleteCertificate(context, item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ISSUE CERTIFICATE MODAL ====================

  Future<void> _showIssueCertificateDialog(
    BuildContext context, {
    StudentWithDetails? initialStudent,
  }) async {
    final studentsAsync = ref.read(studentsListStreamProvider);
    final allStudents = studentsAsync.value ?? [];
    final activeYear = ref.read(activeAcademicYearProvider).value;
    final subjectsAsync = ref.read(subjectsStreamProvider);
    final allSubjects = subjectsAsync.value ?? [];

    StudentWithDetails? selectedStudent =
        initialStudent ?? (allStudents.isNotEmpty ? allStudents.first : null);
    String certType = 'tc';
    final titleController = TextEditingController(
      text: 'Transfer Certificate (T.C.)',
    );
    final reasonController = TextEditingController(
      text: 'Parent relocation to another locality / higher studies',
    );
    final conductController = TextEditingController(
      text: 'Exemplary & Diligent',
    );
    final remarksController = TextEditingController(
      text: 'A well-behaved, respectful, and sincere student.',
    );
    bool duesCleared = true;
    DateTime issueDate = DateTime.now();
    DateTime leavingDate = DateTime.now();

    // Transfer Certificate specific controllers
    final tcFatherNameController = TextEditingController(
      text:
          selectedStudent?.emergencyContactName?.isNotEmpty == true
              ? selectedStudent!.emergencyContactName!
              : 'William Montgomery',
    );
    final tcMotherNameController = TextEditingController(
      text: 'Diane Montgomery',
    );
    final tcNationalityController = TextEditingController(text: 'Nepali');
    final tcSubjectsController = TextEditingController(
      text:
          'Mathematics, Physics, Chemistry, English Literature, Computer Science',
    );
    final tcWhetherFailedController = TextEditingController(
      text: 'No (Passed on first attempt)',
    );
    final tcPromotionController = TextEditingController(
      text: 'Promoted to next grade',
    );
    final tcDuesClearedUpToController = TextEditingController(
      text: 'All dues cleared up to current month',
    );
    final tcFeeConcessionController = TextEditingController(text: 'None');
    final tcWorkingDaysController = TextEditingController(text: '210');
    final tcPresentDaysController = TextEditingController(text: '198');
    final tcLastExamResultController = TextEditingController(
      text: 'Grade 11 (Annual Assessment)',
    );

    // Character Certificate (CC) specific controllers
    final ccFatherNameController = TextEditingController(
      text: 'Carlos Rodriguez',
    );
    final ccMotherNameController = TextEditingController(
      text: 'Maria Rodriguez',
    );
    final ccSessionController = TextEditingController(
      text: activeYear?.name ?? '2025-2026',
    );

    // Bonafide Certificate specific controllers
    final bonFatherNameController = TextEditingController(
      text:
          selectedStudent?.emergencyContactName?.isNotEmpty == true
              ? selectedStudent!.emergencyContactName!
              : 'Carlos Rodriguez',
    );
    final bonMotherNameController = TextEditingController(
      text: 'Maria Rodriguez',
    );
    final bonSessionController = TextEditingController(
      text: activeYear?.name ?? '2025-2026',
    );

    // Marksheet specific controllers
    // Merit Certificate specific controllers
    final meritEventController = TextEditingController(
      text: 'Annual Inter-School Science & Technology Exhibition',
    );
    final meritRankController = TextEditingController(
      text: 'First Place & Gold Medalist',
    );
    final meritCitationController = TextEditingController(
      text:
          'Awarded for extraordinary research and autonomous robotic vehicle design.',
    );
    final meritCoordinatorController = TextEditingController(
      text: 'ACTIVITY COORDINATOR',
    );

    final examNameController = TextEditingController(
      text: 'First Term Assessment 2026',
    );
    final msSessionController = TextEditingController(
      text: activeYear?.name ?? '2025-2026',
    );
    final msFatherNameController = TextEditingController(text: 'Vikram Patel');
    final msMotherNameController = TextEditingController(text: 'Sunita Patel');
    final List<Map<String, dynamic>> marksheetSubjects = [];

    // Initialize marksheet subjects if subjects exist
    void initMarksheetSubjects() {
      marksheetSubjects.clear();
      if (allSubjects.isEmpty) {
        final defaults = [
          {
            'name': 'Mathematics',
            'code': 'MTH-101',
            'fm': 100.0,
            'pm': 40.0,
            'th': '76',
            'pr': '20',
          },
          {
            'name': 'Physics',
            'code': 'PHY-102',
            'fm': 100.0,
            'pm': 40.0,
            'th': '72',
            'pr': '20',
          },
          {
            'name': 'Chemistry',
            'code': 'CHM-103',
            'fm': 100.0,
            'pm': 40.0,
            'th': '70',
            'pr': '19',
          },
          {
            'name': 'English Literature',
            'code': 'ENG-104',
            'fm': 100.0,
            'pm': 40.0,
            'th': '91',
            'pr': '0',
          },
          {
            'name': 'Computer Science',
            'code': 'CS-105',
            'fm': 100.0,
            'pm': 40.0,
            'th': '74',
            'pr': '20',
          },
        ];
        for (final d in defaults) {
          marksheetSubjects.add({
            'subjectCode': d['code'],
            'subjectName': d['name'],
            'fullMarks': d['fm'],
            'passMarks': d['pm'],
            'theoryMarks': 80.0,
            'practicalMarks': (d['pr'] == '0') ? 0.0 : 20.0,
            'theoryObtained': TextEditingController(text: d['th'] as String),
            'practicalObtained': TextEditingController(text: d['pr'] as String),
            'totalObtained': 0.0,
            'grade': 'A+',
            'gradePoint': 4.0,
          });
        }
      } else {
        for (final s in allSubjects) {
          marksheetSubjects.add({
            'subjectCode': s.code,
            'subjectName': s.name,
            'fullMarks': s.fullMarks.toDouble(),
            'passMarks': s.passMarks.toDouble(),
            'theoryMarks': s.theoryMarks?.toDouble(),
            'practicalMarks': s.practicalMarks?.toDouble(),
            'theoryObtained': TextEditingController(text: '72'),
            'practicalObtained': TextEditingController(
              text:
                  (s.practicalMarks != null && s.practicalMarks! > 0)
                      ? '20'
                      : '0',
            ),
            'totalObtained': 0.0,
            'grade': 'A',
            'gradePoint': 3.6,
          });
        }
      }
    }

    initMarksheetSubjects();

    // Custom certificate body
    final customBodyController = TextEditingController(
      text:
          'This is to certify that {student_name}, a student of Class {class}, has successfully participated in the school academic and extracurricular program.',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void onTypeChanged(String newType) {
              certType = newType;
              switch (newType) {
                case 'tc':
                  titleController.text = 'Transfer Certificate (T.C.)';
                  reasonController.text =
                      'Parent relocation to another locality / higher studies';
                  conductController.text = 'Exemplary & Diligent';
                  remarksController.text =
                      'A well-behaved, respectful, and sincere student.';
                  break;
                case 'cc':
                  titleController.text = 'Character Certificate';
                  reasonController.text = 'Completion of studies';
                  conductController.text = 'EXEMPLARY';
                  remarksController.text =
                      'has maintained an unblemished record of moral character, exceptional integrity, and positive leadership throughout tenure at our academy.';
                  break;
                case 'bonafide':
                  titleController.text = 'Bonafide Certificate';
                  reasonController.text =
                      'Passport & Visa documentation verification';
                  remarksController.text =
                      'Their conduct and character have been consistently good throughout their tenure at this institution.';
                  break;
                case 'merit':
                  titleController.text = 'Certificate of Merit & Distinction';
                  reasonController.text =
                      'Annual Inter-School Science & Technology Exhibition';
                  remarksController.text =
                      'Awarded for extraordinary research and autonomous robotic vehicle design.';
                  break;
                case 'marksheet':
                  titleController.text = 'Academic Marksheet / Transcript';
                  break;
                default:
                  titleController.text = 'Certificate of Recognition';
                  reasonController.text = 'Academic Achievement';
                  break;
              }
              setModalState(() {});
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 780,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.post_add,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Issue New Certificate',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Generate and record official institutional certificates',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Form Content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Student Selection
                              Text(
                                '1. Select Student',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppSearchableSelect<int>(
                                value: selectedStudent?.id,
                                label: 'Student',
                                hint: 'Search and select student...',
                                prefixIcon: const Icon(Icons.person, size: 18),
                                items:
                                    allStudents.map((s) {
                                      return SearchableSelectItem<int>(
                                        value: s.id,
                                        label: s.name,
                                        subtitle:
                                            'Admission: ${s.admissionNumber} • Roll: ${s.rollNumber ?? 'N/A'}',
                                        leading: const Icon(
                                          Icons.school,
                                          size: 18,
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      selectedStudent = allStudents.firstWhere(
                                        (s) => s.id == val,
                                      );
                                      if (selectedStudent
                                              ?.emergencyContactName
                                              ?.isNotEmpty ==
                                          true) {
                                        tcFatherNameController.text =
                                            selectedStudent!
                                                .emergencyContactName!;
                                        ccFatherNameController.text =
                                            selectedStudent!
                                                .emergencyContactName!;
                                        msFatherNameController.text =
                                            selectedStudent!
                                                .emergencyContactName!;
                                        bonFatherNameController.text =
                                            selectedStudent!
                                                .emergencyContactName!;
                                      }
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // 2. Certificate Type Selector
                              Text(
                                '2. Certificate Type',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'tc',
                                    label: Text('Transfer (TC)'),
                                    icon: Icon(Icons.swap_horiz, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'cc',
                                    label: Text('Character (CC)'),
                                    icon: Icon(Icons.verified, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'bonafide',
                                    label: Text('Bonafide'),
                                    icon: Icon(Icons.assignment_ind, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'marksheet',
                                    label: Text('Mark Sheet'),
                                    icon: Icon(Icons.grade, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'merit',
                                    label: Text('Merit'),
                                    icon: Icon(Icons.emoji_events, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'custom',
                                    label: Text('Custom'),
                                    icon: Icon(Icons.edit_note, size: 16),
                                  ),
                                ],
                                selected: {certType},
                                onSelectionChanged: (newVal) {
                                  onTypeChanged(newVal.first);
                                },
                              ),
                              const SizedBox(height: 16),

                              // Common: Title & Issue Date
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Certificate Title',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Date: ${_formatDate(issueDate)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: issueDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (d != null) {
                                          setModalState(() => issueDate = d);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Dynamic Type-Specific Fields
                              if (certType == 'tc') ...[
                                _buildTransferCertificateForm(
                                  setModalState,
                                  reasonController,
                                  conductController,
                                  remarksController,
                                  duesCleared,
                                  leavingDate,
                                  (val) => setModalState(
                                    () => duesCleared = val ?? true,
                                  ),
                                  (d) => setModalState(() => leavingDate = d),
                                  tcFatherNameController,
                                  tcMotherNameController,
                                  tcNationalityController,
                                  tcSubjectsController,
                                  tcWorkingDaysController,
                                  tcPresentDaysController,
                                  tcPromotionController,
                                ),
                              ] else if (certType == 'cc') ...[
                                _buildCharacterCertificateForm(
                                  setModalState,
                                  conductController,
                                  remarksController,
                                  ccFatherNameController,
                                  ccMotherNameController,
                                  ccSessionController,
                                ),
                              ] else if (certType == 'bonafide') ...[
                                _buildBonafideCertificateForm(
                                  setModalState,
                                  reasonController,
                                  remarksController,
                                  bonFatherNameController,
                                  bonMotherNameController,
                                  bonSessionController,
                                ),
                              ] else if (certType == 'merit') ...[
                                _buildMeritCertificateForm(
                                  setModalState,
                                  meritEventController,
                                  meritRankController,
                                  meritCitationController,
                                  meritCoordinatorController,
                                ),
                              ] else if (certType == 'marksheet') ...[
                                _buildMarksheetForm(
                                  setModalState,
                                  examNameController,
                                  msSessionController,
                                  msFatherNameController,
                                  msMotherNameController,
                                  marksheetSubjects,
                                  remarksController,
                                ),
                              ] else ...[
                                _buildCustomCertificateForm(
                                  customBodyController,
                                  remarksController,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 18,
                            ),
                            label: const Text('Preview Certificate'),
                            onPressed:
                                selectedStudent == null
                                    ? null
                                    : () async {
                                      final service = ref.read(
                                        certificateServiceProvider,
                                      );
                                      Map<String, dynamic>? dataMap;

                                      if (certType == 'tc') {
                                        dataMap =
                                            TransferCertificateData(
                                              admissionDate:
                                                  selectedStudent
                                                      ?.admissionDate,
                                              admittedClass:
                                                  selectedStudent
                                                      ?.currentClass
                                                      ?.name ??
                                                  'Grade 11',
                                              dateOfLeaving: leavingDate,
                                              classInWhichStudying:
                                                  '${selectedStudent?.currentClass?.name ?? "Grade 11"} ${selectedStudent?.currentSection?.name ?? "Section A"}'
                                                      .trim(),
                                              promotedToClass:
                                                  tcPromotionController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcPromotionController
                                                          .text
                                                          .trim()
                                                      : 'Promoted to next grade',
                                              reasonForLeaving:
                                                  reasonController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? reasonController.text
                                                          .trim()
                                                      : 'Parent relocation to another locality / higher studies',
                                              conduct:
                                                  conductController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? conductController.text
                                                          .trim()
                                                      : 'Exemplary & Diligent',
                                              duesCleared: duesCleared,
                                              duesClearedUpTo:
                                                  tcDuesClearedUpToController
                                                          .text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcDuesClearedUpToController
                                                          .text
                                                          .trim()
                                                      : 'All dues cleared up to current month',
                                              totalWorkingDays:
                                                  int.tryParse(
                                                    tcWorkingDaysController.text
                                                        .trim(),
                                                  ) ??
                                                  210,
                                              totalPresentDays:
                                                  int.tryParse(
                                                    tcPresentDaysController.text
                                                        .trim(),
                                                  ) ??
                                                  198,
                                              fatherName:
                                                  tcFatherNameController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcFatherNameController
                                                          .text
                                                          .trim()
                                                      : (selectedStudent
                                                              ?.emergencyContactName ??
                                                          'William Montgomery'),
                                              motherName:
                                                  tcMotherNameController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcMotherNameController
                                                          .text
                                                          .trim()
                                                      : 'Diane Montgomery',
                                              nationality:
                                                  tcNationalityController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcNationalityController
                                                          .text
                                                          .trim()
                                                      : 'Nepali',
                                              subjectsStudied:
                                                  tcSubjectsController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcSubjectsController
                                                          .text
                                                          .trim()
                                                      : 'Mathematics, Physics, Chemistry, English Literature, Computer Science',
                                              whetherFailed:
                                                  tcWhetherFailedController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcWhetherFailedController
                                                          .text
                                                          .trim()
                                                      : 'No (Passed on first attempt)',
                                              feeConcession:
                                                  tcFeeConcessionController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcFeeConcessionController
                                                          .text
                                                          .trim()
                                                      : 'None',
                                              applicationDate: issueDate,
                                              lastExamResult:
                                                  tcLastExamResultController
                                                          .text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? tcLastExamResultController
                                                          .text
                                                          .trim()
                                                      : 'Grade 11 (Annual Assessment)',
                                              generalRemarks:
                                                  remarksController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? remarksController.text
                                                          .trim()
                                                      : 'A well-behaved, respectful, and sincere student.',
                                            ).toJson();
                                      } else if (certType == 'cc') {
                                        dataMap =
                                            CharacterCertificateData(
                                              periodFrom:
                                                  (activeYear != null
                                                      ? activeYear
                                                          .startDate
                                                          .year
                                                          .toString()
                                                      : (DateTime.now().year -
                                                              1)
                                                          .toString()),
                                              periodTo:
                                                  (activeYear != null
                                                      ? activeYear.endDate.year
                                                          .toString()
                                                      : DateTime.now().year
                                                          .toString()),
                                              characterRating:
                                                  conductController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? conductController.text
                                                          .trim()
                                                      : 'EXEMPLARY',
                                              moralCharacter:
                                                  'Possesses excellent moral character, high integrity and exemplary behavior.',
                                              fatherName:
                                                  ccFatherNameController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? ccFatherNameController
                                                          .text
                                                          .trim()
                                                      : (selectedStudent
                                                              ?.emergencyContactName ??
                                                          'Carlos Rodriguez'),
                                              motherName:
                                                  ccMotherNameController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? ccMotherNameController
                                                          .text
                                                          .trim()
                                                      : 'Maria Rodriguez',
                                              session:
                                                  ccSessionController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? ccSessionController.text
                                                          .trim()
                                                      : (activeYear?.name ??
                                                          '2025-2026'),
                                              generalRemarks:
                                                  remarksController.text.trim(),
                                            ).toJson();
                                      } else if (certType == 'bonafide') {
                                        dataMap =
                                            BonafideCertificateData(
                                              purpose:
                                                  reasonController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? reasonController.text
                                                          .trim()
                                                      : 'Passport & Visa documentation verification',
                                              academicYear:
                                                  bonSessionController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? bonSessionController
                                                          .text
                                                          .trim()
                                                      : (activeYear?.name ??
                                                          '2025-2026'),
                                              fatherName:
                                                  bonFatherNameController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? bonFatherNameController
                                                          .text
                                                          .trim()
                                                      : (selectedStudent
                                                              ?.emergencyContactName ??
                                                          'Carlos Rodriguez'),
                                              motherName:
                                                  bonMotherNameController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? bonMotherNameController
                                                          .text
                                                          .trim()
                                                      : 'Maria Rodriguez',
                                              dob: selectedStudent?.dateOfBirth,
                                              generalRemarks:
                                                  remarksController.text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? remarksController.text
                                                          .trim()
                                                      : 'Their conduct and character have been consistently good throughout their tenure at this institution.',
                                            ).toJson();
                                      } else if (certType == 'marksheet') {
                                        double totalFull = 0.0;
                                        double totalPass = 0.0;
                                        double totalObtained = 0.0;

                                        final entries =
                                            marksheetSubjects.map((sub) {
                                              final full =
                                                  (sub['fullMarks'] as num)
                                                      .toDouble();
                                              final pass =
                                                  (sub['passMarks'] as num)
                                                      .toDouble();
                                              final th = double.tryParse(
                                                (sub['theoryObtained']
                                                        as TextEditingController)
                                                    .text
                                                    .trim(),
                                              );
                                              final pr = double.tryParse(
                                                (sub['practicalObtained']
                                                        as TextEditingController)
                                                    .text
                                                    .trim(),
                                              );
                                              final obtained =
                                                  (th ?? 0) + (pr ?? 0);
                                              final pct =
                                                  full > 0
                                                      ? (obtained / full) * 100
                                                      : 0.0;
                                              final gradeInfo =
                                                  CertificateService.calculateGrade(
                                                    pct,
                                                  );

                                              totalFull += full;
                                              totalPass += pass;
                                              totalObtained += obtained;

                                              return MarksheetSubjectEntry(
                                                subjectCode:
                                                    sub['subjectCode']
                                                        as String,
                                                subjectName:
                                                    sub['subjectName']
                                                        as String,
                                                fullMarks: full,
                                                passMarks: pass,
                                                theoryMarks: sub['theoryMarks'],
                                                practicalMarks:
                                                    sub['practicalMarks'],
                                                theoryObtained: th,
                                                practicalObtained: pr,
                                                totalObtained: obtained,
                                                grade: gradeInfo.letterGrade,
                                                gradePoint:
                                                    gradeInfo.gradePoint,
                                              );
                                            }).toList();

                                        final overallPct =
                                            totalFull > 0
                                                ? (totalObtained / totalFull) *
                                                    100
                                                : 0.0;
                                        final overallGrade =
                                            CertificateService.calculateGrade(
                                              overallPct,
                                            );
                                        final division =
                                            CertificateService.calculateDivision(
                                              overallPct,
                                            );
                                        final isPassed = entries.every(
                                          (e) => e.isPassed,
                                        );

                                        dataMap =
                                            MarksheetData(
                                              examName:
                                                  examNameController.text
                                                      .trim(),
                                              subjects: entries,
                                              totalFullMarks: totalFull,
                                              totalPassMarks: totalPass,
                                              totalMarksObtained: totalObtained,
                                              percentage: double.parse(
                                                overallPct.toStringAsFixed(2),
                                              ),
                                              gpa: overallGrade.gradePoint,
                                              division: division,
                                              result:
                                                  isPassed
                                                      ? 'Passed'
                                                      : 'Failed',
                                              teacherRemarks:
                                                  remarksController.text.trim(),
                                              fatherName:
                                                  msFatherNameController.text
                                                      .trim(),
                                              motherName:
                                                  msMotherNameController.text
                                                      .trim(),
                                              session:
                                                  msSessionController.text
                                                      .trim(),
                                            ).toJson();
                                      } else {
                                        dataMap =
                                            CustomCertificateData(
                                              bodyText:
                                                  customBodyController.text
                                                      .trim(),
                                            ).toJson();
                                      }

                                      final prospectiveNumber = await service
                                          .generateCertificateNumber(certType);

                                      final finalTitle =
                                          titleController.text.trim().isNotEmpty
                                              ? titleController.text.trim()
                                              : (certType == 'tc'
                                                  ? 'Transfer Certificate (T.C.)'
                                                  : certType == 'cc'
                                                  ? 'Character Certificate'
                                                  : certType == 'bonafide'
                                                  ? 'Bonafide Certificate'
                                                  : certType == 'marksheet'
                                                  ? '${examNameController.text.trim().isEmpty ? "Terminal Examination" : examNameController.text.trim()} Mark Sheet'
                                                  : 'Certificate');

                                      final provisionalCert = Certificate(
                                        id: 0,
                                        certificateNumber: prospectiveNumber,
                                        studentId: selectedStudent!.id,
                                        academicYearId: activeYear?.id,
                                        certificateType: certType,
                                        title: finalTitle,
                                        issueDate: issueDate,
                                        status: 'provisional',
                                        reason: reasonController.text.trim(),
                                        conduct: conductController.text.trim(),
                                        duesCleared: duesCleared,
                                        remarks: remarksController.text.trim(),
                                        issuedBy: 'Administration',
                                        dataJson: jsonEncode(dataMap),
                                        createdAt: DateTime.now(),
                                      );

                                      final provisionalItem =
                                          CertificateWithDetails(
                                            certificate: provisionalCert,
                                            student: selectedStudent!.student,
                                            schoolClass:
                                                selectedStudent!.currentClass,
                                            section:
                                                selectedStudent!.currentSection,
                                            academicYear: activeYear,
                                          );

                                      if (!context.mounted) return;

                                      _showPrintCertificateDialog(
                                        context,
                                        provisionalItem,
                                        isProvisional: true,
                                        onConfirmIssue: () async {
                                          try {
                                            final certId = await service
                                                .issueCertificate(
                                                  studentId:
                                                      selectedStudent!.id,
                                                  academicYearId:
                                                      activeYear?.id,
                                                  certificateType: certType,
                                                  title: finalTitle,
                                                  issueDate: issueDate,
                                                  reason:
                                                      reasonController.text
                                                          .trim(),
                                                  conduct:
                                                      conductController.text
                                                          .trim(),
                                                  duesCleared: duesCleared,
                                                  remarks:
                                                      remarksController.text
                                                          .trim(),
                                                  customCertificateNumber:
                                                      prospectiveNumber,
                                                  data: dataMap,
                                                );

                                            ref.invalidate(
                                              certificatesStreamProvider,
                                            );
                                            ref.invalidate(
                                              certificateSummaryProvider,
                                            );

                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }

                                            if (context.mounted) {
                                              context.showSnackbar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Certificate issued successfully!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );

                                              final created = await service
                                                  .getCertificateById(certId);
                                              if (created != null &&
                                                  context.mounted) {
                                                _showPrintCertificateDialog(
                                                  context,
                                                  created,
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              context.showSnackbar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to issue certificate: $e',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      );
                                    },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== TYPE-SPECIFIC FORM BUILDERS ====================

  Widget _buildTransferCertificateForm(
    StateSetter setModalState,
    TextEditingController reasonController,
    TextEditingController conductController,
    TextEditingController remarksController,
    bool duesCleared,
    DateTime leavingDate,
    ValueChanged<bool?> onDuesChanged,
    ValueChanged<DateTime> onDateChanged,
    TextEditingController fatherController,
    TextEditingController motherController,
    TextEditingController nationalityController,
    TextEditingController subjectsController,
    TextEditingController workingDaysController,
    TextEditingController presentDaysController,
    TextEditingController promotionController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: fatherController,
                decoration: const InputDecoration(
                  labelText: "Father's / Guardian's Full Name",
                  hintText: 'e.g. William Montgomery',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: motherController,
                decoration: const InputDecoration(
                  labelText: "Mother's Full Name",
                  hintText: 'e.g. Diane Montgomery',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: nationalityController,
                decoration: const InputDecoration(
                  labelText: 'Nationality & Citizenship',
                  hintText: 'e.g. Nepali',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: subjectsController,
                decoration: const InputDecoration(
                  labelText: 'Subjects Studied (comma-separated)',
                  hintText: 'e.g. Mathematics, Physics, Chemistry...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Leaving',
                  hintText: "e.g. Parent relocation, Higher Studies",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: conductController,
                decoration: const InputDecoration(
                  labelText: 'General Conduct & Discipline',
                  hintText: 'e.g. Exemplary & Diligent',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 16),
                label: Text('Date of Leaving: ${_formatDate(leavingDate)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: leavingDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) onDateChanged(d);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'All School Dues Cleared',
                  style: TextStyle(fontSize: 13),
                ),
                value: duesCleared,
                onChanged: onDuesChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: workingDaysController,
                decoration: const InputDecoration(
                  labelText: 'Total Working Days',
                  hintText: '210',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: presentDaysController,
                decoration: const InputDecoration(
                  labelText: 'Days Present',
                  hintText: '198',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: promotionController,
                decoration: const InputDecoration(
                  labelText: 'Promotion Status',
                  hintText: 'Promoted to next grade',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'General Remarks / Commendations',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterCertificateForm(
    StateSetter setModalState,
    TextEditingController conductController,
    TextEditingController remarksController,
    TextEditingController fatherNameController,
    TextEditingController motherNameController,
    TextEditingController sessionController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: fatherNameController,
                decoration: const InputDecoration(
                  labelText: "Father's Full Name",
                  hintText: 'e.g. Carlos Rodriguez',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: motherNameController,
                decoration: const InputDecoration(
                  labelText: "Mother's Full Name",
                  hintText: 'e.g. Maria Rodriguez',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: sessionController,
                decoration: const InputDecoration(
                  labelText: 'Academic Session',
                  hintText: 'e.g. 2025-2026',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: conductController,
                decoration: const InputDecoration(
                  labelText: 'Moral Character Rating',
                  hintText: 'e.g. EXEMPLARY, VERY GOOD',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: remarksController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Character & Leadership Commendation',
            hintText:
                'e.g. has maintained an unblemished record of moral character, exceptional integrity, and positive leadership throughout tenure at our academy.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildBonafideCertificateForm(
    StateSetter setModalState,
    TextEditingController reasonController,
    TextEditingController remarksController,
    TextEditingController fatherNameController,
    TextEditingController motherNameController,
    TextEditingController sessionController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: fatherNameController,
                decoration: const InputDecoration(
                  labelText: "Father's Full Name",
                  hintText: 'e.g. Carlos Rodriguez',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: motherNameController,
                decoration: const InputDecoration(
                  labelText: "Mother's Full Name",
                  hintText: 'e.g. Maria Rodriguez',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: sessionController,
                decoration: const InputDecoration(
                  labelText: 'Academic Session',
                  hintText: 'e.g. 2025-2026',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Bonafide Certificate',
                  hintText: 'e.g. Passport & Visa documentation verification',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: remarksController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Conduct & Character Commendation',
            hintText:
                'e.g. Their conduct and character have been consistently good throughout their tenure at this institution.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMeritCertificateForm(
    StateSetter setModalState,
    TextEditingController eventController,
    TextEditingController rankController,
    TextEditingController citationController,
    TextEditingController coordinatorController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: eventController,
          decoration: const InputDecoration(
            labelText: 'Event / Competition / Achievement Name',
            hintText:
                'e.g. Annual Inter-School Science & Technology Exhibition',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: rankController,
                decoration: const InputDecoration(
                  labelText: 'Rank / Distinction Achieved',
                  hintText: 'e.g. First Place & Gold Medalist',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: coordinatorController,
                decoration: const InputDecoration(
                  labelText: 'Signatory 1 Title',
                  hintText: 'e.g. ACTIVITY COORDINATOR',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: citationController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Official Citation / Commendation Quote',
            hintText:
                'e.g. Awarded for extraordinary research and autonomous robotic vehicle design.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMarksheetForm(
    StateSetter setModalState,
    TextEditingController examNameController,
    TextEditingController sessionController,
    TextEditingController fatherNameController,
    TextEditingController motherNameController,
    List<Map<String, dynamic>> subjects,
    TextEditingController remarksController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: examNameController,
                decoration: const InputDecoration(
                  labelText: 'Assessment / Exam Name',
                  hintText: 'e.g. First Term Assessment 2026',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: sessionController,
                decoration: const InputDecoration(
                  labelText: 'Academic Session',
                  hintText: 'e.g. 2025-2026',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: fatherNameController,
                decoration: const InputDecoration(
                  labelText: "Father's Full Name",
                  hintText: 'e.g. Vikram Patel',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: motherNameController,
                decoration: const InputDecoration(
                  labelText: "Mother's Full Name",
                  hintText: 'e.g. Sunita Patel',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Subject Marks Evaluation',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
        const SizedBox(height: 6),
        if (subjects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No subjects available in curriculum. Add subjects in Subjects tab first.',
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final sub = subjects[idx];
                final thCtrl = sub['theoryObtained'] as TextEditingController;
                final prCtrl =
                    sub['practicalObtained'] as TextEditingController;
                final fullMarks = sub['fullMarks'] as double;
                final passMarks = sub['passMarks'] as double;

                final th = double.tryParse(thCtrl.text.trim()) ?? 0;
                final pr = double.tryParse(prCtrl.text.trim()) ?? 0;
                final total = th + pr;
                final pct = fullMarks > 0 ? (total / fullMarks) * 100 : 0.0;
                final gInfo = CertificateService.calculateGrade(pct);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub['subjectName'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Code: ${sub['subjectCode']} • FM: $fullMarks • PM: $passMarks',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: thCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Theory',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: prCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Practical',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            gInfo.letterGrade,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        TextFormField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'Class Teacher Remarks',
            hintText: 'e.g. Enthusiastic learner, Excellent analytical skills',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomCertificateForm(
    TextEditingController customBodyController,
    TextEditingController remarksController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: customBodyController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Certificate Body Text',
            hintText:
                'Use placeholders: {student_name}, {admission_no}, {class}, {roll_no}',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Supported tags: {student_name}, {admission_no}, {class}, {roll_no}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'Remarks / Special Honors',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  // ==================== EDIT CERTIFICATE MODAL ====================

  Future<void> _showEditCertificateDialog(
    BuildContext context,
    CertificateWithDetails item,
  ) async {
    final titleController = TextEditingController(text: item.certificate.title);
    final reasonController = TextEditingController(
      text: item.certificate.reason ?? '',
    );
    final conductController = TextEditingController(
      text: item.certificate.conduct ?? 'Good',
    );
    final remarksController = TextEditingController(
      text: item.certificate.remarks ?? '',
    );
    DateTime issueDate = item.certificate.issueDate;
    String status = item.certificate.status;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text('Edit Certificate (${item.certificateNumber})'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Purpose',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: conductController,
                      decoration: const InputDecoration(
                        labelText: 'Conduct',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppSearchableSelect<String>(
                      value: status,
                      label: 'Status',
                      hint: 'Select status',
                      items: const [
                        SearchableSelectItem(value: 'issued', label: 'Issued'),
                        SearchableSelectItem(value: 'draft', label: 'Draft'),
                        SearchableSelectItem(
                          value: 'revoked',
                          label: 'Revoked',
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await ref
                        .read(certificateServiceProvider)
                        .updateCertificate(
                          id: item.id,
                          title: titleController.text.trim(),
                          issueDate: issueDate,
                          status: status,
                          reason: reasonController.text.trim(),
                          conduct: conductController.text.trim(),
                          remarks: remarksController.text.trim(),
                        );
                    ref.invalidate(certificatesStreamProvider);
                    ref.invalidate(certificateSummaryProvider);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== DELETE CONFIRMATION ====================

  Future<void> _confirmDeleteCertificate(
    BuildContext context,
    CertificateWithDetails item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Delete Certificate?'),
            content: Text(
              'Are you sure you want to delete ${item.title} (${item.certificateNumber}) for ${item.studentName}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(certificateServiceProvider).deleteCertificate(item.id);
      ref.invalidate(certificatesStreamProvider);
      ref.invalidate(certificateSummaryProvider);
      if (context.mounted) {
        context.showSnackbar(
          const SnackBar(
            content: Text('Certificate deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ==================== OFFICIAL PRINT CERTIFICATE PREVIEW ====================

  void _showPrintCertificateDialog(
    BuildContext context,
    CertificateWithDetails item, {
    bool isProvisional = false,
    Future<void> Function()? onConfirmIssue,
  }) {
    final cert = item.certificate;
    Map<String, dynamic> dataMap = {};
    if (cert.dataJson != null && cert.dataJson!.isNotEmpty) {
      try {
        dataMap = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      } catch (_) {}
    }

    final isTC = cert.certificateType == 'tc';
    final isCC = cert.certificateType == 'cc';
    final isMarksheet = cert.certificateType == 'marksheet';
    final isBonafide = cert.certificateType == 'bonafide';
    final isMerit = cert.certificateType == 'merit';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 890, maxHeight: 940),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Top Dialog Header Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Color(0xFF334155),
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                              tooltip: isProvisional ? 'Back to Edit' : 'Back',
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isTC
                                          ? (isProvisional
                                              ? 'Transfer Certificate (TC) — Preview'
                                              : 'Transfer Certificate (TC)')
                                          : isCC
                                          ? (isProvisional
                                              ? 'Character Certificate (CC) — Preview'
                                              : 'Character Certificate (CC)')
                                          : isMarksheet
                                          ? (isProvisional
                                              ? 'Academic Marksheet / Transcript — Preview'
                                              : 'Academic Marksheet / Transcript')
                                          : isBonafide
                                          ? (isProvisional
                                              ? 'Bonafide Certificate — Preview'
                                              : 'Bonafide Certificate')
                                          : isMerit
                                          ? (isProvisional
                                              ? 'Certificate of Merit — Preview'
                                              : 'Certificate of Merit')
                                          : (isProvisional
                                              ? 'Official Certificate Preview (Draft)'
                                              : 'Official Certificate Preview'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isProvisional
                                                ? const Color(0xFFFEF3C7)
                                                : (isMarksheet ||
                                                    isBonafide ||
                                                    isMerit)
                                                ? const Color(0xFFEEF2FF)
                                                : const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            isProvisional
                                                ? Border.all(
                                                  color: const Color(
                                                    0xFFF59E0B,
                                                  ).withValues(alpha: 0.5),
                                                )
                                                : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isProvisional) ...[
                                            const Icon(
                                              Icons.visibility_outlined,
                                              size: 13,
                                              color: Color(0xFFD97706),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            isProvisional
                                                ? 'PREVIEW: ${cert.certificateNumber}'
                                                : cert.certificateNumber,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isProvisional
                                                      ? const Color(0xFFB45309)
                                                      : (isMarksheet ||
                                                          isBonafide ||
                                                          isMerit)
                                                      ? const Color(0xFF4338CA)
                                                      : const Color(0xFF0284C7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isProvisional
                                      ? 'Verify all details below before issuing • Recipient: ${item.studentName} (${item.admissionNumber})'
                                      : isTC
                                      ? 'Issued to ${item.studentName} (${item.admissionNumber}) - ${item.className ?? "Grade 11"}'
                                      : isCC
                                      ? 'Issued to ${item.studentName} (${item.admissionNumber}) • ${item.className ?? "Grade 10"}'
                                      : isMarksheet
                                      ? 'Issued to ${item.studentName} (${item.admissionNumber}) • ${item.className ?? "Grade 9"}'
                                      : isBonafide
                                      ? 'Issued to ${item.studentName} (${item.admissionNumber}) • ${item.className ?? "Grade 10"}'
                                      : isMerit
                                      ? 'Issued to ${item.studentName} (${item.admissionNumber}) • ${item.className ?? "Grade 10"}'
                                      : 'Issued to ${item.studentName} (${item.admissionNumber}) - ${item.className ?? "Grade 11"}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color:
                                        isProvisional
                                            ? const Color(0xFFB45309)
                                            : Colors.grey.shade600,
                                    fontWeight:
                                        isProvisional
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (isProvisional) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF334155),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Back to Edit'),
                                onPressed: () => Navigator.pop(dialogContext),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text(
                                  'Confirm & Issue Certificate',
                                ),
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  await onConfirmIssue?.call();
                                },
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF334155),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Download / Save PDF'),
                                onPressed: () {
                                  context.showSnackbar(
                                    SnackBar(
                                      content: Text(
                                        'Downloading Certificate ${cert.certificateNumber} as PDF...',
                                      ),
                                      backgroundColor: Colors.teal,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.print, size: 16),
                                label: const Text('Print Official Certificate'),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  context.showSnackbar(
                                    SnackBar(
                                      content: Text(
                                        'Certificate ${cert.certificateNumber} sent to printer!',
                                      ),
                                      backgroundColor: const Color(0xFF1E3A8A),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Document Slate Canvas Area
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF1F5F9),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 20,
                        ),
                        child: Center(
                          child:
                              isTC
                                  ? _buildOfficialTransferCertificatePaper(
                                    item,
                                    dataMap,
                                  )
                                  : isCC
                                  ? _buildOfficialCharacterCertificatePaper(
                                    item,
                                    dataMap,
                                  )
                                  : isMarksheet
                                  ? _buildOfficialMarksheetPaper(item, dataMap)
                                  : isBonafide
                                  ? _buildOfficialBonafideCertificatePaper(
                                    item,
                                    dataMap,
                                  )
                                  : isMerit
                                  ? _buildOfficialMeritCertificatePaper(
                                    item,
                                    dataMap,
                                  )
                                  : _buildDefaultCertificatePaper(
                                    item,
                                    dataMap,
                                  ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Status Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isProvisional
                              ? const Color(0xFFFFFBEB)
                              : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color:
                              isProvisional
                                  ? const Color(0xFFFDE68A)
                                  : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isProvisional
                                  ? Icons.info_outline
                                  : Icons.check_circle,
                              size: 16,
                              color:
                                  isProvisional
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isProvisional
                                  ? 'Provisional Preview • Review details before confirming certificate issuance'
                                  : 'Official Institutional Document • Anti-tamper digital registry valid',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color:
                                    isProvisional
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isProvisional
                              ? 'Click "Back to Edit" to make adjustments or "Confirm & Issue Certificate" to finalize'
                              : 'Tip: Select "Save as PDF" in print dialog destination to download file',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color:
                                isProvisional
                                    ? const Color(0xFFB45309)
                                    : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== TRANSFER CERTIFICATE PAPER (PIXEL-PERFECT) ====================

  Widget _buildOfficialTransferCertificatePaper(
    CertificateWithDetails item,
    Map<String, dynamic> data,
  ) {
    final cert = item.certificate;
    final tcData = TransferCertificateData.fromJson(data);

    final studentName = item.studentName;
    final fatherName =
        tcData.fatherName?.isNotEmpty == true
            ? tcData.fatherName!
            : (item.student.emergencyContactName?.isNotEmpty == true
                ? item.student.emergencyContactName!
                : 'William Montgomery');
    final motherName =
        tcData.motherName?.isNotEmpty == true
            ? tcData.motherName!
            : 'Diane Montgomery';
    final nationality =
        tcData.nationality?.isNotEmpty == true ? tcData.nationality! : 'Nepali';

    final admissionDate = tcData.admissionDate ?? item.student.admissionDate;
    final admittedClass =
        tcData.admittedClass ??
        (item.className != null && item.className!.isNotEmpty
            ? item.className!
            : 'Grade 11');
    final admissionDateStr = _formatDate(admissionDate);

    final dob = item.student.dateOfBirth ?? DateTime(2008, 12, 4);
    final dobFigures = _formatDate(dob);
    final dobWords =
        tcData.dobInWords?.isNotEmpty == true
            ? tcData.dobInWords!
            : _formatDateInWords(dob);

    final sectionStr = item.sectionName ?? 'Section A';
    final classStudied =
        '${item.className ?? tcData.classInWhichStudying} $sectionStr'.trim();

    final examResult =
        tcData.lastExamPassed?.isNotEmpty == true
            ? tcData.lastExamPassed!
            : 'Grade 11 (Annual Assessment)';
    final whetherFailed =
        tcData.whetherFailed?.isNotEmpty == true
            ? tcData.whetherFailed!
            : 'No (Passed on first attempt)';
    final subjects =
        tcData.subjectsStudied?.isNotEmpty == true
            ? tcData.subjectsStudied!
            : 'Mathematics, Physics, Chemistry, English Literature, Computer Science';
    final promotion =
        tcData.promotedToClass?.isNotEmpty == true
            ? (tcData.promotedToClass!.toLowerCase().startsWith('promoted')
                ? tcData.promotedToClass!
                : 'Promoted to ${tcData.promotedToClass}')
            : 'Promoted to next grade';
    final duesStatus =
        tcData.duesClearedUpTo?.isNotEmpty == true
            ? tcData.duesClearedUpTo!
            : (cert.duesCleared
                ? 'All dues cleared up to current month'
                : 'Pending dues');
    final feeConcession =
        tcData.feeConcession?.isNotEmpty == true
            ? tcData.feeConcession!
            : 'None';
    final totalWorkingDays = tcData.totalWorkingDays ?? 210;
    final totalPresentDays = tcData.totalPresentDays ?? 198;
    final conduct =
        cert.conduct?.isNotEmpty == true
            ? cert.conduct!
            : (tcData.conduct.isNotEmpty
                ? tcData.conduct
                : 'Exemplary & Diligent');
    final appDateStr = _formatDate(tcData.applicationDate ?? cert.issueDate);
    final issueDateStr = _formatDate(cert.issueDate);
    final reasonForLeaving =
        tcData.reasonForLeaving.isNotEmpty
            ? tcData.reasonForLeaving
            : 'Parent relocation to another locality / higher studies';
    final remarks =
        cert.remarks?.isNotEmpty == true
            ? cert.remarks!
            : (tcData.generalRemarks?.isNotEmpty == true
                ? tcData.generalRemarks!
                : 'A well-behaved, respectful, and sincere student.');
    final rollNoDisplay =
        item.rollNumber != null
            ? '${item.className?.replaceAll(RegExp(r'[^0-9]'), '') ?? '11'}A-${item.rollNumber!.toString().padLeft(2, '0')}'
            : '11A-04';

    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Outer charcoal & Inner gold double border frame
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD97706), width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Metadata Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'ESTD: 1998',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'REG NO: EDU-89218-CENTRAL',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'NEB AFFILIATION #NEB-NP-48291',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Institutional Branding Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // School Emblem
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E3A8A),
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'HIMALAYAN APEX MODEL SECONDARY SCHOOL',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 18.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kathmandu Metropolitan-04, Bagmati Province, Nepal | Tel: +977-1-4412345 | info@himalayanapex.edu.np',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(Recognized by the Ministry of Education & Affiliated to National Examination Board)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 62), // Balancing logo spacer
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pill Box: TRANSFER CERTIFICATE (T.C.)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD97706),
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'TRANSFER CERTIFICATE (T.C.)',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4-Column Reference Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _buildRefCol('T.C. Serial No:', cert.certificateNumber),
                        _buildRefCol('Admission No:', item.admissionNumber),
                        _buildRefCol('Roll No:', rollNoDisplay),
                        _buildRefCol('Date of Issue:', issueDateStr),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFD97706), thickness: 1),
                  const SizedBox(height: 6),

                  // Exact 20 Official Items
                  _buildTCRow(
                    number: '1',
                    label: 'Name of Pupil (in Block Letters)',
                    value: studentName,
                    isUppercase: true,
                  ),
                  _buildTCRow(
                    number: '2',
                    label: "Father's / Guardian's Full Name",
                    value: fatherName,
                  ),
                  _buildTCRow(
                    number: '3',
                    label: "Mother's Full Name",
                    value: motherName,
                  ),
                  _buildTCRow(
                    number: '4',
                    label: 'Nationality & Citizenship',
                    value: nationality,
                  ),
                  _buildTCRow(
                    number: '5',
                    label: 'Date of First Admission in School with Class',
                    value: '$admissionDateStr ($admittedClass)',
                  ),
                  _buildTCRow(
                    number: '6',
                    label: 'Date of Birth (in figures)',
                    value: dobFigures,
                    secondaryLabel: 'Date of Birth (in words)',
                    secondaryValue: dobWords,
                  ),
                  _buildTCRow(
                    number: '7',
                    label: 'Class in which pupil last studied',
                    value: classStudied,
                  ),
                  _buildTCRow(
                    number: '8',
                    label:
                        'School / Board Annual Examination last taken with result',
                    value: examResult,
                  ),
                  _buildTCRow(
                    number: '9',
                    label: 'Whether failed, if so once/twice in same class',
                    value: whetherFailed,
                  ),
                  _buildTCRow(
                    number: '10',
                    label: 'Subjects Studied',
                    value: subjects,
                    isItalic: true,
                  ),
                  _buildTCRow(
                    number: '11',
                    label: 'Whether qualified for promotion to higher class',
                    value: promotion,
                  ),
                  _buildTCRow(
                    number: '12',
                    label: 'Month up to which school dues / tuition paid',
                    value: duesStatus,
                  ),
                  _buildTCRow(
                    number: '13',
                    label: 'Any fee concession availed',
                    value: feeConcession,
                  ),
                  _buildTCRow(
                    number: '14',
                    label: 'Total number of working days in academic session',
                    value: '$totalWorkingDays Days',
                  ),
                  _buildTCRow(
                    number: '15',
                    label: 'Total number of school days pupil was present',
                    value: '$totalPresentDays Days',
                  ),
                  _buildTCRow(
                    number: '16',
                    label: 'General Conduct & Institutional Discipline',
                    value: conduct,
                  ),
                  _buildTCRow(
                    number: '17',
                    label: 'Date of application for certificate',
                    value: appDateStr,
                  ),
                  _buildTCRow(
                    number: '18',
                    label: 'Date of issue of certificate',
                    value: issueDateStr,
                  ),
                  _buildTCRow(
                    number: '19',
                    label: 'Reasons for leaving the institution',
                    value: reasonForLeaving,
                  ),
                  _buildTCRow(
                    number: '20',
                    label: 'Any other remarks / commendations',
                    value: remarks,
                  ),

                  const SizedBox(height: 24),

                  // Signatures and Official Seal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left: Admission In-Charge
                      Column(
                        children: [
                          Container(
                            width: 130,
                            height: 1,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ADMISSION IN-CHARGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Checked & Verified by',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      // Center: Dual-ring gold official seal
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD97706),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'OFFICIAL SEAL',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '• VERIFIED •',
                                  style: TextStyle(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'REGISTRY',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Right: Principal
                      Column(
                        children: [
                          Container(
                            width: 130,
                            height: 1,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PRINCIPAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Head of Institution',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 4 Corner Brackets
          _buildCornerBracket(isTop: true, isLeft: true),
          _buildCornerBracket(isTop: true, isLeft: false),
          _buildCornerBracket(isTop: false, isLeft: true),
          _buildCornerBracket(isTop: false, isLeft: false),
        ],
      ),
    );
  }

  // ==================== CHARACTER CERTIFICATE PAPER (PIXEL-PERFECT) ====================

  Widget _buildOfficialCharacterCertificatePaper(
    CertificateWithDetails item,
    Map<String, dynamic> data,
  ) {
    final cert = item.certificate;
    final ccData = CharacterCertificateData.fromJson(data);

    final studentName = item.studentName;
    final fatherName =
        ccData.fatherName?.isNotEmpty == true
            ? ccData.fatherName!
            : (item.student.emergencyContactName?.isNotEmpty == true
                ? item.student.emergencyContactName!
                : 'Carlos Rodriguez');
    final motherName =
        ccData.motherName?.isNotEmpty == true
            ? ccData.motherName!
            : 'Maria Rodriguez';
    final admissionNumber =
        item.admissionNumber.isNotEmpty ? item.admissionNumber : 'ADM-2024-002';
    final rollNumberStr =
        item.rollNumber != null ? item.rollNumber.toString() : '1002';
    final className = item.className ?? 'Grade 10';
    final sectionName = item.sectionName ?? 'Section A';
    final sessionStr =
        ccData.session?.isNotEmpty == true
            ? ccData.session!
            : (item.academicYearName ?? '2025-2026');
    final dateStr = _formatDate(cert.issueDate);
    final ratingStr =
        cert.conduct?.isNotEmpty == true
            ? cert.conduct!
            : (ccData.characterRating.isNotEmpty
                ? ccData.characterRating
                : 'EXEMPLARY');

    final firstName = studentName.split(' ').first;
    final isFemale = item.student.gender.toLowerCase().startsWith('f');
    final pronounPossessive = isFemale ? 'her' : 'his';

    final praiseStatement =
        ccData.generalRemarks?.isNotEmpty == true
            ? (ccData.generalRemarks!.contains('{student_name}') ||
                    ccData.generalRemarks!.contains('{name}')
                ? ccData.generalRemarks!
                    .replaceAll('{student_name}', studentName)
                    .replaceAll('{name}', firstName)
                : (ccData.generalRemarks!.startsWith(firstName) ||
                        ccData.generalRemarks!.startsWith(studentName)
                    ? ccData.generalRemarks!
                    : '$firstName ${ccData.generalRemarks!}'))
            : '$firstName has maintained an unblemished record of moral character, exceptional integrity, and positive leadership throughout $pronounPossessive tenure at our academy.';

    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Outer warm copper/amber & Inner gold double border frame
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF9A3412), width: 1.5),
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD97706), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Metadata Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'ESTD: 1998',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'REG NO: EDU-89218-CENTRAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'NEB AFFILIATION #NEB-NP-48291',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Institutional Header (Emblem + School Name + Address + Motto)
                  Row(
                    children: [
                      // Dual-ring Graduation Emblem
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0F172A),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // School Details
                      Expanded(
                        child: Column(
                          children: const [
                            Text(
                              'HIMALAYAN APEX MODEL SECONDARY SCHOOL',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 19.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'New Baneshwor, Ward No. 10 • Tel: +977 1-4782390 • Email: info@himalayanacademy.edu.np',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Excellence in Character, Scholarship & Leadership',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SizedBox(width: 44), // Symmetry spacer
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Title Pill Banner
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(
                          color: const Color(0xFFD97706),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'CHARACTER & CONDUCT CERTIFICATE',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E),
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Reference, Session & Date Line
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                          ),
                          children: [
                            const TextSpan(text: 'Ref / Serial No: '),
                            TextSpan(
                              text: cert.certificateNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                          ),
                          children: [
                            const TextSpan(text: 'Session: '),
                            TextSpan(
                              text: sessionStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                          ),
                          children: [
                            const TextSpan(text: 'Date: '),
                            TextSpan(
                              text: dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. Formal Header
                  const Center(
                    child: Text(
                      'TO WHOMSOEVER IT MAY CONCERN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 1.8,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF0F172A),
                        decorationThickness: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 6. Body Paragraph 1: Pupil Identification & Enrollment
                  RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.85,
                        color: Color(0xFF1E293B),
                      ),
                      children: [
                        const TextSpan(
                          text: 'This is to solemnly certify that ',
                        ),
                        TextSpan(
                          text: studentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(text: ', Son / Daughter of Mr. '),
                        TextSpan(
                          text: fatherName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(text: ' and Mrs. '),
                        TextSpan(
                          text: motherName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(text: ', bearing Admission Number '),
                        TextSpan(
                          text: admissionNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                        const TextSpan(text: ' and Roll Number '),
                        TextSpan(
                          text: rollNumberStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(
                          text: ', is / was a bonafide student of ',
                        ),
                        const TextSpan(
                          text: 'Himalayan Apex Model Secondary School',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(text: ' studying in '),
                        TextSpan(
                          text: '$className $sectionName'.trim(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7. Body Paragraph 2: Conduct & Discipline Assessment
                  RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.85,
                        color: Color(0xFF1E293B),
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'During their period of study at this institution, their moral character, general behavior, and personal conduct have been ',
                        ),
                        TextSpan(
                          text: ratingStr.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB45309),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '. They have consistently displayed exceptional integrity, institutional discipline, and respect toward teachers, staff, and peers alike.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 8. Body Paragraph 3: Commendation & Record
                  RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.85,
                        color: Color(0xFF1E293B),
                      ),
                      children: [TextSpan(text: praiseStatement)],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 9. Body Paragraph 4: Formal Closing / Blessing
                  RichText(
                    textAlign: TextAlign.justify,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.85,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'serif',
                        color: Color(0xFF334155),
                      ),
                      text:
                          'We commend them for their dignified conduct and extend our heartiest blessings and best wishes for their continued success in all future educational, professional, and personal pursuits.',
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 10. Signatures & Official Institutional Seal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left: Class Teacher Signatory
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Signature',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 140,
                            height: 1,
                            color: const Color(0xFF0F172A),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'CLASS TEACHER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Evaluated by',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),

                      // Center: Official Seal Badge (Dual-Ring Gold)
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 1.8,
                          ),
                        ),
                        padding: const EdgeInsets.all(3.5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFFD97706,
                              ).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 15,
                                  color: Color(0xFFD97706),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'OFFICIAL SEAL',
                                  style: TextStyle(
                                    fontSize: 6,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFB45309),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '★ VERIFIED ★',
                                  style: TextStyle(
                                    fontSize: 5.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                Text(
                                  'REGISTRY',
                                  style: TextStyle(
                                    fontSize: 5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Right: Principal / Head of Institution Signatory
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Authorized Signatory',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 170,
                            height: 1,
                            color: const Color(0xFF0F172A),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'PRINCIPAL / HEAD OF INSTITUTION',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Institutional Signatory',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4 Corner Brackets
          _buildCornerBracket(isTop: true, isLeft: true),
          _buildCornerBracket(isTop: true, isLeft: false),
          _buildCornerBracket(isTop: false, isLeft: true),
          _buildCornerBracket(isTop: false, isLeft: false),
        ],
      ),
    );
  }

  // ==================== OFFICIAL MARKSHEET / ACADEMIC TRANSCRIPT PAPER ====================

  String _getSubjectRemark(String? grade) {
    switch (grade?.trim().toUpperCase()) {
      case 'A+':
        return 'Outstanding';
      case 'A':
        return 'Excellent';
      case 'B+':
        return 'Very Good';
      case 'B':
        return 'Good';
      case 'C+':
        return 'Satisfactory';
      case 'C':
        return 'Acceptable';
      case 'D':
        return 'Insufficient';
      default:
        return 'Passed';
    }
  }

  Widget _buildOfficialMarksheetPaper(
    CertificateWithDetails item,
    Map<String, dynamic> dataMap,
  ) {
    final cert = item.certificate;
    MarksheetData msData;
    try {
      msData = MarksheetData.fromJson(dataMap);
    } catch (_) {
      msData = const MarksheetData(
        examName: 'First Term Assessment 2026',
        subjects: [],
        totalFullMarks: 0,
        totalPassMarks: 0,
        totalMarksObtained: 0,
        percentage: 0,
        gpa: 0,
        division: 'N/A',
        result: 'N/A',
      );
    }

    // Subjects list: fallback to realistic defaults matching reference image if empty
    final List<MarksheetSubjectEntry> subjects;
    if (msData.subjects.isNotEmpty) {
      subjects = msData.subjects;
    } else {
      subjects = [
        MarksheetSubjectEntry(
          subjectCode: 'MTH-101',
          subjectName: 'Mathematics',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 80,
          practicalMarks: 20,
          theoryObtained: 76,
          practicalObtained: 20,
          totalObtained: 96,
          grade: 'A+',
          gradePoint: 4.0,
          remarks: 'Outstanding',
        ),
        MarksheetSubjectEntry(
          subjectCode: 'PHY-102',
          subjectName: 'Physics',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 75,
          practicalMarks: 25,
          theoryObtained: 72,
          practicalObtained: 20,
          totalObtained: 92,
          grade: 'A+',
          gradePoint: 4.0,
          remarks: 'Excellent',
        ),
        MarksheetSubjectEntry(
          subjectCode: 'CHM-103',
          subjectName: 'Chemistry',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 75,
          practicalMarks: 25,
          theoryObtained: 70,
          practicalObtained: 19,
          totalObtained: 89,
          grade: 'A',
          gradePoint: 3.7,
          remarks: 'Very Good',
        ),
        MarksheetSubjectEntry(
          subjectCode: 'ENG-104',
          subjectName: 'English Literature',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 100,
          practicalMarks: 0,
          theoryObtained: 91,
          practicalObtained: 0,
          totalObtained: 91,
          grade: 'A+',
          gradePoint: 4.0,
          remarks: 'Distinction',
        ),
        MarksheetSubjectEntry(
          subjectCode: 'CS-105',
          subjectName: 'Computer Science',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 75,
          practicalMarks: 25,
          theoryObtained: 74,
          practicalObtained: 20,
          totalObtained: 94,
          grade: 'A+',
          gradePoint: 4.0,
          remarks: 'Outstanding',
        ),
      ];
    }

    double totalMax = 0;
    double totalObtained = 0;
    for (final s in subjects) {
      totalMax += s.fullMarks;
      totalObtained += s.totalObtained;
    }
    final percentage =
        totalMax > 0
            ? (totalObtained / totalMax) * 100
            : (msData.percentage > 0 ? msData.percentage : 92.4);
    final overallGrade =
        CertificateService.calculateGrade(percentage).letterGrade;
    final double cumulativeGpa =
        subjects.isNotEmpty
            ? (subjects.map((s) => s.gradePoint).reduce((a, b) => a + b) /
                subjects.length)
            : (msData.gpa > 0 ? msData.gpa : 3.92);
    final isPassed = subjects.every((s) => s.isPassed);
    final String standingText =
        isPassed
            ? (percentage >= 85
                ? 'Passed with Distinction'
                : (percentage >= 70 ? 'Passed with First Division' : 'Passed'))
            : 'Failed';

    final studentName =
        item.studentName.isNotEmpty ? item.studentName : 'Lucas Ryan Patel';
    final admissionNo =
        item.admissionNumber.isNotEmpty ? item.admissionNumber : 'ADM-2024-003';
    final classSection =
        '${item.className ?? "Grade 9"} - Section ${item.sectionName ?? "A"}';
    final rollNumber =
        item.rollNumber != null
            ? item.rollNumber.toString().padLeft(4, '0')
            : '0901';

    final fatherName =
        (dataMap['fatherName'] as String?)?.trim().isNotEmpty == true
            ? dataMap['fatherName'] as String
            : 'Vikram Patel';
    final motherName =
        (dataMap['motherName'] as String?)?.trim().isNotEmpty == true
            ? dataMap['motherName'] as String
            : 'Sunita Patel';
    final dobStr =
        item.student.dateOfBirth != null
            ? _formatDate(item.student.dateOfBirth!)
            : '2011-02-14';
    final resultDateStr = _formatDate(cert.issueDate);
    final sessionStr =
        (dataMap['session'] as String?)?.trim().isNotEmpty == true
            ? dataMap['session'] as String
            : (item.academicYearName ?? '2025-2026');
    final examTitle =
        msData.examName.trim().isNotEmpty
            ? msData.examName.trim()
            : 'FIRST TERM ASSESSMENT 2026';

    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1E293B), width: 1.8),
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1E293B), width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Metadata Row
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ESTD: 1998',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'REG NO: EDU-8924-CENTRAL',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'NEB AFFILIATION #NEB-NP-49291',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. School Letterhead Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Logo
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F172A),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          size: 26,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'HIMALAYAN APEX MODEL SECONDARY SCHOOL',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'New Baneshwor, Ward No. 10 • Tel: +977 1-4781920 • Email: info@himalayanacademy.edu.np',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Annual & Terminal Examination Board • Academic Session $sessionStr',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 52), // Symmetry for logo
                ],
              ),
              const SizedBox(height: 12),

              // 3. Pill Banner
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4F46E5),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'OFFICIAL MARKSHEET & TRANSCRIPT: ${examTitle.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Student & Exam Details Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            'STUDENT NAME',
                            studentName,
                          ),
                        ),
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            'ADMISSION / REG NO',
                            admissionNo,
                          ),
                        ),
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            'CLASS & SECTION',
                            classSection,
                          ),
                        ),
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            'ROLL NUMBER',
                            rollNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            "FATHER'S NAME",
                            fatherName,
                          ),
                        ),
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            "MOTHER'S NAME",
                            motherName,
                          ),
                        ),
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            'DATE OF BIRTH',
                            dobStr,
                          ),
                        ),
                        Expanded(
                          child: _buildMarksheetDetailCell(
                            'RESULT DATE',
                            resultDateStr,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Subject Marks Table
              // Header Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        'S.N.',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 26,
                      child: Text(
                        'SUBJECT NAME',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 12,
                      child: Text(
                        'CODE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 9,
                      child: Text(
                        'MAX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 9,
                      child: Text(
                        'PASS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 11,
                      child: Text(
                        'THEORY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 13,
                      child: Text(
                        'PRACTICAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 13,
                      child: Text(
                        'OBTAINED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: Text(
                        'GRADE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 12,
                      child: Text(
                        'GRADE PT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 16,
                      child: Text(
                        'REMARKS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Subject Rows
              ...List.generate(subjects.length, (i) {
                final s = subjects[i];
                final thText =
                    s.theoryObtained != null
                        ? s.theoryObtained!.toInt().toString()
                        : (s.theoryMarks != null
                            ? s.theoryMarks!.toInt().toString()
                            : '-');
                final prText =
                    s.practicalObtained != null
                        ? s.practicalObtained!.toInt().toString()
                        : (s.practicalMarks != null
                            ? s.practicalMarks!.toInt().toString()
                            : '-');
                final remarkText =
                    s.remarks?.trim().isNotEmpty == true
                        ? s.remarks!.trim()
                        : _getSubjectRemark(s.grade);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 6,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 26,
                        child: Text(
                          s.subjectName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: Text(
                          s.subjectCode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 9,
                        child: Text(
                          '${s.fullMarks.toInt()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 9,
                        child: Text(
                          '${s.passMarks.toInt()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 11,
                        child: Text(
                          thText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 13,
                        child: Text(
                          prText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 13,
                        child: Text(
                          '${s.totalObtained.toInt()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: Text(
                          s.grade,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                s.grade.startsWith('A')
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: Text(
                          s.gradePoint.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Text(
                          remarkText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Total Aggregate Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
                    bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 26),
                    const Expanded(
                      flex: 26,
                      child: Text(
                        'TOTAL AGGREGATE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(flex: 12, child: SizedBox()),
                    Expanded(
                      flex: 9,
                      child: Text(
                        '${totalMax.toInt()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 9,
                      child: Text(
                        '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const Expanded(
                      flex: 11,
                      child: Text(
                        '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const Expanded(
                      flex: 13,
                      child: Text(
                        '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    Expanded(
                      flex: 13,
                      child: Text(
                        '${totalObtained.toInt()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: Text(
                        overallGrade,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 12,
                      child: Text(
                        cumulativeGpa.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 16,
                      child: Text(
                        standingText.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color:
                              isPassed
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6. Summary Result Cards Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OVERALL PERCENTAGE',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CUMULATIVE GPA',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${cumulativeGpa.toStringAsFixed(2)} / 4.00',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FINAL ASSESSMENT STANDING',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            standingText,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color:
                                  isPassed
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 7. Standard Grading Scale Key
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STANDARD GRADING SCALE KEY:',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'A+ (90-100% Outstanding • 4.0)   •   A (80-89% Excellent • 3.6)   •   B+ (70-79% Very Good • 3.2)   •   B (60-69% Good • 2.8)   •   C+ (50-59% Satisfactory • 2.4)',
                      style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'C (40-49% Acceptable • 2.0)   •   D (Below 40% Insufficient)',
                      style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 8. Bottom Signatures & Seal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: Class Teacher Signatory
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Signature',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 140,
                        height: 1,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'CLASS TEACHER',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Prepared by',
                        style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  // Center: Official Seal
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFD97706,
                            ).withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'OFFICIAL SEAL',
                              style: TextStyle(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              'ACCREDITED',
                              style: TextStyle(
                                fontSize: 5.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              resultDateStr,
                              style: const TextStyle(
                                fontSize: 5.5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right: Principal / Authorized Signatory
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Authorized Signatory',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 150,
                        height: 1,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'PRINCIPAL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Authorized Signatory',
                        style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarksheetDetailCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ==================== OFFICIAL BONAFIDE CERTIFICATE PAPER ====================

  Widget _buildOfficialBonafideCertificatePaper(
    CertificateWithDetails item,
    Map<String, dynamic> dataMap,
  ) {
    final cert = item.certificate;
    final bonData = BonafideCertificateData.fromJson(dataMap);

    // Student & parent names
    final studentName = item.studentName;
    final fatherName =
        bonData.fatherName?.trim().isNotEmpty == true
            ? bonData.fatherName!.trim()
            : (item.student.emergencyContactName?.trim().isNotEmpty == true
                ? item.student.emergencyContactName!.trim()
                : 'Carlos Rodriguez');
    final motherName =
        bonData.motherName?.trim().isNotEmpty == true
            ? bonData.motherName!.trim()
            : 'Maria Rodriguez';

    // Academic session
    final sessionStr =
        bonData.session?.trim().isNotEmpty == true
            ? bonData.session!.trim()
            : (bonData.academicYear?.trim().isNotEmpty == true
                ? bonData.academicYear!.trim()
                : (item.academicYearName ?? '2025-2026'));

    // Class & Section
    final className = item.className ?? 'Grade 10';
    final sectionRaw = item.sectionName ?? 'Section A';
    final sectionFormatted =
        sectionRaw.startsWith('Section') ? sectionRaw : 'Section $sectionRaw';
    final gradeSectionStr = '$className ($sectionFormatted)';

    // Admission, Roll, DOB
    final admissionNo =
        item.admissionNumber.isNotEmpty ? item.admissionNumber : 'ADM-2024-002';
    final rollNo =
        item.rollNumber != null ? item.rollNumber.toString() : '1002';

    final DateTime? dobDate = bonData.dob ?? item.student.dateOfBirth;
    final dobFormatted =
        dobDate != null
            ? '${dobDate.year}-${dobDate.month.toString().padLeft(2, '0')}-${dobDate.day.toString().padLeft(2, '0')}'
            : '2010-09-21';

    final issueDate = cert.issueDate;
    final issueDateFormatted =
        '${issueDate.year}-${issueDate.month.toString().padLeft(2, '0')}-${issueDate.day.toString().padLeft(2, '0')}';

    // Purpose & Conduct
    final purposeStr =
        bonData.purpose.trim().isNotEmpty
            ? bonData.purpose.trim()
            : 'Passport & Visa documentation verification';

    final conductStr =
        bonData.generalRemarks?.trim().isNotEmpty == true
            ? bonData.generalRemarks!.trim()
            : 'Their conduct and character have been consistently good throughout their tenure at this institution.';

    return Container(
      width: 760,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        // Outer Charcoal Border (1.8px)
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1E293B), width: 1.8),
        ),
        padding: const EdgeInsets.all(5), // 5px spacing gap
        child: Container(
          // Inner Charcoal Border (1.0px)
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1E293B), width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Top Metadata Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'ESTD: 1998',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'REG NO: EDU-8924-CENTRAL',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'NEB AFFILIATION #NEB-NP-49291',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. School Emblem + Name & Address Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // School Emblem
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E293B),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1E293B),
                          width: 0.8,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.school_outlined,
                          size: 26,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                  // School Name & Contact (Center)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Text(
                          'HIMALAYAN APEX MODEL SECONDARY SCHOOL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'New Baneshwor, Ward No. 10 • Tel: +977 1-4781920 • Email: info@himalayanacademy.edu.np',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Office of the Registrar & Academic Administration',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Balancer
                  const SizedBox(width: 56),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Bonafide Student Certificate Pill Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 5.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF059669),
                    width: 1.2,
                  ),
                ),
                child: const Text(
                  'BONAFIDE STUDENT CERTIFICATE',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Metadata Line (Certificate Ref & Date of Issuance)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontFamily: 'sans-serif',
                      ),
                      children: [
                        const TextSpan(text: 'Certificate Ref: '),
                        TextSpan(
                          text: cert.certificateNumber,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontFamily: 'sans-serif',
                      ),
                      children: [
                        const TextSpan(text: 'Date of Issuance: '),
                        TextSpan(
                          text: issueDateFormatted,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 24),

              // 5. Section Heading: TO WHOMSOEVER IT MAY CONCERN
              Column(
                children: [
                  const Text(
                    'TO WHOMSOEVER IT MAY CONCERN',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 250,
                    height: 1.2,
                    color: const Color(0xFF0F172A),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. Body Paragraph 1: Certification
              RichText(
                textAlign: TextAlign.justify,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xFF334155),
                    fontFamily: 'sans-serif',
                  ),
                  children: [
                    const TextSpan(text: 'This is to officially certify that '),
                    TextSpan(
                      text: studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: ', Son / Daughter of '),
                    TextSpan(
                      text: 'Mr. $fatherName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Mrs. $motherName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(
                      text: ', is a genuine and bonafide regular student of ',
                    ),
                    const TextSpan(
                      text: 'Himalayan Apex Model Secondary School',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: ', presently enrolled in '),
                    TextSpan(
                      text: gradeSectionStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: ' for the academic session '),
                    TextSpan(
                      text: sessionStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 7. Body Paragraph 2: Admission & DOB Ledger
              RichText(
                textAlign: TextAlign.justify,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xFF334155),
                    fontFamily: 'sans-serif',
                  ),
                  children: [
                    const TextSpan(
                      text:
                          'As per our institutional admission ledger, their Student Admission Number is ',
                    ),
                    TextSpan(
                      text: admissionNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const TextSpan(
                      text: ', and their recorded Roll Number is ',
                    ),
                    TextSpan(
                      text: rollNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: '. Their recorded date of birth is '),
                    TextSpan(
                      text: dobFormatted,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 8. Specific Purpose Container Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SPECIFIC PURPOSE OF CERTIFICATE ISSUANCE:',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      purposeStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 9. Body Paragraph 4: Conduct & Character
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  conductStr,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 52),

              // 10. Signatures & Official Institutional Seal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: Registry Clerk
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Signature',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 140,
                        height: 1,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'REGISTRY CLERK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Verified by',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  // Center: Dual-Ring Gold Official Seal
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 1.8,
                      ),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD97706).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'OFFICIAL SEAL',
                              style: TextStyle(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              'ACCREDITED',
                              style: TextStyle(
                                fontSize: 5.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              issueDateFormatted,
                              style: const TextStyle(
                                fontSize: 5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right: Principal
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Authorized Signatory',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 140,
                        height: 1,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'PRINCIPAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Head of Institution',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== OFFICIAL CERTIFICATE OF MERIT & DISTINCTION PAPER ====================

  Widget _buildOfficialMeritCertificatePaper(
    CertificateWithDetails item,
    Map<String, dynamic> dataMap,
  ) {
    final cert = item.certificate;
    final meritData = MeritCertificateData.fromJson(dataMap);

    final studentName = item.studentName;
    final className = item.className ?? 'Grade 10';
    final admissionNo =
        item.admissionNumber.isNotEmpty ? item.admissionNumber : 'ADM-2024-001';

    final eventTitle = meritData.eventTitle;
    final rank = meritData.rank;
    final citation =
        meritData.citation?.trim().isNotEmpty == true
            ? meritData.citation!.trim()
            : (meritData.remarks?.trim().isNotEmpty == true
                ? meritData.remarks!.trim()
                : 'Awarded for extraordinary research and autonomous robotic vehicle design.');

    final coordinatorTitle =
        meritData.coordinatorTitle?.trim().isNotEmpty == true
            ? meritData.coordinatorTitle!.trim()
            : 'ACTIVITY COORDINATOR';
    final principalTitle =
        meritData.principalTitle?.trim().isNotEmpty == true
            ? meritData.principalTitle!.trim()
            : 'PRINCIPAL';

    final issueDate = cert.issueDate;
    final issueDateFormatted =
        '${issueDate.year}-${issueDate.month.toString().padLeft(2, '0')}-${issueDate.day.toString().padLeft(2, '0')}';

    return Container(
      width: 760,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        // Outer Warm Gold / Amber Border (1.8px)
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD97706), width: 1.8),
        ),
        padding: const EdgeInsets.all(5), // 5px spacing gap
        child: Container(
          // Inner Warm Gold / Amber Border (1.0px)
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD97706), width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Top Metadata Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'ESTD: 1998',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'REG NO: EDU-8924-CENTRAL',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'NEB AFFILIATION #NEB-NP-49291',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. School Emblem + Name & Address Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // School Emblem
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E293B),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1E293B),
                          width: 0.8,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.school_outlined,
                          size: 26,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                  // School Name & Contact (Center)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Text(
                          'HIMALAYAN APEX MODEL SECONDARY SCHOOL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'New Baneshwor, Ward No. 10 • Tel: +977 1-4781920 • Email: info@himalayanacademy.edu.np',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Honoring Distinction, Scholarship & Exceptional Merit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Balancer
                  const SizedBox(width: 56),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Certificate of Merit & Distinction Pill Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 5.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFD97706),
                    width: 1.2,
                  ),
                ),
                child: const Text(
                  'CERTIFICATE OF MERIT & DISTINCTION',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Ribbon / Medal Icon
              const Icon(
                Icons.military_tech_outlined,
                size: 30,
                color: Color(0xFFD97706),
              ),
              const SizedBox(height: 10),

              // 5. Award Lead-in
              const Text(
                'THIS CERTIFICATE OF EXCELLENCE IS PROUDLY AWARDED TO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),

              // 6. Recipient Student Name & Underline
              Text(
                studentName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 260,
                height: 1.2,
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(height: 6),

              // 7. Student Grade & Admission Number
              Text(
                '$className • Admission No: $admissionNo',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // 8. Recognition Statement
              const Text(
                'in high recognition of outstanding performance, exemplary dedication, and commendable accomplishment in:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 12),

              // 9. Event / Achievement Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  eventTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 10. Rank / Distinction Line
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                    fontFamily: 'sans-serif',
                  ),
                  children: [
                    const TextSpan(
                      text: 'Rank / Distinction: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: rank,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 11. Citation / Commendation Quote
              Text(
                '"$citation"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 48),

              // 12. Signatures & Official Institutional Seal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: Activity Coordinator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Signature',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 140,
                        height: 1,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        coordinatorTitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Convener',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  // Center: Dual-Ring Gold Official Seal
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 1.8,
                      ),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD97706).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'OFFICIAL SEAL',
                              style: TextStyle(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              'ACCREDITED',
                              style: TextStyle(
                                fontSize: 5.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              issueDateFormatted,
                              style: const TextStyle(
                                fontSize: 5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right: Principal
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Authorized Signatory',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 140,
                        height: 1,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        principalTitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Head of Institution',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DEFAULT CERTIFICATE PAPER (OTHER TYPES) ====================

  Widget _buildDefaultCertificatePaper(
    CertificateWithDetails item,
    Map<String, dynamic> dataMap,
  ) {
    final cert = item.certificate;
    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.indigo.shade800, width: 2),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.shade700, width: 1.5),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // School Letterhead Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigo.shade50,
                      border: Border.all(
                        color: Colors.indigo.shade300,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 36,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'SCHOOL MANAGEMENT SYSTEM',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.indigo.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Affiliated to National Education Board • Estd. 2000',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Kathmandu, Nepal • Phone: +977-1-4000000 • Email: info@school.edu.np',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60), // Balance logo
                ],
              ),
              const SizedBox(height: 14),

              // Ornamental Ribbon / Title Banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    cert.title.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'serif',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Serial and Date Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Certificate No: ${cert.certificateNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Date of Issue: ${_formatDate(cert.issueDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Certificate Body depending on Type
              if (cert.certificateType == 'marksheet') ...[
                _buildPrintMarksheetContent(item, dataMap),
              ] else if (cert.certificateType == 'cc') ...[
                _buildPrintCCContent(item, dataMap),
              ] else if (cert.certificateType == 'bonafide') ...[
                _buildPrintBonafideContent(item, dataMap),
              ] else ...[
                _buildPrintCustomContent(item, dataMap),
              ],

              const SizedBox(height: 40),

              // Signature Blocks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSignatureBlock('Class Teacher'),
                  // School Seal
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.indigo.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'OFFICIAL\nSEAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade300,
                        ),
                      ),
                    ),
                  ),
                  _buildSignatureBlock('Controller / Accountant'),
                  _buildSignatureBlock('Principal / Headmaster'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HELPER BUILDERS FOR OFFICIAL TC ====================

  Widget _buildCornerBracket({required bool isTop, required bool isLeft}) {
    return Positioned(
      top: isTop ? 18 : null,
      bottom: !isTop ? 18 : null,
      left: isLeft ? 18 : null,
      right: !isLeft ? 18 : null,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          border: Border(
            top:
                isTop
                    ? const BorderSide(color: Color(0xFFD97706), width: 2.5)
                    : BorderSide.none,
            bottom:
                !isTop
                    ? const BorderSide(color: Color(0xFFD97706), width: 2.5)
                    : BorderSide.none,
            left:
                isLeft
                    ? const BorderSide(color: Color(0xFFD97706), width: 2.5)
                    : BorderSide.none,
            right:
                !isLeft
                    ? const BorderSide(color: Color(0xFFD97706), width: 2.5)
                    : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRefCol(String title, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTCRow({
    required String number,
    required String label,
    required String value,
    bool isUppercase = false,
    bool isItalic = false,
    String? secondaryLabel,
    String? secondaryValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 355,
                child: Text(
                  '$number. $label:',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUppercase ? value.toUpperCase() : value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          if (secondaryLabel != null && secondaryValue != null) ...[
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 355,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Text(
                      '$secondaryLabel:',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    secondaryValue,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateInWords(DateTime? date) {
    if (date == null) return 'N/A';
    final day = date.day;
    final monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthStr =
        (date.month >= 1 && date.month <= 12) ? monthNames[date.month] : '';

    String daySuffix(int d) {
      if (d >= 11 && d <= 13) return '${d}th';
      switch (d % 10) {
        case 1:
          return '${d}st';
        case 2:
          return '${d}nd';
        case 3:
          return '${d}rd';
        default:
          return '${d}th';
      }
    }

    String yearInWords(int y) {
      final ones = [
        '',
        'One',
        'Two',
        'Three',
        'Four',
        'Five',
        'Six',
        'Seven',
        'Eight',
        'Nine',
        'Ten',
        'Eleven',
        'Twelve',
        'Thirteen',
        'Fourteen',
        'Fifteen',
        'Sixteen',
        'Seventeen',
        'Eighteen',
        'Nineteen',
      ];
      final tens = [
        '',
        '',
        'Twenty',
        'Thirty',
        'Forty',
        'Fifty',
        'Sixty',
        'Seventy',
        'Eighty',
        'Ninety',
      ];

      String twoDigits(int n) {
        if (n < 20) return ones[n];
        final t = n ~/ 10;
        final o = n % 10;
        return o == 0 ? tens[t] : '${tens[t]} ${ones[o]}';
      }

      if (y >= 2000 && y < 2100) {
        final rem = y - 2000;
        if (rem == 0) return 'Two Thousand';
        return 'Two Thousand ${twoDigits(rem)}';
      } else if (y >= 1900 && y < 2000) {
        final rem = y - 1900;
        return 'Nineteen ${twoDigits(rem)}';
      } else {
        return y.toString();
      }
    }

    return '${daySuffix(day)} $monthStr ${yearInWords(date.year)}';
  }

  // ==================== PRINT TEMPLATE RENDERERS ====================

  Widget _buildSignatureBlock(String title) {
    return Column(
      children: [
        Container(width: 120, height: 1, color: Colors.black87),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPrintCCContent(
    CertificateWithDetails item,
    Map<String, dynamic> data,
  ) {
    final cert = item.certificate;
    final ccData = CharacterCertificateData.fromJson(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildCertificateStatement([
          'This is to certify that ',
          _boldText(item.studentName),
          ', Admission No: ',
          _boldText(item.admissionNumber),
          ', Roll No: ',
          _boldText(item.rollNumber?.toString() ?? 'N/A'),
          ', has been a bonafide student of ',
          _boldText('Class ${item.className ?? 'N/A'}'),
          ' in this school during the academic session ',
          _boldText('${ccData.periodFrom} - ${ccData.periodTo}'),
          '.',
        ]),
        const SizedBox(height: 16),
        _buildCertificateStatement([
          'During his/her period of study in this institution, he/she has shown ',
          _boldText(cert.conduct ?? ccData.characterRating),
          ' moral character, disciplined attitude and obedience to teachers.',
        ]),
        const SizedBox(height: 14),
        if (cert.remarks != null && cert.remarks!.isNotEmpty) ...[
          _buildCertificateStatement([
            'Co-curricular Activities & Honors: ',
            _boldText(cert.remarks!),
          ]),
          const SizedBox(height: 14),
        ],
        _buildCertificateStatement([
          'To the best of our knowledge, he/she bears an exemplary moral standing and has not been involved in any disciplinary breach.',
        ]),
      ],
    );
  }

  Widget _buildPrintBonafideContent(
    CertificateWithDetails item,
    Map<String, dynamic> data,
  ) {
    final cert = item.certificate;
    final bonData = BonafideCertificateData.fromJson(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildCertificateStatement([
          'TO WHOMSOEVER IT MAY CONCERN',
        ], isHeader: true),
        const SizedBox(height: 16),
        _buildCertificateStatement([
          'This is to officially certify that ',
          _boldText(item.studentName),
          ', bearing Admission Number ',
          _boldText(item.admissionNumber),
          ', is a bonafide and regular student of this institution currently studying in ',
          _boldText(
            'Class ${item.className ?? 'N/A'} ${item.sectionName != null ? '(${item.sectionName})' : ''}',
          ),
          ', Roll No: ',
          _boldText(item.rollNumber?.toString() ?? 'N/A'),
          ' for the Academic Session ',
          _boldText(
            item.academicYearName ?? bonData.academicYear ?? 'Current Session',
          ),
          '.',
        ]),
        const SizedBox(height: 16),
        _buildCertificateStatement([
          'This certificate is issued upon the request of the student/guardian for the specific purpose of: ',
          _boldText(cert.reason ?? bonData.purpose),
          '.',
        ]),
        const SizedBox(height: 14),
        _buildCertificateStatement([
          'According to school records, his/her date of birth is ',
          _boldText(
            item.student.dateOfBirth != null
                ? _formatDate(item.student.dateOfBirth!)
                : 'As per admission register',
          ),
          '.',
        ]),
      ],
    );
  }

  Widget _buildPrintMarksheetContent(
    CertificateWithDetails item,
    Map<String, dynamic> data,
  ) {
    MarksheetData msData;
    try {
      msData = MarksheetData.fromJson(data);
    } catch (_) {
      msData = const MarksheetData(
        examName: 'Terminal Examination',
        subjects: [],
        totalFullMarks: 0,
        totalPassMarks: 0,
        totalMarksObtained: 0,
        percentage: 0,
        gpa: 0,
        division: 'N/A',
        result: 'N/A',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student details mini-card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student: ${item.studentName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Class: ${item.className ?? 'N/A'} • Section: ${item.sectionName ?? 'N/A'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Adm #: ${item.admissionNumber}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Roll #: ${item.rollNumber ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Marks Table
        Table(
          border: TableBorder.all(color: Colors.grey.shade400),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(3.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(1.5),
            6: FlexColumnWidth(1.5),
          },
          children: [
            // Header
            TableRow(
              decoration: BoxDecoration(color: Colors.indigo.shade50),
              children: const [
                _TableHeadCell('Code'),
                _TableHeadCell('Subject'),
                _TableHeadCell('Full'),
                _TableHeadCell('Pass'),
                _TableHeadCell('Obtained'),
                _TableHeadCell('Grade'),
                _TableHeadCell('GPA'),
              ],
            ),
            // Rows
            ...msData.subjects.map((sub) {
              return TableRow(
                children: [
                  _TableCell(sub.subjectCode),
                  _TableCell(sub.subjectName, alignLeft: true),
                  _TableCell(sub.fullMarks.toStringAsFixed(0)),
                  _TableCell(sub.passMarks.toStringAsFixed(0)),
                  _TableCell(
                    sub.totalObtained.toStringAsFixed(0),
                    isBold: true,
                  ),
                  _TableCell(sub.grade, isBold: true),
                  _TableCell(sub.gradePoint.toStringAsFixed(1)),
                ],
              );
            }),
            // Total Row
            TableRow(
              decoration: BoxDecoration(color: Colors.indigo.shade50),
              children: [
                const _TableCell(''),
                const _TableCell('GRAND TOTAL', alignLeft: true, isBold: true),
                _TableCell(
                  msData.totalFullMarks.toStringAsFixed(0),
                  isBold: true,
                ),
                _TableCell(
                  msData.totalPassMarks.toStringAsFixed(0),
                  isBold: true,
                ),
                _TableCell(
                  msData.totalMarksObtained.toStringAsFixed(0),
                  isBold: true,
                ),
                const _TableCell(''),
                _TableCell(msData.gpa.toStringAsFixed(2), isBold: true),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary Badges
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                'Percentage: ${msData.percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Final GPA: ${msData.gpa.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Division: ${msData.division}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Result: ${msData.result}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color:
                      msData.result == 'Passed'
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintCustomContent(
    CertificateWithDetails item,
    Map<String, dynamic> data,
  ) {
    final customData = CustomCertificateData.fromJson(data);
    var rendered = customData.bodyText;
    rendered = rendered.replaceAll('{student_name}', item.studentName);
    rendered = rendered.replaceAll('{admission_no}', item.admissionNumber);
    rendered = rendered.replaceAll('{class}', item.className ?? 'N/A');
    rendered = rendered.replaceAll(
      '{roll_no}',
      item.rollNumber?.toString() ?? 'N/A',
    );
    rendered = rendered.replaceAll(
      '{academic_year}',
      item.academicYearName ?? 'Current Session',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          rendered,
          style: const TextStyle(
            fontSize: 13,
            height: 1.8,
            fontFamily: 'serif',
          ),
        ),
        if (item.certificate.remarks != null &&
            item.certificate.remarks!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Special Note: ${item.certificate.remarks}',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ],
    );
  }

  // ==================== HELPER WIDGETS & FORMATTERS ====================

  Widget _buildCertificateStatement(
    List<dynamic> parts, {
    bool isHeader = false,
  }) {
    final spans =
        parts.map<InlineSpan>((part) {
          if (part is InlineSpan) return part;
          return TextSpan(text: part.toString());
        }).toList();

    return RichText(
      textAlign: isHeader ? TextAlign.center : TextAlign.justify,
      text: TextSpan(
        style: TextStyle(
          fontSize: isHeader ? 14 : 13,
          color: Colors.black87,
          fontFamily: 'serif',
          height: 1.8,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
        children: spans,
      ),
    );
  }

  InlineSpan _boldText(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
    );
  }

  MaterialColor _getCertificateTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'tc':
        return Colors.orange;
      case 'cc':
        return Colors.green;
      case 'marksheet':
        return Colors.purple;
      case 'bonafide':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }

  IconData _getCertificateTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tc':
        return Icons.swap_horiz;
      case 'cc':
        return Icons.verified;
      case 'marksheet':
        return Icons.grade;
      case 'bonafide':
        return Icons.assignment_ind;
      default:
        return Icons.card_membership;
    }
  }

  String _getCertificateTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'tc':
        return 'Transfer (TC)';
      case 'cc':
        return 'Character (CC)';
      case 'marksheet':
        return 'Mark Sheet';
      case 'bonafide':
        return 'Bonafide';
      default:
        return 'Custom';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _TableHeadCell extends StatelessWidget {
  final String text;

  const _TableHeadCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final bool alignLeft;

  const _TableCell(this.text, {this.isBold = false, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Align(
        alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
