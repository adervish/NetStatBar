# NetStatBar

macOS menu bar app that monitors your internet connection in real time.

- **Color-coded icon** — green → yellow → red based on ping quality over the last 10 seconds
- **Click the icon** to see your public IP, ISP, latency, and packet loss (fetched live)
- **View Full Details** — opens full network info JSON in your browser

## Install

1. Download **[NetStatBar.zip](https://github.com/adervish/NetStatBar/raw/main/NetStatBar.zip)**
2. Unzip it
3. Drag `NetStatBar.app` to your `/Applications` folder
4. Double-click to launch

> **First launch only:** macOS will warn the app is from an unidentified developer.
> Right-click (or ctrl-click) `NetStatBar.app` and choose **Open**, then click **Open** again.

The app has no dock icon — look for the colored circle in your menu bar.

## Build from source

Requires macOS 12+ and Swift.

```bash
git clone https://github.com/adervish/NetStatBar.git
cd NetStatBar
./build.sh
open NetStatBar.app
```

## Requirements

- macOS 12 or later
- The Cloudflare Worker (in `cf-browser-info/`) must be deployed for IP/ISP lookup
