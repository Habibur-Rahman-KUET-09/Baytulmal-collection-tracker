# বাইতুলমাল কালেকশন ট্র্যাকার (Baytulmal Collection Tracker)

Offline-first Flutter Android app for recording and summarizing monthly
BDT collections across Protisthan (Institution) → Ward → Criteria, built
from the project's SRS and wireframes.

## Features

- **প্রতিষ্ঠান / ওয়ার্ড / ক্রাইটেরিয়া ব্যবস্থাপনা** — full CRUD for Institutions,
  their Wards, and their shared Criteria list, each with a Bangla
  confirmation dialog before delete (cascading).
- **ডেটা এন্ট্রি** — a per-ward, per-month form with one optional BDT field
  per criteria; saving overwrites any existing entry for that
  Ward+Criteria+Month (no duplicates).
- **সামারি স্ক্রিন** — Protisthan and Ward monthly summaries with
  criteria/ward breakdowns, all derived from the same Entry table so
  totals are always internally consistent.
- **ট্রেন্ড/তুলনা** — a bar chart (fl_chart) comparing a Protisthan's total,
  a single Criteria, or a single Ward across a month range.
- **ম্যাট্রিক্স রিপোর্ট** — a Ward × Criteria preview grid with row/column/grand
  totals, exportable as PDF (Bangla font embedded) or Excel (.xlsx), with
  a native print/preview dialog and Android share-sheet integration — all
  fully offline.
- **ডেটা এক্সপোর্ট/ইমপোর্ট (Backup & Restore)** — an additional feature beyond
  the SRS: the entire local database (every Protisthan, Ward, Criteria and
  Entry) can be exported to a single JSON file and shared/saved, then
  re-imported later (e.g. after reinstalling the app or moving to a new
  phone) to restore everything exactly as it was. Importing replaces all
  local data after an explicit confirmation.

All UI text is in Bangla, amounts use Bangladeshi (lakh-style) digit
grouping with a ৳ symbol, and the whole app works with no internet
connection — local storage is SQLite (`sqflite`).

## Project structure

```
lib/
  models/       Protisthan, Ward, Criteria, Entry
  db/           DatabaseHelper — schema, CRUD, aggregate queries, backup export/import
  providers/    AppDataProvider (ChangeNotifier) for the home screen + CRUD passthrough
  screens/      One file per screen from the SRS's Screen Inventory (section 6)
  services/     PdfExportService, ExcelExportService, BackupService
  utils/        Bangladeshi currency formatting, Bangla month names/digits
  widgets/      Shared dialogs (confirm / name-input), month picker, empty state
assets/fonts/   Noto Sans Bengali (bundled so PDF export renders Bangla offline)
```

## Building

This was developed in an environment without the Flutter SDK installed, so
it has **not** been compiled/run here — build and test it on a machine
with Flutter before relying on it. Steps:

```bash
flutter pub get
flutter run            # on a connected device/emulator
# or
flutter build apk      # release APK
```

Requirements: a current Flutter stable release (the pinned package
versions need Flutter ≈3.44+ / Dart ≈3.12+ — run `flutter --version` and
`flutter upgrade` if needed). No API keys, backend, or network access are
required; the app is fully offline.

If `android/gradlew` is missing after cloning (it's git-ignored, since it's
regenerated to match your local Flutter/Gradle install), just run
`flutter pub get` or `flutter build apk` once — Flutter's tooling recreates
it automatically.

### Tests

A small unit test for the currency formatter is in `test/widget_test.dart`:

```bash
flutter test
```

## Notes on scope

- Section 7 of the SRS lists "Export to PDF/Excel" as a Phase-1
  fast-follow rather than a hard requirement, but it's implemented here
  per section 3.8 (FR-8.x) and the wireframe's Matrix Report screen.
- Cloud sync, multi-user accounts, and push notifications remain
  explicitly out of scope for Phase 1, per the SRS. The schema already
  carries `uuid` and timestamp columns on every table so a future sync
  layer can be added without a schema rewrite (FR-7.3).
- JSON data export/import (backup & restore) was requested in addition to
  the SRS and is implemented as its own screen (`ডেটা ব্যবস্থাপনা`, reachable
  from the home screen's app bar icon), independent of the PDF/Excel
  matrix report export.

## Versioning

The app version is **1.0.0.N**. `1.0.0` is the Play Store version and
changes only when decided; `N` is the build number, raised by one for every
build that goes out:

```sh
tool/bump_build.sh   # 1.0.0+N -> 1.0.0+(N+1) in pubspec.yaml, prints 1.0.0.(N+1)
```

Android gets versionName `1.0.0.N` and versionCode `N`; CI names the APK
`Baytulmal-1.0.0.N.apk`. The account screen shows the version.
