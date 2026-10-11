# Bifrost architecture

## Current milestone

Milestone 1 establishes the Flutter application boundary and the user-facing navigation shell. It deliberately contains no networking, file access, permissions, or transfer code.

## Planned layers

- `lib/core/` — networking, protocol, crypto, errors, and shared theme utilities. This layer must not import UI screens.
- `lib/features/discovery/` — mDNS, UDP fallback, manual IP, QR connection, and troubleshooting.
- `lib/features/send/` — file selection, offers, streaming, progress, and cancellation.
- `lib/features/receive/` — incoming requests, safe saving, and background receiving.
- `lib/features/history/` — local transfer history.
- `lib/features/settings/` — device name, folders, theme, pairing, and preferences.
- `lib/ui/` — shared widgets, design tokens, and localization.

## State management

Riverpod is used for application state because providers can be tested without rendering the whole app. Network services will be injected into providers rather than created inside widgets.

## Platform targets

- Android: minimum API 26 (Android 8.0).
- Windows: Windows 10/11 desktop build.
- iOS and macOS are out of scope for this project.
