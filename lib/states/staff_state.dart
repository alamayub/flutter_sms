import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../modesl/staff_model.dart';

@immutable
class StaffState {
  final bool loading;
  final String? error;
  final List<StaffModel> staffs;

  const StaffState({
    this.loading = false,
    this.error,
    this.staffs = const [],

  });

  StaffState copyWith({
    bool? loading,
    String? error,
    List<StaffModel>? staffs,
  }) => StaffState(
    loading: loading ?? this.loading,
    error: error ?? this.error,
    staffs: staffs ?? this.staffs,
  );

  @override
  bool operator ==(covariant StaffState other) =>
      identical(this, other) ||
      (loading == other.loading &&
          error == other.error &&
          listEquals(staffs, other.staffs));

  @override
  int get hashCode => Object.hash(loading, error, staffs);
}
