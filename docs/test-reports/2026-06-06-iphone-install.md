# iPhone Install Verification - 2026-06-06

## Scope

Verified the latest Vesper development build after adding multi-item reminder proposals, personal routine settings, and the refreshed README.

## Device

- Device: connected iPhone
- Model reported by CoreDevice: iPhone 17
- App bundle: `com.liangbowenbill.DiaryCompanion`
- Build configuration: Debug, development signed

## Result

Passed.

## Checks

- Installed the latest `Debug-iphoneos/DiaryCompanion.app` with `xcrun devicectl device install app`.
- Launched Vesper with `xcrun devicectl device process launch`.
- Confirmed the app data container remained readable after launch.
- Copied the SwiftData store from the device and inspected the schema.
- Confirmed `ZJOURNALSETTINGSRECORD` includes `ZPERSONALROUTINENOTES`, proving the new personal routine settings field migrated onto the existing on-device database.
- Confirmed the existing journal settings row remained present after migration.

## Notes

This report documents device-level smoke verification only. Full logic coverage remains in `DiaryCompanionCore` tests.
