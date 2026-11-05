> 📣 CodeWalk 2 now checks for updates automatically, remembers dismissed versions, shows release announcements, resumes interrupted downloads, and supports verified installation on Android and Linux.

### Updates

- Discover new versions at startup and hourly, with an optional automatic-check setting and independent checks when opening Settings.
- Keep stable and Beta channels separate, remember dismissed versions, and show installed-release news and accumulated announcements.
- Resume interrupted downloads, keep progress visible across screens, and explain verification, storage, network, and installer errors.
- Verify Android APKs before handing them to the system installer.
- Install verified Linux updates from managed v2 bundles and restart after saving local state. Older or unmanaged bundles keep the exact-version installer command.

### Beta scope

This is an opt-in CodeWalk 2 prerelease for Android arm64 and Linux x64/ARM64. It never replaces the latest stable release, does not import v1 data, and preserves v2 local data during updates. Android installation requires the system confirmation. Linux archive integrity uses the published SHA-256 manifest; no Linux package signature is claimed.
