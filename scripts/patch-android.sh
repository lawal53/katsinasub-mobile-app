#!/usr/bin/env bash
# Scaffolds android/ + ios/ (missing from this repo) and applies the
# manual edits described in README.md automatically, so CI can build
# without a human doing it by hand each time.
#
# Flutter's default Android template changed over time: older
# versions generate Groovy files (build.gradle, settings.gradle);
# newer versions generate Kotlin DSL files (build.gradle.kts,
# settings.gradle.kts). This script detects which one flutter create
# produced and edits the right files with the right syntax.
set -euo pipefail

ORG="com.katsinasub"
APP_ID="com.katsinasub.app"

echo "==> Creating platform folders (android/, ios/) if missing..."
flutter create --org "$ORG" --platforms android,ios .

if [ -f "android/app/build.gradle.kts" ]; then
  KTS=true
  APP_GRADLE="android/app/build.gradle.kts"
  SETTINGS_GRADLE="android/settings.gradle.kts"
  echo "==> Detected Kotlin DSL Gradle template."
elif [ -f "android/app/build.gradle" ]; then
  KTS=false
  APP_GRADLE="android/app/build.gradle"
  ROOT_GRADLE="android/build.gradle"
  echo "==> Detected Groovy Gradle template."
else
  echo "ERROR: neither android/app/build.gradle nor android/app/build.gradle.kts was found after flutter create."
  echo "Contents of android/app/:"
  ls -la android/app/ || true
  exit 1
fi

echo "==> Forcing applicationId to $APP_ID ..."
if [ "$KTS" = true ]; then
  sed -i "s/applicationId = \".*\"/applicationId = \"$APP_ID\"/" "$APP_GRADLE"
  sed -i "s/compileSdk = flutter.compileSdkVersion/compileSdk = 36/" "$APP_GRADLE"
  sed -i "s/targetSdk = flutter.targetSdkVersion/targetSdk = 36/" "$APP_GRADLE"
else
  sed -i "s/applicationId \".*\"/applicationId \"$APP_ID\"/" "$APP_GRADLE"
  sed -i "s/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/" "$APP_GRADLE"
  sed -i "s/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 36/" "$APP_GRADLE"
fi

echo "==> Placing google-services.json ..."
if [ ! -f "google-services-temp.json" ]; then
  echo "ERROR: google-services-temp.json not found at repo root (should be written from secret before this script runs)."
  exit 1
fi
cp google-services-temp.json android/app/google-services.json

echo "==> Setting Android app icon from assets/logo.png ..."
# flutter create always scaffolds the default plain-Flutter launcher
# icon into every mipmap-*/ic_launcher.png — nothing else replaces it,
# so without this the app installs with the generic Flutter icon
# instead of the real logo, regardless of what's used inside the app.
if [ -f "assets/logo.png" ]; then
  CONVERT_CMD=""
  if command -v convert >/dev/null 2>&1; then
    CONVERT_CMD="convert"
  elif command -v magick >/dev/null 2>&1; then
    CONVERT_CMD="magick"
  fi
  if [ -n "$CONVERT_CMD" ]; then
    for pair in "mdpi:48" "hdpi:72" "xhdpi:96" "xxhdpi:144" "xxxhdpi:192"; do
      density="${pair%%:*}"
      size="${pair##*:}"
      dir="android/app/src/main/res/mipmap-${density}"
      mkdir -p "$dir"
      "$CONVERT_CMD" assets/logo.png -resize "${size}x${size}" -background white -gravity center -extent "${size}x${size}" "$dir/ic_launcher.png"
    done
    echo "==> App icon replaced for all densities."
  else
    echo "WARNING: ImageMagick not found on this runner — app icon left as the default Flutter icon."
  fi
else
  echo "WARNING: assets/logo.png not found — app icon left as the default Flutter icon."
fi

echo "==> Adding Google Services Gradle plugin ..."
if [ "$KTS" = true ]; then
  # Kotlin DSL: declare the plugin (with version, apply false) in the
  # top-level settings.gradle.kts plugins block, then apply it
  # (no version) in the app-level build.gradle.kts plugins block.
  if [ -f "$SETTINGS_GRADLE" ] && ! grep -q "com.google.gms.google-services" "$SETTINGS_GRADLE"; then
    perl -0777 -pi -e 's/(plugins\s*\{)/$1\n    id("com.google.gms.google-services") version "4.4.2" apply false/s' "$SETTINGS_GRADLE"
  fi
  if ! grep -q "com.google.gms.google-services" "$APP_GRADLE"; then
    perl -0777 -pi -e 's/(plugins\s*\{)/$1\n    id("com.google.gms.google-services")/s' "$APP_GRADLE"
  fi
