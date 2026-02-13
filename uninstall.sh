#!/usr/bin/env sh
set -eu

# CodeWalk uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/uninstall.sh | sh

APP_ID="com.verseles.codewalk"
APP_NAME="CodeWalk"
XDG_DATA_HOME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="${XDG_DATA_HOME_DIR}/codewalk"
BIN_DIR="$HOME/.local/bin"
LINUX_DESKTOP_PATH="${XDG_DATA_HOME_DIR}/applications/${APP_ID}.desktop"
LINUX_ICON_PATH="${XDG_DATA_HOME_DIR}/icons/hicolor/512x512/apps/${APP_ID}.png"
MAC_APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"

info() { printf '%s\n' "$*"; }

remove_path() {
  target="$1"
  if [ -L "$target" ] || [ -e "$target" ]; then
    rm -rf "$target"
    info "Removed: $target"
    removed_any=1
  fi
}

detect_platform() {
  os="$(uname -s)"
  case "$os" in
    Linux) platform="linux" ;;
    Darwin) platform="macos" ;;
    *)
      info "Unsupported OS: $os"
      info "Nothing to uninstall."
      exit 0
      ;;
  esac
}

update_linux_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${XDG_DATA_HOME_DIR}/applications" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "${XDG_DATA_HOME_DIR}/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

removed_any=0
detect_platform

remove_path "$INSTALL_DIR"
remove_path "$BIN_DIR/codewalk"

if [ "$platform" = "linux" ]; then
  remove_path "$LINUX_DESKTOP_PATH"
  remove_path "$LINUX_ICON_PATH"
  update_linux_caches
fi

if [ "$platform" = "macos" ]; then
  remove_path "$MAC_APP_BUNDLE"
fi

if [ "$removed_any" -eq 1 ]; then
  info ""
  info "CodeWalk uninstall finished."
else
  info "No CodeWalk installation artifacts found."
fi
