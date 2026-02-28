import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val normalizedKeystoreProps: Map<String, String> = keystoreProperties.entries
    .associate { entry ->
        val key = entry.key.toString()
            .trim()
            .removePrefix("\uFEFF")
            .removePrefix("ï»¿")
        val value = entry.value.toString().trim()
        key to value
    }

fun readKeystoreProp(name: String): String? {
    return normalizedKeystoreProps[name]?.takeIf { it.isNotEmpty() }
}

android {
    namespace = "com.cafecircuit.vetassist"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cafecircuit.vetassist"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = requireNotNull(readKeystoreProp("keyAlias")) {
                    "Missing keyAlias in android/key.properties"
                }
                keyPassword = requireNotNull(readKeystoreProp("keyPassword")) {
                    "Missing keyPassword in android/key.properties"
                }
                storeFile = file(requireNotNull(readKeystoreProp("storeFile")) {
                    "Missing storeFile in android/key.properties"
                })
                storePassword = requireNotNull(readKeystoreProp("storePassword")) {
                    "Missing storePassword in android/key.properties"
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug only if key.properties is missing.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
