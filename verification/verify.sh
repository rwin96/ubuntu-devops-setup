#!/usr/bin/env bash

set -u
IFS=$'\n\t'

PASS=0
FAIL=0
WARN=0

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET='\033[0m'

pass() {
    printf "${GREEN}[PASS]${RESET} %s\n" "$*"
    PASS=$((PASS + 1))
}

fail() {
    printf "${RED}[FAIL]${RESET} %s\n" "$*"
    FAIL=$((FAIL + 1))
}

warn() {
    printf "${YELLOW}[WARN]${RESET} %s\n" "$*"
    WARN=$((WARN + 1))
}

info() {
    printf "${BLUE}[INFO]${RESET} %s\n" "$*"
}

check_command() {
    local command="$1"
    local description="${2:-$1}"

    if command -v "${command}" >/dev/null 2>&1; then
        local version=""

        case "${command}" in
            git)
                version="$(git --version 2>/dev/null || true)"
                ;;
            curl)
                version="$(curl --version 2>/dev/null | head -n1 || true)"
                ;;
            wget)
                version="$(wget --version 2>/dev/null | head -n1 || true)"
                ;;
            zsh)
                version="$(zsh --version 2>/dev/null || true)"
                ;;
            tmux)
                version="$(tmux -V 2>/dev/null || true)"
                ;;
            jq)
                version="$(jq --version 2>/dev/null || true)"
                ;;
            rg)
                version="$(rg --version 2>/dev/null | head -n1 || true)"
                ;;
            fd)
                version="$(fd --version 2>/dev/null || true)"
                ;;
            fzf)
                version="$(fzf --version 2>/dev/null || true)"
                ;;
            btop)
                version="$(btop --version 2>/dev/null | head -n1 || true)"
                ;;
            ncdu)
                version="$(ncdu --version 2>/dev/null | head -n1 || true)"
                ;;
            rsync)
                version="$(rsync --version 2>/dev/null | head -n1 || true)"
                ;;
            ssh)
                version="$(ssh -V 2>&1 || true)"
                ;;
            dig)
                version="$(dig -v 2>&1 | head -n1 || true)"
                ;;
            ip)
                version="$(ip -V 2>/dev/null || true)"
                ;;
            ping)
                version="$(ping -V 2>&1 | head -n1 || true)"
                ;;
            traceroute)
                version="$(traceroute --version 2>&1 | head -n1 || true)"
                ;;
            mtr)
                version="$(mtr --version 2>&1 | head -n1 || true)"
                ;;
            nc)
                version="installed"
                ;;
            lsof)
                version="$(lsof -v 2>&1 | head -n1 || true)"
                ;;
            gpg)
                version="$(gpg --version 2>/dev/null | head -n1 || true)"
                ;;
            docker)
                version="$(docker --version 2>/dev/null || true)"
                ;;
            kubectl)
                version="$(kubectl version --client 2>/dev/null | head -n1 || true)"
                ;;
            helm)
                version="$(helm version --short 2>/dev/null || true)"
                ;;
            kubectx)
                version="$(kubectx --version 2>/dev/null || true)"
                ;;
            kubens)
                version="installed"
                ;;
            k9s)
                version="$(k9s version --short 2>/dev/null || true)"
                ;;
            trivy)
                version="$(trivy --version 2>/dev/null | head -n1 || true)"
                ;;
            sops)
                version="$(sops --version 2>/dev/null | head -n1 || true)"
                ;;
            age)
                version="$(age --version 2>/dev/null || true)"
                ;;
            openvpn)
                version="$(openvpn --version 2>/dev/null | head -n1 || true)"
                ;;
            gnome-extensions)
                version="installed"
                ;;
            google-chrome)
                version="$(google-chrome --version 2>/dev/null || true)"
                ;;
            ulauncher)
                version="installed"
                ;;
        esac

        if [[ -n "${version}" ]]; then
            pass "${description}: ${version}"
        else
            pass "${description}"
        fi
    else
        fail "${description}: command not found"
    fi
}

check_package() {
    local package="$1"

    if dpkg-query -W -f='${Status}' "${package}" 2>/dev/null |
        grep -q 'install ok installed'; then
        pass "APT package: ${package}"
    else
        fail "APT package missing: ${package}"
    fi
}

check_file() {
    local file="$1"

    if [[ -f "${file}" ]]; then
        pass "File exists: ${file}"
    else
        fail "File missing: ${file}"
    fi
}

check_directory() {
    local directory="$1"

    if [[ -d "${directory}" ]]; then
        pass "Directory exists: ${directory}"
    else
        fail "Directory missing: ${directory}"
    fi
}

check_alias() {
    local alias_name="$1"
    local expected="$2"

    if zsh -ic "alias ${alias_name}" 2>/dev/null |
        grep -Fq "${expected}"; then
        pass "Zsh alias: ${alias_name}"
    else
        fail "Zsh alias missing/broken: ${alias_name}"
    fi
}

