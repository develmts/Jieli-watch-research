const assert = require('node:assert/strict');
const profile = require('../src/watch/device-profile');
const { run, listen } = require('../src/watch/research-queries');
(async () => {
  let writes = 0, starts = 0, stops = 0, removed = 0, listener;
  const characteristic = { properties: { notify: true }, addEventListener: (_, fn) => { listener = fn; }, removeEventListener: () => { removed++; }, async startNotifications() { starts++; listener({ target: { value: new DataView(Uint8Array.from([97]).buffer) } }); }, async stopNotifications() { stops++; } };
  const server = { connected: true, async getPrimaryService() { return { getCharacteristic: async () => characteristic }; }, writeValueWithoutResponse() { writes++; } };
  const entries = []; const result = await listen(server, item => entries.push(item), 1);
  assert.equal(result.channels, 2); assert.equal(starts, 2); assert.equal(stops, 2); assert.equal(removed, 2); assert.equal(writes, 0); assert.equal(entries[0].notificationHex, '61');
  const original = profile.query;
  const fixture = require('./fixtures/protocol.json');
  try {
    profile.query = async (_, command, key, trace) => { trace({ normalTx: 'test' }); return command === 25 ? { key: 0, payload: Buffer.from(fixture.featureHex, 'hex') } : { key: fixture.watchInfoKey, payload: Buffer.from(fixture.watchInfoHex, 'hex') }; };
    const caps = await run('capabilities', server); assert.equal(caps.success, true); assert.equal(caps.data.codeFormat, 8); assert.equal(caps.request.command, 25); assert(caps.trace.length);
    const infoServer = { connected: true, async getPrimaryService() { return { async getCharacteristic() { return { async readValue() { const b = Buffer.from(fixture.featureHex, 'hex'); return new DataView(b.buffer, b.byteOffset, b.byteLength); } }; } }; } };
    const info = await run('watch-faces', infoServer); assert.equal(info.data.maxDialBytes, 53248); assert.equal(info.data.faceCount, 5); assert.equal(info.request.command, 15); assert(info.featureEvidence);
    const raw = await run('watch-faces', { connected: true, getPrimaryService: async () => { throw Error('No direct read'); } }); assert.equal(raw.success, true); assert(raw.response.payloadHex); assert(raw.interpretationError); assert.equal(raw.data, undefined);
    profile.query = async () => { throw Error('Timed out'); };
    const failed = await run('capabilities', server); assert.equal(failed.success, false); assert.equal(failed.error, 'Timed out'); assert(failed.finishedAt);
  } finally { profile.query = original; }
  assert.equal((await run('capabilities', { connected: false })).success, false);
  console.log('PASS: notification cleanup without commands, known-query interpretation and raw evidence preservation on partial failures.');
})().catch(error => { console.error(error); process.exitCode = 1; });
