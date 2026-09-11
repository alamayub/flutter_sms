import 'dart:convert';
import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// Standard certificate type identifiers
class CertificateTypes {
  static const String transferCertificate = 'tc';
  static const String characterCertificate = 'cc';
  static const String bonafideCertificate = 'bonafide';
  static const String markSheet = 'marksheet';
  static const String meritCertificate = 'merit';
  static const String customCertificate = 'custom';
}

/// Standard certificate status identifiers
class CertificateStatuses {
  static const String issued = 'issued';
  static const String cancelled = 'cancelled';
  static const String draft = 'draft';
}

/// Grade and GPA assessment result
class GradeInfo {
  final String letterGrade;
  final double gradePoint;
  final String description;

  const GradeInfo({
    required this.letterGrade,
    required this.gradePoint,
    required this.description,
  });

  String get grade => letterGrade;
}

/// Subject performance entry in a Mark Sheet
class MarksheetSubjectEntry {
  final String subjectCode;
  final String subjectName;
  final double fullMarks;
  final double passMarks;
  final double? theoryMarks;
  final double? practicalMarks;
  final double? theoryObtained;
  final double? practicalObtained;
  final double totalObtained;
  final String grade;
  final double gradePoint;
  final String? remarks;

  MarksheetSubjectEntry({
    required this.subjectCode,
    required this.subjectName,
    required this.fullMarks,
    required this.passMarks,
    this.theoryMarks,
    this.practicalMarks,
    this.theoryObtained,
    this.practicalObtained,
    double? totalObtained,
    String? grade,
    double? gradePoint,
    this.remarks,
  }) : totalObtained =
           totalObtained ??
           ((theoryObtained ?? theoryMarks ?? 0.0) +
               (practicalObtained ?? practicalMarks ?? 0.0)),
       grade =
           grade ??
           CertificateService.calculateGrade(
             ((totalObtained ??
                         ((theoryObtained ?? theoryMarks ?? 0.0) +
                             (practicalObtained ?? practicalMarks ?? 0.0))) /
                     (fullMarks > 0 ? fullMarks : 100)) *
                 100,
           ).letterGrade,
       gradePoint =
           gradePoint ??
           CertificateService.calculateGrade(
             ((totalObtained ??
                         ((theoryObtained ?? theoryMarks ?? 0.0) +
                             (practicalObtained ?? practicalMarks ?? 0.0))) /
                     (fullMarks > 0 ? fullMarks : 100)) *
                 100,
           ).gradePoint;

  bool get isPassed => totalObtained >= passMarks;
  double get obtainedMarks => totalObtained;

  Map<String, dynamic> toJson() => {
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'fullMarks': fullMarks,
    'passMarks': passMarks,
    'theoryMarks': theoryMarks,
    'practicalMarks': practicalMarks,
    'theoryObtained': theoryObtained,
    'practicalObtained': practicalObtained,
    'totalObtained': totalObtained,
    'grade': grade,
    'gradePoint': gradePoint,
    'remarks': remarks,
  };

  factory MarksheetSubjectEntry.fromJson(Map<String, dynamic> json) {
    return MarksheetSubjectEntry(
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      fullMarks: (json['fullMarks'] as num?)?.toDouble() ?? 100.0,
      passMarks: (json['passMarks'] as num?)?.toDouble() ?? 40.0,
      theoryMarks: (json['theoryMarks'] as num?)?.toDouble(),
      practicalMarks: (json['practicalMarks'] as num?)?.toDouble(),
      theoryObtained: (json['theoryObtained'] as num?)?.toDouble(),
      practicalObtained: (json['practicalObtained'] as num?)?.toDouble(),
      totalObtained: (json['totalObtained'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] as String? ?? 'F',
      gradePoint: (json['gradePoint'] as num?)?.toDouble() ?? 0.0,
      remarks: json['remarks'] as String?,
    );
  }
}

/// Structured JSON payload for Academic Mark Sheet
class MarksheetData {
  final String examName;
  final List<MarksheetSubjectEntry> subjects;
  final double totalFullMarks;
  final double totalPassMarks;
  final double totalMarksObtained;
  final double percentage;
  final double gpa;
  final String division;
  final String result;
  final int? rankInClass;
  final int? totalAttendance;
  final int? totalWorkingDays;
  final String? teacherRemarks;
  final String? fatherName;
  final String? motherName;
  final String? session;

