import 'package:flutter/foundation.dart' show immutable;

import '../modesl/school_model.dart';
import '../config/enums.dart' show AuthAction;

@immutable
class AuthState {
  final String? user;
  final AuthAction state;
  final SchoolModel? school;

  const AuthState({this.user, this.state = AuthAction.login, this.school});

  AuthState copyWith({String? user, AuthAction? state, SchoolModel? school}) =>
      AuthState(user: user ?? this.user, state: state ?? this.state, school: school ?? this.school);

  @override
  bool operator ==(covariant AuthState other) =>
      identical(this, other) || (user == other.user && state == other.state && school == other.school);

  @override
  int get hashCode => Object.hash(user, state, school);
}
