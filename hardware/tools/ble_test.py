"""
Tester BLE fotopułapki z PC (Windows/Linux/macOS) – symuluje BLE Manager aplikacji.

    pip install bleak
    python ble_test.py            # skanuje i łączy z pierwszym "CT-xxxx"
    python ble_test.py CT-A1B2    # łączy z konkretnym urządzeniem

Fotopułapka zwykle śpi – pomachaj przed PIR albo poczekaj na okresowe
wybudzenie (adv), skan trwa do 30 s. Po połączeniu skrypt sam wysyła
SET_TIME (zegar z PC) i WAKE_UP (żeby urządzenie nie zasnęło w trakcie testu).

Po połączeniu wpisuj polecenia: PING, WAKE_UP, SLEEP, TRIGGER, GET_STATUS,
GET_CONFIG, GET_EVENT, SET_CONFIG {"ai":0.7,"rec":15}, SET_TIME <epoch>,
ENABLE_WIFI, DISABLE_WIFI, WIFI_INFO, REBOOT
Dodatkowo:  status  – odczyt charakterystyki STATUS
            config  – odczyt charakterystyki CONFIG
            cfg {"ai":0.7} – zapis JSON bezpośrednio do CONFIG
            quit
"""
import asyncio
import json
import sys
import time

from bleak import BleakClient, BleakScanner

SERVICE_UUID = "6e400000-c0de-4a1b-9f5e-ca3e7a000001"
STATUS_UUID = "6e400001-c0de-4a1b-9f5e-ca3e7a000001"
CONFIG_UUID = "6e400002-c0de-4a1b-9f5e-ca3e7a000001"
COMMAND_UUID = "6e400003-c0de-4a1b-9f5e-ca3e7a000001"
RESPONSE_UUID = "6e400004-c0de-4a1b-9f5e-ca3e7a000001"

ERR_BITS = {1: "CAMERA", 2: "SD", 4: "LOW_BATTERY", 8: "WIFI", 16: "PIR_STUCK"}


def pretty(raw: bytes) -> str:
    text = raw.decode(errors="replace")
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return text
    if isinstance(data, dict) and data.get("err"):
        data["err_names"] = [n for b, n in ERR_BITS.items() if data["err"] & b]
    return json.dumps(data, ensure_ascii=False)


async def find_device(name: str | None):
    print("Skanowanie BLE (do 30 s)...")
    for _ in range(6):
        dev = await _scan_once(name)
        if dev:
            return dev
    return None


async def _scan_once(name: str | None):
    devices = await BleakScanner.discover(timeout=5.0, return_adv=True)
    for dev, adv in devices.values():
        uuids = [u.lower() for u in (adv.service_uuids or [])]
        dev_name = dev.name or adv.local_name or ""
        if name and dev_name != name:
            continue
        if SERVICE_UUID in uuids or dev_name.startswith("CT-"):
            print(f"Znaleziono {dev_name} [{dev.address}] RSSI={adv.rssi} dBm")
            return dev
    return None


async def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    dev = await find_device(target)
    if dev is None:
        print("Nie znaleziono fotopułapki. Czy ESP32 jest włączone i nie jest połączone z innym urządzeniem?")
        return

    async with BleakClient(dev) as client:
        print(f"Połączono, MTU={client.mtu_size}")
        await client.start_notify(STATUS_UUID, lambda _, d: print(f"\n[STATUS_UPDATE] {pretty(d)}"))
        await client.start_notify(RESPONSE_UUID, lambda _, d: print(f"\n[RESPONSE] {pretty(d)}"))

        print("STATUS:", pretty(await client.read_gatt_char(STATUS_UUID)))
        print("CONFIG:", pretty(await client.read_gatt_char(CONFIG_UUID)))
        await client.write_gatt_char(COMMAND_UUID, f"SET_TIME {int(time.time())}".encode(), response=True)
        await client.write_gatt_char(COMMAND_UUID, b"WAKE_UP", response=True)
        print(__doc__.split("Po połączeniu")[1])

        loop = asyncio.get_running_loop()
        while client.is_connected:
            line = (await loop.run_in_executor(None, input, "> ")).strip()
            if not line:
                continue
            low = line.lower()
            if low in ("quit", "exit", "q"):
                break
            if low == "status":
                print(pretty(await client.read_gatt_char(STATUS_UUID)))
            elif low == "config":
                print(pretty(await client.read_gatt_char(CONFIG_UUID)))
            elif low.startswith("cfg "):
                payload = line[4:].strip()
                try:
                    json.loads(payload)
                except json.JSONDecodeError:
                    print('Użycie: cfg {"ai":0.7,"rec":15}')
                    continue
                await client.write_gatt_char(CONFIG_UUID, payload.encode(), response=True)
            else:
                await client.write_gatt_char(COMMAND_UUID, line.encode(), response=True)
            await asyncio.sleep(0.3)  # czas na notyfikację z odpowiedzią


if __name__ == "__main__":
    asyncio.run(main())
