# Testing Bifrost — Milestone 1

## Automated checks

The GitHub Actions workflows run `flutter analyze`, `flutter test`, and a release build. A green workflow means the source passes the automated checks on the runner; it does not prove that a real phone and PC can communicate yet.

## Manual smoke test

1. Install the generated Android APK on an Android 8.0+ phone.
2. Open Bifrost. Confirm that the app opens without a crash.
3. Confirm that the Nearby screen shows the Bifrost header, a radar-style panel, and a **Send files** button.
4. Tap **History**. Confirm that the empty history screen appears.
5. Tap **Settings**. Toggle **Dark theme** off and on. Confirm the colors change.
6. On Windows, run the portable build. Confirm that the same three screens open and resize normally.

## Not verified in this milestone

- Real discovery or file transfer.
- Android permissions, share sheet, foreground service, and MediaStore.
- Windows tray, drag-and-drop, firewall, installer registration, and context menu.
- Background operation, large files, checksums, pairing, and encryption.
- Testing on the user's real phone or Windows PC.