else
  if ! grep -q "com.google.gms:google-services" "$ROOT_GRADLE"; then
    perl -0777 -pi -e "s/(buildscript\s*\{[^}]*dependencies\s*\{)/\$1\n        classpath 'com.google.gms:google-services:4.5.0'/s" "$ROOT_GRADLE"
  fi
  if ! head -n1 "$APP_GRADLE" | grep -q "com.google.gms.google-services"; then
    sed -i "1i apply plugin: 'com.google.gms.google-services'" "$APP_GRADLE"
  fi
fi

echo "==> Forcing all Android library subprojects (including third-party plugins like file_picker) onto a modern compileSdk ..."
# Some plugins hardcode a stale compileSdk in their own android/build.gradle
# regardless of what our app's compileSdk is set to, which then fails to
# build against newer transitive dependencies (e.g. file_picker's own
# compileSdk 34 vs. flutter_plugin_android_lifecycle needing 36+). This
# forces every plugin subproject onto the same modern compileSdk.
#
# IMPORTANT: flutter create's own default build.gradle ALREADY contains
# "subprojects { ... }" blocks (for buildDir/evaluationDependsOn), so a
# guard that greps for the bare word "subprojects" always finds a false
# match and skips adding ours. Guard on a unique marker comment instead.
MARKER="KATSINASUB_COMPILESDK_OVERRIDE"
if [ "$KTS" = true ]; then
  ROOT_GRADLE_KTS="android/build.gradle.kts"
  if [ -f "$ROOT_GRADLE_KTS" ] && ! grep -q "$MARKER" "$ROOT_GRADLE_KTS"; then
    cat >> "$ROOT_GRADLE_KTS" <<EOF3

// $MARKER
// Excludes ":app" deliberately — Flutter's own template forces :app to
// evaluate early via evaluationDependsOn(":app"), so registering
// afterEvaluate on it here throws "Cannot run Project.afterEvaluate
// when the project is already evaluated." app's own compileSdk is
// already set directly earlier in this script anyway.
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let { ext ->
                val method = ext.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType
                }
                method?.invoke(ext, 36)
            }
        }
    }
}
EOF3
  fi
  echo "==> $ROOT_GRADLE_KTS now contains:"
  cat "$ROOT_GRADLE_KTS"
else
  if [ -f "$ROOT_GRADLE" ] && ! grep -q "$MARKER" "$ROOT_GRADLE"; then
    cat >> "$ROOT_GRADLE" <<EOF3

// $MARKER
// Excludes ":app" deliberately — same evaluationDependsOn(":app") timing
// conflict as the Kotlin DSL branch above. app's own compileSdk is
// already set directly earlier in this script anyway.
subprojects { proj ->
    if (proj.name != 'app') {
        proj.plugins.withId('com.android.library') {
            proj.android {
                compileSdk 36
            }
        }
        proj.afterEvaluate {
            if (proj.hasProperty('android')) {
                proj.android {
                    compileSdk 36
                }
            }
        }
    }
}
EOF3
  fi
  echo "==> $ROOT_GRADLE now contains:"
  cat "$ROOT_GRADLE"
fi

echo "==> Applying fingerprint-unlock native edits ..."
MAIN_ACTIVITY=$(find android/app/src/main -name "MainActivity.kt" | head -n1 || true)
if [ -n "$MAIN_ACTIVITY" ]; then
  sed -i "s/io.flutter.embedding.android.FlutterActivity/io.flutter.embedding.android.FlutterFragmentActivity/" "$MAIN_ACTIVITY"
  sed -i "s/: FlutterActivity/: FlutterFragmentActivity/" "$MAIN_ACTIVITY"
fi

ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$ANDROID_MANIFEST" ] && ! grep -q "USE_BIOMETRIC" "$ANDROID_MANIFEST"; then
  perl -0777 -pi -e 's/(<manifest[^>]*>)/$1\n    <uses-permission android:name="android.permission.USE_BIOMETRIC" \/>/s' "$ANDROID_MANIFEST"
fi

if [ -f "ios/Runner/Info.plist" ] && ! grep -q "NSFaceIDUsageDescription" ios/Runner/Info.plist; then
  perl -0777 -pi -e "s/(<dict>)/\$1\n\t<key>NSFaceIDUsageDescription<\/key>\n\t<string>Ana amfani da Face ID\/fingerprint don sauri budewa maimakon rubuta PIN.<\/string>/s" ios/Runner/Info.plist
fi

echo "==> Setting the app's display name to Katsinasub ..."
# flutter create's default AndroidManifest.xml carries
# android:label="vtu_mobile_app" (the project folder name) — this is
# the app name shown under the launcher icon on the phone, Settings >
# Apps, and notifications, and it's been showing the wrong thing in
# every build until now because nothing in this script ever touched
# it. Fixed here so a fresh build+install already has it right, with
# no manual edit or separate script needed.
if [ -f "$ANDROID_MANIFEST" ]; then
  sed -i 's/android:label="[^"]*"/android:label="Katsinasub"/' "$ANDROID_MANIFEST"
  echo "    $ANDROID_MANIFEST android:label is now:"
  grep "android:label" "$ANDROID_MANIFEST"
