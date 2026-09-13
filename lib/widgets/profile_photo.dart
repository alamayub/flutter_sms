import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/image_storage_helper.dart';

/// Displays a profile photo and falls back to up to two uppercase initials.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 64,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius,
    this.fontSize,
  });

  final String name;
  final String? photoPath;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final double? fontSize;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '--';
    if (parts.length == 1) {
      final value = parts.first.toUpperCase();
      return value.substring(0, value.length.clamp(0, 2));
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final path = photoPath?.trim();
    final hasLocalPhoto = ImageStorageHelper.isLocalFile(path);
    final hasNetworkPhoto =
        path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    ImageProvider<Object>? image;
    if (hasLocalPhoto) {
      image = FileImage(File(path!)) as ImageProvider<Object>;
    } else if (hasNetworkPhoto) {
      image = NetworkImage(path) as ImageProvider<Object>;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border:
            borderWidth > 0
                ? Border.all(
                  color: borderColor ?? foregroundColor ?? Colors.transparent,
                  width: borderWidth,
                )
                : null,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          image != null
              ? Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              )
              : _fallback(),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: fontSize ?? size * 0.38,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
    );
  }
}
