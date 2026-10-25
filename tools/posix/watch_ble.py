#!/usr/bin/env python3
"""Bounded BLE research backend for the Bash entry points.

Install Python 3.10+ and requirements.txt in a virtual environment. Linux needs
BlueZ 5.55+, D-Bus and an enabled LE adapter; macOS needs Bluetooth permission.
Bleak API reference and attribution: https://bleak.readthedocs.io/
No upstream implementation is copied. Protocol evidence: docs/SOURCES.md.
Only the normal DF/FD channel may be written; never the OTA characteristics.
"""
import argparse
import asyncio
from datetime import datetime, timezone
import importlib.metadata
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
NORMAL = '6e400001-b5a3-f393-e0a9-e50e24dcca9f'
TX = '6e400002-b5a3-f393-e0a9-e50e24dcca9f'
RX = '6e400003-b5a3-f393-e0a9-e50e24dcca9f'
BATTERY = '00002a19-0000-1000-8000-00805f9b34fb'
FF14 = '0000ff14-0000-1000-8000-00805f9b34fb'
CCCD = '00002902-0000-1000-8000-00805f9b34fb'
GETTERS = {
    'hardware': (10, 16), 'identity': (243, 0), 'features': (25, 0),
    'settings': (9, 0), 'faces': (15, 1), 'today': (5, 10),
    'classic-address': (14, 3), 'alarms': (8, 0),
    'custom-face': (15, 4), 'ota-identity': (19, 1),
}
BATCH = [
    ('bt-connect-status', 2, 60), ('today-summary', 5, 10),
    ('watch-faces', 15, 1), ('ota-info', 19, 1), ('settings-info', 9, 0),
    ('alarms-info', 8, 0), ('custom-face-info', 15, 4),
    ('drink-reminder-info', 17, 0), ('notification-settings-info', 18, 0),
    ('sedentary-reminder-info', 20, 0), ('medication-reminder-info', 16, 0),
    ('power-save-info', 26, 7), ('social-code-types-info', 26, 3),
    ('payment-code-types-info', 26, 5), ('product-identification', 32, 0),
]


def now():
    return datetime.now(timezone.utc).isoformat()


def target_identifier(value):
    """Linux accepts LE addresses; CoreBluetooth requires its device UUID."""
    if not value:
        raise ValueError('Set HRYFINE_WATCH_ADDRESS or pass --address. Use list-posix-ble.sh first.')
    if re.fullmatch(r'[0-9a-fA-F]{12}', value):
        return ':'.join(value[i:i + 2] for i in range(0, 12, 2))
    if re.fullmatch(r'(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}', value):
        return value
    try:
        return str(uuid.UUID(value))
    except ValueError as error:
        raise ValueError('Expected a 12-digit LE address, colon-separated address, or macOS device UUID.') from error


def request_frame(command, key):
    result = bytearray([0xdf, 0, 5, 0, command, 1, key, 0, 0])
    result[3] = sum(result) & 255
    return bytes(result)


def ack_frame(frame):
    result = bytearray([0xfd, 0, 5, 0, frame[4], frame[6], 0, 0, 1])
    result[3] = sum(result) & 255
    return bytes(result)


def extract_frames(pending):
    """Handle fragmentation/coalescing; reject malformed data before ACKing."""
    frames = []
    while len(pending) >= 3:
        if pending[0] not in (0xdf, 0xfd):
            raise ValueError('Unexpected frame header')
        length = 9 if pending[0] == 0xfd else int.from_bytes(pending[1:3], 'big') + 4
        if not 9 <= length <= 65539:
            raise ValueError('Invalid outer frame length')
        if len(pending) < length:
            break
        frame = bytes(pending[:length])
        del pending[:length]
        if (sum(frame[:3]) + sum(frame[4:])) & 255 != frame[3]:
            raise ValueError('Checksum mismatch')
        if frame[0] == 0xdf:
            declared = int.from_bytes(frame[7:9], 'big')
            known_exception = (frame[4], frame[6], declared, len(frame)) == (15, 5, 11, 26)
            if declared + 9 != len(frame) and not known_exception:
                raise ValueError('Inner payload length mismatch')
        frames.append(frame)
    return frames


