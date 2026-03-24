allprojects {
    repositories {
        google()
        mavenCentral() // Fixed typo here
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

// THIS BLOCK FORCES THE FIX ACROSS ALL PLUGINS
subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.concurrent" && requested.name == "concurrent-futures") {
                useVersion("1.1.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}