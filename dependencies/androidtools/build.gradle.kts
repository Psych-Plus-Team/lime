import org.gradle.api.tasks.compile.JavaCompile

plugins {
	id("com.android.library")
}

repositories {
	mavenCentral()
	google()
}

tasks.withType<JavaCompile>().configureEach {
	options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:deprecation"))
}

android {
	namespace = "org.haxe.extension.androidtools"
	compileSdk = project.property("ANDROID_BUILD_SDK_VERSION").toString().toInt()
	buildToolsVersion = project.property("ANDROID_BUILD_TOOLS_VERSION").toString()

	defaultConfig {
		minSdk = project.property("ANDROID_BUILD_MIN_SDK_VERSION").toString().toInt()
	}

	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}
}

dependencies {
	implementation(project(":deps:extension-api"))
	implementation("androidx.core:core:1.15.0")
}
