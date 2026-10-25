"""Offline safety/transport tests. No Bleak dependency, radio or network needed."""
import asyncio
import importlib.util
from pathlib import Path
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('watch_ble', ROOT/'tools/posix/watch_ble.py')
ble = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ble)


class FakeCharacteristic:
    properties = ['write']


class FakeServices:
    def get_characteristic(self, _identifier):
        return FakeCharacteristic()


class FakeClient:
    is_connected = True
    services = FakeServices()

    def __init__(self, battery=80, data=True, corrupt=False, cleanup_error=False):
        self.level, self.data, self.corrupt = battery, data, corrupt
        self.cleanup_error = cleanup_error
        self.writes, self.subscribed, self.stopped = [], [], []

    async def read_gatt_char(self, _characteristic):
        if isinstance(self.level, Exception):
            raise self.level
        return bytes([self.level])

    async def start_notify(self, characteristic, callback):
        self.callback = callback
        self.subscribed.append(characteristic)

    async def stop_notify(self, characteristic):
        self.stopped.append(characteristic)
        if self.cleanup_error:
            raise RuntimeError('Synthetic cleanup failure')

    async def write_gatt_char(self, characteristic, data, response):
        self.writes.append(bytes(data))
        if data[0] == 0xdf and self.data:
            frame = bytearray(ble.request_frame(data[4], 9))
            if self.corrupt:
                frame[3] ^= 1
            self.callback(None, frame[:4])
            self.callback(None, frame[4:])


class ProtocolTests(unittest.TestCase):
    def test_mapping(self):
        for path in (ROOT/'tools/windows').glob('*.ps1'):
            name = path.stem.replace('windows', 'posix') + '.sh'
            self.assertTrue((ROOT/'tools/posix'/name).is_file(), name)

    def test_fragmentation_and_checksum(self):
        frame = ble.request_frame(243, 0)
        pending = bytearray(frame[:4])
        self.assertEqual(ble.extract_frames(pending), [])
        pending.extend(frame[4:] + ble.ack_frame(frame))
        self.assertEqual(len(ble.extract_frames(pending)), 2)
        self.assertEqual(pending, bytearray())
        bad = bytearray(frame)
        bad[3] ^= 1
        with self.assertRaisesRegex(ValueError, 'Checksum'):
            ble.extract_frames(bad)

    def test_identifiers_and_allowlist(self):
        self.assertEqual(ble.target_identifier('AABBCCDDEEFF'), ':'.join(['AA','BB','CC','DD','EE','FF']))
        with self.assertRaises(ValueError):
            ble.target_identifier('Smartwatch')

    def test_only_known_custom_face_length_exception_is_accepted(self):
        frame = bytearray([0xdf, 0, 22, 0, 15, 1, 5, 0, 11] + [0] * 17)
        frame[3] = sum(frame) & 255
        self.assertEqual(ble.extract_frames(bytearray(frame)), [bytes(frame)])
        frame[6] = 6
        frame[3] = (sum(frame[:3]) + sum(frame[4:])) & 255
        with self.assertRaisesRegex(ValueError, 'Inner payload'):
            ble.extract_frames(frame)


class TransportTests(unittest.IsolatedAsyncioTestCase):
    def session(self, client):
        return ble.Session(client, dict(battery=[], queries=[], errors=[]), .2)

    async def test_fragmented_response_ack_and_cleanup(self):
        client = FakeClient()
        session = self.session(client)
        await session.query('identity', 243, 0)
        self.assertTrue(session.report['queries'][0]['success'])
        self.assertEqual([data[0] for data in client.writes], [0xdf, 0xfd])
        frame = bytes.fromhex(session.report['queries'][0]['frames'][0]['hex'])
        self.assertEqual(client.writes[1], ble.ack_frame(frame))
        self.assertEqual(client.stopped, [ble.RX])

    async def test_battery_failures_block_all_writes_and_subscriptions(self):
        for battery in (15, 0, 101, RuntimeError('Unavailable')):
            client = FakeClient(battery=battery)
            with self.assertRaises((ValueError, RuntimeError)):
                await self.session(client).query('identity', 243, 0)
            self.assertEqual(client.writes, [])
            self.assertEqual(client.subscribed, [])

    async def test_stale_gate_and_unknown_request(self):
        client = FakeClient()
        session = self.session(client)
        session.last_battery = (time.monotonic() - 31, 80)
        with self.assertRaisesRegex(ValueError, 'stale'):
            await session.write(ble.request_frame(243, 0))
        with self.assertRaisesRegex(ValueError, 'allowlisted'):
            await session.query('unknown', 255, 255)
        self.assertEqual(client.writes, [])

    async def test_corruption_never_acknowledged_and_cleanup_runs(self):
        client = FakeClient(corrupt=True)
        with self.assertRaisesRegex(ValueError, 'Checksum'):
            await self.session(client).query('identity', 243, 0)
        self.assertEqual(len(client.writes), 1)
        self.assertEqual(client.stopped, [ble.RX])

    async def test_cleanup_error_stops_batch(self):
        client = FakeClient(cleanup_error=True)
        with self.assertRaisesRegex(ValueError, 'cleanup failed'):
            await self.session(client).query('identity', 243, 0)

    async def test_cancellation_unsubscribes(self):
        client = FakeClient(data=False)
        session = self.session(client)
        task = asyncio.create_task(session.query('identity', 243, 0))
        while not client.writes:
            await asyncio.sleep(.001)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        self.assertEqual(client.stopped, [ble.RX])


if __name__ == '__main__':
    unittest.main()
