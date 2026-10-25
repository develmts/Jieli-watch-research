# Jieli Watch Research

Original research notes and tools for an unbranded watch using HryFine/LaxasFit-compatible communication. All project-authored identifiers, messages, comments and documentation use English. The application is maintained separately.

The project name reflects the JieLi chipset hypothesis; the chipset has not been
confirmed. This is an independent research project, unaffiliated with JieLi.

## Start here

- [Observed device profile](docs/OBSERVED_PROFILE.md)
- [UUIDs and frame layouts](docs/UUID_AND_PROTOCOL.md)
- [Query reference](docs/QUERY_REFERENCE.md)
- [Evidence levels and open questions](docs/EVIDENCE.md)
- [Reproduction guide](docs/REPRODUCIBILITY.md)
- [Linux/macOS Bash tools and installation](tools/posix/README.md)
- [External sources and attribution](docs/SOURCES.md)
- [Dependency notices](THIRD_PARTY_NOTICES.md)
- [Contribution and language rules](CONTRIBUTING.md)

## Layout

| Directory | Purpose |
|---|---|
| `docs/` | Findings, historical sessions, source comparisons and limitations |
| `src/watch/` | GATT inventory, DF/FD parsing, information queries and experimental file transport |
| `src/research/` | Offline analysis and battery-gated capture auditing |
| `tools/windows/` | WinRT tools and C# helper source |
| `tests/` | Offline tests with non-identifying or synthetic fixtures |
| `licenses/` | Unmodified dependency license notices |

Excluded: the application, service clients and gallery data, APK/DEX files, reconstructed Java, extracted native libraries, disassemblies, downloaded third-party repositories, private captures, firmware and face binaries. Historical documents identify excluded evidence rather than silently pretending it is available here.

## Install and test

```sh
npm ci
npm test
npm run check
```

Requires Node.js 22.12 or later. Tests do not access Bluetooth, an APK or an external service. Offline analyzers never execute Android code. Keep external inputs under ignored `private/` and generated results under ignored `output/`.

## Windows tools

Run from this directory in Windows PowerShell:

```powershell
$env:HRYFINE_WATCH_ADDRESS = 'AABBCCDDEEFF' # Fictional example; replace it.
powershell -NoProfile -File tools/windows/build-windows-helper.ps1
powershell -NoProfile -File tools/windows/build-advertisement-helper.ps1
powershell -NoProfile -File tools/windows/probe-windows-watch.ps1
```

Helpers are compiled locally; DLLs are not distributed. Some tools subscribe to notifications and transmit known information requests and ACKs: they are not all strictly passive GATT reads. The guarded runner requires known battery above 15%, bounded sessions and an allowlist. The transport module is experimental; tests never transfer a file to hardware.

Manufacturer, SoC and recovery method remain unidentified. Firmware strings and UUIDs are observations, not proof of chipset identity, compatibility or official support.

## Publication status

No license for the original work has been selected. Attribution does not itself grant permission to reuse third-party material. See [publication scope](PUBLICATION.md).
