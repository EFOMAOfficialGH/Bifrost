# Bifrost Patch Notes

## Bifrost v0.10.3+15

- Made Settings → About pressable.
- Added “Vibecoded by EFOMA using Manus AI”.
- Added the app version and useful project information.
- `flutter analyze` passes and all 5 tests pass.

## Bifrost v0.10.2+14

- Replaced the blurry low-resolution icon with the provided 646×648 artwork.
- Regenerated Android adaptive launcher icons and the Windows executable icon.
- `flutter analyze` passes and all 5 tests pass.

## Bifrost v0.10.1+13

- Added the supplied Mistical Spring font to the app assets.
- Applied it to the themed Bifrost startup title.
- Kept the startup tagline bold and readable.
- `flutter analyze` passes and all 5 tests pass.

## Bifrost v0.10.0+12

### Sky themes and branding

- Added illustrated Day, Sunset, and Night themes with clouds, sun, moon, stars, and atmospheric horizons.
- Added persistent theme selection in Settings.
- Added a short themed startup splash with Bifrost branding and glow.
- Added the supplied Neon Crystal Bridge icon to Android and Windows launcher assets.
- Added launcher icon generation configuration for future builds.

### Verification

- `flutter analyze` passes.
- All 5 automated tests pass.
- `git diff --check` passes.

## Bifrost v0.9.0+11

### Native sharing and transfer polish

- Android Share menu support for single and multiple files.
- Windows Explorer Send with Bifrost installer integration.
- APK-aware Install APK History action.
- Missing-file warnings and stale History cleanup.
- Per-file queue states and batch completion summaries.
- Retry failed sent transfers from History.
- Transfer details dialog with status, device, size, time, speed, and path.
- Speed and ETA in Android progress notifications.
- Improved Windows file-location invocation and Bifrost naming.

### Verification

- `flutter analyze` passes.
- All 5 automated tests pass.
- `git diff --check` passes.

## Bifrost v0.8.0+10

### Transfer resilience and speed visibility

- Temporary socket, HTTP, and timeout failures retry up to three times.
- Retries use a short increasing backoff.
- Deliberate cancellation and receiver rejection are not retried.
- Nearby transfer status shows measured speed and estimated time remaining.
- Live History cards show speed and ETA.
- Android stable-signing workflow condition is compatible with GitHub Actions parsing.

### Verification

- `flutter analyze` passes.
- All 5 automated tests pass.
- `git diff --check` passes.

## Bifrost v0.7.0+9

### Fixes and Android update support

- Older installations with a saved device name but no configured save folder now receive the setup screen.
- Windows Open File Location now uses Explorer with the exact quoted file path.
- Added stable Android release-signing support through GitHub Actions secrets.
- Documented the one-time migration from older debug-signed APKs to stable release signing.

### Verification

- `flutter analyze` passes.
- All 5 automated tests pass.
- Android Gradle configuration was parsed successfully; a local APK build could not run because this sandbox has no Android SDK.

## Bifrost v0.7.0+8

### Onboarding and device management

- Added a first-run setup screen for new installations.
- Added device-name setup during first launch.
- Added save-folder setup during first launch.
- Added default save locations:
  - Android: `Download/Bifrost`
  - Windows: `Downloads/Bifrost`
- Added a safe fallback folder when the platform does not allow automatic folder creation.
- Existing installations are migrated without being forced through onboarding again.
- Moved Trusted devices into its own dedicated page.
- Added trusted-device last-seen information.
- Added immediate refresh when opening the Trusted devices page.
- Added confirmation before removing a trusted device.
- Added remove-all trusted devices support.
- Renamed Windows History action from `Open location` to `Open File Location`.
- Fixed Windows Explorer opening the wrong location by passing the exact file path.

### Verification

- `flutter analyze` passes.
- All 5 automated tests pass.

---

## Bifrost v0.6.1+7

### Notification cleanup and History file actions

- Added stable per-transfer notification IDs.
- Progress notifications are removed when a transfer completes, fails, or is cancelled.
- Fixed abandoned progress notifications remaining at an old percentage.
- Fixed multiple old transfer progress bars accumulating in the Android notification area.
- History entries now retain their local file path.
- Added file actions when tapping a History entry:
  - Open
  - Delete from History
  - Open location on Windows
- Phones omit the Windows-only file-location action.
- Deleting from History does not delete the actual file.

---

## Bifrost v0.6.0+6

### Transfer UX and lifecycle polish

- Added live transfer cards to History with percentage progress.
- Added progress reporting for sending and receiving files.
- Added transfer-start feedback.
- Added Trust this device support for automatic approval of trusted senders.
- Added clear-history support.
- Persisted editable device names.
- Prevented multiple Windows app instances from creating duplicate discoverable receivers.
- Improved streaming transfers and progress reporting.

### Stable devices and transfer controls

- Added persistent random device identities separate from editable device names.
- Trusted-device permissions survive app restarts and device reboots.
- Devices with identical names remain separate devices.
- Added sender-side cancellation.
- Added receiver-side cancellation.
- Added cancellation from History.
- Partial files are deleted after cancellation.
- Added Windows drag-and-drop file queuing.
- Added Background receiving toggle.
- Added Android background-ready notification.
- Added trusted-device management controls.
- Sender names are transmitted with offers and refreshed in trusted-device records.

---

## GitHub Release checklist

1. Test the new features for the current version.
2. Open the Bifrost GitHub repository.
3. Select **Releases**.
4. Select **Draft a new release**.
5. Create a tag named `v0.7.0+8`.
6. Set the release title to `Bifrost v0.7.0+8`.
7. Paste the `Bifrost v0.7.0+8` section above into the release description.
8. Upload the source archive: `bifrost-v0.7.0+8.zip`.
9. Do not mark it as the latest release until the focused tests pass.
10. Select **Publish release** after reviewing the title, tag, notes, and attached file.

For the first public release, you can optionally select **This is a pre-release** if you want to label Bifrost as still under testing.
