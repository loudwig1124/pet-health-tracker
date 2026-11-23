/// Owns pet photo files: picking one from the library and storing it inside the
/// app's own directory, so the OS can't delete it out from under the database.
library;

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

class PetPhotos {
  PetPhotos({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The folder the app owns. Anything outside it is never deleted by us.
  Future<Directory> _folder() async =>
      Directory('${await getDatabasesPath()}/pet_photos');

  /// Opens the photo library and copies the choice into app storage.
  ///
  /// iOS hands back a file in a temporary directory that disappears, which is
  /// why the bytes are copied rather than the path stored. Returns null when the
  /// user cancels.
  Future<String?> pickFromLibrary() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      // Picking alone needs no photo-library permission: iOS uses PHPicker.
      // Asking for full metadata is what triggers the access prompt.
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }
    final Directory folder = await _folder();
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    final String name = 'pet_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final File target = File('${folder.path}/$name');
    await target.writeAsBytes(await picked.readAsBytes());
    return target.path;
  }

  /// Deletes a photo the app stored. Paths outside the app's folder are ignored.
  Future<void> deleteOwned(String? path) async {
    final String? trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }
    final Directory folder = await _folder();
    if (!trimmed.startsWith(folder.path)) {
      return;
    }
    final File file = File(trimmed);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
