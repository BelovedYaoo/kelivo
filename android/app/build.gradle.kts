import java.io.IOException
import java.nio.file.Files
import java.nio.file.LinkOption
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystorePropertiesPath = keystorePropertiesFile.toPath()
val keystoreProperties =
    if (
        Files.isRegularFile(
            keystorePropertiesPath,
            LinkOption.NOFOLLOW_LINKS,
        ) &&
        Files.isReadable(keystorePropertiesPath)
    ) {
        // 签名材料只影响 Release；解析错误由执行期门禁转成稳定诊断，不能连带阻断 Debug。
        try {
            Properties().apply {
                keystorePropertiesFile.inputStream().use(::load)
            }
        } catch (_: IOException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        } catch (_: SecurityException) {
            null
        }
    } else {
        null
    }

fun Properties.requireReleaseSigningValue(name: String): String =
    getProperty(name)?.trim()?.takeIf(String::isNotEmpty)
        ?: throw GradleException("Android Release signing configuration is missing field: $name")

android {
    namespace = "com.psyche.kelivo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.psyche.kelivo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keystoreProperties?.getProperty("storeFile")?.trim()?.takeIf(String::isNotEmpty)?.let {
                storeFile = file(it)
            }
            storePassword = keystoreProperties?.getProperty("storePassword")
            keyAlias = keystoreProperties?.getProperty("keyAlias")
            keyPassword = keystoreProperties?.getProperty("keyPassword")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

val validateKelivoReleaseSigning =
    tasks.register("validateKelivoReleaseSigning") {
        group = "verification"
        description = "校验 Android Release 本地签名配置"

        doLast {
            if (!Files.exists(keystorePropertiesPath, LinkOption.NOFOLLOW_LINKS)) {
                throw GradleException("Android Release signing configuration is missing: android/key.properties")
            }
            if (
                !Files.isRegularFile(
                    keystorePropertiesPath,
                    LinkOption.NOFOLLOW_LINKS,
                ) ||
                !Files.isReadable(keystorePropertiesPath)
            ) {
                throw GradleException(
                    "Android Release signing configuration must be a readable regular file: " +
                        "android/key.properties",
                )
            }

            val properties =
                keystoreProperties
                    ?: throw GradleException(
                        "Android Release signing configuration cannot be read or parsed: " +
                            "android/key.properties",
                    )
            val storeFileValue = properties.requireReleaseSigningValue("storeFile")
            properties.requireReleaseSigningValue("storePassword")
            properties.requireReleaseSigningValue("keyAlias")
            properties.requireReleaseSigningValue("keyPassword")

            val configuredStoreFile = file(storeFileValue).toPath()
            if (
                !Files.isRegularFile(
                    configuredStoreFile,
                    LinkOption.NOFOLLOW_LINKS,
                ) ||
                !Files.isReadable(configuredStoreFile)
            ) {
                throw GradleException("Android Release keystore must be a readable regular file")
            }
        }
    }

// Release 必须先经过独立门禁，避免 Gradle 把未签名产物误报为可发布结果。
tasks
    .matching {
        it.name == "preReleaseBuild" || it.name == "validateSigningRelease"
    }.configureEach {
        dependsOn(validateKelivoReleaseSigning)
    }

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for core library desugaring (used by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
