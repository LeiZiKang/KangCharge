# Kang Charge

**English** | [简体中文](README.zh-CN.md)

**A native macOS control center for CANDYSIGN (制糖工厂) CoCan / 小电拼 smart chargers**: live power, per-port switches, charging modes, thermal mode and the status display, plus a menu bar panel and desktop widgets.

Kang Charge is an unofficial, third-party app. It talks to the charger through CANDYSIGN's official MCP endpoint, so there is nothing to flash or modify on the device.

[Features](#features) · [Install](#install) · [First-time setup](#first-time-setup) · [Privacy & security](#privacy--security) · [How it works](#how-it-works)

![Main window](docs/screenshots/dashboard.png)

> Screenshots use built-in sample data, not readings from a real device. The app UI is currently in Simplified Chinese.

## Features

- **Live overview**: power, voltage, current, fast-charge protocol and chip temperature for all five ports, drawn as the "port → cable → charger" diagram from the official app.
- **Controls**: turn individual ports on or off (you are asked to confirm before cutting power to a port that is charging), switch charging mode (FluxAI free-flow, sleep, small-appliance, lossless, C1 exclusive), switch thermal mode (power first / temperature first), and set a temporary power allocation.
- **Port details**: negotiated USB PD profile, PPS/EPR support, cable e-marker info, and the power history stored in the charger's memory.
- **Status display**: brightness, display mode, idle animation and hourly chime (the last three are CP-02S / Mirror only).
- **Menu bar**: total power always visible in the menu bar; click it to toggle ports or switch modes.
- **Desktop widgets**: small, medium and large. The large widget has buttons to switch ports on and off directly.
- **Shortcuts**: "Refresh status", "Switch charging strategy" and "Turn port on/off" actions for the Shortcuts app.

| Port details | Menu bar |
| --- | --- |
| ![Port details](docs/screenshots/port-sheet.png) | ![Menu bar](docs/screenshots/menubar.png) |

| Small | Medium | Large |
| --- | --- | --- |
| ![Small widget](docs/screenshots/widget-small.png) | ![Medium widget](docs/screenshots/widget-medium.png) | ![Large widget](docs/screenshots/widget-large.png) |

## Requirements

- macOS 14 Sonoma or later
- A CANDYSIGN CoCan charger that is online over Wi-Fi and paired in the CANDYSIGN app
- That charger's **MCP server URL** (see [First-time setup](#first-time-setup))
- To build from source: Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Tested mainly on the **CoCan Mirror (CP-02S, 5 ports, 160 W)**. Other models that expose the same MCP tools should work too; the port count and power limits are read from the device.

## Install

For now you need to build from source. Signed and notarized builds will be published under [Releases](../../releases).

```bash
git clone https://github.com/LeiZiKang/KangCharge.git
cd KangCharge
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Edit `Config/Local.xcconfig` and set your own Apple developer Team ID and bundle ID prefix (a free personal team works):

```
DEVELOPMENT_TEAM = ABCDE12345
BUNDLE_ID_PREFIX = com.yourname
```

Then generate the project and build:

```bash
xcodegen generate
open KangCharge.xcodeproj   # choose the KangCharge scheme and press ⌘R
```

Or build and install from the command line:

```bash
xcodebuild -scheme KangCharge -configuration Release -derivedDataPath build/DD build
cp -R "build/DD/Build/Products/Release/Kang Charge.app" /Applications/
```

> The desktop widgets need code signing and an App Group (`<TeamID>.<bundle prefix>.kangcharge`), so a Team ID is required. If Xcode isn't signed in to an Apple ID on the command line, add `CODE_SIGN_STYLE = Manual` to `Local.xcconfig` to sign with the Apple Development certificate in your keychain.

## First-time setup

1. In the CANDYSIGN app, open your charger's **MCP** settings and copy its MCP server URL. It looks like this:
   ```
   https://mcp.thecandysign.com/<device serial>/<access token>/sse
   ```
2. Open Kang Charge, paste the URL into the setup screen, optionally give the charger a name, and click **连接** (Connect).
3. Kang Charge reads the device info once to confirm the URL works, then opens the main window.

You can change the URL or disconnect later in **Kang Charge → Settings (⌘,)**.

### Adding a desktop widget

Right-click an empty area of the desktop → **Edit Widgets**, search for "Kang Charge" and drag a widget onto the desktop. Widgets refresh about every 5 minutes, and sooner while the app is open.

## Privacy & security

- The MCP URL contains your **device serial number and access token**. Anyone who has it can control your charger. Treat it like a password: don't share screenshots of it and never commit it to a repository.
- Kang Charge stores the URL only on your Mac, in the sandboxed App Group shared by the app and its widget. This repository contains no default URL.
- The app only talks to the MCP server you enter. There is no analytics and no third-party service.
- **断开并清除数据** (Disconnect and clear data) in Settings deletes the URL and all cached data.

## Good to know

- **Turning a port off cuts its power immediately.** The app asks for confirmation before turning off a port that is charging.
- **Small-appliance mode** power-cycles the C4 port. **C1 exclusive** turns off every other port.
- The MCP endpoint can set the charging strategy but **cannot report the current one**. The highlighted mode is the last one you picked in Kang Charge; changes made in the official app are not reflected.
- Data goes through CANDYSIGN's cloud, so updates take 1–3 seconds. When the charger is offline, the last cached reading is shown.

## How it works

The charger connects to CANDYSIGN's cloud over Wi-Fi (MQTT). The cloud's `ionbridge-mcp` service exposes the charger as 18 [MCP](https://modelcontextprotocol.io) tools. Kang Charge includes a small MCP client that uses the HTTP + SSE transport:

1. `GET …/sse` opens an event stream and receives an `endpoint` event (a POST URL with a session ID).
2. JSON-RPC requests (`initialize`, `tools/call`, …) are POSTed there; results come back on the SSE stream and are matched by request ID.
3. The client reconnects automatically when the stream drops or the session expires.

A few fields need converting: port power = `vout_mv × iout_ma ÷ 10⁶` W; bit n−1 of `status_bitmask` means port n is on; PD `operating_voltage` / `operating_current` are in units of 10 mV / 10 mA.

```
Shared/            Code shared by the app and the widget
  MCPClient.swift    SSE transport, JSON-RPC request matching, reconnects
  ChargerAPI.swift   Typed tool wrappers, local settings and snapshot cache
  Models.swift       Response types and mode definitions
  Intents.swift      App Intents (widget buttons and Shortcuts)
  CableDiagram.swift Port chips + cables + charger diagram
  Theme.swift        Colors and shared components
App/               Main window, menu bar, settings, first-run setup, polling state
Widget/            TimelineProvider and the three widget sizes
Config/            xcconfig files: signing and bundle IDs (personal values go in Local.xcconfig)
scripts/           Icon generator, README screenshots, release script
```

## Development

- `scripts/screenshots.sh` renders the README screenshots from built-in sample data; no device needed.
- Debug builds accept the launch arguments `-kcDemo YES` (sample data, no network) and `-kcSnapshot YES` (renders the UI to PNG files).
- `scripts/release.sh` builds a Developer ID–signed, notarized zip for a GitHub release.
- After editing `project.yml`, run `xcodegen generate` again.

Issues and pull requests are welcome, especially test reports from other models (CP-02 and others).

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by CANDYSIGN (制糖工厂). "CANDYSIGN", "制糖工厂", "小电拼", "CoCan" and "FluxAI" are trademarks of their respective owners. The interface follows the look of the official app so that it feels familiar. You use this software to control your device at your own risk.

## License

[MIT](LICENSE)
