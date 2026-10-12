
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
