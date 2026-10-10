#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

MODULES=(
    "01-system.sh"
    "02-shell.sh"
    "03-git.sh"
    "04-docker.sh"
    "05-kubernetes.sh"
    "06-network.sh"
    "07-security.sh"
    "08-ssh.sh"
    "09-desktop.sh"
)

main() {
    require_ubuntu
    require_not_root
    require_sudo

    log_info "Ubuntu DevOps Workstation Setup"
    log_info "User: ${USER}"
    log_info "Home: ${HOME}"
    log_info "Repository: ${REPO_DIR}"

    echo
    read -r -p "Continue with installation? [y/N] " answer

    case "${answer}" in
        y|Y|yes|YES) ;;
        *) log_warn "Installation cancelled."; exit 0 ;;
    esac

    sudo -v

    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" 2>/dev/null || exit
    done &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true' EXIT

    for module in "${MODULES[@]}"; do
        module_path="${REPO_DIR}/modules/${module}"

        [[ -f "${module_path}" ]] || die "Module not found: ${module_path}"

        log_step "Running ${module}"
        bash "${module_path}"
        log_success "${module} completed"
    done

    log_success "All modules completed."

    echo
    log_warn "A new login session may be required for Docker group and default shell changes."
    log_warn "GNOME extensions may also require logout/login."
    log_success "Setup finished."
}

main "$@"
