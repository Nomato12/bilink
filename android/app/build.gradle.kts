plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.bilink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // Updated NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // إضافة خيارات لتجاهل التحذيرات
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bilink"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Configuración correcta de manifestPlaceholders en Kotlin DSL
        manifestPlaceholders["MAPS_API_KEY"] = "AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // تحديث خيارات لمعالجة تحذيرات الـ API المتهالك
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_11.toString()
            // إضافة خيارات لتجاهل التحذيرات في كود Kotlin
            freeCompilerArgs = listOf("-Xsuppress-warnings")
        }
    }
    
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:none", "-Xlint:-deprecation", "-Xlint:-unchecked"))
        // أو لرؤية تفاصيل التحذيرات بدلا من تجاهلها، استخدم:
        // options.compilerArgs.add("-Xlint:deprecation")
    }
    
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    // Add the Firebase BoM (Bill of Materials)
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))
    
    // إضافة مكتبة desugar لدعم ميزات Java 8 على الإصدارات القديمة من Android
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.1.5")
    
    // Add other dependencies your app might need
    implementation("com.google.firebase:firebase-analytics-ktx")
}

flutter {
    source = "../.."
}
