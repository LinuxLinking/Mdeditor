import java.io.File

allprojects {
    repositories {
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        google()
        mavenCentral()
    }
}

// 目录围栏:构建产物必须落在项目根内。
// 锚定当前项目根(android 的上级), 不用 "../../build" 这类相对跳数 —— 跳数会随工程
// 位置漂移, 曾把 release 产物写到项目外的同名旧目录。
val projectRoot: File = rootProject.layout.projectDirectory.dir("..").asFile.canonicalFile

fun assertInsideProjectRoot(dir: File) {
    require(dir.canonicalFile.toPath().startsWith(projectRoot.toPath())) {
        "构建目录越出项目根: ${dir.canonicalPath} (项目根: ${projectRoot.canonicalPath})"
    }
}

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
assertInsideProjectRoot(newBuildDir.asFile)
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    assertInsideProjectRoot(newSubprojectBuildDir.asFile)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
