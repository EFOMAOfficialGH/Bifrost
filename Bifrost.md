# Bifrost

Bifrost is a private, local-network file-sharing app for **Android and Windows**. It transfers files directly between nearby devices without accounts, cloud storage, ads, telemetry, or an internet connection for core transfers.

> **Current version: v0.14.3+41**
>
> Version 0.14.3 fixes the app picker flow, adds adjustable grid layouts and automatic OBB prompts, and replaces Windows file-drop handling with native OLE drag-and-drop.

## Highlights

- Automatic nearby-device discovery
- Nearby refresh every 3 seconds
- Android-to-Android transfers
- Android-to-Windows transfers
- Windows-to-Android transfers
- Manual **Connect by IP address** fallback
- Hotspot discovery improvements using interface-specific broadcasts
- Multi-file transfer queues
- Native Windows file and folder drag-and-drop into the transfer queue (OLE drop target)
- Folder drag-and-drop expansion and streamed large-file transfers
- Compact, reorderable transfer queue
- Windows minimize-to-tray with Send files, Check for updates, and Exit actions
- Windows launch-at-sign-in, minimized to tray by default and configurable in Settings
- Adjustable app-picker grid (automatic, 3-column, or 4-column) and list views
- Android Share target integration
- Personal-use Android app export/import, with All/APK/APK & OBB filters and optional OBB confirmation
- Accept or decline incoming transfers
- Trusted devices with persistent device identities
- Favorite nearby devices, stored independently from transfer trust
- Background receiving on Android, on by default with a persistent user preference
- Dismissible background-receiving notification; turn receiving off in Settings
- Transfer progress, speed, and ETA
- Transfer cancellation and retry handling
- SHA-256 file verification
- Resumable chunk transfers with per-chunk checksums and restart recovery
- Persistent transfer History
- History search by filename/device/date and filters by file type and time
- Confirmed send-again and retry actions that preserve separate attempts
- Open file and delete-from-History actions
- Configurable save location
- Day, Sunset, Night, Device Time, and Custom Color themes
- Custom text color
- Illustrated theme backgrounds
- Bifrost splash screen with custom branding and glow
- In-app GitHub Releases updater
- Cached Windows installer, Install now/Later prompts, and restart after updating
- Automatic startup update checks
- Update-size display before downloading
- Download progress, speed, ETA, and cancellation
- Android update progress notification
- Automatic Android and Windows release builds through GitHub Actions
- Automatic versioned GitHub Releases and release notes

## Platforms and requirements

### Android

- Android 8.0 / API 26 or newer
- Application ID: `com.bifrost.app`
- Local network access for discovery and transfers
- Notification permission for transfer and update progress notifications
- APK installation permission when installing an update or a received XAPK inside Bifrost
- All files access may be needed to include or restore Android OBB data

### Windows

- Windows desktop build
- Windows Firewall permission may be required for discovery and transfers
- The installer creates desktop and Start-menu shortcuts; Windows users can pin Bifrost to Start manually
- Inno Setup installer or portable ZIP
- Explorer **Send with Bifrost** integration through the installer

## How transfers work

1. Connect the Android and Windows devices to the same Wi-Fi network or hotspot.
2. Open Bifrost on both devices.
3. Open the **Nearby** tab.
4. Wait for the other device to appear. Nearby refreshes automatically every 3 seconds.
5. Tap the device and choose files, or drop files into the Windows window.
6. The receiving device accepts or declines the transfer.
7. Trusted devices can be allowed to send without approval.

Core transfers stay on the local network. GitHub is used only for the optional in-app update system.

## Hotspot connections

Bifrost supports phone-hotspot scenarios. Discovery sends requests through the global broadcast address and interface-specific directed broadcasts, such as `192.168.43.255`, in addition to multicast discovery.

Some phone hotspots enable **client isolation**, which prevents connected devices from communicating with each other. If that is enabled, automatic discovery may not work. Use **Connect by IP address** as the fallback, or disable client isolation in the hotspot settings if the phone provides that option.

## Background receiving

Background receiving is **on by default**. Use **Settings → Background receiving** to turn it off; the choice is saved across restarts.

Android displays a persistent notification while it is active. Tapping the notification stops background receiving and closes the receiver. Trusted devices can be accepted automatically according to the device's trust setting.

Background activity uses local networking and should be disabled when it is not needed to reduce battery use.

## History

The History tab records completed, failed, cancelled, interrupted, and active transfers. Search by filename, device, or date, and filter by file type or time period. Interrupted outgoing transfers can be retried/resumed; completed outgoing items can be sent again after confirmation. The list includes:

- Filename
- Transfer direction
- Device name
- File size
- Status
- Local time in a readable format such as `3:09 AM`
- Progress, speed, and ETA for active transfers

Depending on the platform and available path, History actions include opening the file, opening its location on Windows, deleting the record, retrying a transfer, and clearing History.

## Themes and appearance

Bifrost includes these theme options:

