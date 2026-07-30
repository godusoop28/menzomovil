allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// agora_rtc_engine (y potencialmente otros plugins) declaran un compileSdk propio más viejo
// (31) que el que ahora exigen sus propias dependencias transitivas de androidx — Gradle lo
// rechaza en el chequeo de metadata del AAR antes de compilar nada. Forzamos compileSdk/
// targetSdk a la versión de la app en todos los módulos Android de plugins, sin tocar el
// código de cada paquete (que vive en pub cache, no en este repo).
subprojects {
    if (project.name == "app") return@subprojects
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                if (androidExtension.compileSdkVersion?.let { it != "android-36" } != false) {
                    androidExtension.compileSdkVersion("android-36")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
