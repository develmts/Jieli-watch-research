# Query reference

These are authored query descriptions based on proprietary-client analysis and local observations. See [sources](SOURCES.md) and [evidence levels](EVIDENCE.md). Listening uses GATT subscription writes even without application commands.

## Read firmware identity

ID: device-info

F3/00 (243/0): request firmware version and project name. Preserve the raw response. Does not bind, synchronize settings or start an update.

## Listen for notifications (15 seconds)

ID: notifications

Subscribe to battery and normal-channel notifications without application commands. Silence is possible. Does not subscribe to the OTA channel.

## Read capabilities

ID: capabilities

19/00 (25/0): request display and format flags over the normal channel. May duplicate a direct characteristic read.

## Read installed face information

ID: watch-faces

0F/01 (15/1): request installed face identifiers, active face and size limits when present. Does not select or transfer a face.
