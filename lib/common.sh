#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "${0}")"

log_info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_success() { printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"; }
log_warn()    { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
log_error()   { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }
log_step()    { echo; printf '\033[1;35m========== %s ==========\033[0m\n' "$*"; echo; }
die()         { log_error "$*"; exit 1; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

apt_package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null |
        grep -q 'install ok installed'
}

install_apt_packages() {
    sudo apt-get install -y "$@"
}

require_command() {
    command_exists "$1" || die "Required command not found: $1"
}

require_not_root() {
    [[ "${EUID}" -ne 0 ]] || die "Do not run this script as root."
}

require_sudo() {
    command_exists sudo || die "sudo is required."
    sudo -v || die "Unable to obtain sudo privileges."
}

require_ubuntu() {
    [[ -f /etc/os-release ]] || die "/etc/os-release not found."
    # shellcheck disable=SC1091
    source /etc/os-release

    [[ "${ID:-}" == "ubuntu" ]] || die "This installer supports Ubuntu only."

    case "${VERSION_ID:-}" in
        22.04|24.04|26.04) ;;
        *)
            log_warn "Ubuntu ${VERSION_ID:-unknown} is not explicitly tested."
            read -r -p "Continue anyway? [y/N] " answer
            case "${answer}" in
                y|Y|yes|YES) ;;
                *) exit 1 ;;
            esac
            ;;
    esac
}

backup_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp -a "${file}" "${backup}"
        log_info "Backup created: ${backup}"
    fi
}

append_if_missing() {
    local line="$1"
    local file="$2"
    touch "${file}"
    grep -Fqx "${line}" "${file}" || printf '%s\n' "${line}" >> "${file}"
}
