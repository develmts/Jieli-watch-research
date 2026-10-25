// Passive GATT inventory: never writes characteristics or enables notifications.
const STANDARD_SERVICES = ['generic_access', 'generic_attribute', 'device_information', 'battery_service', 'heart_rate', 'health_thermometer', 'blood_pressure', 'running_speed_and_cadence', 'cycling_speed_and_cadence', 'current_time'];
const KNOWN_SERVICES = ['0000ff00-0000-1000-8000-00805f9b34fb', '000018a8-0000-1000-8000-00805f9b34fb', '6e400001-b5a3-f393-e0a9-e50e24dcca9f'];
const FIELDS = { '2a00': 'deviceName', '2a24': 'model', '2a25': 'serialNumber', '2a26': 'firmware', '2a27': 'hardware', '2a28': 'software', '2a29': 'manufacturer' };
function interpret(uuid, bytes) {
  const short = uuid.toLowerCase().replace(/^0000/, '').slice(0, 4);
  if (FIELDS[short]) {
    const text = new TextDecoder().decode(bytes).replace(/\0+$/, '');
    if (text && !/[\u0000-\u001f\ufffd]/.test(text)) return { field: FIELDS[short], value: text };
  }
  if (short === '2a19' && bytes.length === 1 && bytes[0] <= 100) return { field: 'batteryPercent', value: bytes[0] };
  return null;
}
function services(extra = '') {
  const values = extra.split(/[\s,;]+/).filter(Boolean);
  if (values.some(v => !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v))) throw new Error('Additional services must use complete UUIDs.');
  return [...new Set([...STANDARD_SERVICES, ...KNOWN_SERVICES, ...values.map(v => v.toLowerCase())])];
}
async function collect(device, requestedServices, { timeoutMs = 12000, onProgress = () => {} } = {}) {
  const report = { schemaVersion: 1, source: 'web-bluetooth-read-only', startedAt: new Date().toISOString(), device: { name: device.name || null, browserDeviceId: device.id || null }, requestedServices, limitations: ['Only services granted by the browser are visible.', 'Browser device ID is not a hardware serial number.', 'No characteristic writes or notification subscriptions; proprietary capabilities may remain unknown.'], identity: {}, services: [], errors: [], complete: false };
  let timedOut = false;
  async function read(action) {
    let timer;
    try { return await Promise.race([action(), new Promise((_, reject) => { timer = setTimeout(() => { timedOut = true; device.gatt.disconnect(); reject(new Error('Read timed out; connection closed.')); }, timeoutMs); })]); }
    finally { clearTimeout(timer); }
  }
  try {
    const gatt = device.gatt.connected ? device.gatt : await read(() => device.gatt.connect());
    for (const service of await read(() => gatt.getPrimaryServices())) {
      if (timedOut || !gatt.connected) break;
      const entry = { uuid: service.uuid, characteristics: [] }; report.services.push(entry); onProgress(service.uuid);
      try {
        for (const characteristic of await read(() => service.getCharacteristics())) {
          if (timedOut || !gatt.connected) break;
          const properties = Object.fromEntries(['read', 'write', 'writeWithoutResponse', 'notify', 'indicate', 'broadcast', 'authenticatedSignedWrites', 'reliableWrite', 'writableAuxiliaries'].map(k => [k, Boolean(characteristic.properties[k])]));
          const item = { uuid: characteristic.uuid, properties }; entry.characteristics.push(item);
          if (!properties.read) { item.status = 'not-readable'; continue; }
          try {
            const value = await read(() => characteristic.readValue());
            const bytes = new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
            item.hex = Array.from(bytes, n => n.toString(16).padStart(2, '0')).join(''); item.bytes = bytes.length; item.observedAt = new Date().toISOString(); item.status = 'read';
            item.interpretation = interpret(characteristic.uuid, bytes);
            if (item.interpretation) report.identity[item.interpretation.field] = { value: item.interpretation.value, sourceCharacteristic: characteristic.uuid, observedAt: item.observedAt };
          } catch (error) { item.status = 'error'; item.error = error.message; }
        }
      } catch (error) { entry.error = error.message; }
    }
    report.complete = !timedOut && gatt.connected;
  } catch (error) { report.errors.push(error.message); }
  report.finishedAt = new Date().toISOString();
  return report;
}
module.exports = { collect, services, interpret };
