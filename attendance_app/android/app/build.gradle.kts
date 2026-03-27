plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.attendance_app"
    
    // CHANGED: Must be 36 to satisfy plugin requirements
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.attendance_app"
        
        minSdk = 26 
        // Keep targetSdk at 35 if you aren't ready for Android 16 behaviors yet,
        // but compileSdk ABOVE must stay at 36.
        targetSdk = 35 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/com.android.tools/proguard/suggested-proguard.rules"
            excludes += "META-INF/proguard/androidx-annotations.pro"
            merges += "META-INF/LICENSE*"
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    api("androidx.concurrent:concurrent-futures:1.2.0")
    api("androidx.concurrent:concurrent-futures-ktx:1.2.0")
    api("com.google.guava:guava:33.0.0-android")
}