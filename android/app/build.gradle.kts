plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pl.net.ultratech.ut_abonent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "pl.net.ultratech.ut_abonent"
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

    // Klucz podpisu: android/key.properties (NIE wrzucać do repozytorium), opis w README.md.
    val kp = java.util.Properties()
    val kpPlik = rootProject.file("key.properties")
    if (kpPlik.exists()) kp.load(java.io.FileInputStream(kpPlik))
    signingConfigs {
        if (kpPlik.exists()) {
            create("release") {
                keyAlias = kp["keyAlias"] as String
                keyPassword = kp["keyPassword"] as String
                storeFile = file(kp["storeFile"] as String)
                storePassword = kp["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            // Bez key.properties podpisuje kluczem testowym (tylko do prób, nie do dystrybucji).
            signingConfig = if (kpPlik.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
    // wymagane przez ota_update (auto-aktualizacja)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
