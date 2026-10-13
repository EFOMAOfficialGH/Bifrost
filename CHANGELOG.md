
## 0.6.0 — Transfer UX and lifecycle polish

- Added live transfer cards to the History tab with percentage progress for sending and receiving files.
- Added an immediate transfer-start snackbar on the sender and receiver.
- Added a Trust this device option on incoming offers so future offers from that device can be accepted automatically.
- Added a clear-history action.
- Persisted device names into the Settings field after app restart.
- Made Windows receiver instances use a fixed port so opening the PC app a second time does not create another discoverable receiver.
- Switched the sender back to a typed streaming pipeline so progress reporting does not require the slower manual request loop.

## 0.6.0 — Stable devices and transfer controls

Bifrost now creates a random device identity once and stores it separately from the editable device name. Two devices with the same name remain different devices, and trusted-device permissions survive an app restart or reboot.

Transfers can be cancelled from the sender while they are running. The cancellation is sent to the receiving device, partial files are deleted, and the History entry is marked Cancelled. Windows also has a drop zone for queuing files before choosing a nearby device.

Settings now includes a Background receiving toggle, a persistent Android ready notification while that mode is enabled, and a Trusted devices list with individual removal. Sender names are transmitted with offers so trusted entries can be labeled and refreshed when a device renames itself.

## 0.6.1+7 — Notification cleanup and file actions

Progress notifications now use stable per-transfer IDs and are explicitly removed when a transfer completes, fails, or is cancelled. This prevents abandoned progress bars from accumulating.

History entries now retain their local file path. Tapping an entry offers Open, Delete from History, and Open location on Windows. Phones omit the location option.

## 0.7.0+8 — Onboarding and device management

New installations now receive a first-run setup screen for choosing a device name and granting or changing the save-folder location. The default is Download/Bifrost on Android and Downloads/Bifrost on Windows, with a safe fallback if the platform does not permit automatic folder creation.

Trusted devices now live on their own management page with last-seen information, immediate refresh, confirmation before removal, and remove-all support. Windows History now labels the action Open File Location and passes Explorer the exact selected file path.

## 0.7.0+9 — Setup migration, Explorer selection, and Android updates

Older installations that have a device name but no configured save folder now receive the setup screen. Windows Open File Location now invokes Explorer through its command shell with the exact quoted file path. Android release builds now support stable keystore signing through GitHub Actions secrets, allowing future APKs to update in place after one migration install.

## 0.8.0+10 — Transfer resilience and speed visibility

Temporary socket, HTTP, and timeout failures now retry up to three times with a short backoff. Deliberate cancellation and receiver rejection still stop immediately. Nearby and live History cards now show measured transfer speed and estimated time remaining. The Android workflow also uses a parser-safe environment-variable condition for stable signing secrets.

## 0.9.0+11 — Native sharing and transfer polish

- Added Android Share menu support for single and multiple files.
- Added Android shared-file queue handling with safe temporary copies.
- Added Windows Explorer Send with Bifrost installer integration.
- Added APK-aware Install APK History action with the correct Android MIME type.
- Added missing-file warnings and stale History cleanup.
- Added per-file queue states: Queued, Sending, Completed, Failed, and Cancelled.
- Added peer address persistence for failed sent transfers.
- Added Retry transfer from History for failed sent files.
- Added transfer details dialog with status, device, size, time, speed, and path.
- Added batch completion summaries while keeping failed files queued.
- Added speed and ETA to Android progress notifications.
- Improved Windows Open File Location invocation and user feedback.
- Standardized visible Android and Windows app naming as Bifrost.

## 0.10.0+12 — Bifrost sky themes and branding

Bifrost now has three illustrated visual themes: Day with blue sky, clouds, and sunlight; Sunset with amber-orange sky, clouds, and a setting sun; and Night with deep blue sky, stars, and moonlight. The selected theme is saved across launches and can be changed from Settings.

A short startup splash now appears each time Bifrost opens, matching the active theme and showing the requested bold Bifrost title, tagline, and faint glow.

The supplied Neon Crystal Bridge icon is registered as a Flutter asset and generated into Android launcher icons and the Windows executable icon.

## 0.10.1+13 — Custom splash typography

- Added the supplied Mistical Spring font to the application assets.
- Applied Mistical Spring to the themed Bifrost startup title.
- Kept the tagline in a bold readable system font for clarity.

## 0.10.2+14 — High-resolution launcher icon

- Replaced the blurry 32×32 ICO source with the provided 646×648 Lightshot artwork.
- Cropped it to a clean square source and regenerated Android adaptive icons and the Windows executable icon.
