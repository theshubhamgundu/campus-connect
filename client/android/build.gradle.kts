buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.7.10")
        classpath("com.google.gms:google-services:4.3.15")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

// Configure all projects
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(33)
                
                defaultConfig {
                    minSdk = 21
                    targetSdk = 33
                }
                
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_1_8
                    targetCompatibility = JavaVersion.VERSION_1_8
                }
                
                kotlinOptions {
                    jvmTarget = "1.8"
                }
            }
        }
    }
}
