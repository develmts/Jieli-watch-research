# Battery-guarded research

Evidence: **observed** native sessions and **offline analysis**. Private captures are excluded. The original authorization was to read/test, not modify, and stop at battery <=15%. There was no unattended loop repeatedly sending arbitrary requests.

## Executed queries

| Query | Command/key, hex | Result |
|---|---|---|
| Battery | GATT 180F/2A19 | 86% on every successful read |
| Components | 0A/10 | ACK `fd0005260a10000901`; no data frame |
| Identity | F3/00 | DF reply key F3; project and V1.5 |
| Bluetooth/contact information | 0E/03 | DF key 04; 16 zero payload bytes |
| Inventory | GATT characteristic/descriptor reads | No change from the native investigation |
| Today's activity | 05/0A | Keys 07 (start), 02 (194-byte hourly block), 08 (end) |
| Capabilities | 19/00 | Same 27-byte AA block |
| Settings | 09/00 | Same payload as the previous session |
| Faces | 0F/01 | Five faces and unchanged size limits |
| Stability | Battery read every four seconds | Disconnect; test stopped |

This batch comprised 13 short sessions, nine proprietary requests and eight received-data ACKs, including failed local attempts. The historical audit checked that every request was an empty allowlisted getter with battery >15% observed less than 30 seconds earlier. No setter, clock update, binding, reset, AB sequence, OTA start or file transfer was recorded.

The 0A/10 hardware candidate came from comparative review of [Gadgetbridge](SOURCES.md#gadgetbridge). Its LED/GSensor interpretation was not confirmed locally because our device returned only an ACK.

## Windows subscription failure and correction

The first components attempt could not read CCCD through a Windows convenience API and stopped before subscription/TX. Direct descriptor 2902 access was then used.

Two later attempts sent requests but recorded no RX because the shared CCCD already reported Notify and the new WinRT client had skipped registering its own subscription. These silences are not evidence of unsupported firmware functions. The correction explicitly registered the local subscription even when shared state was Notify, then restored the previous descriptor value. F3 reception was verified before repeating the candidates. Every session using this path recorded successful restoration; functional settings were unchanged.

Private evidence includes inconclusive hardware and classic-address attempts, followed by a successful F3 query and conclusive components and contact attempts. These captures are excluded, not bundled fixtures.

## Disconnect and stopping condition

The final test planned 30 seconds of battery reads every four seconds, without proprietary requests/subscriptions. Windows recorded a connection lasting about 10.77 seconds. Battery polling did not prevent this disconnect.

The next read failed with ObjectDisposedException `0x80000013`; GATT objects were invalid. Physical research stopped because battery could no longer be verified in that connection. Last valid level: 86%, so the 15% threshold was not reached. The evidence does not identify which side initiated the disconnect. No persistent research process remained running and no binding/state-change keepalive was attempted.

## Battery policy and test limits

`tools/windows/read-watch-session.ps1` requires a valid battery read before a functional request, immediately before TX and after the query. Inventory checks before each service. A value <=15%, an invalid value or read failure stops the session. Offline auditing rejects low, unknown or stale battery evidence, unapproved requests and ACKs without matching data.

The low-battery threshold was not physically exercised: all valid readings were 86%. Synthetic tests validate the policy logic, not the device's behavior under low battery.

## Official firmware lookup: later authorization

A proposed metadata-only request to the official update service was blocked because transmitting the device-derived OTA identity needed specific authorization. No alternative request was made at that time. The user subsequently authorized it; the later response was HTTP 200/success with empty data. See [the separate result](OFFICIAL_UPDATE_LOOKUP.md).

## Reproduction boundary

Private originals are guarded-session captures, with an analysis/hashes index in the historical workspace. Those files and the old index generator are excluded. Current auditing accepts an externally supplied private session directory:

```sh
node src/research/analyze-guarded-sessions.js private/sessions output/guarded-analysis.json
```

The current public tests use synthetic policy examples and non-identifying protocol bytes. They do not claim to re-run the original physical sessions.
