# Capability bit map

Evidence: **static analysis**, applied to an **observed** 27-byte AA response. Source: the proprietary HryFine client, `NotifyWriteUtils.readFeatures`, historical lines 877 onward. The original reconstructed file and the old index generator are not distributed. This is our analysis, not an upstream open-source specification. See [source roles](SOURCES.md) and [evidence levels](EVIDENCE.md).

Byte offsets are zero-based. Yes/No means the client interpretation of a flag; it does not prove a sensor or usable function. Missing bytes remain unknown. Original OEM field names, including misspellings, are preserved as protocol labels.

| APK field | Byte | Mask | Condition | Value | Java line |
|---|---:|---|---|---|---|
| isBLE3 | 1 | 0x80 | == 128 | Yes | 880 |
| isShowContact | 1 | 0x40 | == 64 | Yes | 882 |
| isShowTemperature | 1 | 0x10 | == 16 | No | 883 |
| isShowHourUnitSwitch | 1 | 0x8 | == 8 | Yes | 884 |
| isShowUnitSwitch | 1 | 0x4 | == 4 | Yes | 885 |
| isLanguageEnable | 1 | 0x2 | == 2 | Yes | 886 |
| isSupportBloodOxygen | 1 | 0x1 | == 1 | No | 888 |
| isSupportWatchFaceSet | 2 | 0x80 | == 128 | Yes | 891 |
| isSupportWatchFaceCustomize | 2 | 0x40 | == 64 | Yes | 892 |
| isSupportWatchFacePush | 2 | 0x20 | == 32 | Yes | 893 |
| isChoosePaper | 2 | 0x10 | != 16 | Yes | 894 |
| isSupportViber | 3 | 0x40 | == 64 | No | 904 |
| isShowHeartRate | 14 | 0x80 | == 0 | No | 924 |
| isShowBloodPressure | 14 | 0x40 | == 0 | No | 926 |
| isPushCall | 14 | 0x20 | == 32 | Yes | 928 |
| isSupportSOS | 14 | 0x10 | == 16 | Yes | 930 |
| isSupport200Contact | 14 | 0x8 | == 8 | No | 931 |
| isSupportZalo | 14 | 0x1 | == 1 | No | 932 |
| isSupportRaiseWake | 15 | 0x80 | != 128 | Yes | 942 |
| isSupportPair | 15 | 0x40 | == 64 | Yes | 943 |
| isSupportDeviceInfo | 15 | 0x20 | == 32 | Yes | 944 |
| isSDKDevice | 15 | 0x10 | == 16 | No | 946 |
| isTakeMedicine | 15 | 0x8 | == 8 | No | 948 |
| isDrinkWater | 15 | 0x4 | == 4 | Yes | 949 |
| isNewMsgPushSetting | 15 | 0x2 | == 2 | Yes | 950 |
| isWorkout | 15 | 0x1 | == 1 | No | 952 |
| isScanConnnect | 16 | 0x80 | == 128 | No | 965 |
| isOTA | 16 | 0x40 | == 64 | Yes | 966 |
| isShowGlu | 18 | 0x10 | != 16 | No | 986 |
| isSupport7Weather | 18 | 0x8 | == 8 | Yes | 987 |
| isSupportUserName | 18 | 0x4 | == 4 | Yes | 988 |
| isSupportDiyOnlineWpaper | 18 | 0x2 | == 2 | Yes | 989 |
| isSupportDiyRdefault | 18 | 0x1 | == 1 | Yes | 990 |
| is565Bmp | 18 | 0x80 | == 128 · codeFormat == 8 | Yes | 993 |
| is8Bytes | 18 | 0x40 | == 64 · codeFormat == 8 | Yes | 994 |
| binPreviewFlag | 18 | 0x20 | == 32 · codeFormat == 8 | No | 995 |
| isSedentaryRemind | 19 | 0x80 | == 128 | Yes | 1009 |
| supportPaymentCode | 19 | 0x20 | == 32 | No | 1010 |
| supportMacXor55 | 19 | 0x10 | == 16 | Yes | 1011 |
| supportSocialCode | 19 | 0x8 | == 8 | No | 1013 |
| supportVibrateDis | 19 | 0x4 | == 4 | No | 1014 |
| supportScreenOnTimeSet | 23 | 0x80 | == 128 | No | 1025 |
| isShowSleep | 23 | 0x40 | != 64 | No | 1026 |
| isSleepAwakeHide | 23 | 0x8 | == 8 | No | 1027 |
| supportSedentaryRemind | 24 | 0x20 | != 32 | Yes | 1035 |
| supportAllDayLightUp | 25 | 0x2 | == 2 | No | 1041 |
| isShowPowerSaveMode | 25 | 0x40 | != 64 | Yes | 1042 |
| supportSocialType | 25 | 0x1 | == 1 | No | 1043 |
| supportHID | 26 | 0x1 | == 1 | No | 1050 |
| supportAllDayNotDisturbMode | 26 | 0x8 | == 8 | No | 1051 |
| isSupportPowerSaveSwitch | 26 | 0x40 | == 64 | No | 1052 |
| supportPaymentType | 26 | 0x80 | == 128 | No | 1053 |
| isSupportOutFindPhone | 27 | 0x80 | == 128 | Absent | 1061 |
| isBlePairCode | 28 | 0x8 | == 8 | Absent | 1066 |
| isProductIdentification | 28 | 0x2 | == 2 | Absent | 1067 |


## Coverage

Unmapped means not interpreted by this review, not reserved by firmware.

| Byte | Value | Unmapped mask | Unmapped set bits |
|---:|---|---|---|
| 0 | aa | 00 | 00 |
| 1 | ce | 20 | 00 |
| 2 | e1 | 00 | 00 |
| 3 | 82 | b0 | 80 |
| 4 | d9 | 00 | 00 |
| 5 | 82 | 00 | 00 |
| 6 | f0 | 00 | 00 |
| 7 | 00 | 00 | 00 |
| 8 | 00 | 00 | 00 |
| 9 | 00 | 00 | 00 |
| 10 | 00 | 00 | 00 |
| 11 | 00 | 00 | 00 |
| 12 | 00 | ff | 00 |
| 13 | 00 | 00 | 00 |
| 14 | f0 | 06 | 00 |
| 15 | 66 | 00 | 00 |
| 16 | 40 | 00 | 00 |
| 17 | 08 | 00 | 00 |
| 18 | df | 00 | 00 |
| 19 | 90 | 41 | 00 |
| 20 | 00 | ff | 00 |
| 21 | 00 | ff | 00 |
| 22 | 00 | ff | 00 |
| 23 | 40 | 37 | 00 |
| 24 | 00 | df | 00 |
| 25 | 00 | bc | 00 |
| 26 | 00 | 36 | 00 |


The language map occupies bytes 4-11, scanned most-significant bit first. Set indices: 0, 1, 3, 4, 7, 8, 14, 16, 17, 18, 19. Labels still require comparison with `R.array.language_arr`; language names and guaranteed counts have not been invented.

Byte 13 is 0x00, stored as signed byte zero by the client; it does not mean 240 sports. Byte 19 bit 1 is `is12HourUnit`, represented as numeric 0/2 rather than a conventional Boolean.
