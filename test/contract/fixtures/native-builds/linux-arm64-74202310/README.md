# V2-020CA — observed Linux ARM64 debug compilation

**Outcome: compiler subset accepted; installation and MVP remain pending.**
On 2026-10-11, the explicit `lib/main_v2.dart` target from clean commit
`742023108c57da1ee15ab2a9f2f408f614342ee4` compiled successfully on a native
Ubuntu 24.04 ARM64 container. This completes a missing compiler architecture
under [#356](https://github.com/verseles/codewalk/issues/356), not its remaining
device/reference criteria or parent #255.

## Observed checks and artifacts

- `make v2-native-check` passed: four workspace packages, strict analysis,
  architecture/localization checks and 1,028 Dart tests across six commands.
  Two existing skips remain: an explicitly authorized live OpenCode 2.0.22
  runtime check and a browser-only hard guard. No test was removed or suppressed.
- One `make v2-linux-debug` invocation finished with exit 0 at
  `2026-10-11T22:22:30.474120+00:00`. Its command explicitly selected
  `lib/main_v2.dart`, debug mode and `linux-arm64`.
- The orchestrator independently rehashed all 63 bundle files and inspected
  all 15 ELF files: runner, engine, Tailscale, ONNX and native plugins are
  64-bit little-endian AArch64 (`e_machine = 183`).
- The debug kernel is 116,015,696 bytes. Source remained clean before and after
  compilation. `compiler.json` is the unchanged native builder output;
  `audit.json` records the additional independent checks.

The 275,376,792-byte bundle was inspected in the disposable build environment.
It was not installed, launched, signed, published or delivered as a preview.
This directory retains small textual evidence, not the binary bundle.

## Exact environment

Flutter 3.44.0 was bootstrapped from the official Git release revision
`559ffa3f75e7402d65a8def9c28389a9b2e6fe42`, using engine
`4c525dac5ebe5971c5708ef73558ed8edcf4a362` and Dart 3.12.0. The raw CLI reports
`[user-branch]` because this is a release-pinned Git checkout, not an SDK archive
installation; the framework/engine revisions were checked independently.

The official matching ARM64 Dart and GTK artifacts were fetched by Flutter's
unmodified bootstrap. Go 1.25.5 was separately verified against its official
archive SHA-256 and size; native GCC/G++ 13.3.0 supplied CGO compilation.
All preparation used a disposable local container limited to two CPUs and
6 GiB. Host packages, SDK, credentials, services and existing containers were
not changed. Android compilation remains on GitHub Actions.

The first bootstrap wrapper rejected curl progress preceding machine JSON.
An explicit warmup followed by a separate strict machine call fixed that
integration issue. The first two native-check attempts stopped on absent Go
and then GCC; installing these required tools inside the container resolved
them. Earlier failures were preserved as observations, not reported as passes.
No permanent application, hook, dependency or CI code was changed.

## Evidence boundaries

These are native compiler/check records, not OpenCode/Codex/Claude protocol
recordings or G1/G2/G5 acceptance. #243's unobserved retry/quota cases and the
known post-MVP Chrome failures remain pending. GUI launch, installation,
release AOT, signing, migration, device coverage and owner MVP acceptance are
not established here. Exact source/tool versions do not imply a hermetic or
bit-for-bit reproducible build.
