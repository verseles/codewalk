# V2 install script and distribution endpoints

- Source URL: https://opencode.ai/v2/install (served by https://github.com/anomalyco/opencode/blob/v2/services/www/src/pages/install.astro, which proxies https://raw.githubusercontent.com/anomalyco/opencode/v2/install)
- Fetched: 2026-10-02 (byte-identical to the `v2` branch `install` file at fetch time)
- Note: this is not a docs page; it is the official installer referenced by the Intro page (`curl -fsSL https://opencode.ai/v2/install | bash`). Saved verbatim because a managed-install client needs its exact behavior. The JSON blocks at the end are raw responses observed from the update/metadata endpoint the script itself calls (`https://opencode.ai/update/api/...`); that endpoint is not documented in the docs.

## Key facts extracted (all verifiable in the script below)

- Install dir: `$HOME/.opencode/bin` (same directory the V1 installer uses, so the V2 binary replaces the V1 binary).
- Supported `uname` combos: `linux-x64`, `linux-arm64`, `darwin-x64`, `darwin-arm64`, `windows-x64` (MINGW/MSYS/CYGWIN). `windows-arm64` is NOT accepted by this script even though npm/zip artifacts exist for it. Android/Termux is not special-cased (it would be treated as `linux-arm64`, glibc unless musl is detected).
- Variant selection: `-baseline` when x64 CPU lacks AVX2; `-musl` on Alpine or when `ldd --version` mentions musl; Rosetta-translated shells on Apple silicon get `arm64`.
- Version resolution: `GET https://opencode.ai/update/api/latest/cli/npm` → `version` + `package`; `--version <v>` / `VERSION=<v>` pins a version.
- Download: npm tarball `https://registry.npmjs.org/@opencode/cli-<target>/-/cli-<target>-<version>.tgz`, extracts `package/bin/opencode` (or `opencode.exe`). Fallback to `@opencode-ai/cli-<target>` only for pinned old versions.
- Also writes a legacy shim `opencode2` (`opencode2.cmd` on Windows) that execs `opencode`.
- Flags: `--version`, `--binary <path>`, `--no-modify-path`. Appends `export PATH=$HOME/.opencode/bin:$PATH` to the shell rc unless `--no-modify-path`. Adds to `$GITHUB_PATH` in GitHub Actions.
- Requires `curl` and `tar`.

## Script (verbatim)