- **Day** — blue sky, sun, clouds, and green horizon
- **Sunset** — orange sky, setting sun, and warm clouds
- **Night** — deep blue sky, moon, and stars
- **Use Device Time** — switches between the illustrated themes based on the clock
- **Custom Color** — creates a coordinated atmosphere from a selected color

Text color can be configured independently in Settings. The splash screen uses the Bifrost branding, Mistical Spring title font, Helvetica-style subtitle, and warm yellow glow.

## Updating Bifrost

Bifrost checks the public GitHub Releases API for newer compatible releases.

Repository:

```text
https://github.com/EFOMAOfficialGH/Bifrost
```

### Manual update check

Open:

```text
Settings → Check for updates
```

Bifrost displays the available version and download size before downloading. During the download it shows percentage, downloaded size, speed, and estimated remaining time. On Android, download progress also appears in a notification. On Windows, the update is downloaded and cached before the installer runs; if Bifrost was open, it closes for the upgrade and relaunches afterward.

### Automatic startup checks

Bifrost silently checks for updates after startup. Android uses an in-app prompt; Windows shows a tray alert that opens the Install now/Later dialog. A deferred update is offered again on the next launch.

- Install now
- Later
- Download size

The setting can be disabled here:

```text
Settings → Automatically check for updates
```

It is enabled by default and persists across restarts. Manual checking remains available when automatic checking is disabled.

## GitHub Actions release process

The repository contains two workflows:

```text
.github/workflows/android.yml
.github/workflows/windows.yml
```

They build and publish releases automatically.

### Automatic versioned release behavior

The workflows read the version from `pubspec.yaml`:

```yaml
version: 0.14.3+41
```

When the versioned source is pushed to `main`, the workflows automatically create or update:

```text
Bifrost v0.14.3+41
```

The release receives assets similar to:

```text
Bifrost-Android-0.14.3+41.apk
Bifrost-Windows-0.14.3+41.exe
Bifrost-Windows-0.14.3+41-portable.zip
```

The Android workflow creates the release and generates the release notes. The Windows workflow waits for that release and uploads the Windows installer and portable ZIP without creating duplicate notes.

### Release workflow behavior

- Android and Windows builds run automatically after a push to `main`.
- Newer pushes cancel older in-progress runs.
- Android signing uses GitHub Secrets when configured.
- The private keystore and `android/key.properties` must never be committed.
- Build artifacts and generated Flutter directories should not be uploaded to the source repository.
- Commit several related file changes together to avoid unnecessary workflow runs.

## Build locally

Install Flutter stable, then run:

```bash
flutter pub get
flutter analyze
flutter test
```

Build Android:

```bash
flutter build apk --release
```

Build Windows from Windows:

```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

For release builds, configure Android signing through the GitHub Actions secrets or a local signing setup. Never place a private signing keystore in the repository.

## Build with GitHub Actions

This is the recommended method for beginners.

1. Create or open the Bifrost GitHub repository.
2. Upload the complete project contents, including the hidden `.github` folder.
3. Commit all related changes together.
4. Open the repository's **Actions** tab.
5. Wait for **Build Android APK** and **Build Windows package** to finish.
6. Open **Releases** to find the automatically created versioned release.
7. Download the Android APK, Windows installer, or Windows portable ZIP.

The source repository should contain the Flutter project and workflows, but not private signing files, generated builds, `.dart_tool`, or Windows ephemeral files.

## Project structure

```text
lib/
  core/
    networking/       Discovery, server, client, and runtime logic
    notifications/    Transfer and updater notifications
    storage/          Persistent preferences, History, and trusted devices
    theme/            Illustrated themes and background painters
    updates/          GitHub Releases updater
  features/
    discovery/        Nearby devices and file sending
    receive/          Incoming transfer approval
    send/             Networking test support
android/              Android application and signing configuration
windows/              Windows runner and desktop configuration
.github/workflows/    Automatic Android and Windows build workflows
assets/               App icon and custom font assets
```

## Privacy

Bifrost is designed as local-only software for file transfers. Core transfers do not require an account or cloud storage. The optional updater contacts GitHub only when checking for or downloading a release update.

## Current limitations

- Some hotspots and guest Wi-Fi networks block device-to-device traffic through client isolation.
- Windows Firewall configuration can affect discovery and incoming transfers.
- QR display exists, but camera QR scanning is not implemented.
- A transfer interrupted by a network/app stop needs a retry from History; it resumes saved, verified chunks when available.

- Open File Location behavior on Windows needs continued testing across different install locations.
- Update release notes are available through GitHub, but a dedicated in-app What's New screen is planned.

## Roadmap toward v1.0

Planned priorities include:

- More transfer reliability testing across real-world Wi-Fi and hotspot conditions
- Additional automatic reconnection after network interruptions
- Stronger handling of difficult hotspot networks
- More complete update release-note display
- Improved notification actions
- Further Android and Windows reliability testing
- A simple, dependable first-run experience for everyday users

## License and project status

Bifrost is an active hobby project by EFOMA, vibecoded with Manus AI. The application is functional and regularly tested, but it is still under active development and has not yet reached its final v1.0 stability target.
