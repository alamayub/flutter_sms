import 'package:flutter/foundation.dart' show immutable;

import '../config/enums.dart' show MessageType;

@immutable
class GlobalState {
  final bool loading;
  final String? error;
  final MessageType type;

  const GlobalState({
    this.loading = false,
    this.error,
    this.type = MessageType.neutral,
  });

  const GlobalState.initial()
    : loading = false,
      error = null,
      type = MessageType.neutral;

  GlobalState copyWith({bool? loading, String? error, MessageType? type}) =>
      GlobalState(
        loading: loading ?? this.loading,
        error: error ?? this.error,
        type: type ?? this.type,
      );

  @override
  bool operator ==(covariant GlobalState other) =>
      identical(this, other) ||
      (loading == other.loading && error == other.error && type == other.type);

  @override
  int get hashCode => Object.hash(loading, error, type);
}
