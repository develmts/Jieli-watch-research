# Contribution rules

## Language and naming

All authored prose, documentation, comments, error messages, variables, functions and classes must use English. Use descriptive camelCase JavaScript identifiers, PascalCase classes and descriptive English PowerShell parameters. Conventional byte/index variables and protocol abbreviations are permitted. Filenames use English words and stable ISO dates.

Do not translate exact upstream project/author names, OEM field identifiers, wire bytes, API names or license notices. Those are evidence/attribution, not local prose. Explain unfamiliar terms in English. Encode a non-English literal protocol response as hex or Unicode escapes when displaying it, preserving the actual bytes separately. Do not alter dependency contents in node_modules to enforce project language rules.

## Evidence and sources

Label claims using docs/EVIDENCE.md. Add each external source to docs/sources.json and cite it beside the claim. Record credited author/maintainer, canonical URL, exact revision/artifact when available, role, local use, reuse status and verification/rights limits. Do not infer an open-source license from a public download.

If code is ever copied/adapted, preserve its notices, identify affected files and changes, and verify applicable terms. Current comparison-only entries must not be reused to conceal later code imports. Do not claim clean-room development: this work includes proprietary-client static analysis.

## Experiments and tests

Prefer offline parsing and minimal synthetic fixtures. Never make npm test connect to a device or external service. Physical queries require a defined target, documented action, time bound, battery policy and restoration plan. Keep raw private captures out of the authored tree. Record unsuccessful or contradictory results.

Run npm test and npm run check. The check validates source records, local document links, basic English-content policy and publication exclusions; it is not a general-purpose language detector or legal clearance.

## Licensing and publication

No original-work license has been selected. A future license decision must distinguish code, documentation, dependencies and any borrowed material. This folder remains local; do not create Git history or publish it without a later user instruction.
