# OpenWrt Wi-Fi Manager

Flutter (Android) app that SSHes into an OpenWrt router and changes only `wireless.internal_wifi` SSID/key via UCI.

## Build the APK

### Option A: on your PC (needs Flutter + Android SDK)
```bash
bash setup.sh                    # one time: generates android/ and applies INTERNET permission, app name, minSdk 23
flutter pub get
flutter test                     # mock-router tests
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

### Option B: no local install (GitHub Actions)
Push this folder to a GitHub repo. Actions > "Build APK" > Run workflow. Download the `openwrt-wifi-manager-apk` artifact.

## Install on your phone
- Copy `app-release.apk` to the phone (USB, Drive, email), tap it, allow "Install unknown apps".
- Or with USB debugging on: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
- Or run directly: `flutter run --release` with the phone plugged in.

## Try it without a router
```bash
flutter run --dart-define=MOCK=true
```
Any IP / password works. Host `0.0.0.0` simulates unreachable; password `wrong` simulates bad login.

## Router preparation (home lab)
1. Management Wi-Fi and internal Wi-Fi must be separate `wifi-iface` sections. Name the internal one:
   ```
   uci set wireless.internal_wifi=wifi-iface   # or rename an existing section:
   uci rename wireless.@wifi-iface[1]='internal_wifi'
   uci commit wireless
   ```
2. SSH (dropbear) must listen on the LAN only, never WAN.
3. Phone joins the management Wi-Fi (it has no internet; Android may ask to stay connected, choose yes).

## Security notes
- Host key: trust-on-first-use. The fingerprint is shown once, saved in Android Keystore-backed storage, and a change blocks the connection.
- SSH password is held in memory only, never stored or logged.
- All input is validated (printable ASCII, no `' " ` \ $`) and additionally single-quote escaped.
- Section guard: refuses missing sections, non-AP, unencrypted, or `default_radioN` / `mgmt*` names. The app cannot know which SSID your phone is on, so keep the management network out of `internal_wifi`.
- Auth layer is behind `SshService`; swap it for a restricted account later.

## Layout
`lib/services/ssh_service.dart` transport + host key, `openwrt_service.dart` UCI logic, `mock_ssh_service.dart` fake router.
