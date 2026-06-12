import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ── Load signing config ───────────────────────────────────────────────────────
// Local dev: reads from android/key.properties
// CI (Codemagic): reads from environment variables
val keystorePropertiesFile = rootProject.file("key.properties")

val storeFilePath: String
val storePass: String
val keyPass: String

if (keystorePropertiesFile.exists()) {
    val props = Properties()
    props.load(FileInputStream(keystorePropertiesFile))
    storeFilePath = props["storeFile"] as String
    storePass     = props["storePassword"] as String
    keyPass       = props["keyPassword"] as String
} else {
    storeFilePath = System.getenv("CM_KEYSTORE_PATH") ?: ""
    storePass     = System.getenv("KEYSTORE_PASSWORD") ?: ""
    keyPass       = System.getenv("KEY_PASSWORD") ?: ""
}

android {
    namespace  = "com.cssimplified.cs_simplified"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility            = JavaVersion.VERSION_17
        targetCompatibility            = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            storeFile     = file(storeFilePath)
            storePassword = storePass
            keyPassword   = keyPass
            keyAlias      = "cs_simplified"
        }
    }

    defaultConfig {
        applicationId = "com.cssimplified.cs_simplified"
        minSdk        = 21
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig     = signingConfigs.getByName("release")
            isMinifyEnabled   = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}