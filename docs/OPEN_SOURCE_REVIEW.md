# Open-source and external reference review

This is a comparison record, not a list of compatible implementations. [The detailed six-project review](PROJECT_REVIEW.md) supersedes the earlier Codeberg-access limitation. [SOURCES.md](SOURCES.md) assigns credits and distinguishes verified primary pages, private historical source records and unverified leads.

## Closest communication references

### Victor Billyph's LaxasFit / Home Assistant integration

Credit: **Victor Billyph (victorbillyph) and contributors**. [Repository](https://github.com/victorbillyph/chinese-smartwatch-homeassistant), [protocol notes](https://github.com/victorbillyph/chinese-smartwatch-homeassistant/blob/main/docs/PROTOCOL.md), [implementation](https://github.com/victorbillyph/chinese-smartwatch-homeassistant/blob/main/custom_components/laxasfit/ble_protocol.py). See source ID `LAXASFIT-HA`.

The reviewed material shares the ...9f UUID family and DF framing with checksum at offset 3. This makes it a useful comparison. Its ACK description, first-ACK handling and capability offsets differ from local evidence; its sensor meanings and address derivation were not imported. Its claimed chipset applies to that author's device, not ours. Its MIT notice credits Victor Billyph; no implementation code from the project is vendored here.

### Gadgetbridge's LaxasFit support and capture guidance

Credit: **Freeyourgadget/Gadgetbridge contributors**. The [official device page](https://gadgetbridge.org/gadgets/wearables/laxasfit/) documents partial Q11 support. Its [Bluetooth development guide](https://gadgetbridge.org/internals/development/bluetooth/) is a methodological reference for HCI comparisons. LaxasFit and FitPro are not automatically interchangeable families.

Codeberg initially failed during one session, then selected constants/support/coordinator files were obtained. Their revision, file authors and AGPL-3.0-or-later headers are recorded in [the detailed review](PROJECT_REVIEW.md) and [source register](SOURCES.md#gadgetbridge). An upstream implementation decision is not a measured capability of this watch. No upstream initialization or code was adopted.

### Unverified author posts: ReFine and BOOD/Cus5610

The original research linked two author discussions: [ReFine](https://www.reddit.com/r/hardwarehacking/comments/1wsmxf9/i_reverseengineered_my_hryfine_smartwatchs_ble/) and [BOOD/Cus5610 notes](https://www.reddit.com/r/hardwarehacking/comments/1u6hhqs/initial_reverse_engineering_notes_on_a_generic/). They are preserved as **unverified leads**, not verified open-source projects. The author identities, complete artifacts and licenses were not established during this normalization. No code or prose from those posts is redistributed.

Historically recorded comparisons mentioned DF/FD, chipset assumptions, 18A8 OTA and corrected hardware hypotheses. None of those post-specific claims establishes our chipset or protocol coverage. Our distinction between DF data and FD ACKs comes from local captures. Do not promote these leads to specifications without fetching and checking the primary evidence.

## Other families and layers

| Credited project | Contribution as a reference | Limit |
|---|---|---|
| [kagaimiq/bluetrum-tools](https://github.com/kagaimiq/bluetrum-tools) | Bluetrum chip/firmware tools and notes | Relevant only after hardware identification; no guaranteed local parser or client |
| [atc1441/ATCwatch](https://github.com/atc1441/ATCwatch) | Alternative firmware for explicitly targeted P8/PineTime/DaFit devices | Does not establish compatibility with this HryFine unit |
| [wasp-os contributors](https://github.com/wasp-os/wasp-os) | MicroPython watch environment | Device/software architecture reference, not this protocol |
| [InfiniTime contributors](https://github.com/InfiniTimeOrg/InfiniTime) | PineTime firmware | Another hardware target; does not resolve local WF format |

Credits and reuse status for each are in [SOURCES.md](SOURCES.md). No code or firmware from these projects is included. The review did not locate and verify a public parser/builder for the exact local format 8/WF corpus. That is not proof that none exists.

## Standards and vendor references

Credit: **Bluetooth SIG**, Assigned Numbers and L2CAP specifications; **Nordic Semiconductor**, official Nordic UART Service documentation. Their terminology helps distinguish standard UUID names and CID ranges. The official Nordic service ends in 9E; our observed channel ends in 9F. A similar UUID does not establish a chip manufacturer.

Use external work to identify comparisons and hypotheses, then retain local evidence and the proprietary-client analysis boundary. Do not import startup macros that bind, synchronize time/settings, change language or enter OTA. F3/00 and later information reads were subsequently observed; historical next-step suggestions are not current unexecuted claims.
