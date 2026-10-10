#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Zsh and shell configuration"

OH_MY_ZSH="${HOME}/.oh-my-zsh"

if [[ ! -d "${OH_MY_ZSH}" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    log_info "Oh My Zsh already installed."
fi

ZSH_CUSTOM="${OH_MY_ZSH}/custom"
mkdir -p "${ZSH_CUSTOM}/plugins"

clone_plugin() {
    local repo="$1"
    local destination="$2"

    if [[ -d "${destination}/.git" ]]; then
        log_info "Plugin already present: ${destination}"
    else
        git clone --depth=1 "${repo}" "${destination}"
    fi
}

clone_plugin \
    "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"

clone_plugin \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

clone_plugin \
    "https://github.com/zsh-users/zsh-completions.git" \
    "${ZSH_CUSTOM}/plugins/zsh-completions"

clone_plugin \
    "https://github.com/jonmosco/kube-ps1.git" \
    "${ZSH_CUSTOM}/plugins/kube-ps1"

backup_file "${HOME}/.zshrc"
install -m 0644 "${REPO_DIR}/config/zshrc" "${HOME}/.zshrc"

if [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
    if command_exists chsh; then
        chsh -s "$(command -v zsh)" "${USER}" || \
            log_warn "Could not change default shell automatically."
    fi
fi

log_success "Zsh configured."
