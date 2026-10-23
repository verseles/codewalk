#!/usr/bin/env sh
set -eu

# CodeWalk installer
# Usage: curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | sh

REPO="${CODEWALK_REPO:-verseles/codewalk}"
APP_ID="com.verseles.codewalk"
APP_NAME="CodeWalk"
XDG_DATA_HOME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
LEGACY_INSTALL_DIR="${XDG_DATA_HOME_DIR}/codewalk"
INSTALL_DIR="$LEGACY_INSTALL_DIR"
VERSION_FILE="$INSTALL_DIR/.installed-version"
CHANNEL_FILE="$INSTALL_DIR/.installed-channel"
BIN_DIR="$HOME/.local/bin"
LINUX_DESKTOP_DIR="${XDG_DATA_HOME_DIR}/applications"
LINUX_ICON_DIR="${XDG_DATA_HOME_DIR}/icons/hicolor/512x512/apps"
MAC_APPS_DIR="$HOME/Applications"

info() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    fail "curl or wget is required"
  fi
}

detect_platform() {
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux) platform="linux" ;;
    Darwin) platform="macos" ;;
    *) fail "Unsupported OS: $os" ;;
  esac

  case "$platform" in
    macos)
      case "$arch" in
        x86_64|amd64) arch_tag="x64" ;;
        aarch64|arm64) arch_tag="arm64" ;;
        *) fail "Unsupported macOS architecture: $arch" ;;
      esac
      asset="codewalk-macos-${arch_tag}.tar.gz"
      ;;
    linux)
      case "$arch" in
        x86_64|amd64)
          arch_tag="x64"
          asset="codewalk-linux-x64.tar.gz"
          ;;
        aarch64|arm64)
          arch_tag="arm64"
          asset="codewalk-linux-arm64.tar.gz"
          ;;
        *)
          fail "Unsupported Linux architecture: $arch"
          ;;
      esac
      ;;
  esac
}

configure_install_paths() {
  if [ "$platform" = "linux" ]; then
    INSTALL_DIR="${XDG_DATA_HOME_DIR}/codewalk-app"
  else
    INSTALL_DIR="$LEGACY_INSTALL_DIR"
  fi
  VERSION_FILE="$INSTALL_DIR/.installed-version"
  CHANNEL_FILE="$INSTALL_DIR/.installed-channel"
}

cleanup_legacy_linux_bundle() {
  [ "$platform" = "linux" ] || return 0
  [ "$LEGACY_INSTALL_DIR" != "$INSTALL_DIR" ] || return 0
  [ -d "$LEGACY_INSTALL_DIR" ] || return 0

  # path_provider_linux intentionally reuses this executable-name directory
  # for existing user data. Remove only files owned by old release bundles.
  for entry in codewalk bin data lib codewalk.app .installed-version .installed-channel; do
    rm -rf "$LEGACY_INSTALL_DIR/$entry"
  done
  info "Preserved Linux user data in $LEGACY_INSTALL_DIR"
}

# Release selection. Environment inputs (they must reach this `sh`, not curl):
#   CODEWALK_CHANNEL    stable | v1 | beta (default: saved choice, then stable)
#   CODEWALK_VERSION    exact release tag to install instead of the newest one
#   CODEWALK_MIGRATION  none | accept-v2: consent to move CodeWalk 1 to 2
#   CODEWALK_UPDATE_CONTRACT=1  app handoff: all three above are required
API_URL="https://api.github.com/repos/$REPO"
RELEASE_PAGE_SIZE=100
RELEASE_PAGE_LIMIT=10