  const MarksheetData({
    required this.examName,
    required this.subjects,
    required this.totalFullMarks,
    required this.totalPassMarks,
    required this.totalMarksObtained,
    required this.percentage,
    required this.gpa,
    required this.division,
    required this.result,
    this.rankInClass,
    this.totalAttendance,
    this.totalWorkingDays,
    this.teacherRemarks,
    this.fatherName,
    this.motherName,
    this.session,
  });

  double get totalObtainedMarks => totalMarksObtained;
  bool get isPassed => result == 'Passed';
  String get overallGrade =>
      CertificateService.calculateGrade(percentage).letterGrade;

  Map<String, dynamic> toJson() => {
    'examName': examName,
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'totalFullMarks': totalFullMarks,
    'totalPassMarks': totalPassMarks,
    'totalMarksObtained': totalMarksObtained,
    'percentage': percentage,
    'gpa': gpa,
    'division': division,
    'result': result,
    'rankInClass': rankInClass,
    'totalAttendance': totalAttendance,
    'totalWorkingDays': totalWorkingDays,
    'teacherRemarks': teacherRemarks,
    'fatherName': fatherName,
    'motherName': motherName,
    'session': session,
  };

  factory MarksheetData.fromJson(Map<String, dynamic> json) {
    final list = json['subjects'] as List<dynamic>? ?? [];
    return MarksheetData(
      examName: json['examName'] as String? ?? 'Terminal Examination',
      subjects:
          list
              .map(
                (item) => MarksheetSubjectEntry.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      totalFullMarks: (json['totalFullMarks'] as num?)?.toDouble() ?? 0.0,
      totalPassMarks: (json['totalPassMarks'] as num?)?.toDouble() ?? 0.0,
      totalMarksObtained:
          (json['totalMarksObtained'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      gpa: (json['gpa'] as num?)?.toDouble() ?? 0.0,
      division: json['division'] as String? ?? 'N/A',
      result: json['result'] as String? ?? 'Passed',
      rankInClass: json['rankInClass'] as int?,
      totalAttendance: json['totalAttendance'] as int?,
      totalWorkingDays: json['totalWorkingDays'] as int?,
      teacherRemarks: json['teacherRemarks'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      session: json['session'] as String?,
    );
  }
}

/// Structured payload for Transfer Certificate (TC)
class TransferCertificateData {
  final DateTime? admissionDate;
  final String? admittedClass;
  final DateTime dateOfLeaving;
  final String classInWhichStudying;
  final String? promotedToClass;
  final String reasonForLeaving;
  final String conduct;
  final bool duesCleared;
  final String? duesClearedUpTo;
  final int? totalWorkingDays;
  final int? totalPresentDays;
  final String? fatherName;
  final String? motherName;
  final String? dobInWords;
  final String? nationality;
  final String? subjectsStudied;
  final String? whetherFailed;
  final String? feeConcession;
  final DateTime? applicationDate;
  final String? lastExamResult;
  final String? generalRemarks;

  const TransferCertificateData({
    this.admissionDate,
    this.admittedClass,
    required this.dateOfLeaving,
    required this.classInWhichStudying,
    this.promotedToClass,
    required this.reasonForLeaving,
    required this.conduct,
    this.duesCleared = true,
    this.duesClearedUpTo,
    this.totalWorkingDays,
    this.totalPresentDays,
    this.fatherName,
    this.motherName,
    this.dobInWords,
    this.nationality,
    this.subjectsStudied,
    this.whetherFailed,
    this.feeConcession,
    this.applicationDate,
    this.lastExamResult,
    this.generalRemarks,
  });

  int? get daysPresent => totalPresentDays;
  String? get lastExamPassed =>
      lastExamResult ??
      (generalRemarks?.startsWith('Last Exam: ') == true
          ? generalRemarks!.substring(11)
          : generalRemarks);

  Map<String, dynamic> toJson() => {
    'admissionDate': admissionDate?.toIso8601String(),
    'admittedClass': admittedClass,
    'dateOfLeaving': dateOfLeaving.toIso8601String(),
    'classInWhichStudying': classInWhichStudying,
    'promotedToClass': promotedToClass,
    'reasonForLeaving': reasonForLeaving,
    'conduct': conduct,
    'duesCleared': duesCleared,
    'duesClearedUpTo': duesClearedUpTo,
    'totalWorkingDays': totalWorkingDays,
    'totalPresentDays': totalPresentDays,
    'fatherName': fatherName,
    'motherName': motherName,
    'dobInWords': dobInWords,
    'nationality': nationality,
    'subjectsStudied': subjectsStudied,
    'whetherFailed': whetherFailed,
    'feeConcession': feeConcession,
    'applicationDate': applicationDate?.toIso8601String(),
    'lastExamResult': lastExamResult,
    'generalRemarks': generalRemarks,
  };

  factory TransferCertificateData.fromJson(Map<String, dynamic> json) {
    return TransferCertificateData(
      admissionDate:
          json['admissionDate'] != null
              ? DateTime.tryParse(json['admissionDate'] as String)
              : null,
      admittedClass: json['admittedClass'] as String?,
      dateOfLeaving:
          json['dateOfLeaving'] != null
              ? DateTime.tryParse(json['dateOfLeaving'] as String) ??
                  DateTime.now()
              : DateTime.now(),
      classInWhichStudying: json['classInWhichStudying'] as String? ?? 'N/A',
      promotedToClass: json['promotedToClass'] as String?,
      reasonForLeaving:
          json['reasonForLeaving'] as String? ?? "Parents' Request",
      conduct: json['conduct'] as String? ?? 'Good',
      duesCleared: json['duesCleared'] as bool? ?? true,
      duesClearedUpTo: json['duesClearedUpTo'] as String?,
      totalWorkingDays: json['totalWorkingDays'] as int?,
      totalPresentDays: json['totalPresentDays'] as int?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      dobInWords: json['dobInWords'] as String?,
      nationality: json['nationality'] as String?,
      subjectsStudied: json['subjectsStudied'] as String?,
      whetherFailed: json['whetherFailed'] as String?,
      feeConcession: json['feeConcession'] as String?,
      applicationDate:
          json['applicationDate'] != null
              ? DateTime.tryParse(json['applicationDate'] as String)
              : null,
      lastExamResult: json['lastExamResult'] as String?,
      generalRemarks: json['generalRemarks'] as String?,
    );
  }
}

/// Structured payload for Character Certificate (CC)
class CharacterCertificateData {
  final String periodFrom;
  final String periodTo;
  final String? classFrom;
  final String? classTo;
  final String characterRating;
  final String? academicPerformance;
  final String? coCurricularActivities;
  final String moralCharacter;
  final String? fatherName;
  final String? motherName;
  final String? session;
  final String? generalRemarks;

  const CharacterCertificateData({
    required this.periodFrom,
    required this.periodTo,
    this.classFrom,
    this.classTo,
    required this.characterRating,
    this.academicPerformance,
    this.coCurricularActivities,
    required this.moralCharacter,
    this.fatherName,
    this.motherName,
    this.session,
    this.generalRemarks,
  });

  Map<String, dynamic> toJson() => {
    'periodFrom': periodFrom,
    'periodTo': periodTo,
    'classFrom': classFrom,
    'classTo': classTo,
    'characterRating': characterRating,
    'academicPerformance': academicPerformance,
    'coCurricularActivities': coCurricularActivities,
    'moralCharacter': moralCharacter,
    'fatherName': fatherName,
    'motherName': motherName,
    'session': session,
    'generalRemarks': generalRemarks,
  };

  factory CharacterCertificateData.fromJson(Map<String, dynamic> json) {
    return CharacterCertificateData(
      periodFrom: json['periodFrom'] as String? ?? '',
      periodTo: json['periodTo'] as String? ?? '',
      classFrom: json['classFrom'] as String?,
      classTo: json['classTo'] as String?,
      characterRating: json['characterRating'] as String? ?? 'Good',
      academicPerformance: json['academicPerformance'] as String?,
      coCurricularActivities: json['coCurricularActivities'] as String?,
      moralCharacter:
          json['moralCharacter'] as String? ??
          'Possesses good moral character and conduct.',
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      session: json['session'] as String?,
      generalRemarks: json['generalRemarks'] as String?,
    );
  }
}

/// Structured payload for Bonafide Certificate
class BonafideCertificateData {
  final String purpose;
  final String? academicYear;
  final DateTime? validUntil;
  final String? fatherName;
  final String? motherName;
  final DateTime? dob;
  final String? generalRemarks;

  const BonafideCertificateData({
    required this.purpose,
    this.academicYear,
    this.validUntil,
    this.fatherName,
    this.motherName,
    this.dob,
    this.generalRemarks,
  });

  String? get session => academicYear;
  DateTime? get validTill => validUntil;

  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'academicYear': academicYear,
    'session': academicYear,
    'validUntil': validUntil?.toIso8601String(),
    'fatherName': fatherName,
    'motherName': motherName,
    'dob': dob?.toIso8601String(),
    'generalRemarks': generalRemarks,
  };

  factory BonafideCertificateData.fromJson(Map<String, dynamic> json) {
    return BonafideCertificateData(
      purpose: json['purpose'] as String? ?? 'Passport & Visa documentation verification',
      academicYear: (json['session'] ?? json['academicYear']) as String?,
      validUntil:
          json['validUntil'] != null
              ? DateTime.tryParse(json['validUntil'] as String)
              : null,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      dob:
          json['dob'] != null ? DateTime.tryParse(json['dob'] as String) : null,
      generalRemarks: json['generalRemarks'] as String?,
    );
  }
}

/// Structured payload for Custom Certificate
class CustomCertificateData {
  final String? certificateHeader;
  final String bodyText;
  final String signatory1Title;
  final String signatory2Title;
  final String signatory3Title;

  const CustomCertificateData({
    this.certificateHeader,
    required this.bodyText,
    this.signatory1Title = 'Class Teacher',
    this.signatory2Title = 'Exam Incharge',
    this.signatory3Title = 'Principal',
  });

  Map<String, dynamic> toJson() => {
    'certificateHeader': certificateHeader,
    'bodyText': bodyText,
    'signatory1Title': signatory1Title,
    'signatory2Title': signatory2Title,
    'signatory3Title': signatory3Title,
  };

  factory CustomCertificateData.fromJson(Map<String, dynamic> json) {
    return CustomCertificateData(
      certificateHeader: json['certificateHeader'] as String?,
      bodyText: json['bodyText'] as String? ?? '',
      signatory1Title: json['signatory1Title'] as String? ?? 'Class Teacher',
      signatory2Title: json['signatory2Title'] as String? ?? 'Exam Incharge',
      signatory3Title: json['signatory3Title'] as String? ?? 'Principal',
    );
  }
}

/// Structured payload for Certificate of Merit & Distinction
class MeritCertificateData {
  final String eventTitle;
  final String rank;
  final String? citation;
  final String? academicSession;
  final String? coordinatorTitle;
  final String? principalTitle;
  final String? remarks;

  const MeritCertificateData({
    required this.eventTitle,
    required this.rank,
    this.citation,
    this.academicSession,
    this.coordinatorTitle = 'ACTIVITY COORDINATOR',
    this.principalTitle = 'PRINCIPAL',
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
    'eventTitle': eventTitle,
    'rank': rank,
    'citation': citation,
    'academicSession': academicSession,
    'coordinatorTitle': coordinatorTitle,
    'principalTitle': principalTitle,
    'remarks': remarks,
  };

  factory MeritCertificateData.fromJson(Map<String, dynamic> json) {
    return MeritCertificateData(
      eventTitle:
          json['eventTitle'] as String? ??
          'Annual Inter-School Science & Technology Exhibition',
      rank: json['rank'] as String? ?? 'First Place & Gold Medalist',
      citation:
          json['citation'] as String? ??
          'Awarded for extraordinary research and autonomous robotic vehicle design.',
      academicSession: json['academicSession'] as String?,
      coordinatorTitle:
          json['coordinatorTitle'] as String? ?? 'ACTIVITY COORDINATOR',
      principalTitle: json['principalTitle'] as String? ?? 'PRINCIPAL',
      remarks: json['remarks'] as String?,
    );
  }
}

/// Aggregate certificate statistics
class CertificateSummary {
  final int totalIssued;
  final int tcCount;
  final int ccCount;
  final int bonafideCount;
  final int marksheetCount;
  final int meritCount;
  final int customCount;

  const CertificateSummary({
    required this.totalIssued,
    required this.tcCount,
    required this.ccCount,
    required this.bonafideCount,
    required this.marksheetCount,
    this.meritCount = 0,
    required this.customCount,
  });

  int get total => totalIssued;
  int get transferCertificates => tcCount;
  int get characterCertificates => ccCount;
  int get bonafideCertificates => bonafideCount;
  int get marksheetCertificates => marksheetCount;
  int get meritCertificates => meritCount;
  int get active => totalIssued;

  factory CertificateSummary.empty() => const CertificateSummary(
    totalIssued: 0,
    tcCount: 0,
    ccCount: 0,
    bonafideCount: 0,
    marksheetCount: 0,
    meritCount: 0,
    customCount: 0,
  );
}

/// Service managing Certificate issuance, validation, and grading calculations
class CertificateService {
  final AppDatabase _db;

  CertificateService(this._db);

  // ==================== GRADING & EVALUATION ====================

  /// Calculate Grade and GPA based on percentage
  static GradeInfo calculateGrade(double percentage) {
    if (percentage >= 90.0) {
      return const GradeInfo(
        letterGrade: 'A+',
        gradePoint: 4.0,
        description: 'Outstanding',
      );
    } else if (percentage >= 80.0) {
      return const GradeInfo(
        letterGrade: 'A',
        gradePoint: 3.6,
        description: 'Excellent',
      );
    } else if (percentage >= 70.0) {
      return const GradeInfo(
        letterGrade: 'B+',
        gradePoint: 3.2,
        description: 'Very Good',
      );
    } else if (percentage >= 60.0) {
      return const GradeInfo(
        letterGrade: 'B',
        gradePoint: 2.8,
        description: 'Good',
      );
    } else if (percentage >= 50.0) {
      return const GradeInfo(
        letterGrade: 'C+',
        gradePoint: 2.4,
        description: 'Satisfactory',
      );
    } else if (percentage >= 40.0) {
      return const GradeInfo(
        letterGrade: 'C',
        gradePoint: 2.0,
        description: 'Acceptable',
      );
    } else if (percentage >= 35.0) {
      return const GradeInfo(
        letterGrade: 'D',
        gradePoint: 1.6,
        description: 'Basic',
      );
    } else {
      return const GradeInfo(
        letterGrade: 'F',
        gradePoint: 0.0,
        description: 'Non-Graded',
      );
    }
  }

  /// Calculate Academic Division from overall percentage
  static String calculateDivision(double percentage) {
    if (percentage >= 75.0) {
      return 'Distinction';
    } else if (percentage >= 60.0) {
      return 'First Division';
    } else if (percentage >= 45.0) {
      return 'Second Division';
    } else if (percentage >= 35.0) {
      return 'Third Division';
    } else {
      return 'Fail';
    }
  }

  // ==================== CERTIFICATE NUMBER GENERATION ====================

  /// Generates a unique sequential certificate serial number
  /// e.g. TC-2026-0001, CC-2026-0001, BON-2026-0001, MS-2026-0001
  Future<String> generateCertificateNumber(String certificateType) async {
    final now = DateTime.now();
    final year = now.year;
    String prefix;

    switch (certificateType.toLowerCase()) {
      case 'tc':
        prefix = 'TC';
        break;
      case 'cc':
        prefix = 'CC';
        break;
      case 'bonafide':
        prefix = 'BON';
        break;
      case 'marksheet':
        prefix = 'MS';
        break;
      case 'merit':
        prefix = 'MT';
        break;
      default:
        prefix = 'CERT';
        break;
    }

    final all = await _db.getCertificatesWithDetails(
      certificateType: certificateType,
    );
    final nextNum = all.length + 1;
    return '$prefix-$year-${nextNum.toString().padLeft(4, '0')}';
  }

  // ==================== CRUD OPERATIONS ====================

  /// Issue a new certificate
  Future<int> issueCertificate({
    required int studentId,
    int? academicYearId,
    required String certificateType,
    required String title,
    DateTime? issueDate,
    String status = 'issued',
    String? reason,
    String? conduct,
    bool duesCleared = true,
    String? remarks,
    String? issuedBy,
    String? customCertificateNumber,
    Map<String, dynamic>? data,
  }) async {
    final certNum =
        customCertificateNumber ??
        await generateCertificateNumber(certificateType);

    final companion = CertificatesCompanion(
      certificateNumber: Value(certNum),
      studentId: Value(studentId),
      academicYearId: Value(academicYearId),
      certificateType: Value(certificateType),
      title: Value(title),
      issueDate: Value(issueDate ?? DateTime.now()),
      status: Value(status),
      reason: Value(reason),
      conduct: Value(conduct),
      duesCleared: Value(duesCleared),
      remarks: Value(remarks),
      issuedBy: Value(issuedBy ?? 'Administrator'),
      dataJson: Value(data != null ? jsonEncode(data) : null),
    );

    return _db.insertCertificate(companion);
  }

  /// Update an existing certificate
  Future<bool> updateCertificate({
    required int id,
    required String title,
    required DateTime issueDate,
    String status = 'issued',
    String? reason,
    String? conduct,
    bool duesCleared = true,
    String? remarks,
    String? issuedBy,
    Map<String, dynamic>? data,
  }) async {
    final existing = await _db.getCertificateWithDetailsById(id);
    if (existing == null) return false;

    final updated = existing.certificate.copyWith(
      title: title,
      issueDate: issueDate,
      status: status,
      reason: Value(reason),
      conduct: Value(conduct),
      duesCleared: duesCleared,
      remarks: Value(remarks),
      issuedBy: Value(issuedBy),
      dataJson: Value(data != null ? jsonEncode(data) : existing.dataJson),
    );

    return _db.updateCertificate(updated);
  }

  /// Delete a certificate
  Future<int> deleteCertificate(int id) {
    return _db.deleteCertificate(id);
  }

  /// Watch reactive stream of certificates
  Stream<List<CertificateWithDetails>> watchCertificates({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    return _db.watchCertificatesWithDetails(
      certificateType: certificateType,
      studentId: studentId,
      classId: classId,
      academicYearId: academicYearId,
      query: query,
      status: status,
    );
  }

  /// Get list of certificates as a future
  Future<List<CertificateWithDetails>> getCertificates({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    return _db.getCertificatesWithDetails(
      certificateType: certificateType,
      studentId: studentId,
      classId: classId,
      academicYearId: academicYearId,
      query: query,
      status: status,
    );
  }

  /// Get single certificate with full joined details
  Future<CertificateWithDetails?> getCertificateById(int id) {
    return _db.getCertificateWithDetailsById(id);
  }

  /// Get summary of certificate metrics
  Future<CertificateSummary> getCertificateSummary() async {
    final all = await _db.getCertificatesWithDetails();
    int tc = 0;
    int cc = 0;
    int bonafide = 0;
    int marksheet = 0;
    int merit = 0;
    int custom = 0;

    for (final c in all) {
      switch (c.certificateType.toLowerCase()) {
        case 'tc':
          tc++;
          break;
        case 'cc':
          cc++;
          break;
        case 'bonafide':
          bonafide++;
          break;
        case 'marksheet':
          marksheet++;
          break;
        case 'merit':
          merit++;
          break;
        default:
          custom++;
          break;
      }
    }

    return CertificateSummary(
      totalIssued: all.length,
      tcCount: tc,
      ccCount: cc,
      bonafideCount: bonafide,
      marksheetCount: marksheet,
      meritCount: merit,
      customCount: custom,
    );
  }

  // ==================== DESERIALIZERS ====================

  /// Parse Transfer Certificate structured JSON
  TransferCertificateData? getTransferCertificateData(Certificate cert) {
    if (cert.dataJson == null) return null;
    try {
      final map = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      return TransferCertificateData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse Character Certificate structured JSON
  CharacterCertificateData? getCharacterCertificateData(Certificate cert) {
    if (cert.dataJson == null) return null;
    try {
      final map = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      return CharacterCertificateData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse Bonafide Certificate structured JSON
  BonafideCertificateData? getBonafideCertificateData(Certificate cert) {
    if (cert.dataJson == null) return null;
    try {
      final map = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      return BonafideCertificateData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse Mark Sheet structured JSON
  MarksheetData? getMarksheetData(Certificate cert) {
    if (cert.dataJson == null) return null;
    try {
      final map = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      return MarksheetData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse Custom Certificate structured JSON
  CustomCertificateData? getCustomCertificateData(Certificate cert) {
    if (cert.dataJson == null) return null;
    try {
      final map = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      return CustomCertificateData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ==================== HIGH-LEVEL TYPE-SPECIFIC ISSUANCE ====================

  /// Issue a Transfer Certificate (TC)
  Future<int> issueTransferCertificate({
    required int studentId,
    int? academicYearId,
    required String reason,
    String conduct = 'Good',
    bool duesCleared = true,
    DateTime? leavingDate,
    String? classStudying,
    String? promotedToClass,
    String? lastExamPassed,
    int? totalWorkingDays,
    int? daysPresent,
    String? remarks,
    String? issuedBy,
  }) async {
    final tcData = TransferCertificateData(
      dateOfLeaving: leavingDate ?? DateTime.now(),
      classInWhichStudying: classStudying ?? 'N/A',
      promotedToClass: promotedToClass,
      reasonForLeaving: reason,
      conduct: conduct,
      duesCleared: duesCleared,
      totalWorkingDays: totalWorkingDays,
      totalPresentDays: daysPresent,
      generalRemarks:
          lastExamPassed != null ? 'Last Exam: $lastExamPassed' : null,
    );

    final dataMap = tcData.toJson();
    if (lastExamPassed != null) {
      dataMap['lastExamPassed'] = lastExamPassed;
    }

    return issueCertificate(
      studentId: studentId,
      academicYearId: academicYearId,
      certificateType: CertificateTypes.transferCertificate,
      title: 'Transfer Certificate',
      reason: reason,
      conduct: conduct,
      duesCleared: duesCleared,
      remarks: remarks,
      issuedBy: issuedBy,
      data: dataMap,
    );
  }

  /// Issue a Character Certificate (CC)
  Future<int> issueCharacterCertificate({
    required int studentId,
    int? academicYearId,
    String conduct = 'Good',
    String? motherName,
    String? session,
    String? coCurricularActivities,
    String? academicPerformance,
    String? remarks,
    String? issuedBy,
  }) async {
    final ccData = CharacterCertificateData(
      periodFrom: '',
      periodTo: '',
      characterRating: conduct,
      motherName: motherName,
      session: session,
      academicPerformance: academicPerformance,
      coCurricularActivities: coCurricularActivities,
      moralCharacter: 'Possesses exemplary moral character.',
      generalRemarks: remarks,
    );

    return issueCertificate(
      studentId: studentId,
      academicYearId: academicYearId,
      certificateType: CertificateTypes.characterCertificate,
      title: 'Character Certificate',
      conduct: conduct,
      remarks: remarks,
      issuedBy: issuedBy,
      data: ccData.toJson(),
    );
  }

  /// Issue a Bonafide Certificate
  Future<int> issueBonafideCertificate({
    required int studentId,
    int? academicYearId,
    required String purpose,
    DateTime? validTill,
    String? remarks,
    String? issuedBy,
    String? fatherName,
    String? motherName,
    String? session,
    DateTime? dob,
  }) async {
    final bonData = BonafideCertificateData(
      purpose: purpose,
      academicYear: session,
      validUntil: validTill,
      fatherName: fatherName,
      motherName: motherName,
      dob: dob,
      generalRemarks: remarks,
    );

    return issueCertificate(
      studentId: studentId,
      academicYearId: academicYearId,
      certificateType: CertificateTypes.bonafideCertificate,
      title: 'Bonafide Certificate',
      reason: purpose,
      remarks: remarks,
      issuedBy: issuedBy,
      data: bonData.toJson(),
    );
  }

  /// Parse Merit Certificate structured JSON
  MeritCertificateData? getMeritCertificateData(Certificate cert) {
    if (cert.dataJson == null) return null;
    try {
      final map = jsonDecode(cert.dataJson!) as Map<String, dynamic>;
      return MeritCertificateData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Issue a Certificate of Merit & Distinction
  Future<int> issueMeritCertificate({
    required int studentId,
    int? academicYearId,
    required String eventTitle,
    required String rank,
    String? citation,
    String? academicSession,
    String? coordinatorTitle,
    String? principalTitle,
    String? remarks,
    String? issuedBy,
  }) async {
    final meritData = MeritCertificateData(
      eventTitle: eventTitle,
      rank: rank,
      citation: citation,
      academicSession: academicSession,
      coordinatorTitle: coordinatorTitle ?? 'ACTIVITY COORDINATOR',
      principalTitle: principalTitle ?? 'PRINCIPAL',
      remarks: remarks ?? citation,
    );

    return issueCertificate(
      studentId: studentId,
      academicYearId: academicYearId,
      certificateType: CertificateTypes.meritCertificate,
      title: 'Certificate of Merit & Distinction',
      reason: eventTitle,
      remarks: remarks ?? citation,
      issuedBy: issuedBy,
      data: meritData.toJson(),
    );
  }

  /// Issue a Mark Sheet / Academic Transcript
  Future<int> issueMarksheet({
    required int studentId,
    int? academicYearId,
    required String examName,
    required List<MarksheetSubjectEntry> subjects,
    String? fatherName,
    String? motherName,
    String? session,
    String? remarks,
    String? issuedBy,
  }) async {
    double totalFull = 0;
    double totalPass = 0;
    double totalObtained = 0;
    bool allPassed = true;

    for (final s in subjects) {
      totalFull += s.fullMarks;
      totalPass += s.passMarks;
      totalObtained += s.totalObtained;
      if (!s.isPassed) allPassed = false;
    }

    final percentage = totalFull > 0 ? (totalObtained / totalFull) * 100 : 0.0;
    final gradeInfo = calculateGrade(percentage);
    final division = allPassed ? calculateDivision(percentage) : 'Fail';

    final msData = MarksheetData(
      examName: examName,
      subjects: subjects,
      totalFullMarks: totalFull,
      totalPassMarks: totalPass,
      totalMarksObtained: totalObtained,
      percentage: percentage,
      gpa: gradeInfo.gradePoint,
      division: division,
      result: allPassed ? 'Passed' : 'Failed',
      teacherRemarks: remarks,
      fatherName: fatherName,
      motherName: motherName,
      session: session,
    );

    return issueCertificate(
      studentId: studentId,
      academicYearId: academicYearId,
      certificateType: CertificateTypes.markSheet,
      title: 'Mark Sheet - $examName',
      remarks: remarks,
      issuedBy: issuedBy,
      data: msData.toJson(),
    );
  }

  /// Update certificate status (e.g. issued, cancelled)
  Future<bool> updateCertificateStatus(
    int id,
    String status, {
    String? remarks,
  }) async {
    final existing = await _db.getCertificateWithDetailsById(id);
    if (existing == null) return false;

    final updated = existing.certificate.copyWith(
      status: status,
      remarks: remarks != null ? Value(remarks) : const Value.absent(),
    );

    return _db.updateCertificate(updated);
  }

  /// Get all certificates for a specific student
  Future<List<CertificateWithDetails>> getCertificatesForStudent(
    int studentId,
  ) {
    return _db.getCertificatesWithDetails(studentId: studentId);
  }

  /// Get all certificates optionally filtered
  Future<List<CertificateWithDetails>> getAllCertificates({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    return getCertificates(
      certificateType: certificateType,
      studentId: studentId,
      classId: classId,
      academicYearId: academicYearId,
      query: query,
      status: status,
    );
  }
}
