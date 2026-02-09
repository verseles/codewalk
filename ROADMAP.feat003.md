# Feature 003 - Rebrand OpenMode -> CodeWalk

## Goal
Rename all project identifiers from OpenMode/open_mode/openmode to CodeWalk/codewalk without breaking builds, imports, package IDs, or runtime behavior.

## Scope
- Dart package name and import path updates
- App constants and user-visible branding
- Android namespace/applicationId and Kotlin package path
- Web/PWA metadata
- Test imports and CI references

## Out of Scope
- Visual redesign and responsive desktop layout (handled in Feature 007)

## Current Findings (2026-02-09)
Branding references exist in:
- `pubspec.yaml` (`name: open_mode`, description)
- `README.md` (title, clone path, copy)
- `web/index.html` and `web/manifest.json`
- `android/app/build.gradle.kts` (`namespace`, `applicationId`)
- `android/app/src/main/AndroidManifest.xml` label
- `android/app/src/main/kotlin/com/ft07/openmode/open_mode/MainActivity.kt`
- `lib/core/constants/app_constants.dart`
- `test/widget_test.dart` import path

## Implementation Stages

### Stage 1 - Naming Specification
- Decide canonical IDs:
  - Product: `CodeWalk`
  - Dart package: `codewalk`
  - Android package base (proposal): `com.ft07.codewalk`
- Freeze mapping table old -> new.

### Stage 2 - Source and Metadata Rename
- Update package name and app constants.
- Refactor imports and generated references.
- Update web metadata and manifest labels.
- Update Android namespace/applicationId and Kotlin package directory/package declaration.

### Stage 3 - Build Sanity and Regression Check
- Run `flutter analyze` and targeted build commands.
- Validate startup and navigation after rename.
- Fix any DI, import, or generated-code references broken by package rename.

### Stage 4 - Documentation Consistency
- Ensure surviving docs use CodeWalk naming only.
- Preserve explicit origin attribution (handled fully in Feature 005 README rewrite).

## Deliverables
- Fully rebranded package/app identifiers
- No stale OpenMode/open_mode references in active runtime/build paths

## Risks and Mitigations
- Risk: package rename breaks generated imports and test paths.
  - Mitigation: perform global search + analyzer after each rename batch.
- Risk: Android namespace mismatch causes build failure.
  - Mitigation: rename folder tree and package declaration atomically.

## Definition of Done
- `rg -n "OpenMode|open_mode|openmode"` returns only intentional historical references
- App builds and launches with CodeWalk identity

## Completion Summary

### Decisions Made
- Android package ID: `com.verseles.codewalk` (aligned with commercial domain verseles.com)

### Changes Applied
| Task | Files Modified | Commit |
|------|---------------|--------|
| 3.01 | `pubspec.yaml`, `lib/core/constants/app_constants.dart`, `test/widget_test.dart` | ede3939 |
| 3.02 | `android/app/build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt` (moved to `com/verseles/codewalk/`) | a519f8f |
| 3.03 | `web/index.html`, `web/manifest.json` | 63549d4 |
| 3.04 | `README.md`, `CODEBASE.md`, `ROADMAP.md`, `ROADMAP.feat003.md` | (this commit) |

### Exit Gate Results
- Zero refs to `open_mode`/`OpenMode`/`openMode` in code/config files (dart, yaml, json, html, kts, kt, xml)
- `flutter analyze`: 167 issues (baseline maintained, 0 errors)
- `flutter test`: 1 test passing
- Remaining refs only in historical docs (NOTICE, ADR.md, ROADMAP files, AI_CHAT_IMPLEMENTATION.md)

## Research Log

### Local Research
- Branding scan across root docs, web metadata, Android build files, constants, and tests.
- Confirmed high-risk rename points in namespace and import paths.

### External Sources
- Original upstream repository (origin to acknowledge):
  - https://github.com/easychen/openMode