# Reads one GitHub release object ("single") or a list of them ("list") on
# stdin and prints "tag<TAB>draft<TAB>prerelease" per release. Any malformed,
# truncated or incomplete document fails, so text inside a release body can
# never be taken for a field.
release_records() {
  # Byte semantics keep substr() constant-time on multibyte release notes.
  LC_ALL=C awk -v mode="$1" '
    function bad() { failed = 1; exit 1 }
    function ws() { while (p <= n && index(" \t\r\n", substr(s, p, 1))) p++ }
    function str(  out, c, e) {
      if (substr(s, p, 1) != "\"") bad()
      p++; out = ""
      while (p <= n) {
        c = substr(s, p, 1)
        if (c == "\"") { p++; return out }
        if (c == "\\") {
          e = substr(s, p + 1, 1)
          if (index("\"\\/", e)) { out = out e; p += 2 }
          else if (index("bfnrt", e)) { out = out "\n"; p += 2 }
          else if (e == "u" && substr(s, p + 2, 4) ~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) { out = out "?"; p += 6 }
          else bad()
        } else { out = out c; p++ }
      }
      bad()
    }
    function value(  c) {
      ws(); c = substr(s, p, 1)
      if (c == "{") { object(0); return "object" }
      if (c == "[") { array(0); return "array" }
      if (c == "\"") { str(); return "string" }
      if (substr(s, p, 4) == "true") { p += 4; return "true" }
      if (substr(s, p, 5) == "false") { p += 5; return "false" }
      if (substr(s, p, 4) == "null") { p += 4; return "null" }
      if (match(substr(s, p, 64), /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/)) { p += RLENGTH; return "number" }
      bad()
    }
    # A release is an object whose tag_name, draft and prerelease fields
    # are read at its own level; nested objects are only validated.
    function object(release,  key, kind, tag, draft, pre, seen, c) {
      p++; ws(); tag = ""; draft = ""; pre = ""; seen = 0
      if (substr(s, p, 1) == "}") { p++; if (release) bad(); return }
      while (1) {
        ws(); key = str(); ws()
        if (substr(s, p, 1) != ":") bad()
        p++
        if (release && key == "tag_name") {
          ws(); if (seen) bad()
          tag = str(); seen = 1
        } else if (release && (key == "draft" || key == "prerelease")) {
          kind = value()
          if (kind != "true" && kind != "false") bad()
          if (key == "draft") { if (draft != "") bad(); draft = kind }
          else { if (pre != "") bad(); pre = kind }
        } else value()
        ws(); c = substr(s, p, 1); p++
        if (c == "}") break
        if (c != ",") bad()
      }
      if (release) {
        if (!seen || draft == "" || pre == "") bad()
        if (tag !~ /^[A-Za-z0-9._+-]+$/) tag = "!"
        printf "%s\t%s\t%s\n", tag, draft, pre
      }
    }
    function array(releases,  c) {
      p++; ws()
      if (substr(s, p, 1) == "]") { p++; return }
      while (1) {
        ws()
        if (releases) { if (substr(s, p, 1) != "{") bad(); object(1) }
        else value()
        ws(); c = substr(s, p, 1); p++
        if (c == "]") return
        if (c != ",") bad()
      }
    }
    { s = s $0 "\n" }
    END {
      if (failed) exit 1
      n = length(s); p = 1; ws()
      if (mode == "list") { if (substr(s, p, 1) != "[") bad(); array(1) }
      else { if (substr(s, p, 1) != "{") bad(); object(1) }
      ws(); if (p <= n) bad()
    }
  '
}

# Prints the major of a tag that the given channel may install, or fails.
# stable/v1 take vMAJOR.MINOR.PATCH (v optional) without suffixes; beta takes
# only v2.0.0-beta.N. Native cohort tags (-native.N) belong to none of them.
channel_tag_major() {
  awk -v tag="$1" -v channel="$2" 'BEGIN {
    num = "(0|[1-9][0-9]*)"
    if (channel == "beta") {
      if (tag ~ ("^v2\\.0\\.0-beta\\." num "$")) { print 2; exit 0 }
      exit 1
    }
    if (tag !~ ("^v?" num "\\." num "\\." num "$")) exit 1
    major = tag; sub(/^v/, "", major); sub(/\..*/, "", major)
    if (channel == "v1" && major != "1") exit 1
    print major
  }'
}

