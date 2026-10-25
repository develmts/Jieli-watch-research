# Review of the six proposed projects

The review covered documentation, repository trees and selected source files without Bluetooth work or execution of external software. Credits, revisions and license-verification limits are recorded in [SOURCES.md](SOURCES.md).

Local reference: project `E06B_T27_LC[Smartwatch]_RStyle2_240x240_HryFine`, V1.5, client platform 7 derived from `10000004`, normal ...9f UUIDs, DF/FD, AA capabilities and format 8/WF. Manufacturer, CPU, board, bootloader and recovery remain unknown.

## 1. Gadgetbridge: closest protocol comparison

Credit: **Freeyourgadget/Gadgetbridge contributors**, including the authors named in the reviewed LaxasFit file headers; see [GADGETBRIDGE](SOURCES.md#gadgetbridge). The GitHub archive directs development to Codeberg. Reviewed files at revision `306e1ef0f35999628f12327cf1fb7b7bf7c62c8a`: `LaxasFitConstants.java`, `LaxasFitDeviceSupport.java`, `LaxasFitCoordinator.java`. Earlier access failures were historical; the selected files were subsequently available in the private review workspace.

The [official LaxasFit page](https://gadgetbridge.org/gadgets/wearables/laxasfit/) describes partial Q11 support. The reviewed coordinator recognizes `^(Q11.*)$`, which does not match Smartwatch. Its eight-alarm limit is an implementation choice, not a measured limit on our unit. The manufacturer label LaxasFit is not physical manufacturer identification.

The support class sends 0A/10 for hardware information and interprets two strings as LED and GSensor. That provided a research candidate; our later query was ACK-only, so those components were not identified. Parser offsets on complete frames were not assumed transferable.

Initialization writes multiple commands and synchronizes time. An empty 13/02 is used as band information in that implementation, while the reviewed HryFine path uses 13/02 with payload 01 to request OTA start. Same opcode does not mean same frame or effect.

An upstream comment relating initialization to consumption does not explain our approximately ten-second drops. No explicit keepalive was found in the selected implementation; mentioned 200 ms sleeps were commented out. Comments, executable behavior and physical experiments are distinct evidence.

Decision: use as an attributed comparison of protocol/functions, cross-checking each candidate with local analysis and captures. No Gadgetbridge startup sequence or implementation source was imported or executed. The selected source headers specify AGPL-3.0-or-later; that does not assign the same license to this independently authored research folder.

## 2. kagaimiq/jielie: chip-family investigation

Credit: **kagaimiq (Andrey Grigoryev) and contributors**; [JIELIE](SOURCES.md#jielie). Reviewed tree: `1657d25e6e51df6b2c18cd55cfc576c4a6370c63`. The consulted revision does not establish the repository's current state.

The [firmware-format notes](https://kagaimiq.github.io/jielie/datafmt/newfw.html) describe containers involving `uboot.boot`, `isd_config.ini`, `app_dir_head`, resources and variants. These could help classify a complete firmware image obtained separately; a WF face is not thereby a complete image in that format.

The CPU index distinguishes pi32, pi32v2 and q32s. Appearance cannot select a CPU. The reviewed device index listed a camera and speaker, not this watch project. The protocol index listed RCSP without a developed specification in that section. UBOOT USB/UART paths require different interfaces and are not BLE queries to send now.

Additional primary source: **JieLi Technology's** [Android-JL_Health SDK](https://github.com/Jieli-Tech/Android-JL_Health/blob/main/README_en.md), source ID `JIELI-HEALTH`. It covers watch functions and RCSP communication, but is not universal firmware or proof that our device uses JieLi/RCSP. RCSP was not confirmed in local captures.

Decision: retain a conditional identification lead. Internal platform 7 and an OEM UUID do not confirm it. No jielie code, flasher or firmware is included here; no license has been inferred merely from public access.

## 3. XDA / ZeTime: another protocol family

Credit: **the XDA thread participants and Gadgetbridge ZeTime documentation contributors**, [ZETIME](SOURCES.md#zetime). The [requested thread](https://xdaforums.com/t/testing-gadgetbridge-with-zetime-support.3813241/) returned HTTP 403 during the original review; its complete discussion was not read. Gadgetbridge's MyKronoz page links it and the [ZeTime protocol documentation](https://gadgetbridge.org/internals/specifics/zetime-protocol/), which was reviewed.

That documentation describes 6F/8F framing, channels 6006/8001-8004 and separate validation using byte 03. Our observed framing is DF/FD on ...9f. The concrete protocol difference is stronger evidence than visual similarity. ZeTime hand calibration and boot modes must not be applied to this unit. The reviewed page reported no Gadgetbridge ZeTime firmware-update support.

Decision: a documentation-method example, with no demonstrated direct compatibility.

## 4. OpenWatchProject: model-specific Android ports

Credit: **OpenWatchProject/BLOCKS contributors**, [OPENWATCH](SOURCES.md#openwatch). Reviewed [readme](https://github.com/OpenWatchProject/readme) revision `7ac721e94a38016c694e3a3dd8550ceaa9f770af`. It describes an AOSP project limited there to MediaTek watches, with Harmony/Infinity families and models such as KW88, LEM7 and Thor, using Android/TWRP procedures.

E06B_T27_LC was not found in the reviewed lists. There is no evidence that our unit runs Android or exposes the required boot/recovery interfaces. White-label marketing is not a compatibility criterion.

Decision: no validated replacement-firmware route for this unit.

## 5. Open-Smartwatch: open ESP32 hardware

Credit: **Open-Smartwatch contributors**, [OPEN-SMARTWATCH](SOURCES.md#open-smartwatch). Reviewed operating-system revision `cf10dd635b41b03c30aa21ddd2492ccc07142e63`. The review did not establish the complete state of develop.

The [project documentation](https://open-smartwatch.github.io/) distinguishes Light and GPS Edition. The inspected `platformio.ini` uses espressif32, pico32 and project-specific Light/GPS targets. Its faces and desktop emulator target that software/hardware; they do not create compatible WF binaries. No correspondence to our unknown board was demonstrated, and flashing procedures assume the project's own connections/buttons.

Decision: a useful open-hardware reference, not a located replacement for this unit. The OS repository currently identifies GPL-3.0; no implementation code is included here.

## 6. AsteroidOS: board-specific Linux ports

Credit: **AsteroidOS contributors**, [ASTEROIDOS](SOURCES.md#asteroidos). The [official project](https://asteroidos.org/) describes Linux with Qt/QML, OpenEmbedded and libhybris for compatible Android/Wear OS devices. The reviewed installation list used model/board identifiers such as catfish, sturgeon and lenok, with per-port status. Our firmware project was not found in that review.

Decision: relevant architecture, but no demonstrated port for this unit. License terms are component-specific, not one inferred license for every linked artifact.

## Firmware conclusion and its date

No viable replacement firmware for E06B_T27_LC was established by this six-project review. That is a review result, not proof of impossibility. Transport libraries alone do not establish image/board compatibility, memory/peripheral support, boot behavior or recovery.

The original review did not establish an official update newer than V1.5. A later authorized service lookup returned no offered package; see [the lookup report](OFFICIAL_UPDATE_LOOKUP.md). LaxasFit operating with the existing firmware demonstrates client interoperability, not replacement firmware.

## Evidence boundary

Original downloaded review files and hashes remain in the private workspace and are not redistributed. Selected file provenance is captured in [sources.json](sources.json). Access failures are recorded rather than replaced with claims of complete coverage. No downloaded external program was executed during the review.
