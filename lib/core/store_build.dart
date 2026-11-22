/// WHICH STORE THIS BUILD IS FOR (product audit 2026-11-21).
///
/// The sideloaded build (the default) keeps every capability. A Google Play
/// build is made with
///
///   flutter build appbundle --release \
///     --dart-define=STORE=play --android-project-arg=store=play
///
/// The Gradle side (android/app/build.gradle.kts) then merges
/// src/playRelease/AndroidManifest.xml, which removes the permissions Play
/// refuses for this kind of app (SEND_SMS, READ_CALL_LOG, self-update,
/// package deletion, broad media). The Dart side, here, swaps the features
/// that needed them for their Play-safe versions: a text opens the phone's
/// SMS app with the message filled in, instead of sending silently.
const bool kPlayStoreBuild = String.fromEnvironment('STORE') == 'play';
