plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.adhkari.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // --- التعديل هنا: تفعيل الـ Desugaring المطلوب للمكتبة ---
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
    }

    defaultConfig {
        applicationId = "com.adhkari.app"
        // Android 10 (API 29) هو الحد الأدنى عشان حفظ التلاوات في مكتبة
        // الموسيقى بتاعة الجهاز يشتغل من غير أي صلاحية تخزين — الكتابة في
        // MediaStore بمسار RELATIVE_PATH مضافة في 29 بالظبط. وكمان بتغطي
        // شرط التنبيهات المجدولة.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }

    }
}

flutter {
    source = "../.."
}

// --- إضافة بلوك الـ dependencies في آخر الملف لتعريف المكتبة المطلوبة ---
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
