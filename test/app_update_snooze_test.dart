// The update sheet comes back every time the app is opened (owner,
// 2026-11-01): "Later" lasts until the app is opened again, not 12 hours.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = AppUpdateService.instance;
  final t0 = DateTime(2026, 11, 1, 18);

  test('Later holds while the app stays open, and through a quick return', () async {
    await svc.snooze(206);
    expect(await svc.debugSnoozed(206), isTrue);
    svc.debugLifecycle(AppLifecycleState.paused, t0);
    svc.debugLifecycle(AppLifecycleState.resumed, t0.add(const Duration(seconds: 20)));
    expect(await svc.debugSnoozed(206), isTrue, reason: 'back from the camera: no sheet');
  });

  test('opening the app again after a minute away forgets Later', () async {
    await svc.snooze(206);
    svc.debugLifecycle(AppLifecycleState.paused, t0);
    svc.debugLifecycle(AppLifecycleState.resumed, t0.add(const Duration(minutes: 3)));
    expect(await svc.debugSnoozed(206), isFalse, reason: 'the sheet comes back');
  });
}
