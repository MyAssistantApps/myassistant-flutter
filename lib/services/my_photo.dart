import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'pro_photo.dart';
import 'studio_service.dart';

/// What came of an upload or removal, in words the card can show.
class MyPhotoResult {
  const MyPhotoResult._(this.ok, this.message, {this.retry});
  const MyPhotoResult.done(String message) : this._(true, message);
  const MyPhotoResult.failed(String message) : this._(false, message);

  /// Consent is needed first. Once accepted, call [retry] to store the
  /// photo that was already picked.
  const MyPhotoResult.consent(Future<MyPhotoResult> Function() retry)
      : this._(false, '', retry: retry);
  static const cancelled = MyPhotoResult._(false, '');

  final bool ok;
  final String message;
  final Future<MyPhotoResult> Function()? retry;
  bool get needsConsent => retry != null;
}

/// ─────────────────────────────────────────────────────────────────────────
///  MY PHOTO: the user's own photo, set once and used across the app (owner,
///  2026-11-16: "upload my photo ... it will be used everywhere in the
///  app").
///
///  The photo is stored on the user's account as their default Style Studio
///  photo, the same one Style Studio and Try-on already use, so it follows
///  them to a new phone. A copy is kept on the device (one file per account)
///  so it shows instantly. The professional assistant's hero and the Home
///  banner fall back to it when no profession photo has been set
///  ([ProPhoto.current]).
///
///  Storing a face needs the Studio consent first. The server refuses
///  without it, and [upload] reports that as [MyPhotoResult.consent].
/// ─────────────────────────────────────────────────────────────────────────
class MyPhoto {
  MyPhoto._();

  /// Bumps whenever the photo changes. Listen to it to repaint.
  static final ValueNotifier<int> version = ValueNotifier(0);

  // The photo is per account, and at launch the account may load after the
  // first paint: repaint once it does (or changes), so the banner does not
  // stay on the stock photo (2026-11-17).
  static bool _hooked = false;
  static int? _uid;
  static void _hook() {
    if (_hooked) return;
    _hooked = true;
    _uid = AuthService.instance.user?.id;
    AuthService.instance.addListener(() {
      final id = AuthService.instance.user?.id;
      if (id != _uid) {
        _uid = id;
        _bump();
      }
    });
  }

  static Future<File> _file() async {
    _hook();
    final dir = await getApplicationDocumentsDirectory();
    final uid = AuthService.instance.user?.id ?? 0;
    return File('${dir.path}/my_photo_$uid.jpg');
  }

  static void _bump() {
    version.value++;
    // The pro hero and banner fall back to this photo.
    ProPhoto.version.value++;
  }

  /// The photo on this device, or null when none is set.
  static Future<File?> current() async {
    try {
      final f = await _file();
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Picks a photo and stores it on the account and on the device.
  static Future<MyPhotoResult> upload({required bool camera}) async {
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (_) {
      return const MyPhotoResult.failed(
          'Unable to open the camera or gallery. Please check the app permissions.');
    }
    if (shot == null) return MyPhotoResult.cancelled;
    return save(await shot.readAsBytes(),
        filename: shot.name.isEmpty ? 'me.jpg' : shot.name,
        mimeType: shot.mimeType ?? 'image/jpeg');
  }

  /// Stores [bytes] as the user's photo (after consent, if it was asked).
  static Future<MyPhotoResult> save(List<int> bytes,
      {required String filename, required String mimeType}) async {
    try {
      await StudioService.addPhoto(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        role: 'model',
        label: 'My photo',
        makeDefault: true,
      );
    } on StudioException catch (e) {
      if (e.needsConsent) {
        return MyPhotoResult.consent(
            () => save(bytes, filename: filename, mimeType: mimeType));
      }
      return MyPhotoResult.failed(e.message);
    } catch (_) {
      return const MyPhotoResult.failed(
          'Unable to upload the photo. Check your connection and try again.');
    }
    await _writeLocal(bytes);
    return const MyPhotoResult.done('Your photo has been saved.');
  }

  /// Removes the photo from the device and the account's default photo.
  static Future<MyPhotoResult> remove() async {
    try {
      final s = await StudioService.load();
      final p = s.defaultPhoto;
      if (p != null) await StudioService.deletePhoto(p.id);
    } catch (_) {
      return const MyPhotoResult.failed(
          'Unable to remove the photo. Check your connection and try again.');
    }
    try {
      final f = await _file();
      if (await f.exists()) {
        PaintingBinding.instance.imageCache.evict(FileImage(f));
        await f.delete();
      }
    } catch (_) {}
    _bump();
    return const MyPhotoResult.done('Your photo has been removed.');
  }

  /// After a reinstall or on a new phone, fetches the account's photo so
  /// the device copy matches it. Quiet on failure.
  static Future<void> syncFromAccount() async {
    try {
      if (await current() != null) return;
      final s = await StudioService.load();
      final p = s.defaultPhoto;
      if (p == null) return;
      final d = await ApiService.downloadDocument(p.documentId);
      await _writeLocal(d.bytes);
    } catch (_) {
      // Offline or not signed in: the card simply offers an upload.
    }
  }

  static Future<void> _writeLocal(List<int> bytes) async {
    try {
      final f = await _file();
      await f.writeAsBytes(bytes, flush: true);
      PaintingBinding.instance.imageCache.evict(FileImage(f));
    } catch (_) {}
    _bump();
  }
}
