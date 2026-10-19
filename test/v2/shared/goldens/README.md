# Rich rendering goldens

These snapshots render the canonical rich session-timeline fixture — heading,
list, GFM table, Dart code block, inline LaTeX, allowlisted HTML with a
`progress` element and a Mermaid diagram — at 390x844 and 1280x800 in light and
dark, plus Arabic RTL. They use Flutter's deterministic Ahem test font, DPR 1
and VM-only widget tests. Linux Flutter 3.44.1 generated the initial
snapshots; CI pins the same Flutter 3.44.1 so pixel parity is enforced rather
than assumed. Pixel parity on another renderer/SDK is separate from the local
checks and must be inspected rather than assumed.

The fixture lays out 564 logical px tall, but the shrink-wrapped
`RepaintBoundary` height is reported as 564.00000095 on some architectures and
the golden capture rounds with `ceil`, so the same layout produced a 565px
image on arm64 and a 564px image on x64 CI. `_goldenCanvasHeight` in the test
pins the canvas to an integral 564px and `closeTo` asserts the fixture's
natural height against it, so growing the fixture fails loudly instead of
being clipped silently. Bump both together and regenerate.

Regenerate deliberately after inspecting a visual change:

```sh
export PATH="$HOME/flutter/bin:$PATH"
flutter test --no-pub --update-goldens test/v2/shared/rich_rendering_golden_test.dart
```

Behavioral coverage lives in `rich_rendering_test.dart` and
`session_timeline_rendering_test.dart`; these goldens only lock the composed
pixels.
