// android/app/build.gradle.kts  (Flutter's current Kotlin-DSL template)
//
// 1) At the top of the file:
import java.util.Properties

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// 2) Inside android { defaultConfig { ... } }:
//    minSdk = 23   // required by recent Firebase / Maps plugins
//    manifestPlaceholders["MAPS_API_KEY"] = localProps.getProperty("MAPS_API_KEY", "")
