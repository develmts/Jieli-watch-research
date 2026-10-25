# Reproduction guide

Run commands from this folder. Record OS, runtime, tool versions, firmware identity and date with each result. Public tests are offline; physical experiments are a separate activity.

## Offline baseline

```sh
node --version
npm ci
npm test
npm run check
```

The lockfile fixes dependency versions and integrity. `npm test` covers capability/frame parsing, F3 identity, notification cleanup and synthetic guarded-capture policy. It does not reproduce excluded private captures, validate sensors or establish firmware compatibility.

## External inputs

Neither APKs nor captures are included. Keep any input you are entitled to analyze under ignored private/. Keep all derived output under ignored output/.

```sh
node src/research/analyze-native.js private/client.apk output/native
node src/research/analyze-c30-capture.js private/capture.btsnoop
node src/research/analyze-watch-observations.js private/information-sessions
node src/research/analyze-guarded-sessions.js private/guarded-sessions output/guarded-analysis.json
```

The native analyzer reads archive/ELF bytes and disassembles ARM64; it never loads Android libraries for execution. C30 input must be btsnoop H4; continuation fragments are explicitly not reassembled by that analyzer. Review the parser's limits before treating counts as a complete trace reconstruction. Guarded analysis checks transmitted requests and ACK correlation; input reports must retain raw trace/frame and battery timestamps.

Historical review revisions/URLs/hashes are in [sources.json](sources.json). These metadata identify external artifacts, not a claim that those artifacts are redistributed or still downloadable. Mutable sources without a pinned revision are explicitly marked.

## Windows helpers and discovery

For Linux/macOS, use the [POSIX Bash tools](../tools/posix/README.md), including
their dependency setup, tool mapping and documented backend limitations. Their
offline Python tests run separately from the Node.js test suite.

Use Windows PowerShell with WinRT and the .NET Framework compiler available. Build the two helpers from their C# sources. Set HRYFINE_WATCH_ADDRESS to the target's twelve hex digits without separators. The example AABBCCDDEEFF is fictional.

```powershell
$env:HRYFINE_WATCH_ADDRESS = 'AABBCCDDEEFF'
powershell -NoProfile -File tools/windows/build-windows-helper.ps1
powershell -NoProfile -File tools/windows/build-advertisement-helper.ps1
powershell -NoProfile -File tools/windows/list-windows-ble.ps1
powershell -NoProfile -File tools/windows/probe-windows-watch.ps1
```

These commands are instructions, not automatic experiments during installation/tests. List/discovery output can contain nearby devices; keep it private until redacted. The probe opens GATT and disposes it afterward. Subscriptions change CCCD state even without a functional setter.

For battery-guarded information reads:

```powershell
powershell -NoProfile -File tools/windows/read-watch-session.ps1 -Query identity
```

Inspect the Query allowlist in the runner. Stop on unknown/failed battery or <=15%; do not bypass gates to obtain a response. Rediscover invalidated GATT objects after disconnects. Do not reuse unreviewed initialization sequences from external projects.

## Reporting an experiment

Use [the experiment template](../templates/EXPERIMENT.md). Preserve raw bytes in a private immutable file and record its SHA256. Publish only a deliberately redacted/minimal fixture with a clear synthetic/observed label. Describe baseline, action, outcome, side effects, restoration, contradictions and what the result does not establish.
