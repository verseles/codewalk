# V2-020CA — Android/Linux MVP targets, explicit v2 entry points and aggregate evidence

**Outcome: targets and entry points recorded; the aggregate checks and the
native compiler evidence observed on this revision; device installation,
release signing and MVP acceptance remain pending.**
This record closes the *recording* criteria of
[#356](https://github.com/verseles/codewalk/issues/356) on `main` and reports the
missing prerequisites separately. It is not an MVP platform acceptance, not a
distribution pass and not a closure of the full-platform parent
[#255](https://github.com/verseles/codewalk/issues/255).

It supersedes the record of 2026-10-17 (revision `846b9e5d`): the targets and
the commands are unchanged, and the aggregate evidence is refreshed on the
current revision.

## Agreed targets

| Scope | Target | Status |
|---|---|---|
| Native MVP (reference) | Android 12 / API 31 | compiler/build observed in CI; device install/launch pending |
| Native MVP | Linux x64 | debug build **and** the packaged preview launched and visually verified in CI; release AOT, installed-device acceptance and distribution pending |
| Native MVP | Linux ARM64 | debug compilation observed (see `linux-arm64-74202310/`); GUI/install pending |
| Deferred (post-MVP) | Web/Chrome | explicit manual checkpoint `v2-deferred-web.yml`; no acceptance |
| Deferred (post-MVP) | iOS, macOS, Windows | full-parent obligations recorded by #255/V2-020C; not prerequisites here |

Android build codes, signing and identity policy follow the cross-line
publication rules in `AGENTS.md`; no APK signing material or physical reference
device is available in this environment, so those rows stay pending instead of
being claimed as passes.

## Explicit v2 entry point and commands

- Entry point: `lib/main_v2.dart` (SHA-256
  `8660317e7d66cacc0b76be1654f0ed46be0c10c608ce2a58ac8f868af71d5388`). Governed
  packages in the pub workspace: `packages/codewalk_core`,
  `packages/codewalk_net`, `packages/harness_opencode` and
  `packages/harness_host`.
- Preserved gates: `dart run tool/ci/import_rules.dart` (v2 architecture and
  retained-reference boundaries), `python3 tool/ci/check_v2_foundations.py`
  (strict analysis, scoped l10n and the v2 test lifecycle).

| Make target | Command | CI job |
|---|---|---|
| `make v2-architecture` | `dart run tool/ci/import_rules.dart` | `quality` |
| `make v2-foundations` | `python3 tool/ci/check_v2_foundations.py` | `v2_foundations` |
| `make v2-native-check` | `python3 tool/ci/check_v2_foundations.py --profile native` (+ `test-v2-tools`) | `v2_native_checks` |
| `make v2-android-debug` | `python3 tool/ci/build_v2_native.py android` | `v2_native_builds (android)` |
| `make v2-linux-debug` | `python3 tool/ci/build_v2_native.py linux` | `v2_native_builds (linux)` |
| `make v2-linux-preview-package` | `tool/preview/preview_linux.py package …` | `v2_native_builds (linux)` |
| `make v2-linux-preview-smoke` | `tool/ci/smoke_v2_linux_preview.py …` | `v2_native_builds (linux)` |
| `make v2-smoke` | `flutter test --no-pub test/v2` | `v2_native_checks` (test phase) |

## Aggregate evidence — 2026-10-19, revision `e17d647f`

CI run [`39306060265`](https://github.com/verseles/codewalk/actions/runs/39306060265):

- `v2_native_checks` — **exit 0**: 4 discovered packages and the explicit entry
  point, strict analysis and the architecture/l10n guards, **896 package tests
  and 947 app-level v2 tests passed** with 4 explicit skips: one browser-only
  hard guard (`v1_data_importer_test.dart`) and three tests that need an
  authorized isolated native OpenCode 2.0.22 runtime (the two V2-060B live-smoke
  tests and the native pairing flow). No test was removed, renamed away or
  suppressed.
- `quality`, `v2_foundations`, `coverage`, `windows_build` and both
  `v2_native_builds` succeeded; `test_shards` is intentionally skipped on this
  workflow.

Compiler outputs observed on the same revision (`source_dirty: false`):

- **Linux x64** — `flutter build linux --debug --no-pub --target
  lib/main_v2.dart --target-platform linux-x64` produced
  `build/linux/x64/debug/bundle/codewalk`, and the packaged preview was then
  launched and visually verified on Ubuntu 24.04 (X11/software): archive
  SHA-256 `97c25d28…`, 17 checks, `native_visual: pass`, with the rendered
  theme luminance recorded for the light, dark and restarted-dark states. The
  release-MVP, server-pairing and GPU/Wayland paths are `not-tested` in that
  run.
- **Android arm64** — `flutter build apk --debug --no-pub --target
  lib/main_v2.dart --target-platform android-arm64 --split-per-abi` produced
  `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.
- **Linux ARM64** — the compiler-only record of 2026-10-11
  (`linux-arm64-74202310/`) still stands; no GUI or install evidence exists for
  it.
- Toolchain: Flutter 3.44.1 (`924134a4`), Dart 3.12.1, engine `c416acfe`.

The CI artifacts that carry this evidence: `codewalk-v2-preview-linux-x64-39306060265-1`
(zip SHA-256 `86b32e7c…`), `v2-native-linux-39306060265-1` (`d267dbad…`) and
`v2-native-android-39306060265-1` (`c8b7e59d…`).

## Missing prerequisites (reported, not passed)

- No physical Android 12/API 31 reference device and no signing material in this
  environment: install, launch, layout and permission flows are unverified here.
- Linux x64 release AOT, installed-device acceptance and distribution are
  pending; the ARM64 record is compiler-only.
- The authorized isolated live OpenCode 2.0.22 runtime checks and the
  browser-only guard remain intentional skips rather than failures.
- Android APK builds are not reliable on this ARM64 host; CI remains the build
  path, and a local ARM64 result must never be reported as an Android pass.

## V2-020C lifecycle disposition in this scope

- Retained-legacy path dispositions live in `tool/ci/v2_architecture_manifest.json`
  and are enforced by `tool/ci/import_rules.dart`; nothing was exempted here.
- v2 tests are discovered from the governed packages and the explicit entry
  point only; retained legacy-only checks never substitute for them.
- `V2-084` owns retiring the remaining legacy exclusions at cutover; until then
  this record is the Android/Linux checkpoint link for that retirement.
- No coverage reduction, blanket skip or suppression was introduced by this
  record.

## Acceptance status

- Recorded: the agreed targets, the explicit v2 entry-point commands and CI
  targets, the aggregate evidence with the missing prerequisites separated, the
  lifecycle disposition and the remaining obligations.
- Not recorded and not claimed: Android/Linux device acceptance, packaging or
  distribution, MVP acceptance (`V2-086`), G1–G5, publication authority
  (`V2-077A`), installed-cohort migration (`V1-02A`/`V2-076A`) or closure of
  `V2-020C`/`V2-020` for the deferred platforms (Web/Chrome, iOS, macOS,
  Windows).
