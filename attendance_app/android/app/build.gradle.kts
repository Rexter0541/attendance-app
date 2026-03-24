plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.attendance_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.attendance_app"
        
        // ML Kit Face Detection requires at least API 21. 
        // Overriding the flutter default to ensure stability.
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// THE CRITICAL FIX: 
// Using 'api' helps the camera plugin modules resolve the 
// missing CallbackToFutureAdapter class during compilation.
dependencies {
    api("androidx.concurrent:concurrent-futures:1.2.0")
    api("androidx.concurrent:concurrent-futures-ktx:1.2.0")
    api("com.google.guava:guava:33.0.0-android")
}
