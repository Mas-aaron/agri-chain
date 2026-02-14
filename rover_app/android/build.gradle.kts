allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some older Flutter plugins (e.g. flutter_bluetooth_serial) still rely on the
// AndroidManifest.xml package attribute and do not set the AGP 8+ `namespace`
// field. Inject it here to keep builds working without patching pub cache.
subprojects {
    afterEvaluate {
        if (name == "flutter_bluetooth_serial") {
            extensions.findByName("android")?.let { androidExt ->
                try {
                    val nsProp = androidExt.javaClass.getMethod("getNamespace")
                    val currentNs = nsProp.invoke(androidExt) as? String
                    if (currentNs.isNullOrBlank()) {
                        androidExt.javaClass.getMethod("setNamespace", String::class.java)
                            .invoke(androidExt, "io.github.edufolly.flutterbluetoothserial")
                    }
                } catch (_: Throwable) {
                    // If the Android extension doesn't expose namespace, ignore.
                }
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
