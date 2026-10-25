using System;
using System.Collections.Concurrent;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Storage.Streams;
public sealed class WatchResearchAdvertisementQueue : IDisposable {
    public sealed class Section { public int type; public string hex; }
    public sealed class Manufacturer { public int companyId; public string hex; }
    public sealed class Observation { public string at; public string type; public string name; public short rssi; public string[] serviceUuids; public Section[] sections; public Manufacturer[] manufacturerData; }
    private readonly ulong address;
    private readonly BluetoothLEAdvertisementWatcher watcher;
    private readonly ConcurrentQueue<Observation> queue = new ConcurrentQueue<Observation>();
    public WatchResearchAdvertisementQueue(ulong address) {
        this.address=address;watcher=new BluetoothLEAdvertisementWatcher();watcher.ScanningMode=BluetoothLEScanningMode.Passive;watcher.Received+=OnReceived;watcher.Start();
    }
    private static string Hex(IBuffer buffer) { using(var reader=DataReader.FromBuffer(buffer)){var bytes=new byte[reader.UnconsumedBufferLength];reader.ReadBytes(bytes);return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();} }
    private void OnReceived(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args) {
        if(args.BluetoothAddress!=address || queue.Count>=200) return;
        var uuids=new string[args.Advertisement.ServiceUuids.Count];for(int i=0;i<uuids.Length;i++)uuids[i]=args.Advertisement.ServiceUuids[i].ToString();
        var sections=new Section[args.Advertisement.DataSections.Count];for(int i=0;i<sections.Length;i++){var part=args.Advertisement.DataSections[i];sections[i]=new Section{type=part.DataType,hex=Hex(part.Data)};}
        var data=new Manufacturer[args.Advertisement.ManufacturerData.Count];for(int i=0;i<data.Length;i++){var part=args.Advertisement.ManufacturerData[i];data[i]=new Manufacturer{companyId=part.CompanyId,hex=Hex(part.Data)};}
        queue.Enqueue(new Observation{at=args.Timestamp.UtcDateTime.ToString("o"),type=args.AdvertisementType.ToString(),name=args.Advertisement.LocalName,rssi=args.RawSignalStrengthInDBm,serviceUuids=uuids,sections=sections,manufacturerData=data});
    }
    public Observation Take(){Observation item;return queue.TryDequeue(out item)?item:null;}
    public void Dispose(){watcher.Stop();watcher.Received-=OnReceived;}
}
