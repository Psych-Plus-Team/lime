import org.gradle.api.tasks.compile.JavaCompile

plugins {
	id("com.android.library")
}

tasks.withType<JavaCompile>().configureEach {
	options.compilerArgs.add("-Xlint:-options")
}

android {
	namespace = "org.haxe.extension"
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
