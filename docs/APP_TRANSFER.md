# App Transfer (Stage 3)

App Transfer is an Android-only, user-initiated app export/install feature. It is intended for personal use with apps the user owns. It copies APK install files and optional OBB files only; it never reads or transfers private app data. Android apps may still refuse to run on another device because of signature, licensing, device, ABI, or Play Integrity restrictions.

## XAPK layout

The generated file is a ZIP with the `.xapk` extension:

```text
manifest.json
apks/base.apk
apks/split_1.apk                 # present for each installed split APK
Android/obb/<package-name>/...   # optional; included only when accessible
```

`manifest.json` contains `package_name` (string), `version_name` (string), `version_code` (integer), `apk_files` (ordered list of APK basenames under `apks/`), and `has_obb` (boolean). XAPK is a transfer container rather than an Android package format understood by PackageInstaller directly. The receiver validates the manifest/path list, extracts APKs into temporary app cache, installs all APKs through one PackageInstaller session, handles Android's pending user-confirmation screen when it is required, then copies any OBB entries to `/Android/obb/<package-name>/`.

## Parent integration API

- Import `lib/features/app_transfer/app_transfer_picker.dart` and show `AppTransferPicker(onXapkReady: (File xapk) async { ... })` from the Android Nearby/send UI.
- In that callback, feed `xapk` to the existing Bifrost/Nearby file-send flow (same queue/client path as ordinary files). Do not add a separate socket sender; that preserves the integrated client's chunked resume/checksum behavior. Use a user-facing remote name ending in `.xapk`.
- Received `.xapk` files should be presented to the Android user as an install/restore action via `AppTransferService().installXapk(File(path))`; catch `AppTransferException`/`PlatformException` and surface its message. The method awaits the PackageInstaller commit result. On Windows, do not invoke the installer: save the incoming file as an ordinary received file so the existing history path records it.
- Sender archives are streamed with bounded memory into the app's `BifrostExports` external-files directory (or app cache if unavailable) and should be retained until the queued send completes; the caller may delete them afterward.

The native bridge is `MethodChannel('bifrost/app_transfer')`, registered by `MainActivity`. It enumerates installed non-system apps, streams APK/OBB content into ZIP entries, validates/extracts XAPK entries with bounded buffers, and installs the APK set; app listing returns source APK paths plus icon PNG bytes. Dart connects the picker and install action to the Nearby queue and History. No separate networking protocol is used.

## Android storage and install behavior

Android 11+ restricts direct access to shared-storage OBB folders. Without **All files access**, Android may hide whether another app has an OBB directory, so the picker requests that permission before export-time OBB discovery and asks the user to retry after returning. With access, it includes matching OBB files when present. Restoring an XAPK with OBB also checks permission before starting PackageInstaller; after the APK session succeeds, Bifrost copies OBB content. If access is unavailable or copying fails, the UI clearly reports the partial or blocked operation. Direct OBB copying can still fail on some devices/ROMs. In that case, users can use Shizuku (with the required authorization and a compatible file manager/helper) to copy the XAPK's `Android/obb/<package>/` contents into the matching shared-storage folder. Bifrost does not silently claim the OBB was restored.

Before PackageInstaller starts, Bifrost checks `REQUEST_INSTALL_PACKAGES` permission and opens the per-app **Install unknown apps** settings if needed. The user must return to Bifrost and retry. Android install failures are returned explicitly; signature conflicts, downgrades, insufficient space, and ABI/architecture mismatches get explanatory messages where Android provides recognizable status details. APK signing keys and device compatibility are not bypassed.

## Test checklist

### Android 11, 13, and 14

- [ ] Verify the sender lists user-installed apps only and displays label, icon, package, version, and size; search and select an app with one APK and another with base plus multiple splits.
- [ ] Export an app with no OBB; inspect the ZIP and confirm valid manifest, base/split APKs, and no app-private data.
- [ ] Export an app with OBB. Deny All files access first and confirm a settings prompt and retry message; grant it and verify all OBB files are present under the package path.
- [ ] Transfer a large XAPK through Nearby while using the existing resumable sender. Interrupt Wi-Fi or close/reopen as applicable, resume, and verify the resulting archive opens and APK contents pass ZIP integrity checks.
- [ ] Receive on Android. Deny **Install unknown apps**, confirm the explicit Settings prompt, return and retry; accept any PackageInstaller confirmation screen and confirm all splits are installed by one session.
- [ ] Test update of the same-signature app, mismatched-signature update, lower version, low-storage device, and incompatible ABI; verify clear failure results and no false success.
- [ ] Restore OBB with All files access granted; deny access and verify the result clearly says APK installation succeeded but OBB copy did not. Test direct-write failure and document/verify the Shizuku workaround on the device.
- [ ] Check Android 13/14 permission dialogs and returning from Settings; check Android 11 storage settings flow. Verify non-Android builds never call the Android native channel.

### Clean Windows machine

- [ ] Receive a `.xapk` from Android; verify Bifrost saves it in `%USERPROFILE%\Downloads\Bifrost` (unless the user chose a different destination) and records it in history as an ordinary file, without trying to install/unpack it.
- [ ] Reopen history and verify filename, size, and location; confirm the saved ZIP opens with a standard archive tool.
- [ ] Install on a clean machine. Confirm the Bifrost logo and cyan-accented wizard, checked desktop and Start-menu shortcut choices, and a checked `Run Bifrost` option on the final page.
- [ ] Test Windows startup default-on and the Settings opt-out; verify sign-in starts Bifrost minimized to tray and disabling the toggle removes the per-user startup entry.
- [ ] Close the window and confirm it stays in the tray; test double-click restore, the right-click `Send files`, `Check for updates`, and `Exit` actions.
- [ ] With Bifrost running, install a newer release. Confirm the running instance closes without the scary “close Bifrost?” prompt and is relaunched after installation; confirm files/history survive.
- [ ] Trigger a startup update notice. Confirm the tray balloon opens Bifrost to an in-app `Install now`/`Later` dialog; `Later` should defer action until a future launch.
- [ ] To pin Bifrost to Start, use Windows Start search → right-click Bifrost → `Pin to Start`; the installer creates a Start-menu shortcut but does not silently modify the pinned-app area.
