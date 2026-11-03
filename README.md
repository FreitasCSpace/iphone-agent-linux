# iPhone Agent for Linux — no Mac needed

**Let an AI drive a real iPhone with a ~$7 ESP32-S3 board, set up entirely from Linux. No Mac, no Xcode, no jailbreak.**

> Built on **[ESP32 iPhone Agent by Henry Yuan](https://github.com/onehumanbeing/esp32-iphone-agent)** (MIT).
> All of the firmware, the `esp32agent` CLI and the protocol are his work; this repository adds a Linux-first setup
> and documents the path that never touches a Mac. Original README: [README.upstream.md](README.upstream.md).

## Why this exists

The upstream quick start says you need a *Mac with Xcode* to flash the board and build the iOS app. You don't, if
your computer is the brain instead of the iOS app:

| | Upstream (app mode) | This repo (PC mode) |
|---|---|---|
| Flash the board | Mac | **Linux** (x86_64 or arm64) |
| Agent runs on | iOS app (build with Xcode) | **your computer** — `esp32agent` CLI / MCP server |
| AI | OpenAI-compatible vision API in the app | **Claude Code, Codex, or any MCP client** |
| iOS app | required | **not needed** |

```
iPhone ──Screen Mirroring (Wi-Fi)──▶ ESP32-S3 board ──Bluetooth LE──▶ Linux PC: esp32agent ⇄ Claude Code (MCP)
   ▲                                                                              │
   └────────────── USB mouse + keyboard (AssistiveTouch) ◀────────────────────────┘
```

## What you need

- **ESP32-S3 with native USB and 8 MB PSRAM**, e.g. Seeed Studio XIAO ESP32S3 (plain, not Sense/Plus).
- **iPhone** on iOS 18+, with cellular data (its Wi-Fi joins the board's hotspot). USB-C plugs in directly; Lightning
  needs a Lightning to USB Camera Adapter.
- **Linux PC** with Bluetooth LE (BlueZ), `curl`, `ffmpeg`. Tested on Arch Linux aarch64.

## Quick start

```bash
git clone https://github.com/FreitasCSpace/iphone-agent-linux && cd iphone-agent-linux
scripts/setup-linux.sh        # board plugged into the PC; asks for sudo once (udev rule)
```

The script installs arduino-cli, the ESP32 core 3.3.12 and NimBLE-Arduino 2.5.1, the `esp32agent` binary (each
release download checked against its SHA-256), adds a udev rule for Espressif serial ports, and flashes the firmware.

Then:

```bash
esp32agent pair               # within 3 minutes of the board powering up
```

1. iPhone: **Settings → Accessibility → Touch → AssistiveTouch** on.
2. Plug the board into the iPhone.
3. iPhone: join the Wi-Fi **ESP32Agent-XXXX**, then **Control Center → Screen Mirroring → ESP32 Agent**.
4. `esp32agent screenshot --output phone.png` — you should see the phone's screen.

Hand it to Claude Code:

```bash
claude mcp add esp32agent -- esp32agent mcp
```

and ask: *"Open Settings on my iPhone and go to Wi-Fi."*

## Gotchas we hit (so you don't)

- **Flash the v1.0.0 firmware, not upstream `main`.** The CLI pairing (`cli_link.cpp`) only exists on the `v1.0.0` tag,
  which is not in upstream `main`'s history. With `main`'s firmware the board advertises over Bluetooth but
  `esp32agent pair` says *board not found*. This repo is based on `v1.0.0`.
- **`/dev/ttyACM0` permission denied** — the port belongs to `uucp`/`dialout`. The udev rule in the setup script fixes
  it without logging out.
- **Board stuck in the ROM bootloader** (shows as *USB JTAG/serial debug unit*, `flash.sh` says the port is busy) —
  upload directly; the setup script prints the command.
- **`pair` says board not found** — the pairing window is the first 3 minutes after the board powers up. Unplug,
  replug, run `pair` right away.

## Want the standalone iOS app instead?

That mode still needs Xcode to build the app — see [README.upstream.md](README.upstream.md).

## Responsible use

Only automate devices and accounts you own or may use. The agent acts with your hands: watch it.

## License

[MIT](LICENSE) — Copyright (c) 2026 Henry Yuan. `hardware/hid_bridge/src/airplay/` is ported from
[UxPlay](https://github.com/FDH2/UxPlay) under its own license (see the upstream README). Linux setup additions by
[FreitasCSpace](https://github.com/FreitasCSpace).