else
  echo "    WARNING: $ANDROID_MANIFEST not found — app display name was not set."
fi
# Same app-name fix for iOS, in case this is ever built for it too.
if [ -f "ios/Runner/Info.plist" ]; then
  perl -0777 -pi -e 's/(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*(<\/string>)/${1}Katsinasub${2}/s' ios/Runner/Info.plist
  perl -0777 -pi -e 's/(<key>CFBundleName<\/key>\s*<string>)[^<]*(<\/string>)/${1}Katsinasub${2}/s' ios/Runner/Info.plist
fi

echo "==> Writing android/key.properties from CI secrets ..."
cat > android/key.properties <<EOF
storePassword=${KEYSTORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${KEY_ALIAS}
storeFile=upload-keystore.jks
EOF

echo "==> Wiring signingConfigs into $APP_GRADLE (if not already present) ..."
if ! grep -q "key.properties" "$APP_GRADLE"; then
  if [ "$KTS" = true ]; then
    TMP_FILE=$(mktemp)
    {
      echo "import java.util.Properties"
      echo "import java.io.FileInputStream"
      echo ""
      cat "$APP_GRADLE"
    } > "$TMP_FILE"
    mv "$TMP_FILE" "$APP_GRADLE"

    perl -0777 -pi -e 's/(android\s*\{)/$1\n    val keystoreProperties = Properties()\n    val keystorePropertiesFile = rootProject.file("key.properties")\n    if (keystorePropertiesFile.exists()) {\n        keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n    }\n/s' "$APP_GRADLE"

    perl -0777 -pi -e 's/(buildTypes\s*\{)/    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties["keyAlias"] as String?\n            keyPassword = keystoreProperties["keyPassword"] as String?\n            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }\n            storePassword = keystoreProperties["storePassword"] as String?\n        }\n    }\n\n$1/s' "$APP_GRADLE"

    perl -0777 -pi -e 's/(release\s*\{)/$1\n            signingConfig = signingConfigs.getByName("release")/s' "$APP_GRADLE"
  else
    perl -0777 -pi -e "s/(android \{)/\$1\n    def keystorePropertiesFile = rootProject.file(\"key.properties\")\n    def keystoreProperties = new Properties()\n    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n/s" "$APP_GRADLE"
    perl -0777 -pi -e "s/(buildTypes\s*\{)/    signingConfigs {\n        release {\n            keyAlias keystoreProperties['keyAlias']\n            keyPassword keystoreProperties['keyPassword']\n            storeFile file(keystoreProperties['storeFile'])\n            storePassword keystoreProperties['storePassword']\n        }\n    }\n\$1/s" "$APP_GRADLE"
    perl -0777 -pi -e "s/(release\s*\{)/\$1\n            signingConfig signingConfigs.release/s" "$APP_GRADLE"
  fi
fi

echo "==> Enabling core library desugaring (required by flutter_local_notifications) ..."
if [ "$KTS" = true ]; then
  if grep -q "compileOptions" "$APP_GRADLE"; then
    if ! grep -q "isCoreLibraryDesugaringEnabled" "$APP_GRADLE"; then
      perl -0777 -pi -e 's/(compileOptions\s*\{)/$1\n        isCoreLibraryDesugaringEnabled = true/s' "$APP_GRADLE"
    fi
  else
    perl -0777 -pi -e 's/(android\s*\{)/$1\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }/s' "$APP_GRADLE"
  fi
  if ! grep -q "coreLibraryDesugaring" "$APP_GRADLE"; then
    cat >> "$APP_GRADLE" <<'EOF2'

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
EOF2
  fi
else
  if grep -q "compileOptions" "$APP_GRADLE"; then
    if ! grep -q "coreLibraryDesugaringEnabled" "$APP_GRADLE"; then
      perl -0777 -pi -e 's/(compileOptions\s*\{)/$1\n        coreLibraryDesugaringEnabled true/s' "$APP_GRADLE"
    fi
  else
    perl -0777 -pi -e "s/(android \{)/\$1\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n    }/s" "$APP_GRADLE"
  fi
  if ! grep -q "coreLibraryDesugaring" "$APP_GRADLE"; then
    cat >> "$APP_GRADLE" <<'EOF2'

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
EOF2
  fi
fi

echo "==> Final $APP_GRADLE for reference:"
cat "$APP_GRADLE"

echo "==> Verifying targetSdk is 36+ (Google Play requires this — enforced Aug 31, 2026) ..."
if ! grep -Eq 'targetSdk(Version)?\s*=?\s*3[6-9]' "$APP_GRADLE"; then
  echo "ERROR: targetSdk in build.gradle is not 36 or higher — Google Play will reject this upload. Aborting."
  exit 1
fi

echo "==> Done. Android project is ready to build."
