// Evidence origin: proprietary-client static analysis and local observations.
// External comparisons are attributed in docs/SOURCES.md; no clean-room claim.
// Protocol inferred statically from the APK; transport supplied by the caller.
const UUID = Object.freeze({ service: '0000ff00-0000-1000-8000-00805f9b34fb',
  notify: '0000ff01-0000-1000-8000-00805f9b34fb', write: '0000ff02-0000-1000-8000-00805f9b34fb' });
function crc8(data, initial = 0) {
  let crc = initial;
  for (const byte of data) { crc ^= byte; for (let bit = 0; bit < 8; bit++) crc = ((crc << 1) ^ ((crc & 128) ? 0x31 : 0)) & 255; }
  return crc;
}
function command(operation, payload = Buffer.alloc(0), status = 0) {
  if (payload.length > 65535) throw new Error('Command payload too large');
  const out = Buffer.alloc(payload.length + 9);
  out[0] = 0xd5; out[1] = 5; out[2] = 1; out[3] = operation; out[5] = status;
  out.writeUInt16BE(payload.length, 6); payload.copy(out, 8);
  out[out.length - 1] = out.subarray(0, -1).reduce((sum, b) => (sum + b) & 255, 0);
  return out;
}
function start(attMtu, bytes) {
  if (!Number.isInteger(attMtu) || attMtu < 23 || attMtu > 517 || !Number.isInteger(bytes) || bytes < 1 || bytes > 0xffffffff) throw new Error('Invalid MTU or file size');
  const payload = Buffer.alloc(6); payload.writeUInt16BE(attMtu - 3); payload.writeUInt32BE(bytes, 2);
  return command(1, payload);
}
function decode(frame) {
  if (frame[0] === 0xd6) throw new Error('Device reported OTA error (D6)');
  if (frame.length < 9 || frame[0] !== 0xd5 || frame[1] !== 5 || frame[2] !== 1 || frame.length !== frame.readUInt16BE(6) + 9) throw new Error('Invalid OTA response');
  const sum = frame.subarray(0, -1).reduce((n, b) => (n + b) & 255, 0);
  if (sum !== frame[frame.length - 1]) throw new Error('Response checksum mismatch');
  return { operation: frame[3], status: frame[5], payload: frame.subarray(8, -1) };
}
class Reassembler {
  constructor(onFrame) { this.pending = Buffer.alloc(0); this.onFrame = onFrame; }
  push(chunk) {
    this.pending = Buffer.concat([this.pending, chunk]);
    while (this.pending.length) {
      if (this.pending[0] === 0xd6) throw new Error('Device reported OTA error (D6)');
      if (this.pending[0] !== 0xd5) throw new Error('Invalid notification header');
      if (this.pending.length < 8) return;
      const size = this.pending.readUInt16BE(6) + 9;
      if (this.pending.length < size) return;
      const frame = this.pending.subarray(0, size); this.pending = this.pending.subarray(size); this.onFrame(decode(frame));
    }
  }
}
function groups(data, devicePacketBytes, packetsPerGroup) {
  if (!data.length || !Number.isInteger(devicePacketBytes) || devicePacketBytes < 2 || devicePacketBytes > 514 || !Number.isInteger(packetsPerGroup) || packetsPerGroup < 1 || packetsPerGroup > 127) throw new Error('Invalid transfer parameters');
  const result = [], chunkSize = devicePacketBytes - 1;
  for (let at = 0; at < data.length;) {
    const packets = [], first = at;
    for (let i = 0; i < packetsPerGroup && at < data.length; i++) {
      const chunk = data.subarray(at, Math.min(data.length, at + chunkSize)); at += chunk.length;
      packets.push(Buffer.concat([Buffer.from([0xd6]), chunk]));
    }
    result.push({ packets, crcCommand: command(2, Buffer.from([crc8(data.subarray(first, at))])) });
  }
  return result;
}
// No concrete Bluetooth implementation here. The adapter must discover GATT,
// negotiate attMtu and support write-without-response plus notifications.
async function upload(data, transport, { timeoutMs = 30000, onProgress = () => {}, onTrace = () => {} } = {}) {
  if (typeof transport.write !== 'function' || typeof transport.subscribe !== 'function') throw new Error('Transport adapter required');
  const queue = []; let waiting, fatal;
  const deliver = response => { if (waiting) { const w = waiting; waiting = null; w.resolve(response); } else queue.push(response); };
  const fail = error => { fatal = error; if (waiting) { const w = waiting; waiting = null; w.reject(error); } };
  const parser = new Reassembler(deliver);
  const unsubscribe = await transport.subscribe(bytes => { try { parser.push(Buffer.from(bytes)); } catch (error) { fail(error); } });
  const response = async operation => {
    if (fatal) throw fatal;
    let reply;
    if (queue.length) reply = queue.shift();
    else reply = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { waiting = null; reject(new Error('OTA response timeout')); }, timeoutMs);
      waiting = { resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); } };
    });
    onTrace({ otaResponse: reply.operation, status: reply.status, payloadHex: reply.payload.toString('hex') });
    if (reply.operation !== operation || reply.status !== 0) {
      const detail = reply.operation === 0x81 && reply.status === 13 ? `; APK meaning: watchface too large; requestedBytes=${data.length}; no BIN payload sent` : '';
      throw new Error(`OTA rejected: operation=${reply.operation}, status=${reply.status}${detail}`);
    }
    return reply;
  };
  try {
    const startPacket = start(transport.attMtu, data.length);
    onTrace({ otaStartHex: startPacket.toString('hex'), requestedBytes: data.length, attMtu: transport.attMtu });
    await transport.write(startPacket);
    const ready = await response(0x81);
    if (ready.payload.length < 6) throw new Error('Truncated negotiated parameters');
    const packetBytes = ready.payload.readUInt16BE(0), perGroup = ready.payload[4];
    if (packetBytes > transport.attMtu - 3) throw new Error('Device packet size exceeds negotiated ATT payload');
    const plan = groups(data, packetBytes, perGroup); let sent = 0;
    for (const group of plan) {
      for (const packet of group.packets) { if (fatal) throw fatal; await transport.write(packet); sent += packet.length - 1; }
      await transport.write(group.crcCommand); await response(0x82); onProgress(sent / data.length);
    }
    await transport.write(command(3, Buffer.from([crc8(data)]))); await response(0x83);
    return { bytes: sent, groups: plan.length, crc: crc8(data) };
  } finally { if (typeof unsubscribe === 'function') await unsubscribe(); }
}
module.exports = { UUID, crc8, command, start, decode, Reassembler, groups, upload };
