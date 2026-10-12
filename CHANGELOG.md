# Changelog

## 0.5.0 — Progress, storage, notifications, and history

- Added a configurable and persisted receive directory through the Settings screen.
- Added persistent local transfer history for completed and failed sends and received files.
- Added in-app byte progress while sending files.
- Added Android transfer notifications with percentage progress and completion status.
- Added receiver-side progress callbacks for notification updates.
- Kept the cross-platform Android↔Windows Accept/Decline transfer flow intact.
- Source analysis and all automated tests pass; Android release packaging must run through GitHub Actions because the local sandbox has no Android SDK.

## 0.4.0 — Android↔Windows integration prototype

- Verified bidirectional Android-to-Windows and Windows-to-Android transfers over the local network.
- Verified device discovery, file selection, incoming Accept/Decline, streaming, and checksum verification.
- Recorded current limitations: save location is not configurable, transfer progress has no visible progress bar, Android progress is not shown in notifications, notifications are not instant or reliable in the background, and Transfer History is not implemented.

## 0.1.0 — Milestone 1

- Created Flutter Android and Windows project.
- Set Android application ID to `com.bifrost.app`.
- Set Android minimum SDK to API 26.
- Added Riverpod state-management foundation.
- Added Bifrost dark/light theme and starter mark.
- Added Nearby, History, and Settings navigation shell.
- Added beginner-friendly README and architecture/testing notes.
- Added GitHub Actions workflows for Android and Windows builds.