echo
printf "${BLUE}========================================${RESET}\n"
printf "${BLUE} Ubuntu DevOps Workstation Verification ${RESET}\n"
printf "${BLUE}========================================${RESET}\n"
echo

info "User: ${USER}"
info "Home: ${HOME}"
info "OS: $(. /etc/os-release && echo "${PRETTY_NAME}")"
info "Kernel: $(uname -r)"
info "Architecture: $(uname -m)"
echo

# --------------------------------------------------
# Base commands
# --------------------------------------------------

printf "${BLUE}--- Base tools ---${RESET}\n"

check_command curl
check_command wget
check_command git
check_command vim
check_command zsh
check_command tmux
check_command unzip
check_command zip
check_command tar
check_command gzip
check_command jq
check_command rg "ripgrep"
check_command fd
check_command fzf
check_command btop
check_command ncdu
check_command rsync
check_command ssh
check_command dig
check_command ip
check_command ping
check_command traceroute
check_command mtr
check_command nc
check_command lsof
check_command gpg

echo

# --------------------------------------------------
# APT package verification
# --------------------------------------------------

printf "${BLUE}--- Required APT packages ---${RESET}\n"

BASE_PACKAGES=(
    ca-certificates
    curl
    wget
    git
    vim
    zsh
    tmux
    unzip
    zip
    tar
    gzip
    jq
    ripgrep
    fd-find
    fzf
    btop
    ncdu
    rsync
    openssh-client
    dnsutils
    iproute2
    iputils-ping
    traceroute
    mtr-tiny
    netcat-openbsd
    lsof
    gnupg
    zsh-autosuggestions
    zsh-syntax-highlighting
)

for package in "${BASE_PACKAGES[@]}"; do
    check_package "${package}"
done

echo

# --------------------------------------------------
# Zsh
# --------------------------------------------------

printf "${BLUE}--- Zsh ---${RESET}\n"

check_directory "${HOME}/.oh-my-zsh"
check_directory "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
check_directory "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
check_directory "${HOME}/.oh-my-zsh/custom/plugins/zsh-completions"
check_directory "${HOME}/.oh-my-zsh/custom/plugins/kube-ps1"
check_file "${HOME}/.zshrc"

CURRENT_SHELL="$(getent passwd "${USER}" | cut -d: -f7)"

if [[ "${CURRENT_SHELL}" == "$(command -v zsh)" ]]; then
    pass "Default shell: zsh"
else
    warn "Default shell is ${CURRENT_SHELL}, not zsh"
fi

echo

# --------------------------------------------------
# Git
# --------------------------------------------------

printf "${BLUE}--- Git ---${RESET}\n"

check_file "${HOME}/.gitconfig"

if git config --global init.defaultBranch 2>/dev/null |
    grep -qx 'main'; then
    pass "Git default branch: main"
else
    fail "Git default branch is not main"
fi

if git config --global fetch.prune 2>/dev/null |
    grep -qx 'true'; then
    pass "Git fetch.prune: true"
else
    fail "Git fetch.prune is not true"
fi

if git config --global rerere.enabled 2>/dev/null |
    grep -qx 'true'; then
    pass "Git rerere.enabled: true"
else
    fail "Git rerere.enabled is not true"
fi

echo

# --------------------------------------------------
# Docker
# --------------------------------------------------

printf "${BLUE}--- Docker ---${RESET}\n"

check_command docker

if systemctl is-enabled docker >/dev/null 2>&1; then
    pass "Docker service enabled"
else
    fail "Docker service is not enabled"
fi

if systemctl is-active docker >/dev/null 2>&1; then
    pass "Docker service running"
else
    fail "Docker service is not running"
fi

if getent group docker >/dev/null 2>&1; then
    pass "docker group exists"
else
    fail "docker group missing"
fi

if id -nG "${USER}" | tr ' ' '\n' | grep -qx docker; then
    pass "User is currently in docker group"
else
    warn "User is not currently in docker group (logout/login may be required)"
fi

if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose plugin"
else
    fail "Docker Compose plugin missing"
fi

if docker buildx version >/dev/null 2>&1; then
    pass "Docker Buildx"
else
    fail "Docker Buildx missing"
fi

echo

# --------------------------------------------------
# Kubernetes
# --------------------------------------------------

printf "${BLUE}--- Kubernetes ---${RESET}\n"

check_command kubectl
check_command helm
check_command kubectx
check_command kubens
check_command k9s

if command -v kubectl >/dev/null 2>&1; then
    if kubectl krew version >/dev/null 2>&1; then
        pass "Krew"
    else
        fail "Krew missing"
    fi

    if kubectl krew list 2>/dev/null |
        awk '{print $1}' |
        grep -qx neat; then
        pass "Krew plugin: neat"
    else
        warn "Krew plugin 'neat' missing"
    fi

    if kubectl krew list 2>/dev/null |
        awk '{print $1}' |
        grep -qx tree; then
        pass "Krew plugin: tree"
    else
        warn "Krew plugin 'tree' missing"
    fi
