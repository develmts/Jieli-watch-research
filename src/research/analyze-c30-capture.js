// External data credit: TruthGh0st and contributors, source C30 in docs/SOURCES.md.
// Parser and historical measurements are local analysis; no upstream source/capture is bundled.
// Offline check of the public C30 archive. Does not communicate with any device.
const fs = require('fs');
const crypto = require('crypto');
if (!process.argv[2]) throw Error('Usage: node src/research/analyze-c30-capture.js <external-btsnoop-file>');
const bytes = fs.readFileSync(process.argv[2]);
if (bytes.subarray(0, 8).toString('hex') !== '6274736e6f6f7000' || bytes.readUInt32BE(12) !== 1002) throw Error('Expected btsnoop H4 capture');
const result = { sourceCommit: 'c506e6c45867d860327ae0c504a8867ef167547b', captureSha256: crypto.createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length, records: 0, aclPackets: 0, continuationPacketsSkipped: 0, l2capCidCounts: {}, applicationFrames: {}, discoveredServices: [], discoveredCharacteristics: [], limits: 'Counts of ACL starts; continuation fragments are not reassembled. No attribution of opaque streams to sensors or audio.' };
const count = (object, key) => object[key] = (object[key] || 0) + 1;
const hex = n => '0x' + n.toString(16).padStart(4, '0');
const uuid = b => b.length === 2 ? hex(b.readUInt16LE()) : Buffer.from(b).reverse().toString('hex').replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, '$1-$2-$3-$4-$5');
const services = new Map(), characteristics = new Map();
let offset = 16;
while (offset < bytes.length) {
  if (offset + 24 > bytes.length) throw Error('Truncated record header');
  const length = bytes.readUInt32BE(offset + 4);
  if (offset + 24 + length > bytes.length) throw Error('Truncated record');
  const data = bytes.subarray(offset + 24, offset + 24 + length);
  offset += 24 + length; result.records++;
  if (data[0] !== 2) continue;
  result.aclPackets++;
  if (data.length < 9) throw Error('Truncated ACL start');
  if (((data.readUInt16LE(1) >> 12) & 3) === 1) { result.continuationPacketsSkipped++; continue; }
  const cid = data.readUInt16LE(7), payload = data.subarray(9);
  count(result.l2capCidCounts, hex(cid));
  if (cid !== 4) continue;
  if ([0x12, 0x52, 0x1b].includes(payload[0]) && payload.length >= 4 && [0xab, 0x5a].includes(payload[3])) count(result.applicationFrames, `ATT ${hex(payload[0])}, handle ${hex(payload.readUInt16LE(1))}, prefix ${hex(payload[3])}`);
  if (payload[0] === 0x11 && [6, 20].includes(payload[1])) {
    for (let i = 2; i + payload[1] <= payload.length; i += payload[1]) {
      const item = { startHandle: payload.readUInt16LE(i), endHandle: payload.readUInt16LE(i + 2), uuid: uuid(payload.subarray(i + 4, i + payload[1])) };
      services.set(JSON.stringify(item), item);
    }
  }
  if (payload[0] === 9 && [7, 21].includes(payload[1])) {
    for (let i = 2; i + payload[1] <= payload.length; i += payload[1]) {
      const item = { valueHandle: payload.readUInt16LE(i + 3), uuid: uuid(payload.subarray(i + 5, i + payload[1])) };
      characteristics.set(JSON.stringify(item), item);
    }
  }
}
result.discoveredServices = [...services.values()];
result.discoveredCharacteristics = [...characteristics.values()];
fs.mkdirSync('output', { recursive: true });
fs.writeFileSync('output/c30-analysis.json', JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ records: result.records, aclPackets: result.aclPackets, cid0017: result.l2capCidCounts['0x0017'] || 0, applicationFrames: result.applicationFrames, services: result.discoveredServices.length, continuationPacketsSkipped: result.continuationPacketsSkipped }));