class Session:
    def __init__(self, client, report, timeout):
        self.client, self.report, self.timeout = client, report, timeout
        self.last_battery = None
        self.subscriptions = []

    async def bounded(self, operation):
        return await asyncio.wait_for(operation, self.timeout)

    async def battery(self):
        value = bytes(await self.bounded(self.client.read_gatt_char(BATTERY)))
        if len(value) != 1 or value[0] > 100:
            raise ValueError('Battery unavailable or invalid; stopped')
        entry = dict(observedAt=now(), percent=value[0], hex=value.hex())
        self.report['battery'].append(entry)
        self.last_battery = (time.monotonic(), value[0])
        if value[0] <= 15:
            self.report['stopReason'] = 'battery-at-or-below-15'
            raise ValueError('Battery <=15%; stopped')
        return entry

    def gate(self):
        if not self.client.is_connected:
            raise ValueError('Disconnected; stopped')
        if not self.last_battery or self.last_battery[1] <= 15 or time.monotonic() - self.last_battery[0] > 30:
            raise ValueError('Missing, low or stale battery authorization')

    async def write(self, data):
        self.gate()
        characteristic = self.client.services.get_characteristic(TX)
        if characteristic is None:
            raise ValueError('Normal TX characteristic missing')
        response = 'write' in characteristic.properties
        if not response and 'write-without-response' not in characteristic.properties:
            raise ValueError('Normal TX is not writable')
        await self.bounded(self.client.write_gatt_char(characteristic, data, response=response))

    async def subscribe(self, characteristic, callback):
        self.gate()
        # The OS owns CCCD state. Never write a raw CCCD through Bleak.
        self.subscriptions.append(characteristic)
        await self.bounded(self.client.start_notify(characteristic, callback))

    async def cleanup(self):
        for characteristic in reversed(self.subscriptions):
            try:
                await self.bounded(self.client.stop_notify(characteristic))
            except Exception as error:
                self.report['errors'].append(dict(phase='unsubscribe', error=str(error)))
        self.subscriptions.clear()

    async def inventory(self):
        for service in self.client.services:
            await self.battery()
            item = dict(uuid=service.uuid, attributeHandle=service.handle, characteristics=[])
            self.report['services'].append(item)
            for characteristic in service.characteristics:
                await self.battery()
                entry = dict(uuid=characteristic.uuid, attributeHandle=characteristic.handle,
                             properties=characteristic.properties, descriptors=[])
                item['characteristics'].append(entry)
                if 'read' in characteristic.properties:
                    entry['read'] = await self.read(self.client.read_gatt_char(characteristic))
                else:
                    entry['read'] = dict(status='NotReadable')
                for descriptor in characteristic.descriptors:
                    await self.battery()
                    entry['descriptors'].append(dict(uuid=descriptor.uuid, attributeHandle=descriptor.handle,
                        read=await self.read(self.client.read_gatt_descriptor(descriptor.handle))))

    async def read(self, operation):
        try:
            value = bytes(await self.bounded(operation))
            result = dict(status='Success', observedAt=now(), hex=value.hex(), bytes=len(value))
            try:
                text = value.decode('utf-8').rstrip('\0')
                if text and all(ord(c) >= 32 and ord(c) != 127 for c in text):
                    result['text'] = text
            except UnicodeDecodeError:
                pass
            return result
        except Exception as error:
            return dict(status='Exception', error=str(error))

    async def query(self, identifier, command, key):
        if (command, key) not in set(GETTERS.values()) | {(c, k) for _, c, k in BATCH}:
            raise ValueError('Non-allowlisted request')
        await self.battery()
        queue = asyncio.Queue(maxsize=1024)
        overflow = False

        def receive(_characteristic, data):
            nonlocal overflow
            try:
                queue.put_nowait(bytes(data))
            except asyncio.QueueFull:
                overflow = True

        query = dict(id=identifier, startedAt=now(), request=dict(command=command, key=key, sent=False),
                     trace=[], frames=[], success=False)
        self.report['queries'].append(query)
        pending = bytearray()
        try:
            await self.subscribe(RX, receive)
            await self.battery()
            request = request_frame(command, key)
            query['request']['hex'] = request.hex()
            await self.write(request)
            query['request']['sent'] = True
            query['trace'].append(dict(at=now(), normalTx=request.hex()))
            deadline, last_data = time.monotonic() + 7, None
            while time.monotonic() < deadline:
                if overflow:
                    raise ValueError('Notification queue overflow; stopped')
                if last_data and time.monotonic() - last_data > .9:
                    break
                self.gate()
                try:
                    chunk = await asyncio.wait_for(queue.get(), .1)
                except asyncio.TimeoutError:
                    continue
                query['trace'].append(dict(at=now(), normalRx=chunk.hex()))
                pending.extend(chunk)
                for frame in extract_frames(pending):
                    query['frames'].append(dict(at=now(), hex=frame.hex(), command=frame[4], checksumValid=True))
                    if frame[0] == 0xfd:
                        query['ack'] = dict(key=frame[5], status=frame[8], auxHex=frame[6:8].hex())
                        continue
                    ack = ack_frame(frame)
                    await self.write(ack)
                    query['trace'].append(dict(at=now(), normalAckTx=ack.hex()))
                    if frame[4] == command:
                        query['response'] = dict(key=frame[6], payloadHex=frame[9:].hex())
                        query['success'], last_data = True, time.monotonic()
            if pending:
                query['incompleteHex'] = pending.hex()
            if not query['success']:
                query['error'] = 'No matching data in bounded window; ACK alone is not data'
            await self.battery()
        except BaseException as error:
            query['error'] = str(error) or type(error).__name__
            raise
        finally:
            query['finishedAt'] = now()
            await self.cleanup()
            if self.report['errors']:
                raise ValueError('Subscription cleanup failed; no further queries allowed')


