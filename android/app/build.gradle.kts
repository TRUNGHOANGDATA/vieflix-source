import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Đọc thông tin khóa ký từ android/key.properties nếu có.
// Nếu chưa có (chưa tạo khóa) -> tạm ký bằng khóa debug để vẫn build/chạy được.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vieflix.app_xem_phim"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // CHỈ đóng gói thư viện cho ARM. Từ khi bật trình phát native cho Android,
    // libmpv.so chiếm phần lớn APK — riêng bản x86_64 là 34.6MB trong tổng
    // 93.4MB. x86_64 chỉ dùng cho MÁY ẢO: mọi TV box (Amlogic, Rockchip,
    // MediaTek), Chromecast, Shield, Fire TV và điện thoại Android đều là ARM.
    //
    // `ndk { abiFilters }` KHÔNG ăn ở đây vì plugin Flutter ghi đè, còn cờ
    // `--target-platform` chỉ lọc thư viện CỦA FLUTTER chứ không lọc .so đến từ
    // AAR của plugin (libmpv nằm trong đó). Nên phải loại lúc đóng gói.
    // Cần chạy trên máy ảo Android thì tạm bỏ khối này.
    packaging {
        jniLibs {
            excludes += setOf("lib/x86_64/**", "lib/x86/**")
        }
    }

    defaultConfig {
        applicationId = "com.vieflix.app_xem_phim"
        // TV cần tối thiểu Android 5.0 (API 21); webview/speech cũng cần >= 21
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // Đường dẫn khóa tính từ thư mục android/ (rootProject), khớp key.properties
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Có khóa cố định -> ký release; chưa có -> tạm ký debug.
            signingConfig = if (hasReleaseKey)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
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
