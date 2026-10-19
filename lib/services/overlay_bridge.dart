import 'package:flutter/services.dart';

import '../core/log.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Where the two Android permissions and the owner's switches stand.
class OverlayStatus {
  const OverlayStatus({
    this.overlay = false,
    this.notifications = false,
    this.replies = false,
    this.bubble = false,
  });

  /// "Display over other apps" is allowed.
  final bool overlay;

  /// Notification access is granted to this app.
  final bool notifications;

  /// The owner's switches.
  final bool replies;
  final bool bubble;
}

/// THE ASSISTANT OVER OTHER APPS (2026-10-19): the bridge to the native
/// notification listener, pop-ups and floating mic (Overlay.kt). The native
/// side runs with the app closed, so it keeps its own encrypted copy of the
/// session, handed over at every sign-in and cleared at sign-out.
class OverlayBridge {
  OverlayBridge._();
  static const _ch = MethodChannel('hari/overlay');
  static bool _hooked = false;

  /// What a tap on the floating mic does (set by the shell to the engine's
  /// bubbleTap): 'started' or 'stopped'.
  static Future<String> Function()? onBubbleTap;

  /// What the notification's Stop does first (set by the shell).
  static Future<void> Function()? onStopAll;

  /// Once at startup, beside the other sign-in hooks.
  static void install() {
    if (_hooked) return;
    _hooked = true;
    // The floating mic, tapped over another app: the running app talks
    // right there, without coming to the front (Overlay.kt talk()).
    _ch.setMethodCallHandler((call) async {
      // The notification's Stop: end any conversation before the app closes.
      if (call.method == 'stopAll') {
        await onStopAll?.call();
        return true;
      }
      if (call.method == 'bubbleTap') {
        final tap = onBubbleTap;
        if (tap == null) return 'unavailable';
        return tap();
      }
      return null;
    });
    AuthService.instance.onSignIn(syncAuth);
    AuthService.instance.onSignOut(() => _call('setAuth', {'token': '', 'baseUrl': ''}));
  }

  /// The current session (a renewed token included) for the listener.
  static Future<void> syncAuth() async {
    final t = ApiService.sessionToken;
    if (t == null || t.isEmpty) return;
    await _call('setAuth', {'token': t, 'baseUrl': ApiService.baseUrl});
  }

  static Future<OverlayStatus> status() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('status');
      if (m == null) return const OverlayStatus();
      return OverlayStatus(
        overlay: m['overlay'] == true,
        notifications: m['notifications'] == true,
        replies: m['replies'] == true,
        bubble: m['bubble'] == true,
      );
    } catch (e) {
      AppLog.add('overlay', 'status failed: $e');
      return const OverlayStatus();
    }
  }

  static Future<void> openOverlaySettings() => _call('openOverlaySettings');
  static Future<void> openNotificationAccess() => _call('openNotificationAccess');
  static Future<void> setReplies(bool on) async {
    if (on) await syncAuth();
    await _call('setReplies', {'on': on});
  }

  static Future<void> setBubble(bool on) => _call('setBubble', {'on': on});

  /// The bubble conversation is over: the native side lets go of the
  /// microphone service and the bubble rests.
  static Future<void> bubbleTalkEnded() => _call('bubbleTalkEnded');

  /// The bubble breathes faster while a conversation from it is live.
  static Future<void> setBubbleActive(bool active) => _call('bubbleActive', {'on': active});

  /// Did the floating mic open the app? Answered once.
  static Future<bool> takeTalk() async {
    try {
      return await _ch.invokeMethod<bool>('takeTalk') == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _ch.invokeMethod<Object?>(method, args);
    } catch (e) {
      AppLog.add('overlay', '$method failed: $e');
    }
  }
}
