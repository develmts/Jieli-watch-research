# Third-party notices

## Installed dependencies

| Dependency | Locked version | Credited authors | Packaged license | Use |
|---|---|---|---|---|
| @alexaltea/capstone-js | 5.0.9 | Alexandro Sanchez Bach and contributors | BSD-3-Clause | JavaScript/WASM disassembler wrapper |
| adm-zip | 0.6.1 | Another-D-Mention Software and other contributors | MIT | Reading an externally supplied APK archive |
| bleak | 3.0.2 (optional POSIX requirements) | Henrik Blidh and contributors | MIT | Linux/macOS Bluetooth backend |

Bleak is installed separately in the ignored Python virtual environment. Its
[upstream MIT notice](https://github.com/hbldh/bleak/blob/v3.0.2/LICENSE) credits
Henrik Blidh. No Bleak implementation is vendored. pip installs platform-specific
transitive dependencies with their own notices. See [POSIX setup](tools/posix/README.md).

Unmodified packaged notices: [capstone-js](licenses/capstone-js-BSD-3-Clause.txt), [adm-zip](licenses/adm-zip-MIT.txt). Exact package integrity is in package-lock.json. The Capstone engine and its LLVM-derived components have their own upstream notices: [Capstone LICENSE.TXT](https://github.com/capstone-engine/capstone/blob/5.0.9/LICENSE.TXT). The wrapper's version/license is not asserted to identify every embedded component's source revision or all redistribution obligations. Preserve upstream component notices if distributing a built WASM/binary bundle.

Dependencies are installed under ignored node_modules. No third-party implementation source is identified as vendored under src, tools or tests. Referenced Gadgetbridge, LaxasFit, JieLi, C30 and other research is credited individually in [SOURCES.md](docs/SOURCES.md). Their licenses do not become a license grant for our original work.

## Referenced projects versus copied material

The recorded uses are comparison, methodology, or external data analysis. The private C30 capture was input to an authored parser, not a bundled fixture. Gadgetbridge's reviewed headers credit their original authors and specify AGPL-3.0-or-later; no Gadgetbridge implementation body is redistributed here. No permissive license has been verified for the C30 archive or jielie materials, so reference links are not treated as permission to copy them.

## Original work

No project license has been selected. Author identity and licensing authority are not invented. Before adding copied or adapted code, record its exact origin, revision, author notice, original license, local modifications and distribution requirements in docs/sources.json and in the affected source file.
