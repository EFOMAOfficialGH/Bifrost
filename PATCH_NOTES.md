# Bifrost Patch Notes

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