async def scan(scanner_type, args, report, target=None):
    count = 0
    def receive(device, advertisement):
        nonlocal count
        if target and device.address.lower() != target.lower():
            return
        if count >= 4096:
            return
        count += 1
        report['advertisements'].append(dict(at=now(), address=device.address,
            name=device.name, localName=advertisement.local_name, rssi=advertisement.rssi,
            txPower=advertisement.tx_power, serviceUuids=advertisement.service_uuids,
            manufacturerData={str(k): bytes(v).hex() for k, v in advertisement.manufacturer_data.items()},
            serviceData={k: bytes(v).hex() for k, v in advertisement.service_data.items()}))
    # macOS does not support passive scanning; BlueZ passive scanning needs special
    # monitor filters. Use explicit active discovery and disclose its scan requests.
    async with scanner_type(detection_callback=receive, scanning_mode='active'):
        await asyncio.sleep(args.scan_seconds)
    report['advertisementLimitReached'] = count >= 4096


async def run(args, report):
    from bleak import BleakClient, BleakScanner
    if sys.platform not in ('linux', 'darwin'):
        raise ValueError('Live tools require Linux/BlueZ or macOS/CoreBluetooth; offline tests work elsewhere.')
    report['backend'] = dict(platform=sys.platform, bleak=importlib.metadata.version('bleak'))
    if args.action == 'list':
        await scan(BleakScanner, args, report)
        return
    target = target_identifier(args.address)
    report['device'] = dict(identifier=target)
    if args.action == 'listen' and not args.skip_advertisements:
        await scan(BleakScanner, args, report, target)
    device = await BleakScanner.find_device_by_address(target, timeout=args.timeout)
    if device is None:
        raise ValueError('Target not advertising or not visible; no connection attempted')
    report['device']['name'] = device.name
    def disconnected(_client):
        report['connectionStates'].append(dict(at=now(), status='Disconnected'))
    client = BleakClient(device, disconnected_callback=disconnected, timeout=args.timeout)
    session = Session(client, report, args.timeout)
    try:
        await session.bounded(client.connect())
        report['connectionStates'].append(dict(at=now(), status='Connected'))
        await session.battery()
        if args.action == 'probe':
            report['services'] = [dict(uuid=s.uuid, attributeHandle=s.handle) for s in client.services]
        elif args.action == 'inventory' or args.query == 'inventory':
            await session.inventory()
        elif args.action == 'f3':
            await session.query('device-info', 243, 0)
        elif args.action == 'information':
            for identifier, command, key in BATCH:
                await session.query(identifier, command, key)
                await asyncio.sleep(.8)
        elif args.action == 'listen':
            for characteristic in (BATTERY, FF14, RX):
                if client.services.get_characteristic(characteristic) is None:
                    continue
                await session.battery()
                def receive(sender, data):
                    if len(report['notifications']) < 4096:
                        report['notifications'].append(dict(at=now(), characteristic=sender.uuid, hex=bytes(data).hex()))
                await session.subscribe(characteristic, receive)
            await observe(session, 20)
        elif args.query == 'observe':
            await observe(session, 30)
        elif args.query != 'battery':
            await session.query(args.query, *GETTERS[args.query])
        report.setdefault('stopReason', 'bounded-session-completed')
    finally:
        await session.cleanup()
        if client.is_connected:
            await session.bounded(client.disconnect())


