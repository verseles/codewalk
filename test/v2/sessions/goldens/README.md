# Live timeline goldens

These snapshots lock the composed live session timeline of V2-044C2: the top
of a full window (older rows paged in above, the local-limit notice and the
history action at the very top) at 390x844 and 1280x800, light and dark, plus
Arabic RTL, and the landing on the newest rows. They use Flutter's
deterministic Ahem test font, DPR 1 and VM-only widget tests, with no
progress indicator on screen. Linux Flutter 3.44.1 generated them; CI pins the
same Flutter, so pixel parity is enforced rather than assumed.

Regenerate deliberately after inspecting a visual change:

```sh
export PATH="$HOME/flutter/bin:$PATH"
flutter test --no-pub --update-goldens test/v2/sessions/session_live_timeline_golden_test.dart
```

Behavioral coverage lives in `session_live_pagination_test.dart` and
`session_live_scroll_test.dart`; these goldens only lock the composed pixels.
