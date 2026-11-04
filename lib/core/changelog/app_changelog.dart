class AppChangelogEntry {
  const AppChangelogEntry({
    required this.version,
    required this.status,
    required this.highlights,
  });

  final String version;
  final String status;
  final List<String> highlights;
}

const appChangelogEntries = <AppChangelogEntry>[
  AppChangelogEntry(
    version: '0.15.2+52',
    status: 'Android + Windows release',
    highlights: [
      'Added a searchable in-app history covering every earlier successful build.',
      'Shows platform coverage and whether each build was published; failed builds are excluded.',
      'Includes successful Android-only and Windows-only builds with clear labels.',
    ],
  ),
  AppChangelogEntry(
    version: '0.15.1+51',
    status: 'Android + Windows release',
    highlights: [
      'New-mode Sunset uses dark menus and white text, while Legacy Sunset keeps its classic look.',
      'Fresh installs now default to Device Time.',
      'Made the Settings glass background slightly more transparent.',
    ],
  ),
  AppChangelogEntry(
    version: '0.15.0+50',
    status: 'Android + Windows release',
    highlights: [
      'Day, Sunset, and Night artwork now themes the entire Android app, not just startup.',
      'Added Legacy Theme to restore the classic painter-based themes; Custom Color is available in legacy mode.',
      'Updated the Windows app and installer icons with the new logo.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.10+48',
    status: 'Android + Windows release',
    highlights: [
      'Replaced the logo in app icons, the Nearby header, and the welcome screen.',
      'Added Day, Sunset, and Night Android startup artwork with a Legacy Theme option.',
      'Added a darker translucent blur behind Settings for readability.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.9+47',
    status: 'Android + Windows release',
    highlights: [
      'Refined the Nearby screen and personal app-transfer picker experience.',
      'Updated localized copy and Windows window/drop behavior as part of the transfer UX pass.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.8+46',
    status: 'Android + Windows release',
    highlights: [
      'Fixed installation of split-APK archives received or prepared through Android app sharing.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.6+44',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Fixed split-APK transfer handling and smoothed transfer progress updates.',
      'Simplified the app-picker flow and improved resumable-transfer handling.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.5+43',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Reworked Windows Explorer file/folder drops and fixed the Start-menu shortcut behavior.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.4+42',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Successful version/build refresh; no additional user-facing feature change was recorded for this build.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.3+41',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added automatic OBB detection and optional inclusion when preparing Android apps.',
      'Added automatic, 3-column, and 4-column app-picker grids.',
      'Replaced Windows WM_DROPFILES handling with native OLE drag-and-drop for files and folders.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.2+40',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Improved Windows tray-instance launching, installer replacement, and file/folder drop routing.',
      'Added total file size to transfer details and made Android progress/background notifications dismissible.',
      'Prevented late transfer-progress notifications from reappearing after cancellation.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.1+39',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added multi-app selection, searchable filters, and grid/list layouts to the Android app picker.',
      'Added optional OBB inclusion and preparation progress; cleaned up generated app exports.',
      'Send eligible single APKs directly without wrapping them in XAPK archives.',
    ],
  ),
  AppChangelogEntry(
    version: '0.14.0+38',
    status: 'Android + Windows release',
    highlights: [
      'Added resumable chunk transfers with per-chunk checksums and restart recovery.',
      'Added Android personal-app transfer and import/export support.',
      'Corrected Android split-package and Windows installer paths.',
    ],
  ),
  AppChangelogEntry(
    version: '0.13.6+37',
    status: 'Android + Windows release',
    highlights: [
      'Rate-limited progress notifications while preserving final byte counts, including for large transfers.',
      'Added a compact reorderable/removable transfer-queue dialog and folder-drop expansion.',
      'Added Windows minimize-to-tray actions.',
    ],
  ),
  AppChangelogEntry(
    version: '0.13.5+36',
    status: 'Android + Windows release',
    highlights: [
      'Standardized the Arabic Bifrost brand wording and corrected the background activity description.',
      'Restored nearby discovery after Wi-Fi/hotspot interface changes and allowed failed server startup to retry.',
    ],
  ),
  AppChangelogEntry(
    version: '0.13.4+35',
    status: 'Android + Windows release',
    highlights: ['Updated the About credit wording in English and Arabic.'],
  ),
  AppChangelogEntry(
    version: '0.13.3+34',
    status: 'Windows-only build (not published)',
    highlights: [
      'Corrected requested Arabic wording in the splash, About, and background-activity text.',
      'Fixed dragging in the custom text-color picker.',
    ],
  ),
  AppChangelogEntry(
    version: '0.13.2+33',
    status: 'Android + Windows release',
    highlights: [
      'Caches downloaded update packages and reuses a matching version instead of downloading again.',
      'Added install-ready prompts and installer opening from notifications or Settings; removes cached packages after install.',
    ],
  ),
  AppChangelogEntry(
    version: '0.13.1+32',
    status: 'Android + Windows release',
    highlights: [
      'Corrected Arabic splash, About, and background-receiving text.',
      'Fixed hue dragging in the text-color picker.',
    ],
  ),
  AppChangelogEntry(
    version: '0.13.0+31',
    status: 'Android + Windows release',
    highlights: [
      'Added English and Arabic language selection during setup and in Settings.',
      'Added Arabic UI copy and right-to-left layout support.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.7+30',
    status: 'Android + Windows release',
    highlights: [
      'Fixed app version reporting and version comparisons in the updater.',
      'Synchronized the displayed, packaged, and update-check versions.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.7+29',
    status: 'Android + Windows release',
    highlights: [
      'Restored the radar icon in the bottom Nearby navigation tab.',
      'Kept the supplied artwork in the Nearby header and app icons.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.6+28',
    status: 'Android + Windows release',
    highlights: [
      'Refreshed the Android and Windows application icons with the supplied artwork.',
      'Updated the Nearby screen branding to match the app icon.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.5+27',
    status: 'Android + Windows release',
    highlights: [
      'Updated the app icon artwork and Nearby instructions.',
      'Kept the EFOMA credit in the About dialog.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.0+26',
    status: 'Android + Windows release',
    highlights: [
      'Added theme defaults and cross-platform Bifrost package sharing.',
      'Expanded Android sharing and Windows installer/package delivery support.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.0+25',
    status: 'Android + Windows release',
    highlights: [
      'Integrated the first Android-to-Windows and Windows-to-Android transfer prototype.',
      'Included Nearby discovery, manual-IP fallback, file selection, Accept/Decline, streaming, and SHA-256 verification.',
      'Persisted device/save settings and recorded transfer history with progress and Android notifications.',
    ],
  ),
  AppChangelogEntry(
    version: '0.12.0+23',
    status: 'Android + Windows release',
    highlights: [
      'Established the cross-platform local-transfer baseline with Nearby, History, and Settings.',
      'Added file selection, incoming Accept/Decline, streaming transfers, and SHA-256 verification.',
    ],
  ),
  AppChangelogEntry(
    version: '0.11.3+21',
    status: 'Android + Windows release',
    highlights: [
      'Improved the in-app update service and its Android progress notifications.',
      'Refined the update flow for downloading and installing versioned releases.',
    ],
  ),
  AppChangelogEntry(
    version: '0.11.3+20',
    status: 'Android + Windows release',
    highlights: [
      'Stabilized Android and Windows release-build workflows and package versioning.',
      'No standalone user-facing feature change was recorded for this build.',
    ],
  ),
  AppChangelogEntry(
    version: '0.11.3+19',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Improved transfer-notification handling and Android/Windows release-workflow setup.',
      'Included integration-build reliability changes; no separate feature summary was published.',
    ],
  ),
  AppChangelogEntry(
    version: '0.11.2+18',
    status: 'Android + Windows pre-release',
    highlights: [
      'Added in-app update checks from GitHub Releases, APK download/installation, and Windows installer download/launch.',
      'Added release notes and an update-available indicator in Settings.',
      'Added semantic version comparison and clearer update/download status messages.',
    ],
  ),
  AppChangelogEntry(
    version: '0.11.1+17',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added Device Time, Custom Color atmosphere, text-color presets, and hex color entry.',
      'Improved the Nearby header artwork and splash glow; themes now follow device time automatically.',
    ],
  ),
  AppChangelogEntry(
    version: '0.10.3+15',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added a pressable About section with EFOMA/Manus AI credit, app version, platform targets, and project information.',
    ],
  ),
  AppChangelogEntry(
    version: '0.10.2+14',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Replaced the blurry launcher-icon source with high-resolution artwork and regenerated Android/Windows icons.',
    ],
  ),
  AppChangelogEntry(
    version: '0.10.0+12',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Introduced illustrated Day, Sunset, and Night themes with saved theme selection.',
      'Added a themed startup splash and the original Bifrost launcher branding.',
    ],
  ),
  AppChangelogEntry(
    version: '0.9.0+11',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added Android Share support, multi-file queues, and Windows Explorer “Send with Bifrost”.',
      'Added transfer retry/details, per-file states, batch summaries, and APK-aware install actions in History.',
    ],
  ),
  AppChangelogEntry(
    version: '0.8.0+10',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added retries for temporary socket, HTTP, and timeout failures.',
      'Displayed measured transfer speed and estimated time remaining in Nearby and History.',
    ],
  ),
  AppChangelogEntry(
    version: '0.7.0+9',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Migrated older installations into setup when a save folder was missing.',
      'Fixed Windows Explorer file-location opening and enabled stable Android release signing through CI secrets.',
    ],
  ),
  AppChangelogEntry(
    version: '0.7.0+8',
    status: 'Android + Windows pre-release',
    highlights: [
      'Added first-run setup for device name and save-folder location, with safe defaults and migration support.',
      'Added a dedicated Trusted Devices page with last-seen data, refresh, remove, and remove-all controls.',
      'Improved Windows History’s Open File Location action.',
    ],
  ),
  AppChangelogEntry(
    version: '0.6.1+7',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Cleaned up Android progress notifications when transfers finish, fail, or are cancelled.',
      'Added History actions to open files, remove entries, and open their Windows location.',
    ],
  ),
  AppChangelogEntry(
    version: '0.6.0+6',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added live transfer cards, progress, cancellation, and partial-file cleanup.',
      'Added persistent device identities, trusted-device management, and background receiving.',
      'Added a Windows drop zone and expanded transfer/History controls.',
    ],
  ),
  AppChangelogEntry(
    version: '0.5.0+5',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Expanded local device/storage preferences, discovery, incoming-offer handling, and transfer notifications.',
      'Improved the cross-platform transfer path and persisted device names and save locations.',
    ],
  ),
  AppChangelogEntry(
    version: '0.4.0+4',
    status: 'Android + Windows build only (not published)',
    highlights: [
      'Added the Windows GitHub Actions build workflow.',
      'Improved nearby discovery, incoming transfer offers, and Android/Windows networking integration.',
    ],
  ),
  AppChangelogEntry(
    version: '0.3.0+3',
    status: 'Android-only build (not published)',
    highlights: [
      'Added local-network device discovery and the Nearby device list.',
      'Introduced device runtime and network-connection diagnostics.',
    ],
  ),
  AppChangelogEntry(
    version: '0.2.0+2',
    status: 'Android-only build (not published)',
    highlights: [
      'Added the first transfer protocol, networking client/server, and SHA-256 checksum support.',
      'Added a network test screen and protocol documentation.',
    ],
  ),
  AppChangelogEntry(
    version: '0.1.0+1',
    status: 'Android-only build (not published)',
    highlights: [
      'Established the Flutter app shell, Bifrost theme, and Nearby/History/Settings navigation.',
      'Added the first Android APK CI build; this milestone did not yet include network transfer.',
    ],
  ),
];
