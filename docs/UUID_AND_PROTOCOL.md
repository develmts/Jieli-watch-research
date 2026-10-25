# UUIDs and message layouts

Evidence: **observed** frames and GATT discovery, cross-checked against **static analysis** of the proprietary client. Historical source classes: `BleConstants`, `MBleManager`, `NotifyWriteUtils`, `IssuedUtil`, `AckPackageConfigUtils` and `BleDataUtils`. Reconstructed source and the original private evidence index are excluded. External standards are credited in [SOURCES.md](SOURCES.md).

## Observed services and characteristics

Short UUIDs use `-0000-1000-8000-00805f9b34fb`. The normal proprietary channel uses `-b5a3-f393-e0a9-e50e24dcca9f`.

| UUID | Observed role | What it does not prove |
|---|---|---|
| FF00 | File-transfer/OTA service | SoC manufacturer or file compatibility |
| FF01 | OTA receive/notify; read also advertised | An empty read is not a protocol failure |
| FF02 | OTA write, with and without response | Not a normal information-query channel |
| 6E400001...9F | Normal HryFine message service | Manufacturer or chip identity |
| 6E400002...9F | Requests and ACK writes | An ACK is not a data reply |
| 6E400003...9F | Notification receive; read also advertised | Empty direct reads do not reveal its functions |
| 180A | Device Information | OEM values may not follow the standard field meaning |
| 2A26 | ASCII `10000` | Not a useful unique firmware build identity |
| 2A27 | ASCII `10000` | The client's protocol-version conversion is not validated |
| 2A28 | Proprietary 27-byte AA capabilities | Not a software-version text string on this unit |
| 180F / 2A19 | Battery; 0x61 was 97% in one session | A session measurement is not a fixed capability |

The Bluetooth SIG Assigned Numbers specification defines standard roles for 2A25/2A26/2A27/2A28. This client repurposes some fields. Preserve raw values before assigning a standard meaning. The early browser inventory omitted 2A25; later Windows discovery found it and FF10/FF12. Inventory completeness depends on permissions and discovery method.

Nordic Semiconductor's official UART service ends in **9E**, whereas this device's normal channel ends in **9F**. Similar transport structure does not identify Nordic silicon. See source IDs `BLUETOOTH-SIG` and `NORDIC-NUS` in [SOURCES.md](SOURCES.md).

## Client constants not confirmed on this device

- 18A8/2AA8/2AA9: a separate Cus5610 OTA path. Absence in a normal inventory neither excludes another operating mode nor identifies the unit as a 5610.
- 6E40FF01...9E and 6E40FF02...9E: `SERVICE_OTA_UUID` and `CHA_OTA_WRITE` constants. Generic tables also contain 6E40FF03...9E, FF03 and FF04. Packaged constants do not establish physical presence.
- 2A00 is the standard device-name field. The client's special interpretation of 2A25 must be recorded separately from that standard.

## Normal DF frame

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 1 | DF |
| 1 | 2, big-endian | Payload length + 5 |
| 3 | 1 | Sum of every other frame byte modulo 256 |
| 4 | 1 | Command |
| 5 | 1 | Version; 01 in local captures |
| 6 | 1 | Key/subcommand |
| 7 | 2, big-endian | Payload length |
| 9 | variable | Payload |

Total length is the value at bytes 1-2 plus 4, or payload length plus 9. Both requests and data responses can start with DF. Command 0x0F is decimal 15.

The client's `IssuedUtil` builds an intermediate frame; `NotifyWriteUtils.addSumCheck` inserts the checksum at offset 3 and shifts later fields. Reading only the intermediate constructor produces an off-by-one interpretation.

## FD acknowledgement

Nine bytes: `FD 00 05 SUM CMD KEY AUX_H AUX_L STATUS`. There is no DF-style version field. Command is at 4, key at 5 and success status at 8. Auxiliary bytes 6-7 are not generally understood; do not assume a size or sequence number.

Observed device ACK: `fd0005251900000901` (command 25, key 0, auxiliary 0009, status 1). Local acknowledgement of received data uses auxiliary 0000, consistent with the client call `configAck(...,0,1)`. Requests 25/0 and 15/1 and their data replies/ACKs worked physically. Do not substitute another project's ACK layout without comparison.

## Installed-face reply 0F/09

The request is 0F/01; the valid reply uses 0F/09. Request and response keys need not match.

| Payload offset | Size | Observed meaning |
|---:|---:|---|
| 0 | 1 | 05: face count |
| 1 | 8 | Active face code |
| 9 | 40 | Five 8-byte face codes |
| 49 | 4, big-endian | 00015000: background limit 86016 |
| 53 | 4, big-endian | 0000D000: face limit 53248 |

Payload length: 57 bytes. Compared with `BleDataUtils.handleWatchFaceInfo`, historical lines 467-573. Key 2 is another variant that may involve client defaults; this unit returned key 9 with explicit limits.

## OTA and WF limits

FF00 D5/D6 traffic and the Cus5610 path are distinct from DF/FD. D6 can represent outbound file data or an inbound error, depending on direction/path. Do not use the normal-channel parser for OTA.

A historical 22821-byte WF sample had a client-calculated `getFileBuffer` boundary at 14186 bytes when `binPreviewFlag=false`. The remaining 8635 bytes and the generality of that boundary were not established. The sample is not distributed, and this observation is not a complete WF specification.

Windows F3 discovery additionally exposed FF10 and FF12. Their roles were initially unknown and they received no exploratory commands. Later inventory identified their characteristics; see [the native session](LIVE_INVESTIGATION.md).