fi

echo

# --------------------------------------------------
# Network
# --------------------------------------------------

printf "${BLUE}--- OpenVPN ---${RESET}\n"

check_command openvpn

check_package openvpn
check_package network-manager-openvpn
check_package network-manager-openvpn-gnome

echo

# --------------------------------------------------
# Security
# --------------------------------------------------

printf "${BLUE}--- Security ---${RESET}\n"

check_command trivy
check_command sops
check_command age

echo

# --------------------------------------------------
# SSH
# --------------------------------------------------

printf "${BLUE}--- SSH ---${RESET}\n"

check_directory "${HOME}/.ssh"
check_file "${HOME}/.ssh/config"
check_file "${HOME}/.ssh/known_hosts"

if [[ -f "${HOME}/.ssh/config" ]]; then
    if grep -Fq 'AddKeysToAgent yes' "${HOME}/.ssh/config"; then
        pass "SSH AddKeysToAgent configured"
    else
        warn "SSH AddKeysToAgent not configured"
    fi

    if grep -Fq 'ServerAliveInterval 60' "${HOME}/.ssh/config"; then
        pass "SSH keepalive configured"
    else
        warn "SSH ServerAliveInterval not configured"
    fi
fi

if [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
    pass "Ed25519 private key exists"
else
    warn "No Ed25519 SSH key found (optional)"
fi

if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    pass "Ed25519 public key exists"
else
    warn "No Ed25519 public key found (optional)"
fi

echo

# --------------------------------------------------
# Desktop
# --------------------------------------------------

printf "${BLUE}--- Desktop ---${RESET}\n"

if command -v google-chrome >/dev/null 2>&1; then
    pass "Google Chrome installed: $(google-chrome --version 2>/dev/null)"
else
    warn "Google Chrome not installed"
fi

if command -v ulauncher >/dev/null 2>&1; then
    pass "Ulauncher installed"
else
    warn "Ulauncher not installed"
fi

if command -v gnome-extensions >/dev/null 2>&1; then
    pass "GNOME Extensions CLI available"

    EXTENSIONS=(
        "tiling-assistant@leleat-on-github"
        "Vitals@CoreCoding.com"
        "caffeine@patapon.info"
        "pano@alperenelhan.com"
    )

    for uuid in "${EXTENSIONS[@]}"; do
        if gnome-extensions list 2>/dev/null |
            grep -Fxq "${uuid}"; then
            if gnome-extensions info "${uuid}" 2>/dev/null |
                grep -q 'State: ENABLED'; then
                pass "GNOME extension enabled: ${uuid}"
            else
                warn "GNOME extension installed but not enabled: ${uuid}"
            fi
        else
            warn "GNOME extension not installed: ${uuid}"
        fi
    done
else
    warn "gnome-extensions command not available"
fi

echo

# --------------------------------------------------
# Aliases
# --------------------------------------------------

printf "${BLUE}--- Zsh aliases ---${RESET}\n"

check_alias k "kubectl"
check_alias kg "kubectl get"
check_alias kns "kubens"
check_alias kctx "kubectx"

check_alias d "docker"
check_alias dc "docker compose"

check_alias gs "git status"
check_alias ga "git add"
check_alias gp "git push"

echo

# --------------------------------------------------
# Things intentionally NOT installed
# --------------------------------------------------

printf "${BLUE}--- Minimal-install sanity check ---${RESET}\n"

UNWANTED_COMMANDS=(
    bat
    eza
    zoxide
    delta
)

for command in "${UNWANTED_COMMANDS[@]}"; do
    if command -v "${command}" >/dev/null 2>&1; then
        warn "Optional/unwanted tool is installed: ${command}"
    else
        pass "Not installed: ${command}"
    fi
done

echo

# --------------------------------------------------
# Summary
# --------------------------------------------------

printf "${BLUE}========================================${RESET}\n"
printf "${BLUE} Verification Summary                  ${RESET}\n"
printf "${BLUE}========================================${RESET}\n"

printf "${GREEN}PASS: ${PASS}${RESET}\n"
printf "${YELLOW}WARN: ${WARN}${RESET}\n"
printf "${RED}FAIL: ${FAIL}${RESET}\n"

echo

if (( FAIL == 0 )); then
    printf "${GREEN}Everything required passed.${RESET}\n"
    if (( WARN > 0 )); then
        printf "${YELLOW}There are warnings to review, but no required checks failed.${RESET}\n"
    fi
    exit 0
else
    printf "${RED}Some required checks failed. Review the [FAIL] lines above.${RESET}\n"
    exit 1
fi
