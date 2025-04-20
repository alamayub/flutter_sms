import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../modesl/staff_model.dart';

@immutable
class StaffState {
  final bool loading;
  final String? error;
  final List<StaffModel> staffs;
  final String? search;

  const StaffState({
    this.loading = false,
    this.error,
    this.staffs = const [],
    this.search,

  });

  StaffState copyWith({
    bool? loading,
    String? error,
    List<StaffModel>? staffs,
    String? search,
    String? grade,
  }) => StaffState(
    loading: loading ?? this.loading,
    error: error ?? this.error,
    staffs: staffs ?? this.staffs,
    search: search ?? this.search,
  );

  @override
  bool operator ==(covariant StaffState other) =>
      identical(this, other) ||
      (loading == other.loading &&
          error == other.error &&
          listEquals(staffs, other.staffs) &&
          search == other.search );

  @override
  int get hashCode => Object.hash(loading, error, staffs, search);
}
