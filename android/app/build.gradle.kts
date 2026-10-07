import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --dart-define values reach Gradle base64-encoded in "dart-defines". The
// Kakao native app key (KAKAO_NATIVE_APP_KEY) is never stored in the
// repository; the manifest's Kakao login redirect scheme is "kakao<key>".
// Without a key the scheme gets a placeholder and online features stay off.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?).orEmpty()
        .split(",")
        .filter { it.isNotEmpty() }
        .map { String(Base64.getDecoder().decode(it)).split("=", limit = 2) }
        .associate { it[0] to it.getOrElse(1) { "" } }
val kakaoNativeAppKey = dartDefines["KAKAO_NATIVE_APP_KEY"].orEmpty()

android {
    namespace = "com.todaybungeoppang.todays_bungeoppang"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.todaybungeoppang.todays_bungeoppang"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["kakaoNativeAppKey"] =
            kakaoNativeAppKey.ifEmpty { "-not-configured" }
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
