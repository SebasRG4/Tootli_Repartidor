import java.util.Properties
import java.io.FileInputStream

/**
 * Clave de Maps: NO en el manifest versionado. Orden de resolución:
 * 1) variable de entorno GOOGLE_MAPS_API_KEY o MAPS_API_KEY
 * 2) android/secrets.properties (gitignored)
 * 3) maps.api.key en android/local.properties (gitignored, ya usado por Flutter)
 */
fun loadGoogleMapsApiKey(rootDir: java.io.File): String {
    fun env(name: String): String? =
        System.getenv(name)?.trim()?.takeIf { it.isNotEmpty() }

    env("GOOGLE_MAPS_API_KEY")?.let { return it }
    env("MAPS_API_KEY")?.let { return it }

    val secretsFile = rootDir.resolve("secrets.properties")
    if (secretsFile.exists()) {
        val p = Properties()
        secretsFile.inputStream().use { p.load(it) }
        p.getProperty("GOOGLE_MAPS_API_KEY")?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
        p.getProperty("MAPS_API_KEY")?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
    }

    val localFile = rootDir.resolve("local.properties")
    if (localFile.exists()) {
        val p = Properties()
        localFile.inputStream().use { p.load(it) }
        p.getProperty("maps.api.key")?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
    }

    return ""
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val googleMapsApiKey: String = loadGoogleMapsApiKey(rootProject.projectDir)
if (googleMapsApiKey.isEmpty()) {
    logger.lifecycle(
        "[Tootli] GOOGLE_MAPS_API_KEY vacío: copia android/secrets.properties.example → android/secrets.properties " +
            "o define maps.api.key en android/local.properties. Sin clave el mapa no cargará.",
    )
}

android {
    namespace = "com.Tootli.repartidor"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.Tootli.repartidor"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug") // or "release" if you have real keystore
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.firebase:firebase-messaging:23.4.1")
}
