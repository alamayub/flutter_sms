import 'package:isar/isar.dart';

part 'salary_model.g.dart';

@collection
class SalaryModel {
  Id id = Isar.autoIncrement;

  /// Reference to Staff
  late int staffId;

  /// Year and Month of salary (e.g., 2025-05)
  @Index(composite: [CompositeIndex('staffId')], unique: true)
  late String salaryMonth;

  /// Amount paid
  late double amountPaid;

  /// Payment status
  late bool isPaid;

  /// Payment date (optional if unpaid)
  String? paymentDate;

  /// Metadata
  late int createdBy;
  late String createdAt;
  int? updatedBy;
  String? updatedAt;
}
