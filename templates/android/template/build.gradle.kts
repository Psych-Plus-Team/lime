// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
	repositories {
		mavenCentral()
		google()
	}
	dependencies {
		classpath("com.android.tools.build:gradle:::ANDROID_GRADLE_PLUGIN::")
		classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")

		// NOTE: Do not place your application dependencies here; they belong
		// in the individual module build.gradle files
	}
}

allprojects {
	repositories {
		mavenCentral()
		google()
	}::if ANDROID_GRADLE_BUILD_DIRECTORY::
	layout.buildDirectory.set(File("::ANDROID_GRADLE_BUILD_DIRECTORY::/::APP_FILE::/${project.name}"))::end::
}

tasks.register<Delete>("clean") {
	delete(rootProject.layout.buildDirectory)
}

tasks.wrapper {
	gradleVersion = "::ANDROID_GRADLE_VERSION::"
	distributionType = Wrapper.DistributionType.BIN
}

configure(subprojects.filter { !it.file("build.gradle.kts").exists() && !it.file("build.gradle").exists() && it.file("build.xml").exists() }) {
	buildscript {
		repositories {
			mavenCentral()
			google()
		}

		dependencies {
			classpath("com.android.tools.build:gradle:::ANDROID_GRADLE_PLUGIN::")
		}
	}

	apply(plugin = "com.android.library")

	configure<com.android.build.gradle.LibraryExtension> {
		compileSdk = project.property("ANDROID_BUILD_SDK_VERSION").toString().toInt()
		buildToolsVersion = project.property("ANDROID_BUILD_TOOLS_VERSION").toString()
		::if (ANDROID_GRADLE_PLUGIN>="4.0")::ndkPath = "::ANDROID_NDK_ROOT_ESCAPED::"::end::
		::if (ANDROID_GRADLE_PLUGIN>="4.0")::ndkVersion = "::ANDROID_NDK_VERSION::"::end::

		sourceSets {
			getByName("main") {
				manifest.srcFile("AndroidManifest.xml")
				java.srcDirs("src")
				res.srcDirs("res")
			}
		}
	}

	dependencies {
		add("implementation", project(":deps:extension-api"))
		add("implementation", project(":deps:androidtools"))
	}
}