```bash
#!/usr/bin/env bash
set -euo pipefail
APP=opencode
SOURCE_APP=opencode

MUTED='\033[0;2m'
RED='\033[0;31m'
ORANGE='\033[38;5;214m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
OpenCode Installer

Usage: install.sh [options]

Options:
    -h, --help              Display this help message
    -v, --version <version> Install a specific version (e.g., 0.0.0-beta-17236)
    -b, --binary <path>     Install from a local binary instead of downloading
        --no-modify-path    Don't modify shell config files (.zshrc, .bashrc, etc.)

Examples:
    curl -fsSL https://opencode.ai/v2/install | bash
    curl -fsSL https://opencode.ai/v2/install | bash -s -- --version 0.0.0-beta-17236
    ./install --binary /path/to/opencode
EOF
}

requested_version=${VERSION:-}
no_modify_path=false
binary_path=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            if [[ -n "${2:-}" ]]; then
                requested_version="$2"
                shift 2
            else
                echo -e "${RED}Error: --version requires a version argument${NC}"
                exit 1
            fi
            ;;
        -b|--binary)
            if [[ -n "${2:-}" ]]; then
                binary_path="$2"
                shift 2
            else
                echo -e "${RED}Error: --binary requires a path argument${NC}"
                exit 1
            fi
            ;;
        --no-modify-path)
            no_modify_path=true
            shift
            ;;
        *)
            echo -e "${ORANGE}Warning: Unknown option '$1'${NC}" >&2
            shift
            ;;
    esac
done

INSTALL_DIR=$HOME/.opencode/bin
mkdir -p "$INSTALL_DIR"

# If --binary is provided, skip all download/detection logic
if [ -n "$binary_path" ]; then
    if [ ! -f "$binary_path" ]; then
        echo -e "${RED}Error: Binary not found at ${binary_path}${NC}"
        exit 1
    fi
    specific_version="local"
else
    raw_os=$(uname -s)
    os=$(echo "$raw_os" | tr '[:upper:]' '[:lower:]')
    case "$raw_os" in
      Darwin*) os="darwin" ;;
      Linux*) os="linux" ;;
      MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    esac

    arch=$(uname -m)
    if [[ "$arch" == "aarch64" ]]; then
      arch="arm64"
    fi
    if [[ "$arch" == "x86_64" ]]; then
      arch="x64"
    fi

    if [ "$os" = "darwin" ] && [ "$arch" = "x64" ]; then
      rosetta_flag=$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)
      if [ "$rosetta_flag" = "1" ]; then
        arch="arm64"
      fi
    fi

    combo="$os-$arch"
    case "$combo" in
      linux-x64|linux-arm64|darwin-x64|darwin-arm64|windows-x64)
        ;;
      *)
        echo -e "${RED}Unsupported OS/Arch: $os/$arch${NC}"
        exit 1
        ;;
    esac

    is_musl=false
    if [ "$os" = "linux" ]; then
      if [ -f /etc/alpine-release ]; then
        is_musl=true
      fi

      if command -v ldd >/dev/null 2>&1; then
        if ldd --version 2>&1 | grep -qi musl; then
          is_musl=true
        fi
      fi
    fi

    needs_baseline=false
    if [ "$arch" = "x64" ]; then
      if [ "$os" = "linux" ]; then
        if ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
          needs_baseline=true
        fi
      fi

      if [ "$os" = "darwin" ]; then
        avx2=$(sysctl -n hw.optional.avx2_0 2>/dev/null || echo 0)
        if [ "$avx2" != "1" ]; then
          needs_baseline=true
        fi
      fi

      if [ "$os" = "windows" ]; then
        ps="(Add-Type -MemberDefinition \"[DllImport(\"\"kernel32.dll\"\")] public static extern bool IsProcessorFeaturePresent(int ProcessorFeature);\" -Name Kernel32 -Namespace Win32 -PassThru)::IsProcessorFeaturePresent(40)"
        out=""
        if command -v powershell.exe >/dev/null 2>&1; then
          out=$(powershell.exe -NoProfile -NonInteractive -Command "$ps" 2>/dev/null || true)
        elif command -v pwsh >/dev/null 2>&1; then
          out=$(pwsh -NoProfile -NonInteractive -Command "$ps" 2>/dev/null || true)
        fi
        out=$(echo "$out" | tr -d '\r' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
        if [ "$out" != "true" ] && [ "$out" != "1" ]; then
          needs_baseline=true
        fi
      fi
    fi

    target="$os-$arch"
    if [ "$needs_baseline" = "true" ]; then
      target="$target-baseline"
    fi
    if [ "$is_musl" = "true" ]; then
      target="$target-musl"
    fi

    if ! command -v tar >/dev/null 2>&1; then
        echo -e "${RED}Error: 'tar' is required but not installed.${NC}"
        exit 1
    fi

    package_scope="@opencode"
    if [ -z "$requested_version" ]; then
        metadata=$(curl -fsSL https://opencode.ai/update/api/latest/cli/npm || true)
        specific_version=$(echo "$metadata" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
        package=$(echo "$metadata" | sed -n 's/.*"package":"\([^"]*\)".*/\1/p')

        if [ -z "$specific_version" ] || [ -z "$package" ]; then
            echo -e "${RED}Failed to fetch version information${NC}"
            exit 1
        fi
        package_scope="${package%/cli}"
    else
        # Strip leading 'v' if present
        requested_version="${requested_version#v}"
        specific_version=$requested_version
    fi

    package_name="$package_scope/cli-$target"
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://registry.npmjs.org/$package_scope%2fcli-$target/$specific_version" || true)
    # Older clients install the minimum release before they can migrate package names.
    if [ "$http_status" = "404" ] && [ -n "$requested_version" ]; then
        package_name="@opencode-ai/cli-$target"
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://registry.npmjs.org/@opencode-ai%2fcli-$target/$specific_version" || true)
    fi
    if [ "$http_status" = "404" ]; then
        echo -e "${RED}Error: Version ${specific_version} is not available for $target${NC}"
        echo -e "${MUTED}Available versions: https://www.npmjs.com/package/$package_name?activeTab=versions${NC}"
        exit 1
    fi
    if [ "$http_status" != "200" ]; then
        echo -e "${RED}Failed to fetch package information${NC}"
        exit 1
    fi

    filename="cli-$target-$specific_version.tgz"
    url="https://registry.npmjs.org/$package_name/-/$filename"
    binary_name="$SOURCE_APP"
    if [ "$os" = "windows" ]; then
        binary_name="$SOURCE_APP.exe"
    fi
fi

print_message() {
    local level=$1
    local message=$2
    local color=""

    case $level in
        info) color="${NC}" ;;
        warning) color="${NC}" ;;
        error) color="${RED}" ;;
    esac

    echo -e "${color}${message}${NC}"
}

check_version() {
    if command -v "$APP" >/dev/null 2>&1; then
        opencode_path=$(which "$APP")

        ## Check the installed version
        installed_version=$("$APP" --version 2>/dev/null || echo "")
        installed_version="${installed_version##* }"
        installed_version="${installed_version#v}"

        print_message info "${MUTED}Installed version: ${NC}$installed_version."
    fi
}

unbuffered_sed() {
    if echo | sed -u -e "" >/dev/null 2>&1; then
        sed -nu "$@"
    elif echo | sed -l -e "" >/dev/null 2>&1; then
        sed -nl "$@"
    else
        local pad="$(printf "\n%512s" "")"
        sed -ne "s/$/\\${pad}/" "$@"
    fi
}

print_progress() {
    local bytes="$1"
    local length="$2"
    [ "$length" -gt 0 ] || return 0

    local width=50
    local percent=$(( bytes * 100 / length ))
    [ "$percent" -gt 100 ] && percent=100
    local on=$(( percent * width / 100 ))
    local off=$(( width - on ))

    local filled=$(printf "%*s" "$on" "")
    filled=${filled// /■}
    local empty=$(printf "%*s" "$off" "")
    empty=${empty// /･}

    printf "\r${ORANGE}%s%s %3d%%${NC}" "$filled" "$empty" "$percent" >&4
}

download_with_progress() {
    local url="$1"
    local output="$2"

    if [ -t 2 ]; then
        exec 4>&2
    else
        exec 4>/dev/null
    fi

    local tmp_dir=${TMPDIR:-/tmp}
    local basename="${tmp_dir}/opencode_install_$$"
    local tracefile="${basename}.trace"

    rm -f "$tracefile"
    mkfifo "$tracefile"

    # Hide cursor
    printf "\033[?25l" >&4

    trap "trap - RETURN; rm -f \"$tracefile\"; printf '\033[?25h' >&4; exec 4>&-" RETURN

    (
        curl --trace-ascii "$tracefile" -fsL -o "$output" "$url"
    ) &
    local curl_pid=$!

    unbuffered_sed \
        -e 'y/ACDEGHLNORTV/acdeghlnortv/' \
        -e '/^0000: content-length:/p' \
        -e '/^<= recv data/p' \
        "$tracefile" | \
    {
        local length=0
        local bytes=0

        while IFS=" " read -r -a line; do
            [ "${#line[@]}" -lt 2 ] && continue
            local tag="${line[0]} ${line[1]}"

            if [ "$tag" = "0000: content-length:" ]; then
                length="${line[2]}"
                length=$(echo "$length" | tr -d '\r')
                bytes=0
            elif [ "$tag" = "<= recv" ]; then
                local size="${line[3]}"
                bytes=$(( bytes + size ))
                if [ "$length" -gt 0 ]; then
                    print_progress "$bytes" "$length"
                fi
            fi
        done
    }

    wait $curl_pid
    local ret=$?
    echo "" >&4
    return $ret
}

download_and_install() {
    print_message info "\n${MUTED}Installing ${NC}$APP ${MUTED}version: ${NC}$specific_version"
    local tmp_dir="${TMPDIR:-/tmp}/opencode_install_$$"
    mkdir -p "$tmp_dir"

    if [[ "$os" == "windows" ]] || ! [ -t 2 ] || ! download_with_progress "$url" "$tmp_dir/$filename"; then
        # Fallback to standard curl on Windows, non-TTY environments, or if custom progress fails
        curl -f -# -L -o "$tmp_dir/$filename" "$url"
    fi

    tar -xzf "$tmp_dir/$filename" -C "$tmp_dir"
    local installed_binary="$APP"
    if [ "$os" = "windows" ]; then
        installed_binary="$APP.exe"
    fi
    mv "$tmp_dir/package/bin/$binary_name" "$INSTALL_DIR/$installed_binary"
    chmod 755 "$INSTALL_DIR/$installed_binary"
    rm -rf "$tmp_dir"
}

install_from_binary() {
    print_message info "\n${MUTED}Installing ${NC}$APP ${MUTED}from: ${NC}$binary_path"
    local installed_binary="$APP"
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) installed_binary="$APP.exe" ;;
    esac
    cp "$binary_path" "$INSTALL_DIR/$installed_binary"
    chmod 755 "$INSTALL_DIR/$installed_binary"
}

install_legacy_shim() {
    local shim_os="${os:-}"
    if [[ -z "$shim_os" ]]; then
        case "$(uname -s)" in
            MINGW*|MSYS*|CYGWIN*) shim_os="windows" ;;
        esac
    fi
    rm -f "$INSTALL_DIR/opencode2" "$INSTALL_DIR/opencode2.exe" "$INSTALL_DIR/opencode2.cmd"
    if [[ "$shim_os" == "windows" ]]; then
        cat > "$INSTALL_DIR/opencode2.cmd" <<'EOF'
@echo off
"%~dp0opencode.exe" %*
exit /b %errorlevel%
EOF
        return
    fi
    cat > "$INSTALL_DIR/opencode2" <<'EOF'
#!/bin/sh
exec "$(dirname "$0")/opencode" "$@"
EOF
    chmod 755 "$INSTALL_DIR/opencode2"
}

if [ -n "$binary_path" ]; then
    install_from_binary
else
    check_version
    download_and_install
fi
install_legacy_shim


add_to_path() {
    local config_file=$1
    local command=$2

    if grep -Fxq "$command" "$config_file"; then
        print_message info "Command already exists in $config_file, skipping write."
    elif [[ -w $config_file ]]; then
        echo -e "\n# opencode" >> "$config_file"
        echo "$command" >> "$config_file"
        print_message info "${MUTED}Successfully added ${NC}opencode ${MUTED}to \$PATH in ${NC}$config_file"
    else
        print_message warning "Manually add the directory to $config_file (or similar):"
        print_message info "  $command"
    fi
}

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

current_shell=$(basename "$SHELL")
case $current_shell in
    fish)
        config_files="$HOME/.config/fish/config.fish"
    ;;
    zsh)
        config_files="${ZDOTDIR:-$HOME}/.zshrc ${ZDOTDIR:-$HOME}/.zshenv $XDG_CONFIG_HOME/zsh/.zshrc $XDG_CONFIG_HOME/zsh/.zshenv"
    ;;
    bash)
        config_files="$HOME/.bashrc $HOME/.bash_profile $HOME/.profile $XDG_CONFIG_HOME/bash/.bashrc $XDG_CONFIG_HOME/bash/.bash_profile"
    ;;
    ash)
        config_files="$HOME/.ashrc $HOME/.profile /etc/profile"
    ;;
    sh)
        config_files="$HOME/.ashrc $HOME/.profile /etc/profile"
    ;;
    *)
        # Default case if none of the above matches
        config_files="$HOME/.bashrc $HOME/.bash_profile $XDG_CONFIG_HOME/bash/.bashrc $XDG_CONFIG_HOME/bash/.bash_profile"
    ;;
esac

if [[ "$no_modify_path" != "true" ]]; then
    config_file=""
    for file in $config_files; do
        if [[ -f $file ]]; then
            config_file=$file
            break
        fi
    done

    if [[ -z $config_file ]]; then
        print_message warning "No config file found for $current_shell. You may need to manually add to PATH:"
        print_message info "  export PATH=$INSTALL_DIR:\$PATH"
    elif [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        case $current_shell in
            fish)
                add_to_path "$config_file" "fish_add_path $INSTALL_DIR"
            ;;
            zsh)
                add_to_path "$config_file" "export PATH=$INSTALL_DIR:\$PATH"
            ;;
            bash)
                add_to_path "$config_file" "export PATH=$INSTALL_DIR:\$PATH"
            ;;
            ash)
                add_to_path "$config_file" "export PATH=$INSTALL_DIR:\$PATH"
            ;;
            sh)
                add_to_path "$config_file" "export PATH=$INSTALL_DIR:\$PATH"
            ;;
            *)
                export PATH=$INSTALL_DIR:$PATH
                print_message warning "Manually add the directory to $config_file (or similar):"
                print_message info "  export PATH=$INSTALL_DIR:\$PATH"
            ;;
        esac
    fi
fi

if [ -n "${GITHUB_ACTIONS-}" ] && [ "${GITHUB_ACTIONS}" == "true" ]; then
    echo "$INSTALL_DIR" >> $GITHUB_PATH
    print_message info "Added $INSTALL_DIR to \$GITHUB_PATH"
fi

echo -e ""
echo -e "${MUTED}                    ${NC}             ▄     "
echo -e "${MUTED}█▀▀█ █▀▀█ █▀▀█ █▀▀▄ ${NC}█▀▀▀ █▀▀█ █▀▀█ █▀▀█"
echo -e "${MUTED}█░░█ █░░█ █▀▀▀ █░░█ ${NC}█░░░ █░░█ █░░█ █▀▀▀"
echo -e "${MUTED}▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀  ▀ ${NC}▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀"
echo -e ""
echo -e ""
echo -e "${MUTED}OpenCode includes free models, to start:${NC}"
echo -e ""
echo -e "cd <project>  ${MUTED}# Open directory${NC}"
echo -e "opencode      ${MUTED}# Run command${NC}"
echo -e ""
echo -e "${MUTED}For more information visit ${NC}https://opencode.ai/v2/docs"
echo -e ""
echo -e ""
```

