plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Versiyanı birbaşa pubspec.yaml-dan oxu (gradlew-i birbaşa çağıranda
// flutter.versionCode local.properties-dən gəlir və köhnəlir — bax build_apk.bat).
// pubspec `version: X.Y.Z+N` → versionName=X.Y.Z, versionCode=N.
val pubspecVersion: Pair<Int, String> by lazy {
    val line = file("../../pubspec.yaml").readLines()
        .firstOrNull { it.trimStart().startsWith("version:") }
        ?.substringAfter("version:")?.trim()
    if (line != null && line.contains("+")) {
        line.substringAfter("+").toInt() to line.substringBefore("+")
    } else {
        (flutter.versionCode to flutter.versionName)
    }
}

android {
    namespace = "com.dildostu.dildostu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications java.time API-lərini işlətdiyi üçün
        // köhnə Android səviyyələrində core library desugaring lazımdır.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dildostu.dildostu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = pubspecVersion.first
        versionName = pubspecVersion.second
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
}
