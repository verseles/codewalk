# V2-020CA — Android/Linux MVP targets, explicit v2 entry points and aggregate evidence

**Outcome: targets and entry points recorded; aggregate checks observed on this
revision; device installation, packaging and acceptance remain pending.**
This record closes the *recording* criteria of
[#356](https://github.com/verseles/codewalk/issues/356) on `main` and reports the
missing prerequisites separately. It is not an MVP platform acceptance, not a
distribution pass and not a closure of the full-platform parent
[#255](https://github.com/verseles/codewalk/issues/255).

## Agreed targets

| Scope | Target | Status |
|---|---|---|
| Native MVP (reference) | Android 12 / API 31 | compiler/build observed in CI; device install/launch pending |
| Native MVP | Linux x64 | debug build observed locally; GUI distribution pending |
| Native MVP | Linux ARM64 | debug compilation observed (see `linux-arm64-74202310/`); GUI/install pending |
| Deferred (post-MVP) | Web/Chrome | explicit manual checkpoint `v2-deferred-web.yml`; no acceptance |
| Deferred (post-MVP) | iOS, macOS, Windows | full-parent obligations recorded by #255/V2-020C; not prerequisites here |

Android build codes, signing and identity policy follow the cross-line
publication rules in `AGENTS.md`; no APK signing material or physical reference
device is available in this environment, so those rows stay pending instead of
being claimed as passes.

## Explicit v2 entry point and commands

- Entry point: `lib/main_v2.dart`. Governed packages in the pub workspace:
  `packages/codewalk_core`, `packages/codewalk_net`, `packages/harness_opencode`
  and `packages/harness_host`.
- Preserved gates: `dart run tool/ci/import_rules.dart` (v2 architecture and
  retained-reference boundaries), `python3 tool/ci/check_v2_foundations.py`
  (strict analysis, scoped l10n and the v2 test lifecycle).

| Make target | Command | CI job |
|---|---|---|
| `make v2-architecture` | `dart run tool/ci/import_rules.dart` | `quality` |
| `make v2-foundations` | `python3 tool/ci/check_v2_foundations.py` | `v2_foundations` |
| `make v2-native-check` | `python3 tool/ci/check_v2_foundations.py --profile native` (+ `test-v2-tools`) | `v2_native_checks` |
| `make v2-android-debug` | `python3 tool/ci/build_v2_native.py android` | `v2_native_builds` (android) |
| `make v2-linux-debug` | `python3 tool/ci/build_v2_native.py linux` | `v2_native_builds` (linux) |
| `make v2-linux-preview-package` | `tool/preview/preview_linux.py package …` | manual/local handoff only |
| `make v2-linux-preview-smoke` | `tool/ci/smoke_v2_linux_preview.py …` | manual/local handoff only |
| `make v2-smoke` | `flutter test --no-pub test/v2` | `v2_native_checks` (test phase) |

## Aggregate evidence — 2026-10-17, revision `846b9e5d`

- `make v2-native-check`: **exit 0** — 4 discovered packages and the explicit
  entry point, strict analysis and architecture/l10n guards, **790 tests passed**
  with the two pre-existing explicit skips (an authorized isolated native
  OpenCode 2.0.22 runtime check and a browser-only guard). No test was removed,
  renamed away or suppressed.
- CI on the same revision: `quality`, `v2_foundations`, `v2_native_checks`,
  `v2_native_builds` (android and linux), `coverage` and `windows_build` all
  succeeded; `test_shards` is intentionally skipped on this workflow.
- Compiler outputs previously observed: Android arm64 (CI), Linux x64 (local
  debug) and Linux ARM64 (isolated container, recorded in the sibling fixture).

## Missing prerequisites (reported, not passed)

- No physical Android 12/API 31 reference device and no signing material in this
  environment: install, launch, layout and permission flows are unverified here.
- Linux x64/ARM64 packaging, extraction and GUI smoke are pending; the ARM64
  record is compiler-only.
- The authorized isolated live OpenCode 2.0.22 runtime check and the
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
