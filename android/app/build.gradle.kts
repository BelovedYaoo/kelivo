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

val generatedPluginRegistrant =
    layout.projectDirectory.file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
val generatedPluginFailureLog =
    Regex(
        """Log\.e\(\s*TAG\s*,\s*"Error registering plugin [^"]+"\s*,\s*e\s*\);""",
    )
val generatedPluginCatch = Regex("""catch\s*\(Exception\s+e\)""")
val staticPluginRegistrationFailure =
    "throw new IllegalStateException(\"Plugin registration failed\");"

fun hardenGeneratedPluginRegistrant() {
    val registrantPath = generatedPluginRegistrant.asFile.toPath()
    if (!Files.isRegularFile(registrantPath, LinkOption.NOFOLLOW_LINKS)) {
        throw GradleException("Flutter GeneratedPluginRegistrant.java is missing")
    }
    val generatedSource = Files.readString(registrantPath)
    val hardenedSource =
        generatedPluginFailureLog.replace(generatedSource) {
            staticPluginRegistrationFailure
        }
    if (hardenedSource != generatedSource) {
        Files.writeString(registrantPath, hardenedSource)
    }

    val verifiedSource = Files.readString(registrantPath)
    val catchCount = generatedPluginCatch.findAll(verifiedSource).count()
    val staticFailureCount =
        Regex(Regex.escape(staticPluginRegistrationFailure))
            .findAll(verifiedSource)
            .count()
    if (
        catchCount == 0 ||
        catchCount != staticFailureCount ||
        verifiedSource.contains("Log.e(")
    ) {
        throw GradleException(
            "Flutter GeneratedPluginRegistrant.java contains an unsafe failure branch",
        )
    }
}

tasks.register("hardenKelivoGeneratedPluginRegistrant") {
    group = "verification"
    description = "校验当前 Flutter Android 插件注册器的静态失败分支"
    doLast {
        hardenGeneratedPluginRegistrant()
    }
}

// 每个变体必须在 Flutter 重新生成 registrant 后、Java 编译前独立硬化。
androidComponents {
    onVariants(selector().all()) { variant ->
        val variantName =
            variant.name.replaceFirstChar { character ->
                if (character.isLowerCase()) character.titlecase() else character.toString()
            }
        val hardenVariantRegistrant =
            tasks.register("hardenKelivo${variantName}GeneratedPluginRegistrant") {
                group = "verification"
                description = "将 $variantName 插件注册失败收敛为静态失败事件"
                dependsOn("compileFlutterBuild$variantName")
                doLast {
                    hardenGeneratedPluginRegistrant()
                }
            }
        tasks
            .matching { it.name == "compile${variantName}JavaWithJavac" }
            .configureEach {
                dependsOn(hardenVariantRegistrant)
            }
    }
}
