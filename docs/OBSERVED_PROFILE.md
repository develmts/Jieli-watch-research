# Observed device profile

Provenance: **observed**, **static analysis** and **user-reported**, distinguished below. This document does not rely on another project's hardware identity.

## Capability block

A 27-byte AA block was read from 2A28 and returned identically by request 19/00 (25/0 decimal). See [the complete bit map](FEATURE_MAP.md). Values below describe client interpretation, not physical verification of a sensor or feature.

| Area | Interpretation |
|---|---|
| Faces | Selection, customization and transfer flags set; format 8, 8-byte identifiers, `is565Bmp=true`, `binPreviewFlag=false` |
| Display | Resolution ID 1 and shape 2. The proprietary UI uses 240x240 on its default path; a WF sample is consistent with that. This is not a physical dimension read |
| Extended identity | `isSupportDeviceInfo=true`; `isSDKDevice=false` |
| Connectivity | `isBLE3=true`, `isSupportPair=true`, `isScanConnnect=false`; these are OEM labels, not precise Bluetooth versions |
| Interface | Contacts, units, time format, languages and raise-to-wake are declared |
| Communication | `isPushCall=true`, `isSupportSOS=true`; not functionally verified by these flags |
| Reminders | Water and sedentary reminders declared; medication not declared; `isNewMsgPushSetting=true` |
| Weather | `isSupport7Weather=true` |
| Customization | `isSupportUserName`, `isSupportDiyOnlineWpaper`, `isSupportDiyRdefault` set |
| Health UI | Heart-rate, blood-pressure, sleep and glucose display flags false; oxygen and temperature not declared by their flags |
| Power saving | `isShowPowerSaveMode=true` but `isSupportPowerSaveSwitch=false`; UI visibility and an implemented switch/query are different fields |
| Updates | `isOTA=true`; does not identify chipset, bootloader or compatible firmware |
| Social/payment/HID | Reviewed specific flags false; not a comprehensive list of supported notification types |

A false `isShow*` flag does not prove absent hardware. Physical hardware, usable functionality and measurement accuracy are separate questions.

## Identity and later corrections

Advertised name: `Smartwatch`. 2A26 and 2A27 contain ASCII `10000`. An early browser inventory did not expose 2A24, 2A25 or 2A29; the later native inventory did expose 2A25 as `10000004`. The proprietary client maps that value to internal platform 7. This is not a verified serial number or chipset identity. See [the later inventory](LIVE_INVESTIGATION.md).

The client attempts to parse 2A27 and cast it to a protocol-version byte; `10000` could truncate to 16. Real frames worked with version 01. This discrepancy is documented rather than used to force a different version from reconstructed Java alone.

F3/00 subsequently returned version `V1.5` and project `E06B_T27_LC[Smartwatch]_RStyle2_240x240_HryFine`. The user also reported a factory-test screen with that project identity. The screen reported passing LCD, GSensor, resource, PowerKey and TP tests; this is a user observation, not independent sensor validation.

Shared UUIDs, the app name and internal platform 7 do not establish Nordic, Telink, JieLi or Bluetrum hardware. JieLi remains a working hypothesis.

## Unresolved bytes

- Byte 3 bit 0x80 is set without an identified use in `readFeatures`; shape uses the low nibble.
- Byte 12 and bytes 20-22 are zero without a known interpretation. Do not label them reserved without a specification.
- Unread bits in bytes 1, 3, 14, 19 and 23-26 remain unmapped; zero does not establish meaning.
- Byte 13 is `supportSportMode=0`; its full enumeration is not established.
- Bytes 4-11 form a most-significant-bit-first language bitmap. Indices are known, but resource-label mapping remains unverified.
- ACK auxiliary bytes have no general interpretation beyond observed uses.
- Face-code subfields and the complete WF layout remain unresolved.
- Bytes 27 and 28 do not exist in this 27-byte response. Their flags are absent/unknown, not confirmed false.

## Scope limits

Manufacturer, commercial model, unique serial number, processor, board revision and recovery method are unknown. Claims imported from external projects remain attributed comparisons, not additions to this device's proven profile. See [sources](SOURCES.md).