# Prints the highest tag of the given channel among release records on stdin.
# Version components are compared as digit strings, so no size overflows.
highest_channel_tag() {
  awk -F '\t' -v channel="$1" '
    function newer(a, b,  i, x, y) {
      for (i = 1; i <= 4; i++) {
        x = a[i]; y = b[i]
        if (length(x) != length(y)) return length(x) > length(y)
        if (x != y) return x > y
      }
      return 0
    }
    {
      if ($2 != "false") next
      if (channel == "beta") {
        if ($3 != "true" || $1 !~ /^v2\.0\.0-beta\.(0|[1-9][0-9]*)$/) next
        k[1] = 2; k[2] = 0; k[3] = 0; k[4] = substr($1, 13)
      } else {
        if ($3 != "false" || $1 !~ /^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/) next
        v = $1; sub(/^v/, "", v); split(v, parts, ".")
        if (channel == "v1" && parts[1] != "1") next
        k[1] = parts[1]; k[2] = parts[2]; k[3] = parts[3]; k[4] = ""
      }
      if (best == "" || newer(k, b)) { best = $1; for (i = 1; i <= 4; i++) b[i] = k[i] }
    }
    END { if (best == "") exit 1; print best }
  '
}

read_install_request() {
  contract="${CODEWALK_UPDATE_CONTRACT:-}"
  requested_channel="${CODEWALK_CHANNEL:-}"
  requested_version="${CODEWALK_VERSION:-}"
  migration="${CODEWALK_MIGRATION:-}"
  case "$contract" in
    "") ;;
    1)
      [ -n "$requested_channel" ] && [ -n "$requested_version" ] &&
        [ -n "$migration" ] ||
        fail "CODEWALK_UPDATE_CONTRACT=1 requires CODEWALK_CHANNEL, CODEWALK_VERSION and CODEWALK_MIGRATION"
      ;;
    *) fail "Unsupported CODEWALK_UPDATE_CONTRACT: $contract" ;;
  esac
  case "$requested_channel" in
    ""|stable|v1|beta) ;;
    *) fail "Unsupported CODEWALK_CHANNEL: $requested_channel (use stable, v1 or beta)" ;;
  esac
  case "$migration" in
    "") migration="none" ;;
    none|accept-v2) ;;
    *) fail "Unsupported CODEWALK_MIGRATION: $migration (use none or accept-v2)" ;;
  esac
  case "$requested_version" in
    "") ;;
    *[!A-Za-z0-9._+-]*) fail "Invalid CODEWALK_VERSION: $requested_version" ;;
  esac
}

# The installed version and saved channel of the current bundle. A bundle
# whose version is missing or unreadable is still an existing install; every
# such bundle predates CodeWalk 2, so it keeps the CodeWalk 1 major.
read_install_state() {
  installed_version=""
  for version_file in "$VERSION_FILE" "$LEGACY_INSTALL_DIR/.installed-version"; do
    if [ -f "$version_file" ]; then
      installed_version="$(sed -n '1p' "$version_file" 2>/dev/null | tr -d '\r' || true)"
      [ -z "$installed_version" ] || break
    fi
  done

  existing_install=0
  if [ -n "$installed_version" ] || [ -d "$INSTALL_DIR" ] ||
    [ -L "$BIN_DIR/codewalk" ] || [ -f "$BIN_DIR/codewalk" ] ||
    { [ "$LEGACY_INSTALL_DIR" != "$INSTALL_DIR" ] &&
      find_cli_binary_in "$LEGACY_INSTALL_DIR" >/dev/null 2>&1; }; then
    existing_install=1
  fi

  installed_major=""
  if [ "$existing_install" = "1" ]; then
    installed_major="$(printf '%s' "$installed_version" |
      sed -n 's/^v\{0,1\}\([0-9][0-9]*\)\..*/\1/p')"
    if [ -z "$installed_major" ]; then
      info "Warning: the installed CodeWalk version is unknown; treating it as CodeWalk 1"
      installed_major=1
    fi
  fi

  saved_channel=""
  if [ -f "$CHANNEL_FILE" ]; then
    saved_channel="$(sed -n '1p' "$CHANNEL_FILE" 2>/dev/null | tr -d '\r' || true)"
    case "$saved_channel" in
      stable|v1|beta) ;;
      *)
        [ -n "$requested_channel" ] ||
          fail "Unreadable saved channel in $CHANNEL_FILE; set CODEWALK_CHANNEL to stable, v1 or beta"
        saved_channel=""
        ;;
    esac
  fi
  channel="${requested_channel:-${saved_channel:-stable}}"
}

