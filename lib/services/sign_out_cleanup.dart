import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_service.dart';
import '../features/pricecompare/price_service.dart';
import 'assistant_identity.dart';
import 'avatar_message_service.dart';

/// WHAT SIGNING OUT LEAVES BEHIND (launch readiness, 2026-11-25).
///
/// Two things went wrong when an account left this phone:
///
/// 1. The next account inherited the previous one's local state. The
///    "assistant already named" mark and the cached name were never
///    cleared, so a new account skipped the naming step and met the last
///    person's assistant; recent price searches, price watches and the
///    calendar month kept in memory were shown to whoever signed in next.
///
/// 2. When the SERVER ended the session (a password change, "sign out
///    everywhere", a paused account) the sign-in screen appeared at the
///    root, underneath whatever screen was open: every request on that
///    screen failed and nothing explained why. The user's own Sign Out
///    already returned to the root; an ended session now does too.
///
/// Registered once in main() as an AuthService sign-out hook, so it runs
/// for every way out. What belongs to the PHONE rather than the account
/// stays: permissions, the welcome mark, theme and the app lock.
class SignOutCleanup {
  SignOutCleanup._();

  /// SharedPreferences keys that belong to the account that just left.
  static const accountKeys = <String>[
    'assistant_named_v1', // AssistantSetupGate: the naming step is done
    'assistant_display_name', // AssistantIdentity: the cached name
    'price_compare.recent.v1', // PriceService
    'price_compare.watches.v1',
    'cal_extras_v1', // CalendarService: saved festival and holiday windows
  ];

  static Future<void> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in accountKeys) {
        await prefs.remove(k);
      }
    } catch (_) {
      // A store that cannot be read has nothing to hand to the next account.
    }
    AssistantIdentity.notifier.value = AssistantIdentity.fallback;
    PriceService.instance.reset();
    CalendarService.reset();
    // Back to the root, where AuthGate shows the sign-in screen.
    try {
      AvatarMessageService.navigatorKey.currentState?.popUntil((r) => r.isFirst);
    } catch (_) {
      // No navigator yet (signed out before the first frame).
    }
  }
}
