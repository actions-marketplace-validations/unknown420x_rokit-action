#!/usr/bin/env bash

# ===================================================================================
# Credits:     Rokit project made by @rojo-rbx, modified by @CompeyDev and
#              now modified to be more safe and fast by me
# Description: Made to use rokit via github actions, this includes fuzzy
#              matching, automatic cleanup, and instead of using python, uses jq
#              who is faster and written in C
# ===================================================================================

#
# License
# =======
# The original script was licensed under the MIT License.

#   Copyright (c) 2022 ok-nick
#   Copyright (c) 2024 CompeyDev
#   Copyright (c) unknown420x 2026

#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#   
#   The above copyright notice and this permission notice shall be included in all
#   copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#   SOFTWARE.

set -euo pipefail

# --- Configuration ---
readonly PROGRAM_NAME="rokit"
readonly REPOSITORY="rojo-rbx/rokit"
readonly GITHUB_API_VERSION="2026-03-10"

# Globals for signal tracking and cleanup
TMP_ZIP=""
TMP_BIN=""

# --- Helpers ---
log_info() {
    printf "\n[INFO] %s\n" "$1"
}

log_warn() {
    printf "\n[WARNING] %s\n" "$1" >&2
}

log_error() {
    printf "\n[ERROR] %s\n" "$1" >&2
    exit 1
}

# Cleanup function: removes all temporary files on exit, interrupt or terminations
cleanup() {
    local exit_code=$?
    [ -n "$TMP_ZIP" ] && [ -f "$TMP_ZIP" ] && rm -f "$TMP_ZIP"
    [ -n "$TMP_BIN" ] && [ -f "$TMP_BIN" ] && rm -f "$TMP_BIN"
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Check system has required binaries and permissions
check_environment() {
    local -r dependencies=(curl unzip uname tr jq)
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Required command '$dep' is not installed or available."
        fi
    done

    if [ ! -w "." ]; then
        log_error "Current directory is not writable. Please run in a directory with write permissions."
    fi
}

# Detect OS and Architecture (Preferible to use linux ubuntu-latest)
detect_platform() {
    local os arch
    
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin) OS="macos" ;;
        linux)  OS="linux" ;;
        cygwin*|mingw*|msys*) OS="windows" ;;
        *) log_error "Unsupported operating system: $os" ;;
    esac

    arch="$(uname -m)"
    case "$arch" in
        x86_64|x86-64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="aarch64" ;;
        *) log_error "Unsupported architecture: $arch" ;;
    esac
}

# Set API endpoint and version pattern
resolve_version_and_endpoint() {
    VERSION_PATTERN="[0-9]*\\.[0-9]*\\.[0-9]*"
    API_URL="https://api.github.com/repos/$REPOSITORY/releases/latest"

    if [ -n "${ROKIT_VERSION:-}" ]; then
        local input_version="${ROKIT_VERSION#v}"
        local dot_count="${input_version//[^.]}"
        dot_count="${#dot_count}"

        if [ "$dot_count" -eq 0 ]; then
            VERSION_PATTERN="${input_version}\\.[0-9]*\\.[0-9]*"
            API_URL="https://api.github.com/repos/$REPOSITORY/releases"
            log_info "[1 / 3] Looking for latest $PROGRAM_NAME matching v${input_version}.x.x"
        elif [ "$dot_count" -eq 1 ]; then
            VERSION_PATTERN="${input_version}\\.[0-9]*"
            API_URL="https://api.github.com/repos/$REPOSITORY/releases"
            log_info "[1 / 3] Looking for latest $PROGRAM_NAME matching v${input_version}.x"
        else
            VERSION_PATTERN="$input_version"
            API_URL="https://api.github.com/repos/$REPOSITORY/releases/tags/v$input_version"
            log_info "[1 / 3] Looking for $PROGRAM_NAME release tag 'v$input_version'"
        fi
    else
        log_info "[1 / 3] Looking for latest $PROGRAM_NAME release"
    fi
}

# Safely extract asset ID and name using jq (fast & native :D)
parse_release_asset() {
    local json_data="$1"
    local file_pattern="$2"

    echo "$json_data" | jq -r --arg pattern "$file_pattern" '
        (. | if type=="array" then . else [.] end)[]
        | .assets[]?
        | select(.name | test($pattern))
        | "\(.id)\n\(.name)"
    ' | head -n 2
}

# --- Main Execution ---

main() {
    check_environment

    if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
        log_warn "Unsupported shell environment. Execution may behave unexpectedly."
    fi

    if [ -n "${GITHUB_PAT:-}" ]; then
        log_info "Using provided GitHub Personal Access Token (GITHUB_PAT)."
    fi

    detect_platform
    resolve_version_and_endpoint

    local file_pattern="${PROGRAM_NAME}-${VERSION_PATTERN}-${OS}-${ARCH}\\.zip"

    local -a curl_headers=(
        -H "X-GitHub-Api-Version: $GITHUB_API_VERSION"
    )
    if [ -n "${GITHUB_PAT:-}" ]; then
        curl_headers+=(-H "Authorization: token $GITHUB_PAT")
    fi

    # Query API
    local release_json
    release_json="$(curl --proto '=https' --tlsv1.2 -sSf "$API_URL" "${curl_headers[@]}")"

    if [ -z "$release_json" ] || [[ "$release_json" == *"Not Found"* ]]; then
        log_error "Release metadata could not be retrieved. Check connection or version string."
    fi

    # Parse Asset safely using jq (modified for instead of using bad python use jq)
    local asset_output
    asset_output="$(parse_release_asset "$release_json" "$file_pattern")"
    
    local asset_id asset_name
    asset_id="$(echo "$asset_output" | sed -n '1p')"
    asset_name="$(echo "$asset_output" | sed -n '2p')"

    if [ -z "$asset_id" ] || [ -z "$asset_name" ]; then
        log_error "Failed to locate an asset matching pattern '$file_pattern'."
    fi

    # Download the Rokit binary
    log_info "[2 / 3] Downloading '$asset_name'"
    local download_url="https://api.github.com/repos/$REPOSITORY/releases/assets/$asset_id"
    TMP_ZIP="${asset_name%.*}.zip"

    local -a download_headers=("${curl_headers[@]}" -H "Accept: application/octet-stream")
    curl --proto '=https' --tlsv1.2 -L -o "$TMP_ZIP" -sSf "$download_url" "${download_headers[@]}"

    if [ ! -f "$TMP_ZIP" ]; then
        log_error "Failed to write archive '$TMP_ZIP' to disk."
    fi

    # Unpack Rokit
    TMP_BIN="$PROGRAM_NAME"
    if [ "$OS" = "windows" ]; then
        TMP_BIN="${TMP_BIN}.exe"
    fi

    unzip -o -q "$TMP_ZIP" "$TMP_BIN" -d .
    
    # Delete the zip
    rm -f "$TMP_ZIP"
    TMP_ZIP=""

    if [ ! -f "$TMP_BIN" ]; then
        log_error "Extracted binary '$TMP_BIN' was not found inside the archive :C."
    fi

    # Run Installation
    log_info "[3 / 3] Running $PROGRAM_NAME installation\n"
    if [ "$OS" != "windows" ]; then
        chmod +x "$TMP_BIN"
    fi

    ./"$TMP_BIN" self-install

    # Clean the downloaded binary
    rm -f "$TMP_BIN"
    TMP_BIN=""
}

main "$@"