fetch_api() {
  fetch "$API_URL/$1" ||
    fail "Could not fetch release metadata from GitHub ($1); check the network or the API rate limit"
}

resolve_release() {
  if [ -n "$requested_version" ]; then
    json="$(fetch_api "releases/tags/$requested_version")"
    record="$(printf '%s\n' "$json" | release_records single)" ||
      fail "Malformed release metadata for $requested_version"
    record_tag="$(printf '%s' "$record" | cut -f1)"
    record_draft="$(printf '%s' "$record" | cut -f2)"
    record_prerelease="$(printf '%s' "$record" | cut -f3)"
    [ "$record_tag" = "$requested_version" ] ||
      fail "Release $requested_version was not found as an exact tag"
    expected_prerelease=false
    [ "$channel" != "beta" ] || expected_prerelease=true
    [ "$record_draft" = "false" ] && [ "$record_prerelease" = "$expected_prerelease" ] &&
      target_major="$(channel_tag_major "$requested_version" "$channel")" ||
      fail "Release $requested_version is not a $channel release"
    version="$requested_version"
    return 0
  fi

  if [ "$channel" = "stable" ]; then
    json="$(fetch_api "releases/latest")"
    record="$(printf '%s\n' "$json" | release_records single)" ||
      fail "Malformed release metadata for the latest release"
    version="$(printf '%s\n' "$record" | highest_channel_tag stable)" ||
      fail "The latest release of $REPO is not a stable release"
  else
    records=""
    page=1
    while :; do
      json="$(fetch_api "releases?per_page=$RELEASE_PAGE_SIZE&page=$page")"
      page_records="$(printf '%s\n' "$json" | release_records list)" ||
        fail "Malformed release list on page $page"
      page_count="$(printf '%s' "$page_records" | grep -c . || true)"
      records="$records$page_records
"
      [ "$page_count" -ge "$RELEASE_PAGE_SIZE" ] || break
      [ "$page" -lt "$RELEASE_PAGE_LIMIT" ] ||
        fail "More than $((RELEASE_PAGE_SIZE * RELEASE_PAGE_LIMIT)) releases; cannot prove the newest $channel release"
      page=$((page + 1))
    done
    version="$(printf '%s' "$records" | highest_channel_tag "$channel")" ||
      fail "No $channel release of $REPO is available"
  fi
  target_major="$(channel_tag_major "$version" "$channel")" ||
    fail "Release $version is not a $channel release"
}

# A release of another major replaces CodeWalk only with explicit consent,
# and only from CodeWalk 1 to CodeWalk 2. Nothing has been changed yet.
check_major_policy() {
  [ -n "$installed_major" ] || return 0
  [ "$target_major" != "$installed_major" ] || return 0
  if [ "$installed_major" = "1" ] && [ "$target_major" = "2" ]; then
    [ "$migration" = "accept-v2" ] && return 0
    printf '%s\n' \
      "Error: CodeWalk $version is CodeWalk 2, which works only with OpenCode 2 servers;" \
      "CodeWalk 1 servers stop working with it. Your installation was not changed." \
      "To migrate, run again with CODEWALK_MIGRATION=accept-v2." \
      "To stay on CodeWalk 1, run again with CODEWALK_CHANNEL=v1." >&2
    exit 1
  fi
  fail "CodeWalk $version cannot replace the installed CodeWalk $installed_major ($installed_version); your installation was not changed"
}

detect_install_mode() {
  if [ -n "$installed_version" ]; then
    if [ "$installed_version" = "$version" ]; then
      install_mode="reinstall"
      info "Reinstalling CodeWalk $version ($channel)"
    else
      install_mode="update"
      info "Updating CodeWalk from $installed_version to $version ($channel)"
    fi
    return 0
  fi

  if [ "$existing_install" = "1" ]; then
    install_mode="update"
    info "Existing installation detected. Installing $channel release $version"
    return 0
  fi

  install_mode="install"
  info "Installing CodeWalk $version ($channel)"
}

