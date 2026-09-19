#!/usr/bin/env bash
# Scaffolds android/ + ios/ (missing from this repo) and applies the
# manual edits described in README.md automatically, so CI can build
# without a human doing it by hand each time.
set -euo pipefail

ORG="com.kstsinasub"
APP_ID="com.kstsinasub.app"

echo "==> Creating platform folders (android/, ios/) if missing..."
flutter create --org "$ORG" --platforms android,ios .

APP_GRADLE="android/app/build.gradle"
ROOT_GRADLE="android/build.gradle"

echo "==> Forcing applicationId to $APP_ID ..."
sed -i "s/applicationId \".*\"/applicationId \"$APP_ID\"/" "$APP_GRADLE"

echo "==> Placing google-services.json ..."
if [ ! -f "google-services-temp.json" ]; then
  echo "ERROR: google-services-temp.json not found at repo root (should be written from secret before this script runs)."
  exit 1
fi
cp google-services-temp.json android/app/google-services.json

echo "==> Adding Google Services Gradle plugin ..."
if ! grep -q "com.google.gms:google-services" "$ROOT_GRADLE"; then
  # Add classpath inside the buildscript { dependencies { ... } } block
  perl -0777 -pi -e "s/(buildscript\s*\{[^}]*dependencies\s*\{)/\$1\n        classpath 'com.google.gms:google-services:4.5.0'/s" "$ROOT_GRADLE"
fi

if ! head -n1 "$APP_GRADLE" | grep -q "com.google.gms.google-services"; then
  sed -i "1i apply plugin: 'com.google.gms.google-services'" "$APP_GRADLE"
fi

echo "==> Applying fingerprint-unlock native edits ..."
MAIN_ACTIVITY=$(find android/app/src/main -name "MainActivity.kt")
if [ -n "$MAIN_ACTIVITY" ]; then
  sed -i "s/io.flutter.embedding.android.FlutterActivity/io.flutter.embedding.android.FlutterFragmentActivity/" "$MAIN_ACTIVITY"
  sed -i "s/: FlutterActivity/: FlutterFragmentActivity/" "$MAIN_ACTIVITY"
fi

if [ -f "ios/Runner/Info.plist" ] && ! grep -q "NSFaceIDUsageDescription" ios/Runner/Info.plist; then
  perl -0777 -pi -e "s/(<dict>)/\$1\n\t<key>NSFaceIDUsageDescription<\/key>\n\t<string>Ana amfani da Face ID\/fingerprint don sauri budewa maimakon rubuta PIN.<\/string>/s" ios/Runner/Info.plist
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
  perl -0777 -pi -e "s/(android \{)/\$1\n    def keystorePropertiesFile = rootProject.file(\"key.properties\")\n    def keystoreProperties = new Properties()\n    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n/s" "$APP_GRADLE"
  perl -0777 -pi -e "s/(buildTypes\s*\{)/    signingConfigs {\n        release {\n            keyAlias keystoreProperties['keyAlias']\n            keyPassword keystoreProperties['keyPassword']\n            storeFile file(keystoreProperties['storeFile'])\n            storePassword keystoreProperties['storePassword']\n        }\n    }\n\$1/s" "$APP_GRADLE"
  perl -0777 -pi -e "s/(release\s*\{)/\$1\n            signingConfig signingConfigs.release/s" "$APP_GRADLE"
fi

echo "==> Done. Android project is ready to build."
