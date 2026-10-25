# Known commands and next experiments

This document records a **static-analysis** command map and its later experimental status. It is not an automatic probing sequence. Hexadecimal is used unless decimal is stated. Proprietary method names below are source labels, not copied implementations. Original classes and raw evidence remain outside this folder.

## Prioritized information queries

| Request | Client method/parser | Meaning and limits | Historical status / later result |
|---|---|---|---|
| 19/00 (25/0 decimal) | `SettingIssuedUtils.getDeviceFeatures`, `NotifyWriteUtils.readFeatures` | Capabilities; matches 2A28. Repeated polling is unnecessary | Physically observed |
| 0F/01 (15/1 decimal) | `NotifyWriteUtils.syncProcess`, `BleDataUtils.handleWatchFaceInfo` | Count, active code, installed codes and limits; reply 0F/09 | Physically observed |
| F3/00 (243/0 decimal) | `GeneralUtils.requestDeviceInfo`, `NotifyWriteUtils.dataHandle` | Length-prefixed firmware/project strings | Initially planned; subsequently returned V1.5 and project identity |
| 13/01 (19/1 decimal) | `GeneralUtils.requestOTAInfo`, data handler case 19 | Update identity and version/project variant | Initially planned; later observed. Distinct from OTA start 13/02 |
| 09/00 | `GeneralUtils.requsetSettingInfo`, `UserInfoAndRemindUtils` | Settings and variable/personal state | Later read; no settings changed |
| 08/00 | `GeneralUtils.requsetAlarmClockInfo`, `AlarmClockUtils` | Existing alarm records | Later returned empty data; no alarms changed |
| 0F/04 | `syncProcess`, face reply key 5 | Custom face code, positions, color and elements | Later observed with a narrowly documented inner-length anomaly |
| 1A/03 and 1A/05 | `requestSocialSupport`, `requestPaymentSupport` | Supported social/payment code types | Relevant flags absent/false; later ACK-only replies |
| 20/00 | `requestProductIdentification` | Client expects text fields separated by hyphens | Byte 28 absent; later ACK-only reply, not an identity result |

F3/00 payload: `[versionLength][version][projectLength][project]`, with one-byte lengths. The reconstructed dispatch uses signed/char comparisons; check bytecode or actual frames if another variant differs.

13/01 treats the whole payload as an OTA identity and attempts version parsing after four initial bytes. Those bytes are not proven to be a chip ID or address. The later authorized service lookup is recorded separately in [the update report](OFFICIAL_UPDATE_LOOKUP.md).

## Namespaces must remain distinct

- 02: settings/actions, including time, language, goals, find-watch and switches; not a generic read namespace.
- 03/04: bind/unbind; 06/0D: reset/restore. Outside information-only probing.
- 05: data synchronization and stream activation. An empty payload does not establish an absence of side effects.
- 07/0A/0B: factory, flash and test paths. Document rather than probe blindly.
- 0C: device events/control, such as camera and media.
- 0F: face functions; key 03 selects, 05 configures customization and 0A updates a code. Keep these separate from information requests.
- 13: OTA identity/start. Key 02 with payload 01 may change operating mode and restart the device.
- 19: capabilities; 1A: additional functions mixing reads and setters.
- 1F: pairing/PIN; 20: product identity.
- F0/F1/F3: proprietary verification/firmware/information branches. Only the specific reviewed F3/00 identity request is established here.

## Next work

1. Capture a compatible client's traffic around one explicitly selected action and compare before/after discovery.
2. Correlate requests, replies, notifications and disconnects using timestamps and raw frames.
3. Investigate FFF1/FF13/FF14 only after an observed client action identifies a plausible role.
4. Identify actual board/SoC evidence before selecting any firmware tools.
5. Keep unknown battery, failed reads and the <=15% threshold as stopping conditions for the guarded runner.

Gadgetbridge supplied comparative candidates, including hardware information 0A/10. That role is attributed to [Gadgetbridge's LaxasFit implementation](SOURCES.md#gadgetbridge), not established by our ACK-only response. Do not import upstream initialization, binding or time synchronization as a read-only procedure.
