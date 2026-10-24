# V2-078A — MVP platform evidence (Android/Linux)

> **Scope:** the per-target entry evidence for the v2 MVP beta (roadmap §11.6
> Seq 5.4, Issue [#357](https://github.com/verseles/codewalk/issues/357)),
> following the platform matrix of `v2-plan.md` §15.4. It is not a release,
> a publication, an owner acceptance or a G1/G2/final-G5 record.

`matrix.json` records, for each MVP target, four separate cells. One never
stands in for another, and one architecture never passes another:

| Dimension | What it records |
|---|---|
| `package` | The actual-v2 artifact was built from `lib/main_v2.dart` at the recorded revision, with its digest |
| `install` | The artifact was installed (Android) or extracted and launched (Linux) on that target |
| `signature` | Its identity: the production signer and application id for the Android candidate; Linux bundles are unsigned, which is recorded, not passed as signing |
| `functional` | The pairing → send → permission → stop → reconnect flow was observed on that target |

Targets: `android-s25` (the owner's Galaxy S25, Android 16), `android-api31`
(Android 12/API 31 emulator, the reference floor), `linux-x64`,
`linux-arm64`. `gates` holds the G3, G4 and provisional G5 reruns at a
recorded revision. `deferred` lists Web, iOS, macOS and Windows as
`deferred-post-mvp` with their tracking Issues; they can never pass here.

Cell results: `pending` (its producer has not run), `pass` (revision,
producer, evidence and the dimension's own fact: artifact `sha256`, the
`signer_sha256` or `unsigned: true`, or the `device` it ran on),
`pending-resource` (the missing resource and the next action), `fail` or
`inconclusive` (with the reason), `approved-tier` (with the recorded
decision). Every file in this folder, the matrix included, is pinned in
`SHA256SUMS`; local evidence a cell cites must be one of them, and none may
carry a credential or an address. Remote evidence is a link to this
repository's runs or Issues.

Validate with:

```bash
python3 tool/ci/validate_platform_evidence.py           # structure, no leaks
python3 tool/ci/validate_platform_evidence.py --final   # nothing left pending
```
