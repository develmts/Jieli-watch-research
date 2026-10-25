# Sources and attribution

This register separates upstream knowledge, installed dependencies and our observations. [sources.json](sources.json) is the machine-readable record, including historical external-artifact URLs/hashes and failed fetches. No referenced third-party artifact is bundled.

Local protocol implementations were informed by proprietary-client static analysis and local captures. They are not claimed to be clean-room work. References to HryFine's reconstructed classes identify proprietary analysis, not open-source authorship. Hardware observations are our own evidence, not assertions inherited from an upstream project.

A project being readable online is not a verified redistribution license. License status is recorded narrowly; missing verification is explicit. Exact original author names and OEM identifiers are not translated. No upstream license is assigned to this entire folder.

## Gadgetbridge

**Credit:** Freeyourgadget/Gadgetbridge contributors. Reviewed headers credit Arjan Schrijver, Damien Gaignon, Petr Vaněk, Daniel Dakhno, José Rebelo and the literal contributor name "a b".

**Primary source:** [Gadgetbridge LaxasFit support](https://codeberg.org/Freeyourgadget/Gadgetbridge).

**Use:** Compared normal-channel framing, capability interpretations, Q11 matching, hardware getter and initialization behavior. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** 306e1ef0f35999628f12327cf1fb7b7bf7c62c8a

**License record:** Reviewed source headers: AGPL-3.0-or-later. Official archived README describes AGPLv3; per-file headers are the more precise record.

**Verification:** official-docs-confirmed; pinned-file-headers-verified-locally; Codeberg-refetch-unavailable.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md), [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md), [docs/COMMANDS_AND_NEXT_STEPS.md](../docs/COMMANDS_AND_NEXT_STEPS.md), [docs/NIGHT_RESEARCH.md](../docs/NIGHT_RESEARCH.md).

## LAXASFIT-HA

**Credit:** Victor Billyph (victorbillyph) and contributors

