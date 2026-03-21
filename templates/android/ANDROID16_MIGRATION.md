# Android 16 (SDK 36) Configuration Guide

## Template Migration Completed

The Lime Android templates have been migrated to **Kotlin DSL** (.kts) with support for:
- ✅ **Android 16 (API 36)** - Latest Android version
- ✅ **SDK 36** - Android SDK
- ✅ **JDK 25** - Java Development Kit
- ✅ **NDK r27d** - Native Development Kit
- ✅ **Gradle 8.12** - Build system
- ✅ **AGP 8.8+** - Android Gradle Plugin
- ✅ **Kotlin 2.1.0** - Latest Kotlin version
- ✅ **Compose 2024.12.01** - Jetpack Compose BOM

## Files Updated

1. **build.gradle.kts** (root) - Main build configuration
2. **app/build.gradle.kts** - App module configuration  
3. **settings.gradle.kts** - Project settings
4. **gradle.properties** - Optimized for JDK 25
5. **gradle/wrapper/gradle-wrapper.properties** - Gradle 8.12

## Required Project.xml Configuration

Add or update these properties in your `Project.xml`:

```xml
<!-- Android Build Configuration -->
<android target-sdk-version="36" 
         minimum-sdk-version="24" 
         build-tools-version="36.0.0" />

<!-- Gradle Configuration -->
<setenv name="ANDROID_GRADLE_VERSION" value="8.12" />
<setenv name="ANDROID_GRADLE_PLUGIN" value="8.8.0" />

<!-- NDK Configuration -->
<setenv name="ANDROID_NDK_VERSION" value="27.2.12479018" />
<setenv name="ANDROID_NDK_ROOT" value="path/to/ndk/r27d" />

<!-- AndroidX & Jetifier -->
<config:android android-use-androidx="true" />
<config:android android-enable-jetifier="true" />
```

## Key Updates

### Dependencies Updated
- **androidx.core:core** → 1.15.0
- **androidx.core:core-ktx** → 1.15.0
- **androidx.documentfile** → 1.1.0
- **androidx.appcompat** → 1.7.0
- **material** → 1.12.0
- **Compose BOM** → 2024.12.01 (manages all Compose versions)
- **Kotlin stdlib** → 2.1.0

### Build Optimizations
- Increased heap size to 4GB for large projects
- Enabled parallel builds
- Enabled build caching
- Enabled on-demand configuration
- Using G1GC for better garbage collection
- Java target updated to 17 (required for AGP 8.8+)

### Compose Support
- Added Compose Kotlin Compiler Plugin (2.1.0)
- Using Compose BOM for consistent versioning
- Includes Material3 design components

## Migration Notes

### Breaking Changes
1. **Java 17 Required** - Minimum JDK version is now 17 (you have JDK 25, perfect)
2. **Gradle 8.12 Required** - Older Gradle versions won't work
3. **Groovy DSL Deprecated** - All files now use Kotlin DSL (.kts)

### Backward Compatibility
- Old Groovy files (.gradle) can coexist temporarily
- Lime will prefer .kts files if both exist
- Template variables (::VARIABLE::) remain unchanged

## Testing

After configuration, test with:

```bash
# Clean build
lime clean android

# Build debug
lime build android

# Build release
lime build android -release

# Test on device
lime test android -release
```

## Troubleshooting

### If build fails:
1. Verify JDK version: `java --version` (should be 25)
2. Verify Gradle downloaded: Check `~/.gradle/wrapper/dists/`
3. Clear Gradle cache: `./gradlew clean --no-daemon`
4. Update Android SDK: Check SDK Manager has latest build tools

### Common Issues:
- **"Unsupported Java version"** → Ensure JAVA_HOME points to JDK 25
- **"AGP requires Java 17"** → Check gradle.properties uses correct JDK
- **"Cannot resolve androidx"** → Run `./gradlew --refresh-dependencies`

## Performance Tips

The new configuration enables:
- ⚡ **Faster builds** with parallel execution and caching
- 🎯 **Incremental compilation** for Kotlin
- 💾 **Lower memory usage** with G1GC
- 🔄 **Hot reload** support with Compose

Builds should be significantly faster than before, especially incremental builds.
