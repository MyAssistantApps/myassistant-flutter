import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Crash reports with symbols (services/telemetry.dart, 2026-10-01). The
    // Performance Gradle plugin only instruments native HTTP and does not
    // apply under AGP 9; the SDK's own traces need no plugin.
    id("com.google.firebase.crashlytics")
}

// Release signing: reads android/key.properties (git-ignored). If the file
// is missing, release builds fall back to debug signing so `flutter run
// --release` keeps working on machines without the keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// True only when Flutter builds for x86 alone (`flutter run` on an emulator).
// Release and phone builds always list an arm target, so they keep the
// arm-only packaging below.
val emulatorOnlyBuild: Boolean = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.let { platforms -> platforms.isNotEmpty() && platforms.all { it.contains("x64") || it.contains("x86") } }
    ?: false

// GOOGLE PLAY BUILD (product audit 2026-11-21): `-Pstore=play`
// (flutter build appbundle --dart-define=STORE=play
//  --android-project-arg=store=play) merges src/playRelease/AndroidManifest.xml
// into the release, removing the permissions Play refuses. The default
// (sideloaded) build is unchanged.
val playStoreBuild: Boolean = (project.findProperty("store") as String?) == "play"

// A Play upload must carry the real key: packaging a store=play release
// without android/key.properties fails instead of falling back to the
// debug keystore.
gradle.taskGraph.whenReady {
    val packaging = allTasks.any { it.name == "bundleRelease" || it.name == "assembleRelease" }
    if (playStoreBuild && packaging && !rootProject.file("key.properties").exists()) {
        throw GradleException("store=play needs android/key.properties (the upload key).")
    }
}

android {
    namespace = "com.myassistant.myassistant"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

     compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // The release lint-vital pass alone needs ~1.5 GB of JVM heap and
    // OOM-killed builds on this 5 GB machine; it only re-checks what the
    // analyzer already covers.
    lint {
        checkReleaseBuilds = false
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.myassistant.myassistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8 (API 26): the documented minimum for Firebase Phone
        // Number Verification (2026-09-29). Flutter's default is 24.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Real phones only: x86/x86_64 are emulator ABIs, and their plugin
        // native libs are dead weight in every shared APK.
        // Except an emulator-only `flutter run` (it passes just android-x64
        // or android-x86): that build needs the x86 libs to start at all.
        if (!emulatorOnlyBuild) {
            ndk {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a")
            }
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    sourceSets {
        getByName("release") {
            if (playStoreBuild) manifest.srcFile("src/playRelease/AndroidManifest.xml")
        }
        // THE SELF-UPDATER IS NOT IN A PLAY BUILD (2026-11-25). Its native
        // half — the "hari/updater" channel, ApkInstaller, QuietInstallJob —
        // lives in src/sideload/kotlin and is compiled only into the
        // sideloaded build. A Play build compiles src/play/kotlin instead:
        // an UpdaterChannel of the same name with nothing behind it.
        // tool/check_play_build.sh proves the result on CI.
        getByName("main") {
            kotlin.srcDir(if (playStoreBuild) "src/play/kotlin" else "src/sideload/kotlin")
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
        // `flutter run` on the owner's phone (2026-09-30): the debug build
        // is signed like the release, so it installs OVER the published app
        // (keeping his sign-in and data) instead of being refused, which
        // makes flutter run uninstall the app first.
        debug {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    // The abiFilters above are overridden by the Flutter gradle plugin,
    // so plugin .so files still shipped for the emulator-only x86_64
    // ABI. Packaging excludes
    // are applied last and actually stick.
    packaging {
        jniLibs {
            if (!emulatorOnlyBuild) {
                excludes.add("lib/x86_64/**")
                excludes.add("lib/x86/**")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // PHONE NUMBER VERIFICATION (owner, 2026-09-29): the SIM's number, read
    // from the carrier by Google after Android's consent sheet — it replaced
    // the SMS code (firebase_auth). PhoneNumberVerificationBridge.
    implementation("com.google.firebase:firebase-pnv:16.1.1")

    // THE ASSISTANT OVER OTHER APPS (2026-10-19): the session copy the
    // notification listener uses is kept encrypted (NotifyPrefs).
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
