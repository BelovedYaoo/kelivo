pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

// 国内网络下 Google/Maven Central 官方源不可达；全部依赖走镜像。
// 动态版本解析会查询所有声明仓库，官方源会导致每次构建超时，故移除。
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        // Flutter 引擎 AAR 仓库：镜像环境变量自动指向国内镜像，CI 默认官方源。
        maven(
            (System.getenv("FLUTTER_STORAGE_BASE_URL")
                    ?: "https://storage.googleapis.com") +
                "/download.flutter.io",
        )
        // image_cropper 等插件依赖 JitPack 发布的库。
        maven("https://jitpack.io")
    }
}

include(":app")
