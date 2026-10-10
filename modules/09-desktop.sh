#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Desktop applications and GNOME extensions"

# Google Chrome
if ! command_exists google-chrome; then
    CHROME_TMP="$(mktemp -d)"
    curl -fsSL \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o "${CHROME_TMP}/google-chrome.deb"

    sudo apt-get install -y "${CHROME_TMP}/google-chrome.deb"
    rm -rf "${CHROME_TMP}"
fi

# Ulauncher
if ! command_exists ulauncher; then
    if ! command_exists add-apt-repository; then
        install_apt_packages software-properties-common
    fi

    sudo add-apt-repository -y ppa:agornostal/ulauncher
    sudo apt-get update
    install_apt_packages ulauncher
fi

# TickTick: official download is intentionally not automated because the
# vendor's desktop download URL can change.
if command_exists xdg-open; then
    log_info "TickTick desktop installer is available at: https://ticktick.com/download"
    log_info "Open it manually if you want TickTick."
fi

# Vitals dependencies
install_apt_packages \
    gir1.2-gda-5.0 \
    gir1.2-gsound-1.0 \
    gir1.2-gtop-2.0 \
    lm-sensors

if ! command_exists gnome-extensions; then
    log_warn "gnome-extensions command not available; skipping GNOME extensions."
else
    SHELL_VERSION="$(gnome-shell --version | awk '{print $3}')"

    install_gnome_extension() {
        local uuid="$1"
        local name="$2"
        local info_url
        local download_url
        local tmp

        info_url="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VERSION}"

        tmp="$(mktemp -d)"

        if ! curl -fsSL "${info_url}" -o "${tmp}/info.json"; then
            log_warn "Could not query GNOME extension: ${name}"
            rm -rf "${tmp}"
            return 0
        fi

        download_url="$(jq -r '.download_url // empty' "${tmp}/info.json")"

        if [[ -z "${download_url}" ]]; then
            log_warn "No compatible ${name} release found for GNOME ${SHELL_VERSION}; skipping."
            rm -rf "${tmp}"
            return 0
        fi

        curl -fsSL "https://extensions.gnome.org${download_url}" \
            -o "${tmp}/extension.zip"

        gnome-extensions install --force "${tmp}/extension.zip" || {
            log_warn "Could not install ${name}."
            rm -rf "${tmp}"
            return 0
        }

        gnome-extensions enable "${uuid}" 2>/dev/null || \
            log_warn "Installed ${name}, but enabling it may require logout/login."

        rm -rf "${tmp}"
        log_success "${name} installed."
    }

    install_gnome_extension \
        "tiling-assistant@leleat-on-github" \
        "Tiling Assistant"

    install_gnome_extension \
        "Vitals@CoreCoding.com" \
        "Vitals"

    install_gnome_extension \
        "caffeine@patapon.info" \
        "Caffeine"

    # Pano currently may not publish a release compatible with every GNOME
    # version. Querying the API lets the installer skip it safely.
    install_gnome_extension \
        "pano@alperenelhan.com" \
        "Pano"
fi

log_success "Desktop setup completed."
