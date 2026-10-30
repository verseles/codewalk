# Chat parity captures

`visual_parity_suite_test.dart` writes captures to an owned temporary directory
and removes it after the test. A normal test run does not overwrite the
repository's evidence or a previous capture run.

To retain a new set of captures, provide a new empty directory explicitly:

```sh
source ~/paths
export PATH="$HOME/flutter/bin:$PATH"
mkdir -p /tmp/opencode
export CODEWALK_PARITY_CAPTURE_DIR="$(mktemp -d /tmp/opencode/cp5-captures-XXXXXX)"
flutter test test/parity/visual_parity_suite_test.dart
```

The specified directory is retained. A nonempty directory and an existing
capture filename are rejected; separate concurrent runs must use separate
directories. These are synthetic widget captures, not proof of native chat
parity or owner acceptance.
