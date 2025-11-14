rootProject.name = "campusnet_client"

// Include the app module
include(":app")

// Configure plugin management
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Configure dependency resolution
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

// Include Flutter plugins from .flutter-plugins
val flutterProjectRoot = rootProject.projectDir.parentFile
val pluginsFile = File(flutterProjectRoot, ".flutter-plugins")
if (pluginsFile.exists()) {
    pluginsFile.reader().use { reader ->
        reader.readLines().forEach { line ->
            val parts = line.split(":")
            if (parts.size == 2) {
                includeBuild("${parts[0]}:${parts[1]}")
            }
        }
    }
}
