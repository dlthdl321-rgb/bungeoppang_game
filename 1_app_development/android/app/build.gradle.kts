import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
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

// 26번 5단계: Firebase Analytics reads the app ID from the string resource
// google_app_id that google-services.json would make. This app has no such
// file (online_setup.md 1-4), so the same four --dart-define values the Dart
// side uses (firebase_online_backend.dart) become those resources. Firebase
// then starts the default app natively with the same options, and Dart's
// Firebase.initializeApp(options:) reuses it. Builds without the keys get no
// resources and Analytics stays off.
val firebaseResources: Map<String, String> = mapOf(
    "google_app_id" to dartDefines["FIREBASE_APP_ID"].orEmpty(),
    "google_api_key" to dartDefines["FIREBASE_API_KEY"].orEmpty(),
    "gcm_defaultSenderId" to dartDefines["FIREBASE_SENDER_ID"].orEmpty(),
    "project_id" to dartDefines["FIREBASE_PROJECT_ID"].orEmpty(),
).takeIf { values -> values.values.all { it.isNotEmpty() } }.orEmpty()

// Release builds are signed only with the Play upload key described in
// android/key.properties (never committed; see android/.gitignore and
// 2_development_plans_and_checklists/.../2.1.3_legacy_code_policies_and_online_setup/
// release_signing.md). Without it a release build
// stops with an error instead of silently falling back to the debug key, so a
// debug-signed AAB can never be uploaded by mistake.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
val uploadKeyProblem: String? = when {
    !keyPropertiesFile.exists() ->
        "android/key.properties not found (key.properties 파일이 없습니다)"
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .any { keyProperties.getProperty(it).isNullOrBlank() } ->
        "android/key.properties needs storeFile, storePassword, keyAlias and keyPassword (네 항목이 모두 있어야 합니다)"
    !file(keyProperties.getProperty("storeFile")).exists() ->
        "keystore not found: storeFile=${keyProperties.getProperty("storeFile")} (키 파일이 없습니다; use forward slashes, e.g. C:/keys/bungeoppang-upload.jks)"
    else -> null
}

android {
    namespace = "com.todaybungeoppang.app"
    compileSdk = flutter.compileSdkVersion
    // resValue for the Firebase string resources (firebaseResources above).
    buildFeatures { resValues = true }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (26번 5-1단계 손님 알림) needs core library
        // desugaring for its scheduled notifications on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Fixed for good once the first build is uploaded to Google Play.
        applicationId = "com.todaybungeoppang.app"
        // Flutter 3.47.5 defaults: minSdk 24, targetSdk 36, compileSdk 36.
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
        firebaseResources.forEach { (name, value) -> resValue("string", name, value) }
    }

    signingConfigs {
        if (uploadKeyProblem == null) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Device audits never replace a player's installed game or database.
            if (dartDefines["PRODUCTION_AUDIT"] == "true") {
                applicationIdSuffix = ".step02audit"
            }
        }
        release {
            // Upload key only. No debug-key fallback (see uploadKeyProblem).
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Debug/profile builds do not need the upload key; any task of the release
// variant (flutter build apk/appbundle --release, flutter run --release) does.
gradle.taskGraph.whenReady {
    val problem = uploadKeyProblem ?: return@whenReady
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        throw GradleException(
            "Release build stopped (release 빌드 중단): $problem. " +
                "Release builds are never signed with the debug key (debug 키로 대신 서명하지 않습니다). " +
                "See (만드는 법) 2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/" +
                "2.1.3_legacy_code_policies_and_online_setup/release_signing.md"
        )
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
