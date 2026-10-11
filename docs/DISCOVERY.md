# Discovery in Milestone 3

Bifrost now has a local UDP discovery fallback. A running Bifrost receiver listens on UDP port 43820. A client broadcasts a small versioned request, and receivers answer with their device name, type, and HTTP port. This works on ordinary Wi-Fi and can work on phone hotspots when the hotspot permits client-to-client traffic.

The Nearby screen refreshes discovery automatically, lists device type and address, and offers manual IP and port entry when broadcasts are blocked. The troubleshooting screen explains guest Wi-Fi, client isolation, VPNs, and Windows firewall/network profile issues.

A QR connection code is shown for each discovered device in the format `bifrost://IP:PORT`. This milestone implements displaying and manually entering the connection details. Camera scanning is intentionally deferred until the Android camera permission and Windows camera behavior are designed together; the QR payload is already version-independent and ready for that scanner.
