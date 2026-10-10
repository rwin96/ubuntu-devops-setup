#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Git configuration"

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global fetch.prune true
git config --global rerere.enabled true
git config --global core.editor "vim"

if [[ ! -f "${HOME}/.gitconfig" ]]; then
    install -m 0644 "${REPO_DIR}/config/gitconfig" "${HOME}/.gitconfig"
else
    log_info "~/.gitconfig already exists; preserving it."
fi

log_warn "Git user.name and user.email were not changed automatically."
log_info "Set them when ready:"
log_info "  git config --global user.name 'Your Name'"
log_info "  git config --global user.email 'you@example.com'"

log_success "Git configured."
