# Change log

## POSIX research tools

- Added Bash entry points for all nine Windows PowerShell tools, backed by an
  authored Python/Bleak transport for Linux and macOS.
- Documented dependencies, platform differences, active discovery, CCCD limits,
  bounded read/query behavior and offline tests under tools/posix.
- Added Bleak attribution and content checks for Python and Bash source files.
- Verified simulated transport behavior and Bash syntax/help; physical POSIX
  Bluetooth interoperability remains unverified.

## English and provenance normalization

- Normalized authored documentation, query labels, comments and runtime messages to English. Existing authored API identifiers were already English; OEM field labels and exact wire values remain unchanged.
- Preserved numeric findings, capability tables, request/reply bytes and explicit contradictions. Historical planned/unknown statements now identify later observations rather than presenting both as current facts.
- Added per-project credits, reviewed revisions, source roles, license-verification limits and historical external-artifact metadata. Kept primary-page failures and unverified leads explicit.
- Added dependency notices and unmodified packaged license files. No project license, identity or clean-room claim was invented.
- Added evidence levels, a claim register, reproduction instructions, a contribution policy, an experiment template and offline content checks.
- Kept this folder local, without Git/remotes/publication. No application changes or physical Bluetooth experiments were made during normalization.
