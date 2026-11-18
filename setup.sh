#!/usr/bin/env bash
# One-time: generate the Android scaffolding around the Dart sources and apply the 3 required Android tweaks.
set -euo pipefail
cd "$(dirname "$0")"

flutter create --project-name openwrt_wifi_manager --org com.benison --platforms=android .
rm -f test/widget_test.dart   # default counter test doesn't apply to this app

MANIFEST=android/app/src/main/AndroidManifest.xml
# 1. Release builds need the INTERNET permission to open SSH sockets.
grep -q 'android.permission.INTERNET' "$MANIFEST" || \
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
# 2. App name on the launcher.
sed -i 's#android:label="[^"]*"#android:label="OpenWrt Wi-Fi Manager"#' "$MANIFEST"
# 3. flutter_secure_storage needs minSdk 23.
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && sed -i -E 's/minSdk(Version)?([ =]+)flutter\.minSdkVersion/minSdk\1\2 23/' "$f"
done
echo "Setup done. Next: flutter pub get && flutter test && flutter build apk --release"
