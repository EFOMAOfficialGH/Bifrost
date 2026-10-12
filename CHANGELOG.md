
## 0.6.0 — Transfer UX and lifecycle polish

- Added live transfer cards to the History tab with percentage progress for sending and receiving files.
- Added an immediate transfer-start snackbar on the sender and receiver.
- Added a Trust this device option on incoming offers so future offers from that device can be accepted automatically.
- Added a clear-history action.
- Persisted device names into the Settings field after app restart.
- Made Windows receiver instances use a fixed port so opening the PC app a second time does not create another discoverable receiver.
- Switched the sender back to a typed streaming pipeline so progress reporting does not require the slower manual request loop.
