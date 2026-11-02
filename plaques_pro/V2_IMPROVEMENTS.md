# Plaques Pro V2 — improved Flutter Android app

## Improvements included in this source copy
- New modern Material 3 visual theme with refreshed cards, fields and navigation.
- New dashboard showing today's invoiced total, today's invoice count, lifetime invoiced total, client count and recent invoices.
- Search in client list (name, telephone, city).
- Search in catalogue (plate type).
- Search in invoice history (invoice number and client).
- Confirmation before deleting a catalogue item.
- Original French-language workflow and MAD calculations retained.
- Original project files retained; this is a separate source ZIP.

## Technology
The app is Flutter/Dart. Node.js is only used to run the build workflow; it does not compile Flutter source.

## Build
Requirements: Node.js, Flutter stable SDK, Android SDK/Android Studio command-line tools, Java toolchain.

```bash
flutter doctor
flutter doctor --android-licenses
npm run build:apk
```

The script creates the missing Android project if necessary, runs `flutter pub get`,
runs `flutter analyze`, then builds a release APK and copies it to
`dist/PlaquesPro-V2-release.apk`.

The generated Android package ID is intended to be `ma.plaques.plaques_pro_copy`.
Verify `applicationId` in the generated `android/app/build.gradle` or
`android/app/build.gradle.kts` before installing alongside the original app.
If it matches the original package ID, change it to a unique ID and rebuild.

## Important: not yet verified on a device
The source archive provided did not include the Android Gradle project or wrapper.
This environment did not have Flutter/Android SDK, so this updated source has not
been compiled or tested on a physical phone. Bluetooth thermal printing, PDF layout,
and runtime permissions must be tested on your Android device and printer.

## Recommended next development phase
- Add payment tracking (paid / partial / unpaid) and outstanding balance reports.
- Add database backup and restore with a user-selected destination.
- Add company details (ICE, IF, RC, address, phone, logo) to PDF invoices.
- Harden invoice numbering using a transaction-safe sequence.
- Add tests for invoice totals, tax calculations, database migration and PDF export.

Existing invoices are preserved in the current database schema; no schema migration
was made in this design/search/dashboard update. Install the copy with a distinct
application ID and test using sample data first. Do not uninstall the original app.
