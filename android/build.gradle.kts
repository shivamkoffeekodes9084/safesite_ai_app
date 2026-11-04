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

    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            for (method in androidExt.javaClass.methods) {
                if (method.name in listOf("compileSdkVersion", "setCompileSdkVersion", "setCompileSdk")) {
                    try {
                        if (method.parameterTypes.size == 1 && (method.parameterTypes[0] == Int::class.javaPrimitiveType || method.parameterTypes[0] == java.lang.Integer::class.java)) {
                            method.invoke(androidExt, 36)
                        }
                    } catch (_: Throwable) {}
                }
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
