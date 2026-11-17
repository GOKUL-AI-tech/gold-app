allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Suppress obsolete Java 8 source/target warnings and deprecation notes
    // that come from third-party plugins (e.g. razorpay_flutter).
    // Our own app code compiles with Java 17 (see app/build.gradle.kts).
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(
            listOf("-Xlint:-options", "-Xlint:-deprecation")
        )
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
