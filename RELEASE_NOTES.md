# Release Notes

## 2026-02-10 - Parity Wave 011-016 Signoff

Scope: reliability hardening and release-readiness closure for the parity wave.

### Highlights

- Completed multi-server orchestration with server-scoped persistence and health-aware switching.
- Completed model/provider controls with variant (reasoning effort) serialization and scoped restore.
- Completed realtime event parity for session/message/permission/question flows, including reconnect and fallback behavior.
- Completed advanced session lifecycle operations (rename/archive/share/unshare/fork/delete + status/todo/diff/children insights).
- Completed directory-scoped project/workspace orchestration with `/global/event` synchronization and worktree operations.

### Feature 016 Closure

- Expanded automated coverage for parity-critical scenarios in unit/widget/integration suites.
- Executed and documented QA matrix `PAR-001`..`PAR-008` in `QA.feat016.release-readiness.md`.
- Verified runtime smokes (Linux + Chrome) and build gates (`flutter build linux`, `flutter build web`, `flutter build apk --debug`).
- Verified Android release artifact generation and upload path through `make android`.

### Known Limitations

- Local Android emulator startup (`Pixel_7_API_34`) fails on this host with emulator exit code `-6`; interactive Android runtime validation remains environment-blocked in this session.
- Windows and macOS runtime validation still require native hosts for full target runtime checks.

### Release Readiness Decision

Accepted for parity-wave release readiness with no open P0/P1 product defects and one documented host-environment limitation.
