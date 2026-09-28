import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../../config/extensions.dart';

class UploadSchoolLogo extends StatelessWidget {
  final String? logoPath;
  final Function()? onLogoPick;
  final Function()? onLogoRemove;
  const UploadSchoolLogo({
    super.key,
    this.logoPath,
    this.onLogoPick,
    this.onLogoRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.theme.colorScheme.surfaceContainerHighest
                      .withAlpha(90),
                  border: Border.all(
                    color: context.theme.colorScheme.primary.withAlpha(120),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.theme.colorScheme.primary.withAlpha(30),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child:
                      logoPath != null && File(logoPath!).existsSync()
                          ? Image.file(File(logoPath!), fit: BoxFit.cover)
                          : Center(
                            child: Icon(
                              Icons.school_rounded,
                              size: 42,
                              color: context.theme.colorScheme.primary,
                            ),
                          ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: onLogoPick,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: onLogoPick,
                icon: const Icon(Icons.upload_rounded, size: 15),
                label: Text(
                  logoPath == null ? 'Upload School Logo' : 'Change Logo',
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (logoPath != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onLogoRemove,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: context.theme.colorScheme.error,
                  ),
                  label: Text(
                    'Remove',
                    style: TextStyle(
                      color: context.theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
