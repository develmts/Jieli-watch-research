// Evidence origin: proprietary-client static analysis and local observations.
// External comparisons are attributed in docs/SOURCES.md; no clean-room claim.
// F3/00: length-prefixed version and project strings, as consumed by the APK.
// Preserve opaque bytes separately in the report; do not guess missing fields.
function parseDeviceInfo(payload) {
  const bytes = new Uint8Array(payload.buffer, payload.byteOffset, payload.byteLength);
  let offset = 0;
  function readText(field) {
    if (offset >= bytes.length) throw Error(`Truncated identity: missing ${field} length.`);
    const length = bytes[offset++];
    if (offset + length > bytes.length) throw Error(`Truncated identity: ${field} extends beyond the payload.`);
    const value = bytes.subarray(offset, offset + length); offset += length;
    if (!length) return null;
    let text;
    try { text = new TextDecoder('utf-8', { fatal: true }).decode(value).replace(/\0+$/, ''); }
    catch { throw Error(`Identity field ${field} is not valid UTF-8.`); }
    if (/[\u0000-\u001f\u007f]/.test(text)) throw Error(`Identity field ${field} contains control bytes.`);
    return text || null;
  }
  const firmwareVersion = readText('version'), projectName = readText('project');
  return { firmwareVersion, projectName, trailingHex: Array.from(bytes.subarray(offset), n => n.toString(16).padStart(2, '0')).join('') };
}
module.exports = { parseDeviceInfo };
