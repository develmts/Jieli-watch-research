# Native Bluetooth investigation

Evidence: **observed** WinRT sessions and **offline interpretation**, cross-checked against **proprietary-client static analysis**. No external project's hardware identity is treated as our own. Private source files listed below are excluded from this distribution.

## Scope and private evidence

Complete inventory: six services, twelve characteristics and four CCCD descriptors. All eight readable characteristics and four descriptors were read successfully; four other characteristics were write-only. Proprietary information queries: fifteen distinct queries, sixteen executions, ten data responses and six ACK-only outcomes, including the repeated alarm query. F3 was also executed separately.

| Private capture alias (timestamps omitted; numbered to distinguish captures) | Recorded role |
|---|---|
| `winrt_f3.json` | Confirmed extended identity |
| `winrt_inventory_1.json` | First fully successful inventory |
| `winrt_inventory_2.json` | Expanded native inventory |
| `winrt_information_1.json` | First known-query batch |
| `winrt_information_2.json` | Connection/activity/face/alarm queries |
| `winrt_passive_1.json` | Advertisements and notification listening |
| `winrt_passive_2.json` | Listening with explicit disconnect records |
| `winrt_passive_3.json` | Windows MaintainConnection experiment |

The original interpretation/hashes index is not bundled. `src/research/analyze-watch-observations.js` can analyze externally provided information-session files. Public tests do not include these private captures.

## GATT inventory

Short UUIDs use `-0000-1000-8000-00805f9b34fb`. Normal-channel UUID is exactly `6e400001-b5a3-f393-e0a9-e50e24dcca9f`, ending in 9f.

| Service (handle) | Characteristic (handle) | Properties | Read/interpretation |
|---|---|---|---|
| 180F (1) | 2A19 (2) | Read, Notify | `56`: 86% battery, not the text letter V |
| 180A (5) | 2A25 (6) | Read | ASCII `10000004`; client maps to internal platform 7 |
| 180A | 2A27 (8) | Read | ASCII `10000`, generic hardware revision |
| 180A | 2A26 (10) | Read | ASCII `10000`, distinct from useful F3 version V1.5 |
| 180A | 2A28 (12) | Read | 27-byte AA capability block, matching earlier reads |
| FF10 (14) | FFF1 (15) | Write, WriteWithoutResponse | Unknown meaning; no writes sent |
| FF12 (17) | FF13 (18) | Write | Unknown meaning; no writes sent |
| FF12 | FF14 (20) | Read, Notify | Empty read; no messages while listening |
| normal (23) | ...0003...9f (24) | Read, Notify | Empty direct read; known-query replies arrive as notifications |
| normal | ...0002...9f (27) | Write, WriteWithoutResponse | Known DF requests and FD ACKs |
| FF00 (29) | FF01 (30) | Read, Notify | OTA channel, empty read; no new OTA subscription |
| FF00 | FF02 (33) | Write, WriteWithoutResponse | OTA channel; no writes sent |

CCCD 2902 appears at handles 4, 22, 26 and 32. Descriptor values are temporary session state. FF01 already read `0100` once; that does not mean this investigation initiated OTA. Shared state and invalidated session objects can complicate subscription cleanup.

Windows reported a public address, appearance 0 and session MaxPduSize 256. That does not establish a safe application-level OTA packet size. The 2A25 platform mapping is the proprietary client's interpretation, not a verified serial number, brand or processor identity.

## Proprietary queries

Commands/keys below are hexadecimal. Requests have empty payloads; valid received data is acknowledged. ACK-only means no data reply within six seconds, not proof of an absent function.

| Query | Request -> reply key | Description and result |
|---|---|---|
| Extended identity | F3/00 -> F3 | Version V1.5; project `E06B_T27_LC[Smartwatch]_RStyle2_240x240_HryFine`; consistent with the user-reported factory label |
| Update identity | 13/01 -> 01 | Opaque prefix `69d6029a`, V1.5 and Smartwatch; not OTA-start request 13/02. No server lookup during this session |
| General settings | 09/00 -> 09 | Goal 5000, language code 4 interpreted as Spanish, left wrist, Android indicator, vibration, 24-hour format; see details below |
| Alarms | 08/00 -> 10 | Valid empty payload twice: zero returned records; maximum supported slots unknown |
| Face customization | 0F/04 -> 05 | Code `0000000100000000`, x=30, y=30, color=65535, aboveTime=4, belowTime=1, backgroundUpdate=2; not a sixth installed face |
| Water reminder | 11/00 -> 11 | Disabled; 60-minute interval, hours 08-22, repeat mask 0, lunchBreak=0 |
| Notification settings | 12/00 -> 12 | Visibility/enabled flags; no test notifications sent |
| Sedentary reminder | 14/00 -> 14 | Disabled; threshold 0, interval 45 minutes, hours 08-22, repeat 0, lunchBreak=0 |
| Medication | 10/00 | ACK-only; corresponding feature flag false |
| Power saving | 1A/07 | ACK-only; `isSupportPowerSaveSwitch=false`; UI visibility is a different field |
| Social code type | 1A/03 | ACK-only; `supportSocialType=false` |
| Payment code type | 1A/05 | ACK-only; `supportPaymentType=false` |
| Product identity | 20/00 | ACK-only; required flag byte absent in the received block |
| Bluetooth connection state | 02/3C | Client-known getter; ACK-only, no detailed state |
| Today's activity | 05/0A -> 08 | Sequence 07 -> 02 -> 08: start, 194-byte hourly block, end. A calendar-date field and 24 slots with zero raw steps/distance/calories; not proof of actual inactivity. No pulse measurements |
| Installed faces | 0F/01 -> 09 | Five faces, active internal code `0018000000000007`, limits 53248/86016 bytes; matches earlier capture |

