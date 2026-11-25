import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// WHAT A BROKEN WIDGET LOOKS LIKE IN A RELEASE BUILD (2026-11-25).
///
/// When one widget throws while building, Flutter's release default is a
/// blank grey box where it stood: no words, nothing to do. The error is
/// already reported (services/telemetry.dart); this only replaces the grey
/// box with one calm sentence. Debug builds keep Flutter's red error text.
void installBuildErrorNote({bool release = kReleaseMode}) {
  if (!release) return;
  ErrorWidget.builder = (FlutterErrorDetails details) => const BuildErrorNote();
}

class BuildErrorNote extends StatelessWidget {
  const BuildErrorNote({super.key});

  static const message =
      'This part of the screen could not be shown. Please go back and open it again.';

  @override
  Widget build(BuildContext context) => const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A8F9C),
                fontSize: 13,
                height: 1.4,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );
}
