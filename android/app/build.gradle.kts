import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun releaseKeystoreIsConfigured(): Boolean {
    if (!keystorePropertiesFile.exists()) return false
    val path = keystoreProperties.getProperty("storeFile") ?: return false
    val store = file(path)
    if (!store.isFile) return false
    val alias = keystoreProperties.getProperty("keyAlias")
    val storePwd = keystoreProperties.getProperty("storePassword")
    val keyPwd = keystoreProperties.getProperty("keyPassword")
    return !alias.isNullOrBlank() && !storePwd.isNullOrBlank() && !keyPwd.isNullOrBlank()
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Firebase Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.zeynabijaz.five_s_digital_assessment"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (releaseKeystoreIsConfigured()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.zeynabijaz.five_s_digital_assessment"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Avoid NPE in signReleaseBundle when storeFile is missing or invalid.
            signingConfig = if (releaseKeystoreIsConfigured()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            // ProGuard rules (not needed when minify is disabled, but kept for future use)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Firebase BoM (controls versions automatically)
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))

    // Analytics
    implementation("com.google.firebase:firebase-analytics")

    // Authentication
    implementation("com.google.firebase:firebase-auth")

    // Firestore
    implementation("com.google.firebase:firebase-firestore")

    // App Check
    implementation("com.google.firebase:firebase-appcheck")
    implementation("com.google.firebase:firebase-appcheck-debug")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
}

flutter {
    source = "../.."
}