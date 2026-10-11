# Bifrost

Bifrost is a local-network file sharing app for Android and Windows. It is designed to transfer files directly between nearby devices over the same Wi-Fi network, without accounts, cloud storage, ads, telemetry, or internet calls.

> **Current status: Milestone 1.** The project shell, theme, navigation, empty screens, and cloud build workflows are in place. Networking and real file transfer are intentionally not implemented yet.

## What works now

The project targets Android and Windows, uses application ID `com.bifrost.app`, and requires Android 8.0 (API 26) or newer. It includes Bifrost dark and light themes, Nearby, History, and Settings screens, a responsive starter layout, and an original Bifrost mark. It does not yet access files or the network.

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

Milestone 1 establishes the project shell and cloud builds. Milestone 2 adds the networking core and one-file transfer. Milestone 3 adds discovery, manual IP, QR connection, and troubleshooting. Milestone 4 adds the full multi-file send/receive flow. Milestone 5 adds Android and Windows integration. Milestone 6 adds security, certificates, pairing, and its review. Milestone 7 adds polish, localization, accessibility, and final documentation.

## Privacy promise

Bifrost is being designed as local-only software. The current shell does not perform network calls.
