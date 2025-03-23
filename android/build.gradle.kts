plugins {
    id("com.android.application") apply false
    kotlin("android") version "1.8.22" apply false // Usa solo esta línea para el plugin de Kotlin
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}