find_macos_bundle() {
  find "$INSTALL_DIR" -maxdepth 4 -type d -name '*.app' 2>/dev/null | head -1
}

find_cli_binary_in() {
  search_root="$1"
  for candidate in \
    "$search_root/codewalk" \
    "$search_root/bin/codewalk" \
    "$search_root/codewalk.app/Contents/MacOS/codewalk"; do
    if [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  candidate="$(find "$search_root" -maxdepth 3 -type f -name 'codewalk' 2>/dev/null | head -1 || true)"
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  return 1
}

find_cli_binary() {
  find_cli_binary_in "$INSTALL_DIR"
}

find_linux_icon_in() {
  search_root="$1"
  for candidate in \
    "$search_root/data/$APP_ID.png" \
    "$search_root/data/app_icon.png" \
    "$search_root/$APP_ID.png" \
    "$search_root/app_icon.png"; do
    if [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

install_macos_bundle() {
  [ "$platform" = "macos" ] || return 1

  bundle_path="$(find_macos_bundle || true)"
  [ -n "$bundle_path" ] || return 1

  mkdir -p "$MAC_APPS_DIR"
  target_bundle="$MAC_APPS_DIR/$APP_NAME.app"
  rm -rf "$target_bundle"
  cp -R "$bundle_path" "$target_bundle"
  # Remove macOS quarantine attribute so Gatekeeper does not block the app.
  xattr -cr "$target_bundle" 2>/dev/null || true

  app_exec="$(find "$target_bundle/Contents/MacOS" -maxdepth 1 -type f 2>/dev/null | head -1 || true)"
  if [ -n "$app_exec" ] && [ -x "$app_exec" ]; then
    ln -sf "$app_exec" "$BIN_DIR/codewalk"
    mac_app_bundle="$target_bundle"
    return 0
  fi

  return 1
}

integrate_linux_desktop() {
  [ "$platform" = "linux" ] || return 0

  mkdir -p "$LINUX_DESKTOP_DIR" "$LINUX_ICON_DIR"

  icon_source="$(find_linux_icon_in "$INSTALL_DIR" || true)"
  [ -n "$icon_source" ] || fail "Could not find Linux icon in extracted archive"

  linux_icon_path="$LINUX_ICON_DIR/$APP_ID.png"
  cp -f "$icon_source" "$linux_icon_path"

  linux_desktop_path="$LINUX_DESKTOP_DIR/$APP_ID.desktop"
  cat > "$linux_desktop_path" <<EOF_DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Cross-platform OpenCode client
Exec=$BIN_DIR/codewalk %U
Icon=$linux_icon_path
Terminal=false
Categories=Development;Utility;
StartupNotify=true
StartupWMClass=$APP_ID
Keywords=AI;Code;Assistant;OpenCode;
EOF_DESKTOP

  chmod 0644 "$linux_desktop_path"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$LINUX_DESKTOP_DIR" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "${XDG_DATA_HOME_DIR}/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

cleanup_install_attempt() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e
  rm -rf "$tmp" "$staged_install_dir"
  if [ -e "$backup_install_dir" ] || [ -L "$backup_install_dir" ]; then
    if [ "${install_succeeded:-0}" = "1" ]; then
      rm -rf "$backup_install_dir"
    else
      rm -rf "$INSTALL_DIR"
      mv "$backup_install_dir" "$INSTALL_DIR"
    fi
  fi
  exit "$status"
}

download_and_install() {
  tmp="${TMPDIR:-/tmp}/codewalk-install-$$"
  install_parent="${INSTALL_DIR%/*}"
  staged_install_dir="${INSTALL_DIR}.staged-$$"
  backup_install_dir="${INSTALL_DIR}.backup-$$"
  mkdir -p "$tmp" "$install_parent"
  rm -rf "$staged_install_dir" "$backup_install_dir"
  mkdir -p "$staged_install_dir"
  install_succeeded=0
  trap cleanup_install_attempt EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  url="https://github.com/$REPO/releases/download/$version/$asset"
  info "Downloading $asset from $REPO ($version)"
  fetch "$url" > "$tmp/$asset" || fail "Failed to download $url"

  tar -xzf "$tmp/$asset" -C "$staged_install_dir" ||
    fail "Failed to extract $asset"
  staged_cli_binary="$(find_cli_binary_in "$staged_install_dir" || true)"
  [ -n "$staged_cli_binary" ] ||
    fail "Downloaded archive does not contain a codewalk executable"
  if [ "$platform" = "linux" ]; then
    staged_linux_icon="$(find_linux_icon_in "$staged_install_dir" || true)"
    [ -n "$staged_linux_icon" ] ||
      fail "Downloaded archive does not contain a Linux icon"
    [ -f "$staged_install_dir/lib/libflutter_linux_gtk.so" ] ||
      fail "Downloaded archive does not contain the Flutter Linux runtime"
    [ -f "$staged_install_dir/lib/libapp.so" ] ||
      fail "Downloaded archive does not contain the CodeWalk application library"
    [ -f "$staged_install_dir/data/icudtl.dat" ] ||
      fail "Downloaded archive does not contain ICU data"
    [ -d "$staged_install_dir/data/flutter_assets" ] ||
      fail "Downloaded archive does not contain Flutter assets"
    [ -n "$(find "$staged_install_dir/data/flutter_assets" -mindepth 1 -print -quit)" ] ||
      fail "Downloaded archive contains empty Flutter assets"
  fi

  if [ -e "$INSTALL_DIR" ] || [ -L "$INSTALL_DIR" ]; then
    mv "$INSTALL_DIR" "$backup_install_dir"
  fi
  if ! mv "$staged_install_dir" "$INSTALL_DIR"; then
    if [ -e "$backup_install_dir" ] || [ -L "$backup_install_dir" ]; then
      mv "$backup_install_dir" "$INSTALL_DIR"
    fi
    fail "Failed to activate the downloaded CodeWalk bundle"
  fi
  mkdir -p "$BIN_DIR"

  mac_app_bundle=""
  if [ "$platform" = "macos" ]; then
    install_macos_bundle || true
  fi

  if [ -z "$mac_app_bundle" ]; then
    cli_binary="$(find_cli_binary || true)"
    [ -n "$cli_binary" ] || fail "Could not find codewalk executable in extracted archive"
    ln -sf "$cli_binary" "$BIN_DIR/codewalk"
  fi

  cleanup_legacy_linux_bundle
  integrate_linux_desktop
  printf '%s\n' "$version" > "$VERSION_FILE"
  printf '%s\n' "${channel:-stable}" > "$CHANNEL_FILE"
  install_succeeded=1
  rm -rf "$tmp" "$staged_install_dir" "$backup_install_dir"
  trap - EXIT HUP INT TERM
}

print_done() {
  info ""
  info "CodeWalk installed to $INSTALL_DIR"
  info "Version: $version"
  info "Binary link: $BIN_DIR/codewalk"

  if [ "$platform" = "linux" ]; then
    info "Desktop entry: ${linux_desktop_path:-$LINUX_DESKTOP_DIR/$APP_ID.desktop}"
    info "Desktop icon: ${linux_icon_path:-$LINUX_ICON_DIR/$APP_ID.png}"
  fi

  if [ "$platform" = "macos" ] && [ -n "${mac_app_bundle:-}" ]; then
    info "App bundle: $mac_app_bundle"
  fi

  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      info "Add to PATH if needed:"
      info "  export PATH=\"$HOME/.local/bin:\$PATH\""
      ;;
  esac

  info "Run: codewalk"
}

main() {
  detect_platform
  configure_install_paths
  read_install_request
  read_install_state
  resolve_release
  check_major_policy
  detect_install_mode
  download_and_install
  print_done
}

if [ "${CODEWALK_INSTALLER_SOURCE_ONLY:-0}" != "1" ]; then
  main "$@"
fi
