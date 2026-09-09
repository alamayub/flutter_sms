// lib/features/exams/services/pdf/report_card_pdf_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/result_calculator.dart';

class StudentAttendanceStats {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final double percentage;

  const StudentAttendanceStats({
    this.totalDays = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.percentage = 0.0,
  });
}

class ReportCardData {
  final String schoolName;
  final String? schoolAddress;
  final String? schoolPhone;
  final String? schoolPrincipal;
  final String academicYearName;
  final String examName;
  final String studentName;
  final String? studentCode;
  final int? rollNumber;
  final String className;
  final String sectionName;
  final StudentExamResult result;
  final StudentAttendanceStats attendanceStats;
  final DateTime issueDate;

  const ReportCardData({
    required this.schoolName,
    this.schoolAddress,
    this.schoolPhone,
    this.schoolPrincipal,
    required this.academicYearName,
    required this.examName,
    required this.studentName,
    this.studentCode,
    this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.result,
    this.attendanceStats = const StudentAttendanceStats(),
    required this.issueDate,
  });
}

class ReportCardPdfService {
  /// Compiles a single student report card into raw PDF bytes.
  static Future<Uint8List> generateReportCardPdf(ReportCardData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => _buildReportCardPage(data),
      ),
    );

    return await pdf.save();
  }

  /// Compiles bulk report cards for multiple students into a single multi-page PDF document.
  static Future<Uint8List> generateBulkReportCardsPdf({
    required List<ReportCardData> studentsData,
    void Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < studentsData.length; i++) {
      final data = studentsData[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildReportCardPage(data),
        ),
      );
      onProgress?.call(i + 1, studentsData.length);
    }

    return await pdf.save();
  }

  /// Launches the native operating system print dialog for a report card.
  static Future<void> printReportCard(ReportCardData data) async {
    final bytes = await generateReportCardPdf(data);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'ReportCard_${data.studentName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Shares or exports the PDF file via the operating system.
  static Future<void> shareReportCardPdf(ReportCardData data) async {
    final bytes = await generateReportCardPdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'ReportCard_${data.studentName.replaceAll(' ', '_')}.pdf',
    );
  }

  // --- PDF Widget Builders ---

  static pw.Widget _buildReportCardPage(ReportCardData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. Institutional Header
        _buildHeader(data),
        pw.SizedBox(height: 12),

        // 2. Student & Academic Meta Box
        _buildMetaBox(data),
        pw.SizedBox(height: 16),

        // 3. Subject-by-Subject Marks Table
        _buildSubjectTable(data),
        pw.SizedBox(height: 16),

        // 4. Results & Summary Stats
        _buildSummaryBox(data),
        pw.SizedBox(height: 14),

        // 5. Attendance Summary
        _buildAttendanceBox(data),
        pw.Spacer(),

        // 6. Signature Lines & Footer
        _buildSignatures(data),
      ],
    );
  }

  static pw.Widget _buildHeader(ReportCardData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1.5, color: PdfColors.black),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            data.schoolName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (data.schoolAddress != null && data.schoolAddress!.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              data.schoolAddress!,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ],
          if (data.schoolPhone != null && data.schoolPhone!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Contact: ${data.schoolPhone!}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              '${data.examName.toUpperCase()} - ACADEMIC PROGRESS REPORT',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaBox(ReportCardData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildMetaRow('Student Name:', data.studentName, isBold: true),
              _buildMetaRow('Student ID:', data.studentCode ?? 'N/A'),
              _buildMetaRow('Academic Year:', data.academicYearName),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildMetaRow(
                'Class & Section:',
                '${data.className} - ${data.sectionName}',
              ),
              _buildMetaRow(
                'Roll Number:',
                data.rollNumber?.toString() ?? 'N/A',
              ),
              _buildMetaRow(
                'Issue Date:',
                '${data.issueDate.year}-${data.issueDate.month.toString().padLeft(2, '0')}-${data.issueDate.day.toString().padLeft(2, '0')}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey800,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSubjectTable(ReportCardData data) {
    final headers = [
      'Subject',
      'Full',
      'Pass',
      'Theory',
      'Practical',
      'Total',
      'Grade',
      'GP',
    ];

    final rows =
        data.result.subjectResults.map((s) {
          final totalStr =
              s.totalMarks != null
                  ? s.totalMarks!.toStringAsFixed(1)
                  : (s.status.name.toUpperCase());
          final gpStr =
              s.gradePoint != null ? s.gradePoint!.toStringAsFixed(2) : '-';

          return [
            s.subjectName,
            s.fullMarks.toStringAsFixed(0),
            s.passMarks.toStringAsFixed(0),
            s.theoryMarks?.toStringAsFixed(1) ?? '-',
            s.practicalMarks?.toStringAsFixed(1) ?? '-',
            totalStr,
            s.grade,
            gpStr,
          ];
        }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {0: pw.Alignment.centerLeft},
      headerAlignments: {0: pw.Alignment.centerLeft},
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
    );
  }

  static pw.Widget _buildSummaryBox(ReportCardData data) {
    final res = data.result;
    final isPassed = res.isPassed;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: isPassed ? PdfColors.green50 : PdfColors.red50,
        border: pw.Border.all(
          color: isPassed ? PdfColors.green300 : PdfColors.red300,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Total Marks',
            '${res.totalMarksObtained.toStringAsFixed(1)} / ${res.totalFullMarks.toStringAsFixed(0)}',
          ),
          _buildSummaryItem(
            'Percentage',
            '${res.percentage.toStringAsFixed(2)}%',
          ),
          _buildSummaryItem('Overall Grade', res.overallGrade),
          if (res.gpa != null)
            _buildSummaryItem('GPA', res.gpa!.toStringAsFixed(2)),
          if (res.rank != null) _buildSummaryItem('Rank', '#${res.rank}'),
          _buildSummaryItem(
            'Final Result',
            isPassed ? 'PASSED' : 'FAILED',
            color: isPassed ? PdfColors.green900 : PdfColors.red900,
            isBold: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(
    String label,
    String value, {
    PdfColor? color,
    bool isBold = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAttendanceBox(ReportCardData data) {
    final att = data.attendanceStats;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Attendance:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Working Days: ${att.totalDays}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Present: ${att.presentDays}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Absent: ${att.absentDays}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Attendance: ${att.percentage.toStringAsFixed(1)}%',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures(ReportCardData data) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 24, bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            children: [
              pw.Container(width: 130, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text('Class Teacher', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.Column(
            children: [
              pw.Container(width: 130, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text(
                'Exam Coordinator',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Container(width: 130, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text(
                data.schoolPrincipal != null && data.schoolPrincipal!.isNotEmpty
                    ? data.schoolPrincipal!
                    : 'Principal',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
