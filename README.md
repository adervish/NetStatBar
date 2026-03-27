# WiFi Scout

macOS menu bar app that monitors your Wi-Fi and internet connection in real time.

- **Color-coded dot** — green → yellow → red based on latency and packet loss
- **Public & private IP**, ISP, latency, and packet loss at a glance
- **Wi-Fi details** — SSID, BSSID, RSSI, channel, band, and channel width
- **Ping history** — graph and timestamped log; BSSID changes highlighted in bold to catch roaming events
- **Ethernet aware** — shows N/A for Wi-Fi fields when connected via wired interface
- **Local SQLite database** — every measurement logged; export to TSV for analysis in Excel or Numbers
- **Preferences** — configurable ping target, interval, and database size limit

## Install

1. Download **[NetStatBar.zip](https://github.com/adervish/NetStatBar/releases/latest/download/NetStatBar.zip)**
2. Unzip and drag `NetStatBar.app` to your `/Applications` folder
3. Double-click to launch

The app has no dock icon — look for the colored dot in your menu bar.

**First launch:** grant Location permission when prompted. This is required by macOS to read the BSSID of your access point.

## Build from source

Requires macOS 13+ and Swift.

```bash
git clone https://github.com/adervish/NetStatBar.git
cd NetStatBar
./build.sh          # dev build for local testing
./build.sh github   # Developer ID build + notarization
./build.sh appstore # App Store distribution build
```

## Requirements

- macOS 13 or later
- The Cloudflare Worker (in `cf-browser-info/`) must be deployed for public IP/ISP lookup
