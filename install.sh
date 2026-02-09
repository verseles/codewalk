#!/usr/bin/env sh
set -eu

# CodeWalk installer
# Usage: curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | sh

REPO="${CODEWALK_REPO:-helio/codewalk}"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/codewalk"
BIN_DIR="$HOME/.local/bin"

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

  case "$arch" in
    x86_64|amd64) arch_tag="x64" ;;
    aarch64|arm64) arch_tag="arm64" ;;
    *) fail "Unsupported architecture: $arch" ;;
  esac

  asset="codewalk-${platform}-${arch_tag}.tar.gz"
}

latest_release() {
  json="$(fetch "https://api.github.com/repos/$REPO/releases/latest")"
  version="$(printf '%s' "$json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$version" ] || fail "Could not determine latest release for $REPO"
}

download_and_install() {
  tmp="${TMPDIR:-/tmp}/codewalk-install-$$"
  mkdir -p "$tmp"
  trap 'rm -rf "$tmp"' EXIT

  url="https://github.com/$REPO/releases/download/$version/$asset"
  info "Downloading $asset from $REPO ($version)"
  fetch "$url" > "$tmp/$asset" || fail "Failed to download $url"

  mkdir -p "$INSTALL_DIR" "$BIN_DIR"
  tar -xzf "$tmp/$asset" -C "$INSTALL_DIR"

  if [ -x "$INSTALL_DIR/codewalk" ]; then
    ln -sf "$INSTALL_DIR/codewalk" "$BIN_DIR/codewalk"
  elif [ -x "$INSTALL_DIR/bin/codewalk" ]; then
    ln -sf "$INSTALL_DIR/bin/codewalk" "$BIN_DIR/codewalk"
  else
    fail "Could not find codewalk executable in extracted archive"
  fi
}

print_done() {
  info ""
  info "CodeWalk installed to $INSTALL_DIR"
  info "Binary link: $BIN_DIR/codewalk"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      info "Add to PATH if needed:"
      info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
      ;;
  esac
  info "Run: codewalk"
}

detect_platform
latest_release
download_and_install
print_done