## Observed metadata endpoint responses (2026-10-02, raw, pretty-printed)

### `GET https://opencode.ai/update/api/latest/cli/npm` (at time of first fetch; later in the session it reported 2.0.22)

```json
{
    "channel": "latest",
    "name": "cli",
    "distribution": "npm",
    "version": "2.0.21",
    "metadata": {
        "package": "@opencode/cli",
        "github": {
            "sha": "f46fa72a9285a0e8479e25d400f7026bfd8fe5c8",
            "run_id": "36785870631",
            "run_attempt": "1",
            "actor": "rekram1-node",
            "ref": "refs/heads/v2"
        }
    },
    "active": true,
    "minimum": false,
    "time_created": 1790809179138,
    "time_updated": 1790809179138
}
```

### `GET https://opencode.ai/update/api/latest/cli`

```json
{
    "channel": "latest",
    "name": "cli",
    "artifacts": [
        {
            "channel": "latest",
            "name": "cli",
            "distribution": "aur",
            "version": "2.0.21",
            "metadata": {
                "package": "opencode-beta",
                "github": {
                    "sha": "f46fa72a9285a0e8479e25d400f7026bfd8fe5c8",
                    "run_id": "36785870631",
                    "run_attempt": "1",
                    "actor": "rekram1-node",
                    "ref": "refs/heads/v2"
                }
            },
            "active": true,
            "minimum": false,
            "time_created": 1790809201775,
            "time_updated": 1790809201775
        },
        {
            "channel": "latest",
            "name": "cli",
            "distribution": "homebrew",
            "version": "2.0.21",
            "metadata": {
                "package": "anomalyco/tap/opencode-v2",
                "github": {
                    "sha": "f46fa72a9285a0e8479e25d400f7026bfd8fe5c8",
                    "run_id": "36785870631",
                    "run_attempt": "1",
                    "actor": "rekram1-node",
                    "ref": "refs/heads/v2"
                }
            },
            "active": true,
            "minimum": false,
            "time_created": 1790809204791,
            "time_updated": 1790809204791
        },
        {
            "channel": "latest",
            "name": "cli",
            "distribution": "npm",
            "version": "2.0.21",
            "metadata": {
                "package": "@opencode/cli",
                "github": {
                    "sha": "f46fa72a9285a0e8479e25d400f7026bfd8fe5c8",
                    "run_id": "36785870631",
                    "run_attempt": "1",
                    "actor": "rekram1-node",
                    "ref": "refs/heads/v2"
                }
            },
            "active": true,
            "minimum": false,
            "time_created": 1790809179138,
            "time_updated": 1790809179138
        },
        {
            "channel": "latest",
            "name": "cli",
            "distribution": "opencode",
            "version": "2.0.21",
            "metadata": {
                "files": {
                    "opencode-linux-arm64.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-linux-arm64.tar.gz",
                        "sha256": "16c354810ef5844da2971b7dd103ccd18677bc1489755f788ac09cab72b0824d",
                        "size": 89283658
                    },
                    "opencode-linux-x64-baseline.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-linux-x64-baseline.tar.gz",
                        "sha256": "8ef5c24debedefbb7b5e13b807699c8b2b8097d5ca703184188cefd64e5f3472",
                        "size": 90441098
                    },
                    "opencode-linux-x64.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-linux-x64.tar.gz",
                        "sha256": "d613a5d534e50d744f983672fa006e6f12179feb43a0ba14589d796cdc93983b",
                        "size": 90440866
                    },
                    "opencode-windows-x64-baseline.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-windows-x64-baseline.zip",
                        "sha256": "24dc2e3281dc7b8e4408714f0b3038117735877b906900cbd58a4372237dbe00",
                        "size": 92689247
                    },
                    "opencode-darwin-x64-baseline.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-darwin-x64-baseline.zip",
                        "sha256": "3aa5f9b0e5108f4fb641b5e32ab2f573b92f6b7cfb9c72376a4d059d80b6e6e8",
                        "size": 82646948
                    },
                    "opencode-windows-arm64.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-windows-arm64.zip",
                        "sha256": "0dea9570af67f9bde6461818f8529ac23de88aeda35fb225bd4c33cb2545a736",
                        "size": 88155418
                    },
                    "opencode-darwin-arm64.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-darwin-arm64.zip",
                        "sha256": "41caebd166aa1a72bb85c2e9a3ca81c6ff3170af1cbef8b7b07f92f19adb6840",
                        "size": 77632443
                    },
                    "opencode-linux-x64-musl.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-linux-x64-musl.tar.gz",
                        "sha256": "19bd871cf5406e9564c4c0169bc2defe86ffb9507081a3d88966993111bfccd2",
                        "size": 89820672
                    },
                    "opencode-linux-x64-baseline-musl.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-linux-x64-baseline-musl.tar.gz",
                        "sha256": "5210d0b17f08c1e375d15793b89ada14e19084ee2cdf444ead64b76160a84c9a",
                        "size": 89820639
                    },
                    "opencode-linux-arm64-musl.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-linux-arm64-musl.tar.gz",
                        "sha256": "2b91209518e7ee8b4e21022fa4a6f93b2f2514897cf125b0caf85979c997a97a",
                        "size": 88452572
                    },
                    "opencode-darwin-x64.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-darwin-x64.zip",
                        "sha256": "6790e125af2b31c25e7bac8f42e527d37e4519c802bbf2767f764146acc5a16d",
                        "size": 82647131
                    },
                    "opencode-windows-x64.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-windows-x64.zip",
                        "sha256": "8a34ead1de25316314cfcb3911457f88c42e7d9a17214ac378d33379921b3d63",
                        "size": 92689190
                    }
                },
                "github": {
                    "sha": "f46fa72a9285a0e8479e25d400f7026bfd8fe5c8",
                    "run_id": "36785870631",
                    "run_attempt": "1",
                    "actor": "rekram1-node",
                    "ref": "refs/heads/v2"
                }
            },
            "active": true,
            "minimum": false,
            "time_created": 1790809179291,
            "time_updated": 1790809179291
        }
    ]
}
```

