// Evidence origin: proprietary-client static analysis and local observations.
// External comparisons are attributed in docs/SOURCES.md; no clean-room claim.
// Read-only requests from SettingIssuedUtils.getDeviceFunction / syncProcess.
const NORMAL = { service: '6e400001-b5a3-f393-e0a9-e50e24dcca9f', write: '6e400002-b5a3-f393-e0a9-e50e24dcca9f', notify: '6e400003-b5a3-f393-e0a9-e50e24dcca9f' };
function request(command, key) {
  const b = Buffer.from([0xdf, 0, 5, 0, command, 1, key, 0, 0]);
  b[3] = b.reduce((s, n) => (s + n) & 255, 0); return b;
}
function ack(command, key) {
  const b = Buffer.from([0xfd, 0, 5, 0, command, key, 0, 0, 1]);
  b[3] = b.reduce((s, n) => (s + n) & 255, 0); return b;
}
function features(b) {
  if (b.length < 4 || b[0] !== 0xaa) throw new Error('Unrecognized device feature response');
  const rid = b.length >= 17 && (b[16] & 63) ? (b[16] & 63) + 15 : b[2] & 15;
  const codeFormat = b.length >= 18 ? b[17] : 0;
  return { raw: b.toString('hex'), resolutionId: rid, screenShape: b[3] & 15,
    supportsWatchFacePush: !!(b[2] & 32), codeFormat,
    is8Bytes: codeFormat === 8 && b.length >= 19 ? !!(b[18] & 64) : false,
    binPreviewFlag: codeFormat === 8 && b.length >= 19 ? !!(b[18] & 32) : null };
}
function watchInfo(payload, key, profile) {
  const size = profile.is8Bytes ? 8 : 2;
  if (payload.length < 1 + size) throw new Error('Truncated watchface info');
  const minimum = 1 + size + payload[0] * size;
  if (payload.length < minimum) throw new Error('Truncated watchface IDs');
  const result = { raw: payload.toString('hex'), responseKey: key, faceCount: payload[0], currentFaceId: payload.subarray(1, 1 + size).toString('hex'), maxDialBytes: null, maxBackgroundBytes: null };
  if ((key !== 2 || profile.resolutionId >= 16) && payload.length >= minimum + 8) {
    result.maxBackgroundBytes = payload.readUInt32BE(payload.length - 8); result.maxDialBytes = payload.readUInt32BE(payload.length - 4);
  } else if (key === 2 && profile.resolutionId === 1) { result.maxDialBytes = 266240; result.maxBackgroundBytes = 118784; result.limitSource = 'APK defaults'; }
  else if (key === 2 && profile.resolutionId === 2) { result.maxDialBytes = 90112; result.maxBackgroundBytes = 32768; result.limitSource = 'APK defaults'; }
  return result;
}
async function query(server, command, key, log = () => {}) {
  const service = await server.getPrimaryService(NORMAL.service), rx = await service.getCharacteristic(NORMAL.notify), tx = await service.getCharacteristic(NORMAL.write);
  let pending = Buffer.alloc(0), resolve, reject, timer;
  const response = new Promise((a, b) => { resolve = a; reject = b; });
  response.catch(() => {}); // A write may fail before the reply promise is awaited.
  const listener = event => {
    try {
      const v = event.target.value, chunk = Buffer.from(v.buffer, v.byteOffset, v.byteLength);
      log({ normalRx: chunk.toString('hex') }); pending = Buffer.concat([pending, chunk]);
      while (pending.length >= 3) {
        if (![0xdf, 0xfd].includes(pending[0])) throw new Error('Invalid normal protocol header');
        const total = pending[0] === 0xfd ? 9 : pending.readUInt16BE(1) + 4;
        if (total < 9 || total > 65539) throw new Error('Invalid normal frame size');
        if (pending.length < total) break;
        const frame = pending.subarray(0, total); pending = pending.subarray(total);
        if (frame[0] === 0xfd) continue;
        const sum = frame.reduce((s, n, i) => i === 3 ? s : (s + n) & 255, 0);
        if (sum !== frame[3] || frame.readUInt16BE(7) + 9 !== total) throw new Error('Invalid normal frame checksum/length');
        // ACK only confirms a received response; never changes watchface/settings.
        const confirmation = ack(frame[4], frame[6]); log({ normalAckTx: confirmation.toString('hex') });
        const sent = tx.writeValueWithoutResponse(confirmation);
        if (frame[4] === command) sent.then(() => resolve({ key: frame[6], payload: frame.subarray(9) }), reject);
        else sent.catch(reject);
      }
    } catch (e) { reject(e); }
  };
  rx.addEventListener('characteristicvaluechanged', listener);
  let subscribed = false;
  try {
    await rx.startNotifications();
    subscribed = true;
    timer = setTimeout(() => reject(new Error('Device profile query timed out')), 12000);
    const bytes = request(command, key); log({ normalTx: bytes.toString('hex') });
    await tx.writeValueWithoutResponse(bytes); return await response;
  } finally { clearTimeout(timer); rx.removeEventListener('characteristicvaluechanged', listener); if (subscribed && server.connected) await rx.stopNotifications(); }
}
module.exports = { NORMAL, request, ack, features, watchInfo, query };
