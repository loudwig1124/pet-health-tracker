/// The pet photo painting rules shared by the pet page, the profile list and
/// the pet form: one image widget that fills its frame, never a black crop.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../ui/theme/app_theme.dart';

/// Warm paper tint used behind a missing photo. Derived from the theme accent
/// so the fallback always belongs to the palette.
Color get _photoFallbackTint => Color.alphaBlend(
  AppColors.accent.withValues(alpha: 0.12),
  AppColors.surface,
);

/// The path of an existing photo file, or null when the pet has none (or the
/// file moved). Checked synchronously so a missing file renders the fallback
/// instead of an image error.
String? existingPhotoPath(String? photoPath) {
  final String? trimmed = photoPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return File(trimmed).existsSync() ? trimmed : null;
}

/// First letter of a name, for photo fallbacks ("?" when unnamed).
String photoInitial(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Full-bleed pet photo with a portrait fallback. The photo is painted at
/// whatever size the parent gives it — callers must keep the frame fixed.
class PetPhoto extends StatelessWidget {
  const PetPhoto({
    super.key,
    this.photoPath,
    required this.petName,
    this.fit = BoxFit.cover,
  });

  final String? photoPath;
  final String petName;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String? path = existingPhotoPath(photoPath);
    if (path == null) {
      return _PhotoFallback(petName: petName);
    }
    return Image.file(
      File(path),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _PhotoFallback(petName: petName),
    );
  }
}

/// Round thumbnail for lists. Falls back to the pet's initial on the paper tint.
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    this.photoPath,
    required this.petName,
    this.size = 42,
  });

  final String? photoPath;
  final String petName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? path = existingPhotoPath(photoPath);
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? ColoredBox(
                color: _photoFallbackTint,
                child: Center(
                  child: Icon(
                    Icons.pets_rounded,
                    size: size * 0.55,
                    color: AppColors.accent,
                  ),
                ),
              )
            : Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(
              AppColors.dueSoonSurface.withValues(alpha: 0.9),
              AppColors.surface,
            ),
            AppColors.paper,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.pets_rounded,
          size: 132,
          color: AppColors.accent.withValues(alpha: 0.32),
          semanticLabel: 'Photo of $petName',
        ),
      ),
    );
  }
}
