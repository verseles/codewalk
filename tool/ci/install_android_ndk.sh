#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${ANDROID_HOME:-}" && -n "${ANDROID_SDK_ROOT:-}" &&
      "$ANDROID_HOME" != "$ANDROID_SDK_ROOT" ]]; then
  printf '%s\n' 'ANDROID_HOME and ANDROID_SDK_ROOT disagree.' >&2
  exit 1
fi

sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk_root" ]]; then
  printf '%s\n' 'An explicit Android SDK root is required.' >&2
  exit 1
fi
sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$sdkmanager" ]]; then
  printf 'Android SDK manager is missing or not executable: %s\n' "$sdkmanager" >&2
  exit 1
fi

"$sdkmanager" --version
"$sdkmanager" --sdk_root="$sdk_root" --install "ndk;28.2.13676358"
