import java.awt.GridBagConstraints
import java.awt.GridBagLayout
import java.awt.Insets

plugins {
	id("com.android.application")
	id("org.jetbrains.kotlin.android")
	id("org.jetbrains.kotlin.plugin.compose") version "2.1.0"
}

System.setProperty("java.awt.headless", "false")

//Uncomment to debug deprecation warnings.
/* tasks.withType<JavaCompile> {
	options.compilerArgs.addAll(listOf("-Xlint:unchecked", "-Xlint:deprecation"))
} */

android {
	namespace = "::APP_PACKAGE::"
	compileSdk = project.property("ANDROID_BUILD_SDK_VERSION").toString().toInt()
	buildToolsVersion = project.property("ANDROID_BUILD_TOOLS_VERSION").toString()
	::if (ANDROID_GRADLE_PLUGIN>="4.0")::ndkPath = "::ANDROID_NDK_ROOT_ESCAPED::"::end::
	::if (ANDROID_GRADLE_PLUGIN>="4.0")::ndkVersion = "::ANDROID_NDK_VERSION::"::end::

	defaultConfig {
		applicationId = "::META_PACKAGE_NAME::"
		minSdk = project.property("ANDROID_BUILD_MIN_SDK_VERSION").toString().toInt()
		targetSdk = project.property("ANDROID_BUILD_TARGET_SDK_VERSION").toString().toInt()
		versionCode = project.property("VERSION_CODE").toString().toInt()
		versionName = project.property("VERSION_NAME").toString()
		::if (languages != null)::resourceConfigurations.addAll(listOf(::foreach languages::"::__current__::", ::end::""))::end::
	}

	::if KEY_STORE::
	signingConfigs {
		var keyStorePassword = project.property("KEY_STORE_PASSWORD").toString()
		var keyStoreAliasPassword = project.property("KEY_STORE_ALIAS_PASSWORD").toString()

		if (keyStorePassword == "null") {
			val keyStoreFile = project.property("KEY_STORE").toString().split("/")
			keyStorePassword = getPassword("\nPlease enter key password for ${keyStoreFile.last()}:")
		}

		if (keyStoreAliasPassword == "null") {
			keyStoreAliasPassword = getPassword("\nPlease enter key alias password for alias ${project.property("KEY_STORE_ALIAS")}:")
		}

		create("release") {
			storeFile = file(project.property("KEY_STORE").toString())
			storePassword = keyStorePassword
			keyAlias = project.property("KEY_STORE_ALIAS").toString()
			keyPassword = keyStoreAliasPassword
		}
	}
	::else::
	signingConfigs {
		val signingFile = file("signing.properties")
		if (signingFile.exists()) {
			val signing = java.util.Properties()
			signing.load(java.io.FileInputStream(signingFile))

			create("release") {
				storeFile = file(signing["KEY_STORE"].toString())
				storePassword = signing["KEY_STORE_PASSWORD"].toString()
				keyAlias = signing["KEY_STORE_ALIAS"].toString()
				keyPassword = signing["KEY_STORE_ALIAS_PASSWORD"].toString()
			}
		} else {
			create("release")
		}
	}
	::end::

	buildTypes {
		release {
			isMinifyEnabled = false
			signingConfig = signingConfigs.getByName("release")
			proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
		}
	}

	buildFeatures {
		buildConfig = true
		compose = true
	}

	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}

	kotlinOptions {
		jvmTarget = "17"
	}

	applicationVariants.all {
		outputs.all {
			if (this is com.android.build.gradle.internal.api.BaseVariantOutputImpl) {
				outputFileName = "::APP_FILE::-${buildType.name}.apk"
			}
		}
	}
}

dependencies {
	::if (ANDROID_USE_ANDROIDX)::
	// AndroidX Core
	implementation("androidx.core:core:1.15.0")
	implementation("androidx.core:core-ktx:1.15.0")
	implementation("androidx.documentfile:documentfile:1.1.0")
	implementation("androidx.appcompat:appcompat:1.7.0")
	
	// Material Design
	implementation("com.google.android.material:material:1.12.0")
	
	// Compose BOM for consistent versions
	val composeBom = platform("androidx.compose:compose-bom:2026.03.00")
	implementation(composeBom)
	
	// Compose Libraries (versions managed by BOM)
	implementation("androidx.compose.ui:ui")
	implementation("androidx.compose.material3:material3:1.4.0")
	implementation("androidx.compose.material:material-icons-extended")
	implementation("androidx.compose.ui:ui-tooling-preview")
	implementation("androidx.compose.foundation:foundation")
	
	// Compose Tooling (debug)
	debugImplementation("androidx.compose.ui:ui-tooling")
	::end::
	
	// Kotlin
	implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
	
	// Local libs
	implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar"))))
	
	// Library projects
	::if (ANDROID_LIBRARY_PROJECTS)::::foreach (ANDROID_LIBRARY_PROJECTS)::implementation(project(":deps:::name::"))
	::end::::end::
}

fun getPassword(message: String): String {
	var password = ""
	if (System.console() == null) {
		javax.swing.SwingUtilities.invokeAndWait {
			val panel = javax.swing.JPanel(GridBagLayout())
			val gbc = GridBagConstraints()
			
			gbc.gridx = 0
			gbc.gridy = 0
			gbc.fill = GridBagConstraints.HORIZONTAL
			gbc.insets = Insets(0, 0, 10, 0)
			panel.add(javax.swing.JLabel("<html><body style='width: 350px'>$message</body></html>"), gbc)
			
			gbc.gridy = 1
			val passwordField = javax.swing.JPasswordField(20)
			panel.add(passwordField, gbc)
			
			val result = javax.swing.JOptionPane.showConfirmDialog(
				null,
				panel,
				"Enter password",
				javax.swing.JOptionPane.OK_CANCEL_OPTION,
				javax.swing.JOptionPane.PLAIN_MESSAGE
			)
			
			if (result == javax.swing.JOptionPane.OK_OPTION) {
				password = String(passwordField.password)
			}
		}
	} else {
		password = String(System.console().readPassword(message))
	}
	return password
}
