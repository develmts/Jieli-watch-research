# C30 Pro / FitHere: text compared with the published capture

Source attribution: **TruthGh0st and contributors**, [C30-20-Pro-BLE-Reverse-Engineering](https://github.com/TruthGh0st/C30-20-Pro-BLE-Reverse-Engineering), reviewed revision `c506e6c45867d860327ae0c504a8867ef167547b`. See [source register](SOURCES.md#c30). README and EXTRA_CONTEXT were reviewed; the archive's btsnoop was analyzed independently. DOCX/PDF documents were not reviewed in full. No commands were sent to our device.

## Author claims versus our analysis

The README describes FitHere/C30, AB/5A frames, hidden services and initialization. It also acknowledges unresolved unlock triggering, CRC8 validation and a working client. EXTRA_CONTEXT warns of possible errors and describes one watch changing identity; this differs from a two-watch narrative elsewhere. These are attributed author statements, not established facts about our watch.

The useful contribution is a downloadable HCI capture. A fixed list of archive members was extracted for examination without executing them. The archive, capture and third-party prose are not redistributed here; no permissive license for that archive has been verified. The project being publicly accessible does not establish redistribution permission.

## Independent results on that external capture

The authored offline analyzer is `src/research/analyze-c30-capture.js`; it requires an external btsnoop path. These results describe a historical run, not an automatically reproducible bundled fixture.

| Measurement | Result |
|---|---|
| File | 10155021 bytes, btsnoop H4 |
| Records | 41529, no truncated record; matches the advertised count |
| ACL packets | 14210; no continuation fragments in this capture |
| AB commands | 5161 ATT 0x52 writes, handle 0x002C, CID 0x0004 |
| 5A responses | 92 ATT 0x1B notifications, handle 0x002F, CID 0x0004 |
| CID 0x0017 | Zero identified packets |
| GATT discovery | Eight distinct services; repeated topology |

Discovery identifies service 0x18D0 at handles 42-49, characteristic 0x2D01 at handle 44/0x2C and 0x2D00 at handle 47/0x2F. That is where AB requests and 5A replies travel. Another proprietary service is `5833ff01-9b8b-5191-6142-22a4536ef123`. AE00, FD03 and FF00 do not appear in the analyzed discovery replies; a different firmware state could still expose them.

Opaque traffic on CID 0x0042 uses another HCI handle: 8656 packets with 940/941-byte payloads. It has not been identified as sensor data or confidently attributed to the watch. Packet size and frequency alone are insufficient.

## Interpretation corrections

AB commands in this capture travel over ATT/GATT. The data does not support the assertion that GATT is merely decorative while functional traffic uses hidden CID 0x0017.

The [Bluetooth SIG L2CAP specification, section 2.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-61/out/en/host/logical-link-control-and-adaptation-protocol-specification.html) places dynamic CIDs at 0x0040 and above; 0x0017 is not a dynamic CID in that scheme. Distinguish CID, PSM, HCI handle, ATT handle and UUID. This does not identify exactly which fields the original narrative confused.

The README mentions PHY6222. [Phyplus identifies PHY6222 as its product](https://en.phyplusinc.com/product_detail/1.html); that label is not itself a JieLi part name. Multiple components or mistaken identification remain possible. This does not establish our watch's manufacturer.

Our verified transport is DF/FD on the ...9f channel with FF00 OTA. The external capture is AB/5A on 18D0/2D01/2D00. Those are different protocols. No AB startup/unlock sequence or external constant was transferred into the local implementation.

The methodological lesson is to compare actual discovery before/after an explicit action and retain original captures. Conditional services are possible, but require evidence of both states and their trigger. The capture does not confirm JieLi silicon in our watch and provided no verified replacement firmware for E06B_T27_LC.
