# POSIX Bluetooth research tools

These Bash entry points adapt every PowerShell tool in `../windows`. Bash launches
an authored Python backend using [Bleak](https://bleak.readthedocs.io/), credited to
Henrik Blidh and contributors under MIT. No C# compiler, DLL, PowerShell, Node.js
or third-party research implementation is needed for these tools. The normal
DF/FD protocol comes from this project's existing research; see
[the source register](../../docs/SOURCES.md).

## Install

Use Bash 3.2+, Python 3.10+ with pip/venv, and a working Bluetooth LE adapter.
Commands below run from the research root. Installation does not scan, connect,
pair or send anything to the watch.

On Debian/Ubuntu, install the OS dependencies with your package manager:

```sh
sudo apt install bash python3 python3-venv python3-pip bluez
```

Linux requires BlueZ 5.55+ and a running system D-Bus/Bluetooth service. Enable
Bluetooth in the desktop settings. If blocked, check `rfkill list bluetooth`;
use `rfkill unblock bluetooth` only when appropriate for your machine. The user
must be permitted by the distribution's D-Bus/Polkit policy to use Bluetooth.
Do not run the whole script as root to work around an unexplained access error.
Other distributions need equivalent packages. Containers and WSL do not normally
inherit the host's Bluetooth controller; use a native installation or an explicitly
configured controller/backend.

On macOS, install Python 3.10+ (for example, the python.org installer or
`brew install python` if Homebrew is already installed), enable Bluetooth, and
grant the terminal application Bluetooth permission in System Settings. Bleak
uses CoreBluetooth and PyObjC; pip installs the Python backend dependencies.
Upstream supports macOS 10.15+, but the chosen Python/PyObjC wheels may require a
newer system. These tools have not been physically verified on either platform.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/posix/requirements.txt
bash tools/posix/build-posix-helper.sh
bash tools/posix/build-advertisement-helper.sh
```

Bleak is pinned to 3.0.2. Its transitive dependencies are platform-specific and
are not fully locked here. Record `.venv/bin/python -m pip freeze` with private
experiment results when exact environment reproduction is needed. The two build
commands check imports only: notification and advertisement queues are Python
callbacks, so there is no native helper to compile. To use a different interpreter,
set `HRYFINE_PYTHON` to its executable path. The scripts find the project `.venv`
independently of the current working directory.

## Tool mapping

| Windows PowerShell tool | Bash equivalent | Behavior |
|---|---|---|
| build-windows-helper.ps1 | build-posix-helper.sh | Check notification backend dependencies |
| build-advertisement-helper.ps1 | build-advertisement-helper.sh | Check advertisement backend dependencies |
| list-windows-ble.ps1 | list-posix-ble.sh | Active discovery instead of Windows cached/paired enumeration |
| probe-windows-watch.ps1 | probe-posix-watch.sh | Connect, read battery, enumerate services, disconnect |
| inventory-windows-watch.ps1 | inventory-posix-watch.sh | Read readable GATT values and descriptors, without subscriptions |
| listen-windows-watch.ps1 | listen-posix-watch.sh | Target advertisements, then bounded battery/FF14/normal notifications |
| query-windows-f3.ps1 | query-posix-f3.sh | One F3 identity getter and matching ACKs |
| query-windows-information.ps1 | query-posix-information.sh | Same 15 information getters, 800 ms apart |
| read-watch-session.ps1 | read-watch-session.sh | One selected guarded session, battery-only by default |

`WindowsNotificationQueue.cs` and `WindowsAdvertisementQueue.cs` are replaced by
callbacks in `watch_ble.py`, not translated to C#. Shared code lives in
`common.sh` and `watch_ble.py` to avoid nine copies of the Bluetooth protocol.

## Use

```sh
bash tools/posix/list-posix-ble.sh --scan-seconds 10
# Linux: use your own target address, with or without separators.
export HRYFINE_WATCH_ADDRESS=AABBCCDDEEFF
# macOS: use the CoreBluetooth UUID returned by discovery instead of an LE MAC.
bash tools/posix/probe-posix-watch.sh
bash tools/posix/read-watch-session.sh --query battery
bash tools/posix/read-watch-session.sh --query identity
bash tools/posix/inventory-posix-watch.sh
bash tools/posix/listen-posix-watch.sh --skip-advertisements
bash tools/posix/query-posix-f3.sh
bash tools/posix/query-posix-information.sh
```

The address above is fictional. `--address` overrides the environment variable.
Choose the device by its identifier, not by name alone. `--help` lists options.
PowerShell switches are replaced by lowercase GNU-style options; for example
`-SkipAdvertisements` becomes `--skip-advertisements` and `-Query identity`
becomes `--query identity`. `-MaintainConnection` has no equivalent and is rejected.

Session choices are `battery`, `observe`, `inventory`, `hardware`, `identity`,
`features`, `settings`, `faces`, `today`, `classic-address`, `alarms`, `custom-face`
and `ota-identity`. `observe` polls battery every four seconds for up to thirty
seconds. `hardware` uses the existing empty 0A/10 getter attributed to Gadgetbridge;
it does not issue arbitrary flash addresses or lengths. `ota-identity` reads
identity through the normal channel; it never starts OTA or contacts a server.
Query purposes and interpretation limits are in
[the query reference](../../docs/QUERY_REFERENCE.md).

Reports go to ignored `output/sessions` under the research root, with random IDs
and no calendar date in the filename. `--output /path/to/new-report.json` selects
another destination; existing files are never overwritten. Runtime timestamps
remain inside captures for battery freshness, ordering and offline auditing.
Reports preserve raw frames, ACKs, notification chunks, battery observations,
disconnect events and errors. Device identifiers and discovery of nearby devices
are private evidence; review and redact before publishing. Failed operations
return a nonzero exit status and still save the partial report.

## Platform differences and limits

- All connected modes require a valid battery reading above 15%. Failed,
  disconnected, low or stale battery authorization stops functional writes.
  This adds a battery gate to the older Windows probe/inventory/batch equivalents.
- Discovery uses active scanning, which can send BLE scan requests; it is not a
  passive radio capture. Bleak exposes interpreted advertisement fields, not raw
  HCI packets, original AD ordering, flags, address type or a complete PHY trace.
  Advertisement and notification lists are bounded to 4096 entries.
- Linux uses BlueZ/D-Bus; macOS hides physical LE addresses behind UUIDs. GATT
  handles, descriptors, MTU and cached service information can differ. WinRT
  access statuses, appearance/session metadata and MaintainConnection are not
  simulated. Missing fields do not imply a missing watch capability.
- Notifications use `start_notify`/`stop_notify`. They can change CCCD state.
  Bleak does not provide portable restoration of an arbitrary pre-existing CCCD
  value: the runner removes its own subscriptions and disconnects. It does not
  claim the Windows runner's exact CCCD restoration semantics. Avoid concurrent
  phone/desktop clients; do not run notification/query modes when that exact
  restoration guarantee is required. Cleanup failures stop a batch.
- No pairing, binding, time synchronization, configuration setter, live sensor
  enable, reset, unknown write or firmware transfer is implemented. Only approved
  getters and ACKs for checksum-valid DF data use normal TX. ACK-only replies do
  not prove a feature exists or is unsupported. Unexpected framing aborts the
  session, with the documented custom-face inner-length exception retained.
- Each operation has a timeout (default 15 seconds, configurable 1..30). Query
  listening is bounded to seven seconds, with a short settling period after data.
  Notification capture is twenty seconds. OS-level discovery and disconnection
  behavior remains backend-dependent; no reconnect loop runs automatically.

## Offline verification

```sh
python3 -m unittest discover -s tests -p 'test_posix_tools.py'
for script in tools/posix/*.sh; do bash -n "$script"; done
```

The tests use simulated BLE clients, not a watch, adapter, network or installed
Bleak. They cover battery gates, fragmented responses, checksums, ACK correlation,
query cleanup and the PowerShell-to-Bash entry-point mapping. Passing them does
not establish physical Linux/macOS interoperability; record actual trials as
separate experiments.

References: [Bleak installation](https://bleak.readthedocs.io/en/latest/installation.html),
[Linux backend](https://bleak.readthedocs.io/en/latest/backends/linux.html),
[macOS backend](https://bleak.readthedocs.io/en/latest/backends/macos.html),
[client API](https://bleak.readthedocs.io/en/latest/api/client.html), and
[pinned package metadata](https://github.com/hbldh/bleak/blob/v3.0.2/pyproject.toml).
