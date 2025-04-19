import 'package:flutter/foundation.dart' show immutable;

import 'typedefs.dart';

@immutable
class GenericController {
  final CloseGenericController close;
  final UpdateGenericController update;

  const GenericController({required this.close, required this.update});
}
