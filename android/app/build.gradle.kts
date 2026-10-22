import java.io.File
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing properties from key.properties if present (populated by CI).
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}

val requestedTasks = gradle.startParameter.taskNames.map { it.lowercase() }
val requiresReleaseSigning = requestedTasks.any {
    "release" in it || "bundle" in it || "publish" in it
}

// The owner's development preview (`-PcodewalkPreview=true`) installs beside
// the production app under its own ID and label; without the property the
// production identity is untouched, and a release never carries the preview.
val codewalkPreview = providers.gradleProperty("codewalkPreview").orNull == "true"
if (codewalkPreview && requiresReleaseSigning) {
    throw GradleException("The development preview identity cannot be used for a release build.")
}

val releaseStoreFile = resolveSigningFile(
    keyProperties.getProperty("storeFile"),
)

fun requireReleaseSigningConfig() {
    if (!keyPropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties. Refusing to build a release APK with the debug key.",
        )
    }
    if (releaseStoreFile == null || !releaseStoreFile.exists()) {
        throw GradleException(
            "Release keystore not found for android release signing. Check storeFile in android/key.properties.",
        )
    }
}

fun resolveSigningFile(rawValue: String?): File? {
    if (rawValue.isNullOrBlank()) return null

    val trimmed = rawValue.trim()
    val userHome = System.getProperty("user.home")
    val currentHomeDir = File(userHome)

    return when {
        trimmed.startsWith("~/") -> File(userHome, trimmed.removePrefix("~/"))
        File(trimmed).isAbsolute -> {
            val absoluteFile = File(trimmed)
            if (absoluteFile.exists()) {
                absoluteFile
            } else {
                val homeParent = currentHomeDir.parentFile
                val homePrefix = homeParent?.absolutePath?.let { "$it${File.separator}" }
                if (homePrefix != null && trimmed.startsWith(homePrefix)) {
                    val pathAfterNamedHome = trimmed.removePrefix(homePrefix)
                    val separatorIndex = pathAfterNamedHome.indexOf(File.separatorChar)
                    if (separatorIndex >= 0) {
                        File(currentHomeDir, pathAfterNamedHome.substring(separatorIndex + 1))
                    } else {
                        absoluteFile
                    }
                } else {
                    absoluteFile
                }
            }
        }
        else -> {
            val homeRelative = File(userHome, trimmed)
            if (homeRelative.exists()) homeRelative else rootProject.file(trimmed)
        }
    }
}

android {
    namespace = "com.verseles.codewalk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.verseles.codewalk"
        if (codewalkPreview) applicationIdSuffix = ".v2preview"
        manifestPlaceholders["appLabel"] = if (codewalkPreview) "CodeWalk v2 Preview" else "CodeWalk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = releaseStoreFile
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (requiresReleaseSigning) {
                requireReleaseSigningConfig()
            }
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.browser:browser:1.9.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    androidTestImplementation("androidx.test:core-ktx:1.6.1")
    androidTestImplementation("androidx.test.ext:junit-ktx:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
