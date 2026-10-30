# Bifrost 0.14.0 Test Checklist

Run these checks on real devices before publishing. Android 11, 13, and 14 checks should use a clean install where indicated. Keep a second Bifrost device on the same local network for transfer tests.

## Android 11, 13, and 14

### First launch and settings

- [ ] On a fresh install, confirm background receiving is on by default and the receiver starts when permitted.
- [ ] Turn background receiving off, restart Bifrost, and confirm the explicit choice remains off. Turn it back on and confirm it continues receiving after the app moves to the background.
- [ ] On Android 13 and 14, verify notification permission and background-receiving notifications behave correctly. On Android 11, verify the relevant background restrictions and notification behavior.
- [ ] Switch English ↔ Arabic on onboarding and in Settings. Check RTL alignment, the exact Arabic brand spelling `بايفروست`, and the exact language labels `English` and `العربية`.

### Transfers and history

- [ ] Send a small file, a folder containing nested folders, and a file larger than 200 MiB. Verify the receiver gets the expected filenames, sizes, and SHA-256 hashes; confirm progress remains smooth rather than flooding the UI.
- [ ] Interrupt a large transfer by disabling Wi-Fi. Restore the network and use the History retry action; verify the saved transfer resumes from acknowledged chunks and the final file is intact.
- [ ] Stop or force-close the sender during a transfer, reopen Bifrost, and retry the `Interrupted` History record. Verify it resumes rather than starting a duplicate copy.
- [ ] Stop/restart the receiver after it has accepted a transfer and saved chunks. Retry from the sender and verify the receiver resumes the same transfer without asking for approval again.
- [ ] Search History by filename, device name, date, and file extension/type. Combine the file-type and date filters, clear them, and confirm all records reappear.
- [ ] Pin and unpin a nearby device. Confirm pinning changes sort order but does not grant trust or enable automatic acceptance.
- [ ] Use `Send again` for a completed outgoing record and confirm the confirmation prompt appears and the new attempt is recorded separately.

### App transfer and installation

- [ ] On each Android version, list installed user apps and verify name, icon, package, version, and size. Search for an app and export one single-APK app and one app with multiple split APKs.
- [ ] Export an app without OBB data. Inspect the XAPK ZIP and confirm it contains `manifest.json`, the base/split APKs, and no private app data.
- [ ] For an app with OBB data, deny All files access first. Confirm Bifrost explains why access is needed, opens the appropriate Settings page, and lets the user retry after returning. Grant access and verify every OBB file is present under `Android/obb/<package>/`.
- [ ] Transfer a large XAPK through the normal Nearby queue. Interrupt and resume it, then verify the received archive opens and its entries are intact.
- [ ] Receive an XAPK on Android. Deny **Install unknown apps**, confirm Bifrost opens the per-app setting and tells the user to retry, then retry and accept Android's installation confirmation when shown.
- [ ] Confirm all APK splits install in one PackageInstaller session. Test a same-signature update, a different-signature conflict, a lower-version downgrade, low storage, and an unsupported ABI; verify clear errors and no false success.
- [ ] Restore an XAPK with OBB data. Confirm APK installation succeeds before OBB copying begins; test missing All files access and direct-copy failure, then follow the documented Shizuku fallback procedure.

## Clean Windows machine

### Install and startup

- [ ] Install the release on a clean Windows 10 or 11 machine. Confirm the modern wizard shows the Bifrost logo and cyan accents.
- [ ] Confirm `Create a desktop shortcut` and `Create a Start-menu shortcut` are checked by default. On the final page, confirm `Run Bifrost` is checked by default and launches the app when selected.
- [ ] Confirm `Launch Bifrost at startup` is on by default. Sign out and back in; verify the app starts minimized to the tray. Turn the setting off, restart, and verify the startup entry is removed.
- [ ] Close the main window and verify Bifrost remains in the tray. Double-click the tray icon to restore it. Right-click and test `Send files`, `Check for updates`, and `Exit`.
- [ ] To add Bifrost to the pinned Start area, open Start, search for Bifrost, right-click it, and choose `Pin to Start`. Setup creates a regular Start-menu shortcut; the pinned area remains under the user's control.

### Transfer, updates, and recovery

- [ ] Drag a folder and a file larger than 200 MiB from Explorer into Nearby. Confirm each queued item can be removed/reordered and the compact queue opens with its full list.
- [ ] Transfer to and from an Android device. Interrupt Wi-Fi or exit Bifrost during an active send, reopen it, and retry the interrupted History record; verify the final file checksum.
- [ ] Receive an `.xapk` from Android. Verify it is saved in `%USERPROFILE%\Downloads\Bifrost` unless a different folder was selected, appears in History, opens as an archive, and is not installed or unpacked on Windows.
- [ ] Search/filter History by filename, device, date, and file type. Use the History retry/resend actions and verify each attempt has its own record.
- [ ] With Bifrost open, check for a newer release. Confirm the tray notification says an update is available and that clicking it brings Bifrost to the in-app `Install now` / `Later` choices. Choose `Later`, relaunch Bifrost, and confirm the update is offered again.
- [ ] Choose `Install now`. Confirm the cached installer launches, the running Bifrost process closes without an extra “Bifrost is running, close it?” prompt, and Bifrost is relaunched after installation. Confirm settings, received files, and History survive.
- [ ] Repeat the update with Bifrost already minimized in the tray. Verify the installer can still close it and the post-update app opens normally.

## Platform limitation to account for

The Windows installer creates a Start-menu shortcut but does not silently pin Bifrost into the Start menu's pinned area. Windows exposes the pinning action through the user's Start menu; use the manual step above when testing.