### `GET https://opencode.ai/update/api/latest/desktop`

```json
{
    "channel": "latest",
    "name": "desktop",
    "artifacts": [
        {
            "channel": "latest",
            "name": "desktop",
            "distribution": "opencode",
            "version": "2.0.21",
            "metadata": {
                "files": {
                    "opencode-desktop-linux-aarch64.rpm": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-aarch64.rpm",
                        "sha256": "453e6e19b7e532b14f38dff0b2e6a3299aebecb81372dd9fec132edfd1f20831",
                        "size": 159153601
                    },
                    "opencode-desktop-linux-amd64.deb": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-amd64.deb",
                        "sha256": "548ac5200a51daf4a8204e735fb5aec849e2a3ad0949c0c4fd18a902b9a7980a",
                        "size": 197558032
                    },
                    "opencode-desktop-linux-arm64.AppImage": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-arm64.AppImage",
                        "sha256": "6a21ee304ed226ca9046ed4b83f6f41f2a4ee73c10f1ba192097d0a4fe459a53",
                        "size": 245039042
                    },
                    "opencode-desktop-linux-arm64.deb": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-arm64.deb",
                        "sha256": "43ee67d10b3500d3b0195329f07511286dc309b6d1b221e836ee587532f85718",
                        "size": 189767584
                    },
                    "opencode-desktop-linux-x86_64.AppImage": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-x86_64.AppImage",
                        "sha256": "32b483c41cab4241b9ef7782fe0cd4f8f1c75c42e7dd42187514ac7cc79929b1",
                        "size": 244914139
                    },
                    "opencode-desktop-linux-x86_64.rpm": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-x86_64.rpm",
                        "sha256": "29d2ba769f59f7773101c742fc1a9994515035c1bcacbdf544491d6bdcb82afd",
                        "size": 166755393
                    },
                    "opencode-desktop-mac-arm64.app.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.app.tar.gz",
                        "sha256": "a774693e58b9198e41c3586ce13230ff55828e67658e0440dc57f7ec3a1704a4",
                        "size": 235345937
                    },
                    "opencode-desktop-mac-arm64.dmg": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.dmg",
                        "sha256": "a15562d36ab83b424ca43d6297772762faff8b14103c234789e996fa1572ae2d",
                        "size": 234589355
                    },
                    "opencode-desktop-mac-arm64.dmg.blockmap": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.dmg.blockmap",
                        "sha256": "e965dd23218015adc1da40edd0c1ec0e44e7fca3dfc6f5206ea9367062a90acf",
                        "size": 245572
                    },
                    "opencode-desktop-mac-arm64.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.zip",
                        "sha256": "a3d2d874d0f87f6f33dc50b0248ed618a86f8fa18985c25618270c80013ea3fa",
                        "size": 226205577
                    },
                    "opencode-desktop-mac-arm64.zip.blockmap": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.zip.blockmap",
                        "sha256": "3ccc52be4d225a9e4ff850baec2aa013ca9c125aa1cf43bebe38ed48e6f191fe",
                        "size": 238699
                    },
                    "opencode-desktop-mac-x64.app.tar.gz": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.app.tar.gz",
                        "sha256": "246d6b61f8819683bea16180bdbfdcec65375a910b3a982650d405c78fc1785d",
                        "size": 247279490
                    },
                    "opencode-desktop-mac-x64.dmg": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.dmg",
                        "sha256": "560f6cd567abed7e03bced0cbad2720d70b3c8cd5c5ff3b68c9d63198e1ae33d",
                        "size": 246232485
                    },
                    "opencode-desktop-mac-x64.dmg.blockmap": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.dmg.blockmap",
                        "sha256": "2344d27661c03f0dba1a30787ffba940a39ed4da500f49f97f7529c79f974bd3",
                        "size": 255885
                    },
                    "opencode-desktop-mac-x64.zip": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.zip",
                        "sha256": "5ce0b4bc5cd0ebcd727d2fe48d49d88862238e2966fec96f2b5e1c1e1f3f39fc",
                        "size": 237833238
                    },
                    "opencode-desktop-mac-x64.zip.blockmap": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.zip.blockmap",
                        "sha256": "40fe025b8a16573a3ca88b5684dea6e574648c5eb4aaf54f4cb43442c17d2fd3",
                        "size": 251238
                    },
                    "opencode-desktop-win-arm64.exe": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-win-arm64.exe",
                        "sha256": "80ab25f6c44db4199e4e31bf64a7344afe75328aecaa704f3c09ab295f371910",
                        "size": 206018296
                    },
                    "opencode-desktop-win-arm64.exe.blockmap": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-win-arm64.exe.blockmap",
                        "sha256": "41aa56817dea69dd5cf0eec5847c301ed4c64df6633057c39838b66e7d027b59",
                        "size": 217706
                    },
                    "opencode-desktop-win-x64.exe": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-win-x64.exe",
                        "sha256": "1b3323484a9d258ed277d6746ffdcffa1757faad83430edbec6ae8458ce0eacc",
                        "size": 216381304
                    },
                    "opencode-desktop-win-x64.exe.blockmap": {
                        "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-win-x64.exe.blockmap",
                        "sha256": "52a1e53e14d62bee6387c899925859b4f172c6d8d917cbc2cbf461dd996b4689",
                        "size": 227256
                    }
                },
                "manifests": {
                    "desktop.yml": {
                        "files": [
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-win-arm64.exe",
                                "sha512": "n7fWbIPRBXvUd19WaY7oVHSr2n48MwJabCJE/+VyWrAv6r07gxeVBshhbQ9+x/ddbEjZPIWECcI8ze3lpvn1hw==",
                                "size": 206018296
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-win-x64.exe",
                                "sha512": "Y4VspPIl1Aed842Ntc4LYbngEewENXnKBwnwa66UME7JjmGeJOo3STPh5w833obWpa+Ay8FIVev5gr3MexREAA==",
                                "size": 216381304
                            }
                        ],
                        "releaseDate": "2026-09-30T22:48:10.173Z"
                    },
                    "desktop-mac.yml": {
                        "files": [
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.zip",
                                "sha512": "owQ9aM3uz/0+0clm9iGJJl/94zeFlSbiGCxIx8r9XNFbRo2HlKmKft1CERcDCiTVf29e9V4Ta4EXSVjBNr44mg==",
                                "size": 226205577
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-arm64.dmg",
                                "sha512": "owQ9aM3uz/0+0clm9iGJJl/94zeFlSbiGCxIx8r9XNFbRo2HlKmKft1CERcDCiTVf29e9V4Ta4EXSVjBNr44mg==",
                                "size": 234589355
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.zip",
                                "sha512": "2sWg1lgWqzI1sjFYFl4Z4W6ucMltgTQz3RtNhTQKnCP5dNWhFg6EmB0X/nsntDUDwgpsF8KCSc47mh1oCIX74w==",
                                "size": 237833238
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-mac-x64.dmg",
                                "sha512": "2sWg1lgWqzI1sjFYFl4Z4W6ucMltgTQz3RtNhTQKnCP5dNWhFg6EmB0X/nsntDUDwgpsF8KCSc47mh1oCIX74w==",
                                "size": 246232485
                            }
                        ],
                        "releaseDate": "2026-09-30T22:49:28.031Z"
                    },
                    "desktop-linux.yml": {
                        "files": [
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-x86_64.AppImage",
                                "sha512": "q1QgHDLBRBv5+5CU+U5W0OwPQZ7S71zU/MQ5h7y3MGMVsB1OmIeJI5hC87hST1cTQJQrDsyHWdFvIxkYBiK8xg==",
                                "size": 244914139,
                                "blockMapSize": 255983
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-amd64.deb",
                                "sha512": "8PUyIjQSoP91ASvGXhmC1NR12SYHVhjB2oKMeqI2ceGPFJrqku7joReEGyWn2eAkabnHa6F1VM7NAg2BiD8qqQ==",
                                "size": 197558032
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-x86_64.rpm",
                                "sha512": "q1QgHDLBRBv5+5CU+U5W0OwPQZ7S71zU/MQ5h7y3MGMVsB1OmIeJI5hC87hST1cTQJQrDsyHWdFvIxkYBiK8xg==",
                                "size": 166755393
                            }
                        ],
                        "releaseDate": "2026-09-30T22:42:22.905Z"
                    },
                    "desktop-linux-arm64.yml": {
                        "files": [
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-arm64.AppImage",
                                "sha512": "unn7Qvs8hUm4He/vLZ+VV/RLy0Wx4w9hiO36BK41ATNwtotVUQzEBwF9A/F/eWn/bH7bAjGqXb0M/He0X79hTQ==",
                                "size": 245039042,
                                "blockMapSize": 256782
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-arm64.deb",
                                "sha512": "lrhM4f0C2j+/RaomZkiCpo/RoHpM7594GR0tXDnx9vInfx1ctOnKcsVJ9LqX65qGy6qAiss26iVSq+ep8uEa/Q==",
                                "size": 189767584
                            },
                            {
                                "url": "https://opencode.ai/files/bin/2.0.21/opencode-desktop-linux-aarch64.rpm",
                                "sha512": "unn7Qvs8hUm4He/vLZ+VV/RLy0Wx4w9hiO36BK41ATNwtotVUQzEBwF9A/F/eWn/bH7bAjGqXb0M/He0X79hTQ==",
                                "size": 159153601
                            }
                        ],
                        "releaseDate": "2026-09-30T22:49:58.919Z"
                    }
                },
                "github": {
                    "sha": "f46fa72a9285a0e8479e25d400f7026bfd8fe5c8",
                    "run_id": "36785870631",
                    "run_attempt": "1",
                    "actor": "rekram1-node",
                    "ref": "refs/heads/v2"
                }
            },
            "active": true,
            "minimum": false,
            "time_created": 1790809363188,
            "time_updated": 1790809363188
        }
    ]
}
```
