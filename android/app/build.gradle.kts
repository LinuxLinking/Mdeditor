plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mdeditor.app"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mdeditor.app"
        minSdk = 28
        targetSdk = 34
        // 版本号唯一来源是 pubspec.yaml 的 version（X.Y.Z+N → versionName/versionCode），
        // 由 flutter-gradle-plugin 构建时注入，此处不硬编码，避免双源漂移。
    }

    // release 签名：注入 KEYSTORE_FILE / KEYSTORE_PASSWORD / KEY_ALIAS 环境变量时使用
    // 固定发布密钥（每次构建签名一致、可覆盖安装）；未注入（本地构建 / CI 未配 secrets）
    // 时回退 debug 签名。配置正式密钥的步骤见仓库根目录 AGENTS.md 施工单A。
    signingConfigs {
        create("release") {
            System.getenv("KEYSTORE_FILE")?.let { ksPath ->
                storeFile = file(ksPath)
                storeType = "PKCS12"
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (System.getenv("KEYSTORE_FILE") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation(project(":render-core"))

    // dexmaker 动态代理：用于在运行时创建 Android 包私有构造函数的回调子类
    // （PrintDocumentAdapter.LayoutResultCallback/WriteResultCallback 无法直接 new）。
    // dex 引擎（dalvik-dx）由其传递依赖提供。
    implementation("com.linkedin.dexmaker:dexmaker:2.28.3")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
