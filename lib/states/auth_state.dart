import 'package:flutter/foundation.dart' show immutable;

import '../config/enums.dart' show AuthAction;

@immutable
class AuthState {
  final String? user;
  final AuthAction state;

  const AuthState({this.user, this.state = AuthAction.login});

  AuthState copyWith({String? user, AuthAction? state}) =>
      AuthState(user: user ?? this.user, state: state ?? this.state);

  @override
  bool operator ==(covariant AuthState other) =>
      identical(this, other) || (user == other.user && state == other.state);

  @override
  int get hashCode => Object.hash(user, state);
}
