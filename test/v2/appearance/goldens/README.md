# Appearance goldens

These snapshots render the actual v2 appearance controls at 390×844 and
1280×800 in light and OC-2 dark mode. They use Flutter's deterministic Ahem
test font, English, DPR 1, fixed settings and an injected no-dynamic-color
source. Linux Flutter 3.44.1/Dart 3.12.1 generated the initial snapshots;
CI currently uses Flutter 3.44.0. Pixel parity on another renderer/SDK is
separate from the local checks and must be inspected rather than assumed.

Regenerate deliberately after inspecting a visual change:

```sh
export PATH="$HOME/flutter/bin:$PATH"
flutter test --no-pub --update-goldens test/v2/appearance/appearance_golden_test.dart
```

Goldens are VM-only. Behavioral tests independently cover all five density
tiers, 320/390/1280 widths, RTL, persistence and preset selection.
