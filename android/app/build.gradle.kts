import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ── Load signing config ───────────────────────────────────────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")

val storeFilePath: String = if (keystorePropertiesFile.exists()) {
    val props = Properties().apply { load(FileInputStream(keystorePropertiesFile)) }
    props["storeFile"] as String
} else {
    System.getenv("CM_KEYSTORE_PATH") ?: ""
}

val storePass: String = if (keystorePropertiesFile.exists()) {
    val props = Properties().apply { load(FileInputStream(keystorePropertiesFile)) }
    props["storePassword"] as String
} else {
    System.getenv("KEYSTORE_PASSWORD") ?: ""
}

val keyPass: String = if (keystorePropertiesFile.exists()) {
    val props = Properties().apply { load(FileInputStream(keystorePropertiesFile)) }
    props["keyPassword"] as String
} else {
    System.getenv("KEY_PASSWORD") ?: ""
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
        jvmTarget = "17"
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
