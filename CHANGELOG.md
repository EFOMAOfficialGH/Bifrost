
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
