const assert = require('node:assert/strict');
const tools = require('../src/watch/device-profile'), ota = require('../src/watch/ota-protocol');
assert.equal(tools.request(15, 1).toString('hex'), 'df0005f50f01010000');
const featureBytes = Buffer.alloc(19); featureBytes[0] = 0xaa; featureBytes[2] = 32; featureBytes[3] = 1; featureBytes[16] = 1;
const feature = tools.features(featureBytes); assert.equal(feature.resolutionId, 16); assert(feature.supportsWatchFacePush);
const realFeatures = tools.features(Buffer.from('aacee182d982f000000000000000f0664008df9000000040000000', 'hex'));
const realInfo = tools.watchInfo(Buffer.from('0500180000000000070018000000000007001800000003000400180100000300050018000000000006000001000000005a000150000000d000', 'hex'), 9, realFeatures);
assert.equal(realFeatures.resolutionId, 1); assert(realFeatures.is8Bytes); assert.equal(realFeatures.binPreviewFlag, false);
assert.equal(realInfo.maxDialBytes, 53248); assert.equal(realInfo.maxBackgroundBytes, 86016);
const payload = Buffer.alloc(13); payload[0] = 1; payload.writeUInt32BE(32768, 5); payload.writeUInt32BE(49152, 9);
assert.equal(tools.watchInfo(payload, 2, feature).maxDialBytes, 49152);
assert.throws(() => tools.features(Buffer.from([0])), /Unrecognized/);
assert.throws(() => tools.watchInfo(Buffer.from([10, 0, 0]), 2, feature), /Truncated/);
const old = tools.watchInfo(payload.subarray(0, 5), 2, { resolutionId: 3 }); assert.equal(old.maxDialBytes, null);
function normalFrame(command, key, data) {
  const frame = Buffer.alloc(data.length + 9); frame[0] = 0xdf; frame.writeUInt16BE(data.length + 5, 1);
  frame[4] = command; frame[5] = 1; frame[6] = key; frame.writeUInt16BE(data.length, 7); data.copy(frame, 9);
  frame[3] = frame.reduce((sum, b) => (sum + b) & 255, 0); return frame;
}
(async () => {
  let listener, stopped = false; const writes = [];
  const rx = { addEventListener: (_, fn) => { listener = fn; }, removeEventListener: () => {}, startNotifications: async () => {}, stopNotifications: async () => { stopped = true; } };
  const tx = { writeValueWithoutResponse: async bytes => {
    writes.push(bytes); if (bytes[0] === 0xfd) return;
    const frame = normalFrame(15, 2, payload);
    for (const chunk of [frame.subarray(0, 4), frame.subarray(4)]) listener({ target: { value: new DataView(chunk.buffer, chunk.byteOffset, chunk.byteLength) } });
  }};
  const server = { connected: true, getPrimaryService: async () => ({ getCharacteristic: async uuid => uuid === tools.NORMAL.notify ? rx : tx }) };
  const response = await tools.query(server, 15, 1);
  assert.equal(response.key, 2); assert.deepEqual(response.payload, payload); assert(stopped); assert.equal(writes.length, 2); assert.equal(writes[1][0], 0xfd);
  let callback; const otaWrites = [], traces = [];
  const transport = { attMtu: 23, subscribe: async fn => { callback = fn; return () => {}; }, write: async frame => { otaWrites.push(frame); callback(ota.command(0x81, Buffer.alloc(0), 13)); } };
  await assert.rejects(ota.upload(Buffer.alloc(62325), transport, { onTrace: event => traces.push(event) }), /requestedBytes=62325; no BIN payload sent/);
  assert.equal(otaWrites.length, 1); assert.equal(otaWrites[0][0], 0xd5); assert.equal(traces[1].status, 13);
  console.log('PASS: read-only profile request/ACK/fragmentation, capacity parsing, and status-13 rejection sends no BIN bytes.');
})().catch(e => { console.error(e); process.exitCode = 1; });
