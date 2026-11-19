plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// google-services.json TIDAK di-commit (repo publik). Plugin hanya diterapkan jika file
// sudah ditaruh manual, sehingga CI tetap bisa build tanpa rahasia.
// Lokasi: packages/hybrid_ai/example/android/app/google-services.json
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("google-services.json belum ada: Firebase tidak akan berjalan di app contoh.")
}

android {
    namespace = "com.lumina.hybrid_ai_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Harus sama dengan package name yang terdaftar di Firebase (google-services.json).
        applicationId = "com.lumina.app"
        // firebase-ai-ondevice (Gemini Nano) membutuhkan API level 26+.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // App contoh hanya untuk pengujian; tidak pernah dirilis.
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
    // App Check debug provider: mencetak debug token ke logcat agar bisa didaftarkan di Console.
    // Versi mengikuti dokumentasi Firebase AI Logic hybrid (Android).
    implementation("com.google.firebase:firebase-appcheck-debug:20.1.0")
}
