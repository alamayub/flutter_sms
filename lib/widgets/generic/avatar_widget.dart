import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../../utils/image_storage_helper.dart';

class AvatarWidget extends StatelessWidget {
  final String? path;
  final Color color;
  final String name;
  const AvatarWidget({
    super.key,
    this.path,
    required this.color,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final photo = path?.trim();
    if (photo != null && photo.isNotEmpty) {
      if (ImageStorageHelper.isLocalFile(photo)) {
        return CircleAvatar(
          radius: 24,
          backgroundImage: FileImage(File(photo)),
          backgroundColor: color.withAlpha(30),
        );
      } else if (photo.startsWith('http')) {
        return CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(photo),
          backgroundColor: color.withAlpha(30),
        );
      }
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withAlpha(30),
      child: Text(
        name.isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'E',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
