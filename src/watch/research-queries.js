// Evidence origin: proprietary-client static analysis and local observations.
// External comparisons are attributed in docs/SOURCES.md; no clean-room claim.
const { parseDeviceInfo } = require('./device-info');
const profile = require('./device-profile');
const definitions = [
  { id: 'device-info', name: 'Read firmware identity', description: 'F3/00 (243/0): request firmware version and project name. Preserve the raw response. Does not bind, synchronize settings or start an update.' },
  { id: 'notifications', name: 'Listen for notifications (15 seconds)', description: 'Subscribe to battery and normal-channel notifications without application commands. Silence is possible. Does not subscribe to the OTA channel.' },
  { id: 'capabilities', name: 'Read capabilities', description: '19/00 (25/0): request display and format flags over the normal channel. May duplicate a direct characteristic read.' },
  { id: 'watch-faces', name: 'Read installed face information', description: '0F/01 (15/1): request installed face identifiers, active face and size limits when present. Does not select or transfer a face.' }
];
async function listen(server, trace, durationMs = 15000) {
  const subscriptions = [], errors = [];
  let timer, onDisconnect;
  try {
    for (const [serviceId, characteristicId] of [['battery_service', 'battery_level'], [profile.NORMAL.service, profile.NORMAL.notify]]) {
      try {
        const service = await server.getPrimaryService(serviceId), characteristic = await service.getCharacteristic(characteristicId);
        if (!characteristic.properties.notify && !characteristic.properties.indicate) throw Error('Notifications are not supported.');
        const listener = event => { const value = event.target.value; trace({ at: new Date().toISOString(), service: service.uuid || serviceId, characteristic: characteristic.uuid || characteristicId, notificationHex: Buffer.from(value.buffer, value.byteOffset, value.byteLength).toString('hex') }); };
        characteristic.addEventListener('characteristicvaluechanged', listener);
        try { await characteristic.startNotifications(); subscriptions.push({ characteristic, listener }); }
        catch (error) { characteristic.removeEventListener('characteristicvaluechanged', listener); throw error; }
      } catch (error) { errors.push({ service: serviceId, error: error.message }); }
    }
    if (!subscriptions.length) throw Error('Could not subscribe to any notification channel.');
    let interrupted = false;
    await new Promise(resolve => {
      onDisconnect = () => { interrupted = true; resolve(); };
      server.device?.addEventListener('gattserverdisconnected', onDisconnect);
      timer = setTimeout(resolve, durationMs);
      if (!server.connected) onDisconnect();
    });
    return { durationMs, interrupted, channels: subscriptions.length, errors };
  } finally {
    clearTimeout(timer); server.device?.removeEventListener('gattserverdisconnected', onDisconnect);
    for (const { characteristic, listener } of subscriptions) {
      characteristic.removeEventListener('characteristicvaluechanged', listener);
      if (server.connected) { try { await characteristic.stopNotifications(); } catch (error) { trace({ cleanupError: error.message }); } }
    }
  }
}
async function run(id, server, { durationMs = 15000 } = {}) {
  const definition = definitions.find(item => item.id === id);
  if (!definition) throw Error('Unknown query.');
  const result = { id, name: definition.name, description: definition.description, startedAt: new Date().toISOString(), trace: [], success: false };
  const trace = entry => result.trace.push({ at: new Date().toISOString(), ...entry });
  try {
    if (!server?.connected) throw Error('Watch is disconnected.');
    if (id === 'notifications') result.data = await listen(server, trace, durationMs);
    else {
      const [command, key] = { 'capabilities': [25, 0], 'watch-faces': [15, 1], 'device-info': [0xf3, 0] }[id];
      result.request = { command, key, hex: profile.request(command, key).toString('hex') };
      const response = await profile.query(server, command, key, trace);
      result.response = { key: response.key, payloadHex: response.payload.toString('hex') };
      if (id === 'device-info') {
        if (![0, 0xf3].includes(response.key)) result.interpretationError = 'Unexpected response key; raw bytes preserved without interpretation.';
        else {
          try { result.data = parseDeviceInfo(response.payload);
            if (result.data.trailingHex) result.interpretationError = 'Response contains additional bytes with unknown meaning.';
          } catch (error) { result.interpretationError = error.message; }
        }
      }
      else if (id === 'capabilities') result.data = profile.features(response.payload);
      else {
        // Information interpretation needs the actual device flags, never inferred defaults.
        let bytes;
        try { const service = await server.getPrimaryService('device_information'); const characteristic = await service.getCharacteristic('00002a28-0000-1000-8000-00805f9b34fb'); const v = await characteristic.readValue(); bytes = Buffer.from(v.buffer, v.byteOffset, v.byteLength); }
        catch (error) { result.interpretationError = error.message; }
        if (bytes) {
          result.featureEvidence = { characteristic: '00002a28-0000-1000-8000-00805f9b34fb', hex: bytes.toString('hex') };
          try { result.data = profile.watchInfo(response.payload, response.key, profile.features(bytes)); }
          catch (error) { result.interpretationError = error.message; }
        } else result.interpretationError ||= 'Capabilities unavailable; raw response preserved without interpretation.';
      }
    }
    result.success = true;
  } catch (error) { result.error = error.message; }
  result.finishedAt = new Date().toISOString();
  return result;
}
module.exports = { definitions, run, listen };
