// lib/features/exams/domain/exam_models.dart

enum ExamStatus {
  draft,
  scheduled,
  inProgress,
  marksEntry,
  verification,
  published,
  archived;

  String get value {
    switch (this) {
      case ExamStatus.draft:
        return 'draft';
      case ExamStatus.scheduled:
        return 'scheduled';
      case ExamStatus.inProgress:
        return 'in_progress';
      case ExamStatus.marksEntry:
        return 'marks_entry';
      case ExamStatus.verification:
        return 'verification';
      case ExamStatus.published:
        return 'published';
      case ExamStatus.archived:
        return 'archived';
    }
  }

  String get displayName {
    switch (this) {
      case ExamStatus.draft:
        return 'Draft';
      case ExamStatus.scheduled:
        return 'Scheduled';
      case ExamStatus.inProgress:
        return 'In Progress';
      case ExamStatus.marksEntry:
        return 'Marks Entry';
      case ExamStatus.verification:
        return 'Under Verification';
      case ExamStatus.published:
        return 'Published';
      case ExamStatus.archived:
        return 'Archived';
    }
  }

  static ExamStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'draft':
        return ExamStatus.draft;
      case 'scheduled':
        return ExamStatus.scheduled;
      case 'in_progress':
      case 'inprogress':
        return ExamStatus.inProgress;
      case 'marks_entry':
      case 'marksentry':
        return ExamStatus.marksEntry;
      case 'verification':
        return ExamStatus.verification;
      case 'published':
        return ExamStatus.published;
      case 'archived':
        return ExamStatus.archived;
      default:
        return ExamStatus.draft;
    }
  }
}

enum MarkStatus {
  present,
  absent,
  medical,
  notAppeared,
  withheld,
  exempt;

  String get value {
    switch (this) {
      case MarkStatus.present:
        return 'present';
      case MarkStatus.absent:
        return 'absent';
      case MarkStatus.medical:
        return 'medical';
      case MarkStatus.notAppeared:
        return 'not_appeared';
      case MarkStatus.withheld:
        return 'withheld';
      case MarkStatus.exempt:
        return 'exempt';
    }
  }

  String get displayName {
    switch (this) {
      case MarkStatus.present:
        return 'Present';
      case MarkStatus.absent:
        return 'Absent';
      case MarkStatus.medical:
        return 'Medical Leave';
      case MarkStatus.notAppeared:
        return 'Not Appeared';
      case MarkStatus.withheld:
        return 'Withheld';
      case MarkStatus.exempt:
        return 'Exempt';
    }
  }

  static MarkStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'present':
        return MarkStatus.present;
      case 'absent':
        return MarkStatus.absent;
      case 'medical':
        return MarkStatus.medical;
      case 'not_appeared':
      case 'notappeared':
        return MarkStatus.notAppeared;
      case 'withheld':
        return MarkStatus.withheld;
      case 'exempt':
        return MarkStatus.exempt;
      default:
        return MarkStatus.present;
    }
  }
}

class GradeRuleModel {
  final String grade;
  final double minPercentage;
  final double maxPercentage;
  final double? gradePoint;
  final String? description;
  final bool isPassing;

  const GradeRuleModel({
    required this.grade,
    required this.minPercentage,
    required this.maxPercentage,
    this.gradePoint,
    this.description,
    this.isPassing = true,
  });

  Map<String, dynamic> toJson() => {
    'grade': grade,
    'minPercentage': minPercentage,
    'maxPercentage': maxPercentage,
    'gradePoint': gradePoint,
    'description': description,
    'isPassing': isPassing,
  };

  factory GradeRuleModel.fromJson(Map<String, dynamic> json) => GradeRuleModel(
    grade: json['grade'] as String,
    minPercentage: (json['minPercentage'] as num).toDouble(),
    maxPercentage: (json['maxPercentage'] as num).toDouble(),
    gradePoint: (json['gradePoint'] as num?)?.toDouble(),
    description: json['description'] as String?,
    isPassing: json['isPassing'] as bool? ?? true,
  );
}
