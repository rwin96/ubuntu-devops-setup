#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "SSH configuration"

SSH_DIR="${HOME}/.ssh"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

SSH_CONFIG="${SSH_DIR}/config"

if [[ ! -f "${SSH_CONFIG}" ]]; then
    cat > "${SSH_CONFIG}" <<'CONFIG'
Host *
    AddKeysToAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    HashKnownHosts yes
    Compression yes
    TCPKeepAlive yes
CONFIG
    chmod 600 "${SSH_CONFIG}"
else
    log_info "${SSH_CONFIG} already exists; preserving it."
fi

touch "${SSH_DIR}/known_hosts"
chmod 600 "${SSH_DIR}/known_hosts"

echo
read -r -p "Create an Ed25519 SSH key now? [y/N] " answer

case "${answer}" in
    y|Y|yes|YES)
        read -r -p "Email/comment for the key: " SSH_COMMENT
        SSH_KEY="${SSH_DIR}/id_ed25519"

        if [[ -f "${SSH_KEY}" ]]; then
            log_warn "SSH key already exists: ${SSH_KEY}"
        else
            ssh-keygen -t ed25519 -C "${SSH_COMMENT}" -f "${SSH_KEY}"
        fi

        if command_exists ssh-add && [[ -f "${SSH_KEY}" ]]; then
            ssh-add "${SSH_KEY}" 2>/dev/null || true
        fi

        log_info "Public key:"
        cat "${SSH_KEY}.pub"
        ;;
    *)
        log_info "SSH key creation skipped."
        ;;
esac

log_success "SSH configured."
