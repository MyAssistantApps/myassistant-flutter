import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRO PHOTO — the professional's OWN photo on their assistant (owner,
///  2026-11-14: "keep this as default, and add an edit icon where if I am a
///  doctor, I can upload my image instead").
///
///  The stock photo stays the default. A picked photo is copied into the
///  app's documents folder, one file per ACCOUNT and profession, so a
///  shared phone never shows the previous account's face. [version] bumps
///  on every change so the hero and the Home banner repaint at once.
/// ─────────────────────────────────────────────────────────────────────────
class ProPhoto {
  ProPhoto._();

  /// Bumps whenever a photo is set or cleared — listen to repaint.
  static final ValueNotifier<int> version = ValueNotifier(0);

  static Future<File> _fileFor(String kind) async {
    final dir = await getApplicationDocumentsDirectory();
    final uid = AuthService.instance.user?.id ?? 0;
    return File('${dir.path}/pro_photo_${uid}_$kind.jpg');
  }

  /// The user's own photo for [kind], or null to show the default.
  static Future<File?> current(String kind) async {
    try {
      final f = await _fileFor(kind);
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Camera or gallery → stored as this account's photo. Returns false when
  /// the user cancelled or the photo couldn't be saved.
  static Future<bool> pick(String kind, {required bool camera}) async {
    try {
      final shot = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        // A hero is at most ~1200 px wide on a phone; anything bigger is
        // memory spent on every open of the page.
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
      if (shot == null) return false;
      final f = await _fileFor(kind);
      await File(shot.path).copy(f.path);
      // A new file under the same name: drop the decoded old one.
      PaintingBindingCache.evict(f);
      version.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Back to the default stock photo.
  static Future<void> reset(String kind) async {
    try {
      final f = await _fileFor(kind);
      if (await f.exists()) {
        PaintingBindingCache.evict(f);
        await f.delete();
      }
    } catch (_) {}
    version.value++;
  }
}

/// Image.file caches by path; the same path with new bytes must be evicted
/// or the old face keeps showing until the app restarts.
class PaintingBindingCache {
  static void evict(File f) {
    try {
      FileImage(f).evict();
    } catch (_) {}
  }
}
