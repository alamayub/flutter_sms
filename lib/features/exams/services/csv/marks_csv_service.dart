import 'package:csv/csv.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/exam_models.dart';

class CsvRowError {
  final int rowNumber;
  final String studentCode;
  final String field;
  final String message;

  const CsvRowError({
    required this.rowNumber,
    required this.studentCode,
    required this.field,
    required this.message,
  });

  @override
  String toString() => 'Row $rowNumber ($studentCode): [$field] $message';
}

class ValidatedCsvMarkRow {
  final int rowNumber;
  final String studentId;
  final String studentCode;
  final String studentName;
  final double? theoryMarks;
  final double? practicalMarks;
  final double? internalMarks;
  final MarkStatus status;
  final String? remarks;

  const ValidatedCsvMarkRow({
    required this.rowNumber,
    required this.studentId,
    required this.studentCode,
    required this.studentName,
    this.theoryMarks,
    this.practicalMarks,
    this.internalMarks,
    required this.status,
    this.remarks,
  });
}

class CsvPreviewResult {
  final int totalRows;
  final List<ValidatedCsvMarkRow> validRows;
  final List<CsvRowError> errors;

  const CsvPreviewResult({
    required this.totalRows,
    required this.validRows,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isValid => errors.isEmpty && validRows.isNotEmpty;
}

class MarksCsvService {
  const MarksCsvService();

  /// Generates a blank CSV template for entering marks for an exam subject.
  String generateMarksTemplate({
    required ExamSubject examSubject,
    required List<Student> students,
  }) {
    final rows = <List<dynamic>>[];

    // Header row
    rows.add([
      'Student Code',
      'Student Name',
      if (examSubject.theoryMarks != null)
        'Theory (${examSubject.theoryMarks!.toInt()})',
      if (examSubject.practicalMarks != null)
        'Practical (${examSubject.practicalMarks!.toInt()})',
      if (examSubject.internalMarks != null)
        'Internal (${examSubject.internalMarks!.toInt()})',
      'Status (present/absent/medical/exempt)',
      'Remarks',
    ]);

    // Student rows pre-filled
    for (final s in students) {
      final row = <dynamic>[
        s.studentCode,
        '${s.firstName} ${s.lastName}',
        if (examSubject.theoryMarks != null) '',
        if (examSubject.practicalMarks != null) '',
        if (examSubject.internalMarks != null) '',
        'present',
        '',
      ];
      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Exports current marks entries to CSV.
  String exportMarks({
    required ExamSubject examSubject,
    required List<Student> students,
    required List<Mark> marks,
  }) {
    final rows = <List<dynamic>>[];

    // Map studentId -> Mark
    final marksMap = {for (final m in marks) m.studentId: m};

    rows.add([
      'Student Code',
      'Student Name',
      if (examSubject.theoryMarks != null)
        'Theory (${examSubject.theoryMarks!.toInt()})',
      if (examSubject.practicalMarks != null)
        'Practical (${examSubject.practicalMarks!.toInt()})',
      if (examSubject.internalMarks != null)
        'Internal (${examSubject.internalMarks!.toInt()})',
      'Total Marks',
      'Status',
      'Remarks',
    ]);

    for (final s in students) {
      final mark = marksMap[s.id];
      final statusStr = mark?.status ?? 'present';
      final isAbsentLike = statusStr == 'absent' || statusStr == 'not_appeared';

      final row = <dynamic>[
        s.studentCode,
        '${s.firstName} ${s.lastName}',
        if (examSubject.theoryMarks != null)
          (isAbsentLike ? '' : (mark?.theoryMarks?.toString() ?? '')),
        if (examSubject.practicalMarks != null)
          (isAbsentLike ? '' : (mark?.practicalMarks?.toString() ?? '')),
        if (examSubject.internalMarks != null)
          (isAbsentLike ? '' : (mark?.internalMarks?.toString() ?? '')),
        isAbsentLike
            ? statusStr.toUpperCase()
            : (mark?.totalMarks?.toString() ?? ''),
        statusStr,
        mark?.remarks ?? '',
      ];
      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Exports calculated class results to CSV.
  String exportResults({
    required Exam exam,
    required List<Student> students,
    required List<Result> results,
    required List<ExamSubject> subjects,
  }) {
    final rows = <List<dynamic>>[];
    final resultMap = {for (final r in results) r.studentId: r};

    // Header row
    final header = <dynamic>[
      'Rank',
      'Student Code',
      'Student Name',
      'Total Marks Obtained',
      'Total Full Marks',
      'Percentage (%)',
      'GPA',
      'Grade',
      'Result Status',
    ];
    rows.add(header);

    // Sort results by rank ascending
    final sortedStudents = List<Student>.from(students);
    sortedStudents.sort((a, b) {
      final rankA = resultMap[a.id]?.rank ?? 99999;
      final rankB = resultMap[b.id]?.rank ?? 99999;
      return rankA.compareTo(rankB);
    });

    for (final s in sortedStudents) {
      final res = resultMap[s.id];
      rows.add([
        res?.rank ?? '-',
        s.studentCode,
        '${s.firstName} ${s.lastName}',
        res?.totalMarksObtained.toStringAsFixed(1) ?? '-',
        res?.totalFullMarks.toStringAsFixed(1) ?? '-',
        res?.percentage.toStringAsFixed(2) ?? '-',
        res?.gpa?.toStringAsFixed(2) ?? '-',
        res?.overallGrade ?? '-',
        res?.isPassed == true
            ? 'PASSED'
            : (res != null ? 'FAILED' : 'NO RESULT'),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Validates and parses imported CSV string for an ExamSubject.
  CsvPreviewResult validateAndParseCsv({
    required String csvContent,
    required ExamSubject examSubject,
    required List<Student> students,
  }) {
    final errors = <CsvRowError>[];
    final validRows = <ValidatedCsvMarkRow>[];

    // Normalize newlines
    final normalized = csvContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final rawRows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(normalized);

    if (rawRows.isEmpty) {
      errors.add(
        const CsvRowError(
          rowNumber: 0,
          studentCode: '',
          field: 'File',
          message: 'CSV file is completely empty.',
        ),
      );
      return CsvPreviewResult(totalRows: 0, validRows: [], errors: errors);
    }

    final headerRow =
        rawRows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // Find column indexes
    int colStudentCode = -1;
    int colTheory = -1;
    int colPractical = -1;
    int colInternal = -1;
    int colStatus = -1;
    int colRemarks = -1;

    for (var i = 0; i < headerRow.length; i++) {
      final h = headerRow[i];
      if (h.contains('code')) {
        colStudentCode = i;
      } else if (h.contains('theory')) {
        colTheory = i;
      } else if (h.contains('practical')) {
        colPractical = i;
      } else if (h.contains('internal')) {
        colInternal = i;
      } else if (h.contains('status')) {
        colStatus = i;
      } else if (h.contains('remark')) {
        colRemarks = i;
      }
    }

    if (colStudentCode == -1) {
      errors.add(
        const CsvRowError(
          rowNumber: 1,
          studentCode: '',
          field: 'Header',
          message: 'Missing required column "Student Code".',
        ),
      );
      return CsvPreviewResult(
        totalRows: rawRows.length - 1,
        validRows: [],
        errors: errors,
      );
    }

    final studentMapByCode = {
      for (final s in students) s.studentCode.trim().toLowerCase(): s,
    };

    for (var rIdx = 1; rIdx < rawRows.length; rIdx++) {
      final row = rawRows[rIdx];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      final studentCodeStr =
          (colStudentCode < row.length
              ? row[colStudentCode].toString().trim()
              : '');
      if (studentCodeStr.isEmpty) {
        errors.add(
          CsvRowError(
            rowNumber: rIdx + 1,
            studentCode: '',
            field: 'Student Code',
            message: 'Student code is required.',
          ),
        );
        continue;
      }

      final student = studentMapByCode[studentCodeStr.toLowerCase()];
      if (student == null) {
        errors.add(
          CsvRowError(
            rowNumber: rIdx + 1,
            studentCode: studentCodeStr,
            field: 'Student Code',
            message:
                'Student code "$studentCodeStr" does not match any enrolled student in this class.',
          ),
        );
        continue;
      }

      // Parse status
      MarkStatus markStatus = MarkStatus.present;
      if (colStatus != -1 && colStatus < row.length) {
        final statusRaw = row[colStatus].toString().trim().toLowerCase();
        if (statusRaw.isNotEmpty) {
          switch (statusRaw) {
            case 'present':
              markStatus = MarkStatus.present;
              break;
            case 'absent':
              markStatus = MarkStatus.absent;
              break;
            case 'medical':
              markStatus = MarkStatus.medical;
              break;
            case 'exempt':
              markStatus = MarkStatus.exempt;
              break;
            case 'withheld':
              markStatus = MarkStatus.withheld;
              break;
            case 'not_appeared':
            case 'not appeared':
              markStatus = MarkStatus.notAppeared;
              break;
            default:
              errors.add(
                CsvRowError(
                  rowNumber: rIdx + 1,
                  studentCode: studentCodeStr,
                  field: 'Status',
                  message:
                      'Invalid status "$statusRaw". Allowed: present, absent, medical, exempt, withheld, not_appeared.',
                ),
              );
          }
        }
      }

      // Parse theory
      double? theory;
      if (colTheory != -1 && colTheory < row.length) {
        final valStr = row[colTheory].toString().trim();
        if (valStr.isNotEmpty) {
          final parsed = double.tryParse(valStr);
          if (parsed == null) {
            errors.add(
              CsvRowError(
                rowNumber: rIdx + 1,
                studentCode: studentCodeStr,
                field: 'Theory',
                message: 'Invalid numeric mark "$valStr".',
              ),
            );
          } else if (parsed < 0 ||
              (examSubject.theoryMarks != null &&
                  parsed > examSubject.theoryMarks!)) {
            errors.add(
              CsvRowError(
                rowNumber: rIdx + 1,
                studentCode: studentCodeStr,
                field: 'Theory',
                message:
                    'Marks ($parsed) must be between 0 and max theory (${examSubject.theoryMarks}).',
              ),
            );
          } else {
            theory = parsed;
          }
        }
      }

      // Parse practical
      double? practical;
      if (colPractical != -1 && colPractical < row.length) {
        final valStr = row[colPractical].toString().trim();
        if (valStr.isNotEmpty) {
          final parsed = double.tryParse(valStr);
          if (parsed == null) {
            errors.add(
              CsvRowError(
                rowNumber: rIdx + 1,
                studentCode: studentCodeStr,
                field: 'Practical',
                message: 'Invalid numeric mark "$valStr".',
              ),
            );
          } else if (parsed < 0 ||
              (examSubject.practicalMarks != null &&
                  parsed > examSubject.practicalMarks!)) {
            errors.add(
              CsvRowError(
                rowNumber: rIdx + 1,
                studentCode: studentCodeStr,
                field: 'Practical',
                message:
                    'Marks ($parsed) must be between 0 and max practical (${examSubject.practicalMarks}).',
              ),
            );
          } else {
            practical = parsed;
          }
        }
      }

      // Parse internal
      double? internal;
      if (colInternal != -1 && colInternal < row.length) {
        final valStr = row[colInternal].toString().trim();
        if (valStr.isNotEmpty) {
          final parsed = double.tryParse(valStr);
          if (parsed == null) {
            errors.add(
              CsvRowError(
                rowNumber: rIdx + 1,
                studentCode: studentCodeStr,
                field: 'Internal',
                message: 'Invalid numeric mark "$valStr".',
              ),
            );
          } else if (parsed < 0 ||
              (examSubject.internalMarks != null &&
                  parsed > examSubject.internalMarks!)) {
            errors.add(
              CsvRowError(
                rowNumber: rIdx + 1,
                studentCode: studentCodeStr,
                field: 'Internal',
                message:
                    'Marks ($parsed) must be between 0 and max internal (${examSubject.internalMarks}).',
              ),
            );
          } else {
            internal = parsed;
          }
        }
      }

      // Parse remarks
      String? remarks;
      if (colRemarks != -1 && colRemarks < row.length) {
        final valStr = row[colRemarks].toString().trim();
        if (valStr.isNotEmpty) remarks = valStr;
      }

      // If absent, theory/practical/internal should be clear
      if (markStatus == MarkStatus.absent ||
          markStatus == MarkStatus.notAppeared) {
        theory = null;
        practical = null;
        internal = null;
      }

      validRows.add(
        ValidatedCsvMarkRow(
          rowNumber: rIdx + 1,
          studentId: student.id,
          studentCode: student.studentCode,
          studentName: '${student.firstName} ${student.lastName}',
          theoryMarks: theory,
          practicalMarks: practical,
          internalMarks: internal,
          status: markStatus,
          remarks: remarks,
        ),
      );
    }

    return CsvPreviewResult(
      totalRows: rawRows.length - 1,
      validRows: validRows,
      errors: errors,
    );
  }
}
