import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_typography.dart';

/// Memory's avatar.
///
/// One place decides how a missing photo degrades: to the person's initial on
/// the accent, never to a generic silhouette.
class MemoryAvatar extends StatelessWidget {
  const MemoryAvatar({
    super.key,
    required this.radius,
    required this.dark,
    this.imageUrl,
    this.bytes,
    this.image,
    this.initial,
    this.background,
    this.foreground,
  });

  final double radius;
  final bool dark;

  /// A remote photo. Ignored when [bytes] is set.
  final String? imageUrl;

  /// A locally-picked photo, shown before it finishes uploading.
  final Uint8List? bytes;

  /// An already-resolved provider, for callers that build their own (cached,
  /// file-backed, or asset images). Takes precedence over [imageUrl].
  final ImageProvider? image;

  /// Falls back to '?' when the name is empty.
  final String? initial;

  final Color? background;
  final Color? foreground;

  ImageProvider? get _image {
    if (bytes != null) return MemoryImage(bytes!);
    if (image != null) return image;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return NetworkImage(imageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final letter = (initial == null || initial!.isEmpty)
        ? '?'
        : initial![0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          background ?? (dark ? MemoryColors.accent : MemoryColors.ink),
      backgroundImage: image,
      child: image != null
          ? null
          : Text(
              letter,
              style: MemoryTypography.headlineLarge.copyWith(
                // Scale the initial with the circle so it never crowds the edge.
                fontSize: radius * 0.75,
                color: foreground ?? Colors.white,
              ),
            ),
    );
  }
}
