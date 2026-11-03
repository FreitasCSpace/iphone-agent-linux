#!/usr/bin/env bash
# One-shot setup on Linux (x86_64 or arm64): toolchain, serial access, firmware, esp32agent CLI.
# Usage: scripts/setup-linux.sh [--no-flash]
# Every download is an official GitHub release checked against its published SHA-256.
set -euo pipefail
cd "$(dirname "$0")/.."

ARDUINO_CLI_VERSION=1.5.1
ESP32_CORE=3.3.12
NIMBLE=2.5.1
ESP32AGENT_VERSION=0.1.0
BIN="$HOME/.local/bin"
FLASH=1
[[ ${1:-} == --no-flash ]] && FLASH=0

case $(uname -m) in
  x86_64) ACLI_ARCH=64bit; GOARCH=amd64 ;;
  aarch64|arm64) ACLI_ARCH=ARM64; GOARCH=arm64 ;;
  *) echo "unsupported CPU: $(uname -m)"; exit 1 ;;
esac
need() { command -v "$1" >/dev/null || { echo "missing: $1 ($2)"; exit 1; }; }
need curl "install curl"; need sha256sum "coreutils"; need ffmpeg "needed for screenshots"
need bluetoothctl "install bluez and start bluetooth.service"
mkdir -p "$BIN"; export PATH="$BIN:$PATH"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# fetch <repo> <tag> <asset> <checksums-file>: download a release asset and verify it
fetch() {
  local base="https://github.com/$1/releases/download/$2"
  curl -fsSL -o "$TMP/$3" "$base/$3"
  curl -fsSL -o "$TMP/sums.txt" "$base/$4"
  (cd "$TMP" && grep -E "[ *]$3\$" sums.txt | sha256sum -c -)
}

echo "==> arduino-cli $ARDUINO_CLI_VERSION"
if ! arduino-cli version 2>/dev/null | grep -q "$ARDUINO_CLI_VERSION"; then
  a="arduino-cli_${ARDUINO_CLI_VERSION}_Linux_${ACLI_ARCH}.tar.gz"
  fetch arduino/arduino-cli "v$ARDUINO_CLI_VERSION" "$a" "arduino-cli_${ARDUINO_CLI_VERSION}_checksums.txt"
  tar -xzf "$TMP/$a" -C "$TMP" arduino-cli && install -m755 "$TMP/arduino-cli" "$BIN/"
fi

echo "==> ESP32 core $ESP32_CORE + NimBLE-Arduino $NIMBLE"
arduino-cli config init --overwrite >/dev/null
arduino-cli config add board_manager.additional_urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core update-index >/dev/null
arduino-cli core install "esp32:esp32@$ESP32_CORE"
arduino-cli lib install "NimBLE-Arduino@$NIMBLE"

echo "==> esp32agent CLI $ESP32AGENT_VERSION"
a="esp32agent_linux_${GOARCH}.tar.gz"
fetch onehumanbeing/esp32-iphone-agent "cli-v$ESP32AGENT_VERSION" "$a" checksums.txt
tar -xzf "$TMP/$a" -C "$TMP" esp32agent && install -m755 "$TMP/esp32agent" "$BIN/"

echo "==> serial access to Espressif boards (udev, needs sudo once)"
RULE=/etc/udev/rules.d/99-esp32.rules
if [[ ! -f $RULE ]]; then
  echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", MODE="0666"' | sudo tee "$RULE" >/dev/null
  sudo udevadm control --reload && sudo udevadm trigger
fi

if (( FLASH )); then
  echo "==> flashing firmware (board plugged into this computer)"
  hardware/flash.sh || {
    echo "flash.sh failed; if the board is stuck in the ROM bootloader, upload directly:"
    echo "  cd hardware && arduino-cli upload -b \"esp32:esp32:esp32s3:USBMode=default,CDCOnBoot=cdc,FlashSize=8M,PSRAM=opi,PartitionScheme=default_8MB\" -p /dev/ttyACM0 --input-dir build hid_bridge"
    exit 1
  }
fi

cat <<'EOF'

Done. Next:
  1. iPhone: Settings > Accessibility > Touch > AssistiveTouch: on.
  2. Plug the board into the iPhone, then within 3 minutes:   esp32agent pair
  3. iPhone: join the board's Wi-Fi (ESP32Agent-XXXX), then
     Control Center > Screen Mirroring > ESP32 Agent.
  4. Test:  esp32agent screenshot --output phone.png
  5. Let Claude Code drive it:  claude mcp add esp32agent -- esp32agent mcp
EOF