**Primary source:** [LaxasFit BLE Home Assistant integration](https://github.com/victorbillyph/chinese-smartwatch-homeassistant).

**Use:** Compared UUID/framing and documented differences in ACK handling and capability parsing. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** MIT; LICENSE credits Copyright (c) 2026 Victor Billyph.

**Verification:** primary-page-confirmed.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## Jielie

**Credit:** kagaimiq (Andrey Grigoryev) and contributors

**Primary source:** [JieLi STUFF](https://github.com/kagaimiq/jielie).

**Use:** Chip, CPU, firmware-container and programming-interface reference; no chip identification inferred for this device. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** 1657d25e6e51df6b2c18cd55cfc576c4a6370c63

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md).

## JIELI-HEALTH

**Credit:** JieLi Technology / Jieli-Tech and contributors

**Primary source:** [Android-JL_Health](https://github.com/Jieli-Tech/Android-JL_Health/blob/main/README_en.md).

**Use:** RCSP SDK comparison; not proof of local RCSP or firmware compatibility. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md).

## ZeTime

**Credit:** Gadgetbridge ZeTime documentation contributors and the credited XDA thread participants

**Primary source:** [Gadgetbridge ZeTime protocol and linked XDA discussion](https://gadgetbridge.org/internals/specifics/zetime-protocol/).

**Use:** Compared 6F/8F framing and used documentation structure as a methodological reference. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** historical-primary-document-review; XDA-thread-unavailable-HTTP-403.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md).

## OpenWatch

**Credit:** OpenWatchProject/BLOCKS contributors

**Primary source:** [OpenWatchProject readme](https://github.com/OpenWatchProject/readme).

**Use:** Compared explicitly targeted MediaTek/AOSP devices and recovery assumptions. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** 7ac721e94a38016c694e3a3dd8550ceaa9f770af

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md).

## Open-Smartwatch

**Credit:** Open-Smartwatch contributors

**Primary source:** [Open-Smartwatch OS](https://github.com/Open-Smartwatch/open-smartwatch-os).

**Use:** Compared ESP32 hardware targets and desktop-emulator scope. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** cf10dd635b41b03c30aa21ddd2492ccc07142e63

**License record:** OS repository identifies GPL-3.0. Hardware/docs may have separate terms; not inferred here.

**Verification:** primary-page-confirmed.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md).

## AsteroidOS

**Credit:** AsteroidOS contributors

**Primary source:** [AsteroidOS](https://asteroidos.org/).

**Use:** Compared Linux stack and board-specific port model. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Component-specific; no blanket license asserted.

**Verification:** primary-page-confirmed.

**Local references:** [docs/PROJECT_REVIEW.md](../docs/PROJECT_REVIEW.md).

## C30

**Credit:** TruthGh0st and contributors

**Primary source:** [C30-20-Pro-BLE-Reverse-Engineering](https://github.com/TruthGh0st/C30-20-Pro-BLE-Reverse-Engineering).

**Use:** Compared author claims and independently analyzed an external btsnoop capture. Authored parser; historical third-party data input only. No README/PDF/DOCX/archive/capture redistributed.

**Revision/version:** c506e6c45867d860327ae0c504a8867ef167547b

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/C30_README_REVIEW.md](../docs/C30_README_REVIEW.md), [src/research/analyze-c30-capture.js](../src/research/analyze-c30-capture.js).

## BLUETRUM-TOOLS

**Credit:** kagaimiq and contributors

**Primary source:** [bluetrum-tools](https://github.com/kagaimiq/bluetrum-tools).

**Use:** Architecture/hardware-family reference only; not used to identify or support this unit. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## ATCWATCH

**Credit:** atc1441 and contributors

**Primary source:** [ATCwatch](https://github.com/atc1441/ATCwatch).

**Use:** Architecture/hardware-family reference only; not used to identify or support this unit. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## WASP-OS

**Credit:** wasp-os contributors

**Primary source:** [wasp-os](https://github.com/wasp-os/wasp-os).

**Use:** Architecture/hardware-family reference only; not used to identify or support this unit. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## INFINITIME

**Credit:** InfiniTime contributors

**Primary source:** [InfiniTime](https://github.com/InfiniTimeOrg/InfiniTime).

**Use:** Architecture/hardware-family reference only; not used to identify or support this unit. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-page-confirmed.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## BLUETOOTH-SIG

**Credit:** Bluetooth SIG

**Primary source:** [Bluetooth Assigned Numbers and L2CAP](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/index-en.html).

**Use:** Standard UUID terminology and CID distinction. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-reference-recorded-in-historical-review.

**Local references:** [docs/UUID_AND_PROTOCOL.md](../docs/UUID_AND_PROTOCOL.md).

## NORDIC-NUS

**Credit:** Nordic Semiconductor

**Primary source:** [Nordic UART Service](https://nrfconnectdocs.nordicsemi.com/ncs/latest/nrf/libraries/bluetooth/services/nus.html).

**Use:** Distinguishes official ...9E service from observed ...9F. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-reference-recorded-in-historical-review.

**Local references:** [docs/UUID_AND_PROTOCOL.md](../docs/UUID_AND_PROTOCOL.md).

## PHYPLUS

**Credit:** Phyplus

**Primary source:** [PHY6222 product information](https://en.phyplusinc.com/product_detail/1.html).

**Use:** Vendor attribution for PHY6222; not our hardware identification. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** primary-reference-recorded-in-historical-review.

**Local references:** [docs/C30_README_REVIEW.md](../docs/C30_README_REVIEW.md).

## REFINE-LEAD

**Credit:** Author identity not verified; refer to the original post before attribution beyond this link.

**Primary source:** [ReFine author discussion](https://www.reddit.com/r/hardwarehacking/comments/1wsmxf9/i_reverseengineered_my_hryfine_smartwatchs_ble/).

**Use:** Unverified lead only. Not a verified open-source implementation or source for local findings. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** unverified-historical-lead.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## BOOD-LEAD

**Credit:** Author identity not verified; refer to the original post before attribution beyond this link.

**Primary source:** [BOOD/Cus5610 author discussion](https://www.reddit.com/r/hardwarehacking/comments/1u6hhqs/initial_reverse_engineering_notes_on_a_generic/).

**Use:** Unverified lead only. Not a verified open-source implementation or source for local findings. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** Not verified; no code or text redistributed.

**Verification:** unverified-historical-lead.

**Local references:** [docs/OPEN_SOURCE_REVIEW.md](../docs/OPEN_SOURCE_REVIEW.md).

## CAPSTONE-JS

**Credit:** Alexandro Sanchez Bach and contributors

**Primary source:** [@alexaltea/capstone-js](https://github.com/AlexAltea/capstone.js).

**Use:** Installed analysis dependency. Dependency installed through npm; excluded node_modules is not vendored project source.

**Revision/version:** 5.0.9

**License record:** BSD-3-Clause; unmodified packaged notice retained.

**Verification:** installed-package-and-primary-repository-confirmed.

**Local references:** [src/research/analyze-native.js](../src/research/analyze-native.js).

## ADM-ZIP

**Credit:** Another-D-Mention Software and other contributors

**Primary source:** [adm-zip](https://github.com/cthackers/adm-zip).

**Use:** Installed analysis dependency. Dependency installed through npm; excluded node_modules is not vendored project source.

**Revision/version:** 0.6.1

**License record:** MIT; unmodified packaged notice retained.

**Verification:** installed-package-and-primary-repository-confirmed.

**Local references:** [src/research/analyze-native.js](../src/research/analyze-native.js).

## CAPSTONE-ENGINE

**Credit:** Capstone engine and LLVM contributors

**Primary source:** [Capstone disassembly framework](https://github.com/capstone-engine/capstone).

**Use:** Underlying engine provenance for the JavaScript/WASM dependency. Reference/comparison only; no upstream implementation source vendored.

**Revision/version:** Not pinned; do not imply a frozen upstream state.

**License record:** See upstream LICENSE.TXT and component notices; wrapper license alone is not a substitute.

**Verification:** primary-page-confirmed.

**Local references:** [src/research/analyze-native.js](../src/research/analyze-native.js).


## BLEAK

**Credit:** Henrik Blidh and contributors. [Bleak](https://github.com/hbldh/bleak), pinned release `v3.0.2`, MIT; upstream notice credits Copyright (c) 2020, Henrik Blidh.

**Use:** Optional Linux/macOS Bluetooth transport dependency and official API/backend documentation reference for the authored POSIX adapter. No upstream implementation is vendored. Package metadata and license were checked at the pinned tag. Physical POSIX interoperability remains unverified.

**Local references:** [POSIX tools](../tools/posix/README.md), [backend](../tools/posix/watch_ble.py), [requirements](../tools/posix/requirements.txt), [notices](../THIRD_PARTY_NOTICES.md).
