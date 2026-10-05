plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val playGamesAppId = Regex("""name="app_id"[^>]*>\s*([0-9]*)\s*<""")
    .find(file("src/main/res/values/games-ids.xml").readText())
    ?.groupValues?.get(1).orEmpty()
val playGamesEnabled = playGamesAppId.isNotEmpty()

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
    }

    sourceSets.getByName("main") {
        java.srcDir(if (playGamesEnabled) "src/playGames/kotlin" else "src/noPlayGames/kotlin")
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

// Play Games Services v2 (v1 can no longer be used by new titles) is linked
// only once games-ids.xml holds the numeric Play Console app ID. Until then
// the build carries no Play Games SDK and online ranking stays hidden.
dependencies {
    if (playGamesEnabled) {
        implementation("com.google.android.gms:play-services-games-v2:22.1.0")
    }
}
