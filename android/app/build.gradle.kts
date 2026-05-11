
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
// Look for key.properties in common locations: android/, repo root, or android/key.properties
val androidRoot = rootProject.projectDir
val repoRoot = androidRoot.parentFile
val keystoreCandidates = listOf(
    File(androidRoot, "key.properties"),
    File(androidRoot, "../key.properties"),
    File(repoRoot, "key.properties"),
    File(androidRoot, "android/key.properties")
)
val keystorePropertiesFile = keystoreCandidates.firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}



plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.metamind.gospelquiz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.metamind.gospelquiz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"].toString()
            keyPassword = keystoreProperties["keyPassword"].toString()
            storePassword = keystoreProperties["storePassword"].toString()
            
            val stFile = keystoreProperties["storeFile"] as String?
            if (stFile != null) {
                val candidate = file(stFile)
                if (candidate.exists()) {
                    storeFile = candidate
                } else {
                    val repoCandidate = File(rootProject.projectDir.parentFile, stFile)
                    if (repoCandidate.exists()) {
                        storeFile = repoCandidate
                    } else {
                        // fallback: try path relative to android root
                        val androidRootCandidate = File(rootProject.projectDir, stFile)
                        if (androidRootCandidate.exists()) {
                            storeFile = androidRootCandidate
                        }
                    }
                }
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