## Settings interpretation

The client parser `UserInfoAndRemindUtils` uses records with identifier and fixed length after a five-byte prefix. Prefix `01ba568ae0` and trailing `0000` remain opaque. Times below are interpreted as minutes of day, not independent confirmation that every setting is enforced.

- Sleep monitoring enabled, 22:00-08:00.
- Raise-to-wake disabled, 08:00-22:00.
- Automatic pulse measurement disabled, cycle field 60, hours 08:00-22:00. This does not prove a working or accurate sensor.
- Do-not-disturb disabled, 22:00-08:00.
- General-block sedentary fields are zero, interpreted as interval 30 minutes and hours 00-00. This conflicts with the dedicated query's 45 minutes/08-22; both report disabled. Neither has been chosen arbitrarily as ground truth.
- Eleven legacy notification flags are set; the dedicated query is more detailed.
- Tag 12=`00` is unknown; tag 14 temperature-unit raw=0 has no established scale.

## Notification flags

Each nibble uses bit 0 for visibility and bit 1 for enabled state. Byte pairs are calls/SMS, WeChat/QQ, DingTalk/Weibo, Alipay/Teams, Facebook/Twitter, WhatsApp/Snapchat, Instagram/Messenger, LinkedIn/Skype, KakaoTalk/Telegram, VK/Zalo, Viber/Line and other/Outlook. The first 22 and Outlook show both bits; other shows visibility only. MAX has both flags false. A six-byte zero tail is uninterpreted. These are client preferences, not verified delivery tests for each application.

## Narrow firmware-length anomaly

Customization frame: `df0016570f0105000b0000000100000000001e001effff040102`. Outer length and checksum are valid, but declared inner payload length is 11 and actual payload length is 17. The offline parser accepts only this specific 0F/05 11-to-17 case and emits a warning. Compatibility with older shorter face codes is a hypothesis, not a finding. The first runner classified the frame as an error; retained raw bytes allowed later interpretation.

The first alarm attempt also had a local empty-payload conversion error. Repetition and the valid frame establish an empty response rather than a device failure.

## Advertisements, listening and disconnects

Twenty seconds of passive advertisement observation recorded nine target packets: Smartwatch, ConnectableUndirected, RSSI -44 to -39 dBm. AD flags 01=`06`; full name AD 09=`536d6172747761746368`. No service UUID or manufacturer data was present in those packets. This can explain UUID-filtered discovery failures, without proving the device never advertises other data.

Three approximately twenty-second listens subscribed to battery, FF14 and the normal channel, without application requests/ACKs. Zero spontaneous notifications were observed. Silence does not identify FF14. Enabling a CCCD is a subscription write, even when no functional command is sent.

Without MaintainConnection, the session ended disconnected after a connection lasting about 9.67 seconds. With temporary Windows MaintainConnection, the connection dropped after about 9.78 seconds, then Windows reconnected after about two seconds; the session ended connected. MaintainConnection did not prevent a drop. Its previous false value was restored.

Cleanup of all three notification channels reported ObjectDisposedException `0x80000013`: original GATT objects were invalid. A persistent implementation must rediscover characteristics and resubscribe after reconnecting. The initiator of the drop, and its relationship to all browser failures, remain unknown.

## Open questions and boundaries

Keep opaque data rather than inventing labels. Manufacturer, commercial model, unique serial, SoC, OTA prefix, settings prefix/tail, FFF1/FF13/FF14 meaning and complete WF layout remain unresolved. Internal platform 7 does not identify a processor.

No arbitrary bytes, F0/F1 verification/binding, global synchronization, live sensor activation, control actions, factory tests, reset or OTA start were attempted. The useful next experiment is capture/differential analysis of a compatible client around a known action, not interpreting a silent writable characteristic as a complete protocol.

Current tools are under `tools/windows/`; their historical predecessors and excluded captures remain in the private original workspace. The first inventory with local conversion errors is retained privately and is not used as evidence of a device failure. There was no continuous research process running in the background.
