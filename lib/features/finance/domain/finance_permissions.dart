// lib/features/finance/domain/finance_permissions.dart
import '../../../core/constants/app_constants.dart';

class FinancePermissions {
  static const String feesView = 'fees.view';
  static const String feesStructureManage = 'fees.structure_manage';
  static const String feesDiscountManage = 'fees.discount_manage';
  static const String feesGenerateDues = 'fees.generate_dues';
  static const String feesCollect = 'fees.collect';
  static const String feesReversePayment = 'fees.reverse_payment';
  static const String feesWaive = 'fees.waive';
  static const String feesReprintReceipt = 'fees.reprint_receipt';
  static const String expensesView = 'expenses.view';
  static const String expensesCreate = 'expenses.create';
  static const String expensesApprove = 'expenses.approve';
  static const String expensesReverse = 'expenses.reverse';
  static const String incomeManage = 'income.manage';
  static const String dailyClose = 'finance.daily_close';
  static const String reportsView = 'finance.reports_view';

  static bool hasPermission(String role, String permission) {
    final lowerRole = role.toLowerCase();

    // Admin & Principal have full authority
    if (lowerRole == UserRole.admin || lowerRole == UserRole.principal) {
      return true;
    }

    if (lowerRole == UserRole.accountant) {
      switch (permission) {
        case feesView:
        case feesStructureManage:
        case feesGenerateDues:
        case feesCollect:
        case feesReprintReceipt:
        case expensesView:
        case expensesCreate:
        case incomeManage:
        case dailyClose:
        case reportsView:
          return true;
        case feesReversePayment:
        case feesWaive:
        case expensesApprove:
        case expensesReverse:
        case feesDiscountManage:
          // Strict separation of duties: accountant cannot reverse payments or approve expenses alone
          return false;
        default:
          return false;
      }
    }

    // Teachers do not have finance access
    return false;
  }
}
