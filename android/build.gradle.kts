buildscript {
    // Definisikan kotlin_version sebagai variabel langsung
    val kotlin_version = "1.7.10"
    
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:7.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Gunakan pendekatan Kotlin DSL untuk build directory
rootProject.layout.buildDirectory.set(file("../build"))
subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.asFile.get()}/${project.name}"))
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}