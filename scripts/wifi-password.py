# /// script
# requires-python = ">=3.10"
# dependencies = ["bleak>=0.22"]
# ///
"""Print the board's hotspot SSID and password (esp32agent has no command for it).

Usage: uv run scripts/wifi-password.py [BLE-address]
Without an address it scans for a device named "ESP32 Agent ...".
The NET characteristic is encrypted, so BlueZ bonds with the board on first read.
"""
import asyncio
import json
import sys

from bleak import BleakClient, BleakScanner

NET = "6e400001-a9e8-4b1b-9c39-6d6f8a3c0005"


async def find() -> str:
    dev = await BleakScanner.find_device_by_filter(
        lambda d, _: (d.name or "").startswith("ESP32 Agent"), timeout=15
    )
    if not dev:
        sys.exit("board not found: is it powered and advertising?")
    return dev.address


async def main() -> None:
    addr = sys.argv[1] if len(sys.argv) > 1 else await find()
    async with BleakClient(addr, timeout=20) as client:
        try:
            await client.pair()
        except Exception:
            pass  # already bonded, or BlueZ pairs on demand
        net = json.loads(await client.read_gatt_char(NET))
        print(f"SSID:     {net.get('ssid')}")
        print(f"Password: {net.get('pass')}")


asyncio.run(main())
