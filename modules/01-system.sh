#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Base system packages"

sudo apt-get update

BASE_PACKAGES=(
    ca-certificates curl wget git vim zsh tmux
    unzip zip tar gzip
    jq ripgrep fd-find fzf btop ncdu
    rsync
    openssh-client
    dnsutils iproute2 iputils-ping traceroute mtr-tiny netcat-openbsd lsof
    gnupg
    zsh-autosuggestions zsh-syntax-highlighting
)

install_apt_packages "${BASE_PACKAGES[@]}"

if command_exists fdfind && ! command_exists fd; then
    mkdir -p "${HOME}/.local/bin"
    ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"
fi

log_success "Base packages installed."
