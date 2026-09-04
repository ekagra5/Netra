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

// Some Flutter plugins (tflite_flutter 0.11.0 among them) ship an Android
// module whose Java compile task still targets 1.8 while its Kotlin
// compile task infers the JVM target from the host JDK (21 here, from
// Android Studio's bundled JBR) - a mismatch newer Kotlin Gradle plugin
// versions reject outright ("Inconsistent JVM Target Compatibility").
// Forcing every subproject to the same target the app module already
// uses (17) fixes this without needing to patch the plugin itself.
// Registered BEFORE evaluationDependsOn(":app") below: that call forces
// early evaluation of some subprojects, and afterEvaluate() throws if
// called on a project that's already evaluated by the time this runs.
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
