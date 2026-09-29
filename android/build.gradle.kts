allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu")
        exclude(group = "org.tensorflow", module = "tensorflow-lite-api")
        exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu-api")
        exclude(group = "org.tensorflow", module = "tensorflow-lite-support-api")
    }
}

subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            if (project.name == "tflite_flutter") {
                val androidExt = project.extensions.findByName("android")
                if (androidExt != null) {
                    try {
                        val setCompileSdk = androidExt.javaClass.methods.find { it.name == "setCompileSdk" }
                        setCompileSdk?.invoke(androidExt, 34)
                    } catch (e: Exception) {}
                    try {
                        val setCompileSdkVersion = androidExt.javaClass.methods.find { it.name == "setCompileSdkVersion" }
                        setCompileSdkVersion?.invoke(androidExt, 34)
                    } catch (e: Exception) {}
                }
            }
            
            project.dependencies {
                add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
                add("compileOnly", "androidx.concurrent:concurrent-futures:1.2.0")
            }
        }
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