async def observe(session, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        session.gate()
        await asyncio.sleep(min(4, max(0, deadline - time.monotonic())))
        await session.battery()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['list','probe','inventory','listen','f3','information','session'])
    parser.add_argument('--query', choices=['battery','observe','inventory', *GETTERS], default='battery')
    parser.add_argument('--address', default=os.environ.get('HRYFINE_WATCH_ADDRESS'))
    parser.add_argument('--timeout', type=float, default=15)
    parser.add_argument('--scan-seconds', type=float, default=20)
    parser.add_argument('--skip-advertisements', action='store_true')
    parser.add_argument('--output', type=Path, help='New report path; existing files are never overwritten')
    args = parser.parse_args()
    if not 1 <= args.timeout <= 30 or not 1 <= args.scan_seconds <= 60:
        parser.error('Timeout must be 1..30 seconds; scan duration must be 1..60 seconds')
    output = args.output or ROOT/'output/sessions'/('posix_' + args.action + '_' + uuid.uuid4().hex + '.json')
    output.parent.mkdir(parents=True, exist_ok=True)
    # Reserve the output before contacting a device, so path errors cannot lose evidence.
    with output.open('x', encoding='utf-8') as handle:
        report = dict(schemaVersion=1, source='posix-bleak-' + args.action, startedAt=now(),
            queryId=args.query, batteryThreshold=15, battery=[], queries=[], services=[],
            advertisements=[], notifications=[], connectionStates=[], errors=[],
            policy='Allowlisted information getters and matching ACKs only; battery must exceed 15%. '
                   'OS-managed temporary notifications; no settings, binding, clock, reset or OTA writes. '
                   'Discovery is active, not passive. Exact prior CCCD state restoration is not exposed by Bleak.')
        status = 0
        try:
            asyncio.run(run(args, report))
        except (Exception, KeyboardInterrupt) as error:
            report['errors'].append(str(error) or type(error).__name__)
            report.setdefault('stopReason', 'error-stop-no-further-requests')
            status = 1
        finally:
            report['finishedAt'] = now()
            json.dump(report, handle, indent=2)
            handle.write('\n')
    print('Report: ' + str(output))
    for error in report['errors']:
        print(error, file=sys.stderr)
    return status


if __name__ == '__main__':
    sys.exit(main())
