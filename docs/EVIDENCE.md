# Evidence levels and claim register

Use one of these labels whenever reporting a result. A flag, an ACK and a successful physical action are different evidence.

| Level | Meaning | Required context |
|---|---|---|
| observed | Bytes or behavior recorded from the local unit or an explicitly identified service request | Device/firmware, date, request/reply, capture reference and limits |
| user-reported | Physical behavior reported by the device owner | Exact action and report; do not silently upgrade to an instrumented test |
| static-analysis | Interpretation of proprietary-client code/bytecode | Method/path, version/revision if available, assumptions and reconstruction limits |
| external-reference | Information attributed to another project, author, standard or vendor | Source ID, URL, revision, attribution and transferability limits |
| hypothesis | A plausible interpretation not yet established | Supporting evidence and a specific falsifying/confirming experiment |
| synthetic-test | Behavior of authored code against constructed/non-identifying inputs | Test file and assertions; not proof of hardware behavior |
| unknown | Insufficient evidence | What is missing; do not replace with an arbitrary default |

## Current claim register

| ID | Claim | Evidence level | Reference | Limit / next evidence |
|---|---|---|---|---|
| E001 | Normal transport is DF/FD on ...9f | observed + static-analysis | [UUID layout](UUID_AND_PROTOCOL.md) | Do not generalize to every HryFine device |
| E002 | F3/00 returned V1.5 and E06B_T27_LC project identity | observed | [native investigation](LIVE_INVESTIGATION.md) | Does not identify SoC/board revision |
| E003 | Client maps 2A25 text 10000004 to platform 7 | observed + static-analysis | [profile](OBSERVED_PROFILE.md) | Internal platform number is not chip identity |
| E004 | Explicit limits are 53248 face bytes and 86016 background bytes | observed | [0F/09 layout](UUID_AND_PROTOCOL.md) | File interpretation/physical compatibility remain separate |
| E005 | UI capability bits are not sensor proof | static-analysis | [bit map](FEATURE_MAP.md) | Physical function and accuracy need independent tests |
| E006 | 0A/10 is called hardware information by Gadgetbridge | external-reference | [GADGETBRIDGE](SOURCES.md#gadgetbridge) | Local response was ACK-only; no local LED/GSensor identity |
| E007 | JieLi is a plausible chip-family hypothesis | hypothesis | [project review](PROJECT_REVIEW.md) | Requires chip/board/firmware evidence; UUIDs are insufficient |
| E008 | C30 external AB/5A traffic uses ATT/GATT in the analyzed capture | external data + local analysis | [C30 comparison](C30_README_REVIEW.md) | Different protocol/device; no inference of local compatibility |
| E009 | One battery-only connection dropped after about 10.77 seconds | observed | [guarded session](NIGHT_RESEARCH.md) | Disconnect initiator and general cause unknown |
| E010 | Guard policy rejects battery <=15%, missing/stale evidence and unapproved requests | synthetic-test + historical capture audit | tests/test-guarded-policy.js | Physical low-battery behavior was not exercised |
| E011 | Official update lookup offered no package in the recorded request | observed service response | [lookup report](OFFICIAL_UPDATE_LOOKUP.md) | No general claim of unavailable/future firmware |
| E012 | Six reviewed projects yielded no demonstrated firmware port for this unit | bounded external review | [review](PROJECT_REVIEW.md) | Absence of a located port is not proof of impossibility |

## Corrections and contradictions

Early browser discovery omitted fields later found natively. Historical F3-planned statements were superseded by actual F3 results. An initially blocked service request was later explicitly authorized. General and dedicated sedentary-setting replies disagree. Preserve both observations and identify their sequence rather than rewriting history or choosing a convenient value.

Unknown/absent bytes are not false flags. Empty readable characteristics and ACK-only replies are not proof of absent functionality. No-code-reuse statements do not imply clean-room development or automatically settle licensing.
