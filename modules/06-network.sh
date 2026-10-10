#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "OpenVPN"

install_apt_packages \
    openvpn \
    network-manager-openvpn \
    network-manager-openvpn-gnome

log_success "OpenVPN installed."
