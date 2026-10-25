# Official firmware availability lookup

Evidence: **observed service response**, not an open-source result. The user explicitly authorized sending the device-derived OTA identity to the official HryFine update endpoint. One GET request was made to `https://ota.lianhezhuli.com/api/hry/get_update` using parameters/signing behavior identified in the proprietary client.

The server returned HTTP 200 with `code=success` and an empty `data` object. The original non-English message is preserved below as escaped protocol text rather than translated evidence:

```json
{"code":"success","msg":"\u83b7\u53d6\u6210\u529f","data":{}}
```

No update package was offered for that OTA identity in that request. This does not prove that no other firmware exists or that no future update will become available. No firmware was downloaded or installed, and the lookup did not connect over Bluetooth.

Private evidence aliases, not distributed (timestamp prefixes omitted):

- `official-update.json`
- `official-update.body.txt`

The earlier blocked lookup and the later authorized request are separate events. Their authorization status must not be confused.
