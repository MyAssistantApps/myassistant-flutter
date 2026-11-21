import 'package:local_auth/local_auth.dart';

/// THE USER'S DOCUMENTS SIT BEHIND THEIR SCREEN LOCK (owner, 2026-11-21).
///
/// Aadhaar, PAN and passports are the most sensitive things in the app, so
/// opening My Documents, or a document the assistant pops up by voice,
/// first asks for the phone's own screen lock: fingerprint, face, PIN,
/// pattern or password, whichever the user set in Android. Nothing new to
/// remember and nothing stored by the app.
///
/// One unlock covers [window], so moving between documents, or asking the
/// assistant for a second one, does not ask again. Leaving the app for
/// longer than that locks them again. A phone with no screen lock at all
/// cannot be asked, so documents open as before.
class DocumentsLock {
  DocumentsLock._();
  static final DocumentsLock instance = DocumentsLock._();

  static const window = Duration(minutes: 5);
  final _auth = LocalAuthentication();
  DateTime? _unlockedAt;
  Future<bool>? _asking;

  /// For tests: the clock.
  DateTime Function() now = DateTime.now;

  bool get isUnlocked {
    final at = _unlockedAt;
    return at != null && now().difference(at) < window;
  }

  /// Asks for the screen lock unless an unlock is still fresh. True when
  /// the documents may be shown. Concurrent callers share one prompt.
  Future<bool> unlock() {
    if (isUnlocked) return Future.value(true);
    return _asking ??= _ask().whenComplete(() => _asking = null);
  }

  Future<bool> _ask() async {
    try {
      if (!await _auth.isDeviceSupported()) {
        // No screen lock on this phone: nothing to ask with.
        _unlockedAt = now();
        return true;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock to view your documents',
        options: const AuthenticationOptions(
          biometricOnly: false, // PIN, pattern or password count too
          stickyAuth: true,
        ),
      );
      if (ok) _unlockedAt = now();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Locks the documents again (the app went to the background for long).
  void lock() => _unlockedAt = null;

  /// For tests.
  void debugUnlock() => _unlockedAt = now();
}
