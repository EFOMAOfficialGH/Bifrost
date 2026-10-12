# Bifrost

Bifrost is a local-network file sharing app for Android and Windows. It is designed to transfer files directly between nearby devices over the same Wi-Fi network, without accounts, cloud storage, ads, telemetry, or internet calls.

> **Current status: Android↔Windows transfer verified.** Local discovery, file selection, Accept/Decline, checksum verification, and bidirectional Android-to-Windows and Windows-to-Android transfers have been manually tested. The current build is still an integration prototype, not a polished release.

## What works now

The project targets Android and Windows, uses application ID `com.bifrost.app`, and requires Android 8.0 (API 26) or newer. It includes Bifrost dark and light themes, Nearby, History, Settings, local discovery, manual-IP fallback, file selection, incoming Accept/Decline requests, streaming, and SHA-256 verification.

## Current limitations

- Save location is now configurable and persisted, but Android storage permissions and background behavior still need more device testing.
- Transfer progress is now visible in-app and on Android notifications; Windows currently shows in-app progress only.
- Incoming notifications are not instant or reliable when the app is not in the foreground.
- Transfer History now records completed and failed transfers locally, but it needs more UI polish and filtering.
- Device names and save locations are persisted locally.
- QR display exists, but camera QR scanning is not implemented.
- Background receiving and a persistent Android foreground service are not implemented.

## Build locally (optional)

You do **not** need to install Flutter for the first test if you use GitHub Actions. If you do have Flutter installed, run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Build using GitHub Actions (recommended for beginners)

1. Create a free account at [github.com](https://github.com/).
2. Create a new empty repository named `bifrost`.
3. Upload this whole project folder, including the `.github` folder. On the website, choose **Add file → Upload files** and drag the project files in.
4. Open the repository's **Actions** tab and approve workflows if GitHub asks.
5. Choose **Build Android APK** and click **Run workflow**, or push a change to start it automatically.
6. When it finishes, open the run and download the artifact named `bifrost-android-apk`.
7. The Windows workflow creates `bifrost-windows-build`, containing a portable zip and installer.

The APK in this milestone is a CI smoke build signed with a temporary debug key. Before public distribution, a later milestone will document a private release keystore and update the workflow to use GitHub Secrets. Never upload a private keystore to the repository.

## Package choices

`flutter_riverpod 2.6.1` provides predictable, testable state management with no widget coupling. Material 3 widgets are maintained in the Flutter SDK and provide accessible controls without another UI dependency.

## Milestones

Milestone 1 established the project shell and cloud builds. Milestone 2 added the networking core and one-file transfer. Milestone 3 added discovery, manual IP, QR details, and troubleshooting. The current integration build adds file selection and Accept/Decline transfers across Android and Windows. Next priorities are configurable save locations, progress UI and Android notifications, working History, background receiving, and release polish.

## Privacy promise

Bifrost is being designed as local-only software. The current shell does not perform network calls.
