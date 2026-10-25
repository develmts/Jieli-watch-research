// A browser selection grants access; GATT connection is a separate asynchronous step.
async function connectDevice(device, { timeoutMs = 20000 } = {}) {
  if (!device?.gatt) throw new Error('The selected device does not provide GATT.');
  let timer, expired = false;
  const connection = device.gatt.connect();
  const pending = Promise.resolve(connection).then(server => {
    if (expired) {
      device.gatt.disconnect();
      throw new Error('Bluetooth connection completed after the timeout.');
    }
    if (!server.connected) throw new Error('The watch disconnected while connecting.');
    return server;
  });
  try {
    return await Promise.race([pending, new Promise((_, reject) => {
      timer = setTimeout(() => {
        expired = true;
        const error = new Error(`The watch was selected but did not complete the Bluetooth connection within ${Math.round(timeoutMs / 1000)} seconds.`);
        error.name = 'ConnectionTimeoutError';
        // Reject first; disconnect can emit synchronous events or fail on an OS stack error.
        reject(error);
        try { device.gatt.disconnect(); } catch {}
      }, timeoutMs);
    })]);
  } finally { clearTimeout(timer); }
}
function connectionError(error) {
  return `${error.name || 'Error'}: ${error.message || 'Could not establish the Bluetooth connection.'}`;
}
module.exports = { connectDevice, connectionError };
