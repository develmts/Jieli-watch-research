using System;
using System.Collections.Concurrent;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;
public sealed class WatchResearchNotificationQueue : IDisposable {
    private readonly GattCharacteristic characteristic;
    private readonly ConcurrentQueue<byte[]> queue = new ConcurrentQueue<byte[]>();
    public WatchResearchNotificationQueue(GattCharacteristic characteristic) {
        this.characteristic = characteristic;
        characteristic.ValueChanged += OnValue;
    }
    private void OnValue(GattCharacteristic sender, GattValueChangedEventArgs args) {
        using (var reader = DataReader.FromBuffer(args.CharacteristicValue)) {
            var bytes = new byte[reader.UnconsumedBufferLength];
            reader.ReadBytes(bytes);
            queue.Enqueue(bytes);
        }
    }
    public static Windows.Foundation.IAsyncOperation<GattCommunicationStatus> WriteBytes(GattCharacteristic characteristic, byte[] bytes) {
        using (var writer = new DataWriter()) {
            writer.WriteBytes(bytes);
            return characteristic.WriteValueAsync(writer.DetachBuffer(), GattWriteOption.WriteWithoutResponse);
        }
    }
    public static Windows.Foundation.IAsyncOperation<GattReadResult> ReadCharacteristic(GattCharacteristic characteristic) {
        return characteristic.ReadValueAsync(Windows.Devices.Bluetooth.BluetoothCacheMode.Uncached);
    }
    public static Windows.Foundation.IAsyncOperation<GattReadResult> ReadDescriptor(GattDescriptor descriptor) {
        return descriptor.ReadValueAsync(Windows.Devices.Bluetooth.BluetoothCacheMode.Uncached);
    }
    public static byte[] BufferBytes(Windows.Storage.Streams.IBuffer buffer) {
        using (var reader = DataReader.FromBuffer(buffer)) {
            var bytes = new byte[reader.UnconsumedBufferLength]; reader.ReadBytes(bytes); return bytes;
        }
    }
    public static byte[] ResultBytes(GattReadResult result) { return BufferBytes(result.Value); }
    public byte[] Take() { byte[] bytes; return queue.TryDequeue(out bytes) ? bytes : null; }
    public void Dispose() { characteristic.ValueChanged -= OnValue; }
}
