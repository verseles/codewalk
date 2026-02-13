#!/usr/bin/env sh
set -eu

# CodeWalk installer
# Usage: curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | sh

REPO="${CODEWALK_REPO:-verseles/codewalk}"
APP_ID="com.verseles.codewalk"
APP_NAME="CodeWalk"
XDG_DATA_HOME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="${XDG_DATA_HOME_DIR}/codewalk"
VERSION_FILE="$INSTALL_DIR/.installed-version"
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

latest_release() {
  json="$(fetch "https://api.github.com/repos/$REPO/releases/latest")"
  version="$(printf '%s' "$json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$version" ] || fail "Could not determine latest release for $REPO"
}

detect_install_mode() {
  installed_version=""
  if [ -f "$VERSION_FILE" ]; then
    installed_version="$(sed -n '1p' "$VERSION_FILE" | tr -d '\r' || true)"
  fi

  if [ -n "$installed_version" ]; then
    if [ "$installed_version" = "$version" ]; then
      install_mode="reinstall"
      info "Reinstalling CodeWalk $version"
    else
      install_mode="update"
      info "Updating CodeWalk from $installed_version to $version"
    fi
    return 0
  fi

  if [ -d "$INSTALL_DIR" ] || [ -L "$BIN_DIR/codewalk" ] || [ -f "$BIN_DIR/codewalk" ]; then
    install_mode="update"
    info "Existing installation detected. Installing latest release $version"
    return 0
  fi

  install_mode="install"
  info "Installing CodeWalk $version"
}

find_macos_bundle() {
  find "$INSTALL_DIR" -maxdepth 4 -type d -name '*.app' 2>/dev/null | head -1
}

find_cli_binary() {
  for candidate in \
    "$INSTALL_DIR/codewalk" \
    "$INSTALL_DIR/bin/codewalk" \
    "$INSTALL_DIR/codewalk.app/Contents/MacOS/codewalk"; do
    if [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  candidate="$(find "$INSTALL_DIR" -maxdepth 3 -type f -name 'codewalk' 2>/dev/null | head -1 || true)"
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s' "$candidate"
    return 0
  fi

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

  icon_source=""
  for candidate in \
    "$INSTALL_DIR/data/$APP_ID.png" \
    "$INSTALL_DIR/data/app_icon.png" \
    "$INSTALL_DIR/$APP_ID.png" \
    "$INSTALL_DIR/app_icon.png"; do
    if [ -f "$candidate" ]; then
      icon_source="$candidate"
      break
    fi
  done

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

download_and_install() {
  tmp="${TMPDIR:-/tmp}/codewalk-install-$$"
  extract_dir="$tmp/extract"
  mkdir -p "$extract_dir"
  trap 'rm -rf "$tmp"' EXIT

  url="https://github.com/$REPO/releases/download/$version/$asset"
  info "Downloading $asset from $REPO ($version)"
  fetch "$url" > "$tmp/$asset" || fail "Failed to download $url"

  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR" "$BIN_DIR"

  tar -xzf "$tmp/$asset" -C "$extract_dir"
  cp -R "$extract_dir"/. "$INSTALL_DIR"/

  mac_app_bundle=""
  if [ "$platform" = "macos" ]; then
    install_macos_bundle || true
  fi

  if [ -z "$mac_app_bundle" ]; then
    cli_binary="$(find_cli_binary || true)"
    [ -n "$cli_binary" ] || fail "Could not find codewalk executable in extracted archive"
    ln -sf "$cli_binary" "$BIN_DIR/codewalk"
  fi

  integrate_linux_desktop
  printf '%s\n' "$version" > "$VERSION_FILE"
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

detect_platform
latest_release
detect_install_mode
download_and_install
print_done
