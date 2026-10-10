#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="${1:-$HOME/rwin/ubuntu-devops-setup}"

if [[ -e "$REPO_DIR" ]]; then
    echo "ERROR: $REPO_DIR already exists."
    echo "Refusing to overwrite it. Remove/rename it first, or pass another path:"
    echo "  $0 /path/to/new/repo"
    exit 1
fi

mkdir -p "$REPO_DIR"/{config,lib,modules}
cd "$REPO_DIR"

cat > install.sh <<'EOF'
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
EOF

cat > lib/common.sh <<'EOF'
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
EOF

cat > modules/01-system.sh <<'EOF'
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
EOF

cat > modules/02-shell.sh <<'EOF'
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
EOF

cat > config/zshrc <<'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyruss"

plugins=(
  git
  docker
  kubectl
  helm
  sudo
  fzf
  colored-man-pages
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Completion
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion zsh)
  compdef _kubectl k
fi

# fzf
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# kube-ps1
if [[ -f "$ZSH/custom/plugins/kube-ps1/kube-ps1.sh" ]]; then
  source "$ZSH/custom/plugins/kube-ps1/kube-ps1.sh"
  PROMPT='$(kube_ps1)'$PROMPT
fi

# Local binaries
export PATH="$HOME/.local/bin:$PATH"

# Kubernetes
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ka='kubectl apply'
alias kdel='kubectl delete'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kgi='kubectl get ingress'
alias kga='kubectl get all'
alias kctx='kubectx'
alias kns='kubens'

# Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate --all'

# Linux
alias ll='ls -lah'
alias la='ls -la'
alias l='ls -CF'

# Safety / convenience
alias ..='cd ..'
alias ...='cd ../..'
EOF

cat > modules/03-git.sh <<'EOF'
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
EOF

cat > config/gitconfig <<'EOF'
[init]
    defaultBranch = main

[pull]
    rebase = false

[fetch]
    prune = true

[rerere]
    enabled = true

[core]
    editor = vim
EOF

cat > modules/04-docker.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Docker Engine"

sudo apt-get remove -y \
    docker.io \
    docker-compose \
    docker-compose-v2 \
    docker-doc \
    docker-buildx \
    podman-docker \
    containerd \
    runc 2>/dev/null || true

sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

source /etc/os-release

cat <<DOCKER_SOURCES_EOF | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER_SOURCES_EOF

sudo apt-get update

install_apt_packages \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable --now docker

sudo groupadd -f docker
sudo usermod -aG docker "${USER}"

sudo docker version
sudo docker compose version
sudo docker buildx version

log_warn "The docker group grants root-equivalent privileges."
log_warn "Log out and back in before using docker without sudo."

log_success "Docker installed."
EOF

cat > modules/05-kubernetes.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Kubernetes tooling"

KUBERNETES_MINOR_VERSION="${KUBERNETES_MINOR_VERSION:-v1.37}"

sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
    curl -fsSL \
        "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/Release.key" |
        sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

cat <<KUBERNETES_SOURCES_EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/ /
KUBERNETES_SOURCES_EOF

sudo apt-get update
install_apt_packages kubectl

# Helm
sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/helm.gpg ]]; then
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey |
        sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
    sudo chmod 0644 /etc/apt/keyrings/helm.gpg
fi

cat <<HELM_SOURCES_EOF | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main
HELM_SOURCES_EOF

sudo apt-get update
install_apt_packages helm kubectx

# Krew
if ! command_exists kubectl-krew; then
    KREW_TMP="$(mktemp -d)"
    trap 'rm -rf "${KREW_TMP}"' EXIT

    case "$(uname -s)" in
        Linux) KREW_OS="linux" ;;
        *) die "Unsupported OS for Krew: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) KREW_ARCH="amd64" ;;
        arm64|aarch64) KREW_ARCH="arm64" ;;
        *) die "Unsupported architecture for Krew: $(uname -m)" ;;
    esac

    KREW_VERSION="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/krew/releases/latest |
        jq -r '.tag_name')"

    [[ "${KREW_VERSION}" != "null" && -n "${KREW_VERSION}" ]] ||
        die "Could not determine latest Krew version."

    KREW_TARBALL="krew-${KREW_OS}_${KREW_ARCH}.tar.gz"
    curl -fsSL \
        "https://github.com/kubernetes-sigs/krew/releases/download/${KREW_VERSION}/${KREW_TARBALL}" \
        -o "${KREW_TMP}/${KREW_TARBALL}"

    tar -xzf "${KREW_TMP}/${KREW_TARBALL}" -C "${KREW_TMP}"

    "${KREW_TMP}/krew-${KREW_OS}_${KREW_ARCH}" install krew
    rm -rf "${KREW_TMP}"
    trap - EXIT
fi

export PATH="${HOME}/.krew/bin:${PATH}"

kubectl krew install --manifest='https://krew.sigs.k8s.io/plugins/manifest/neat.yaml' 2>/dev/null || true
kubectl krew install tree 2>/dev/null || true

# k9s
if ! command_exists k9s; then
    K9S_VERSION="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest |
        jq -r '.tag_name')"

    K9S_TMP="$(mktemp -d)"
    curl -fsSL \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
        -o "${K9S_TMP}/k9s.tar.gz"

    tar -xzf "${K9S_TMP}/k9s.tar.gz" -C "${K9S_TMP}" k9s
    sudo install -m 0755 "${K9S_TMP}/k9s" /usr/local/bin/k9s
    rm -rf "${K9S_TMP}"
fi

kubectl version --client
helm version
kubectx --version || true
k9s version --short || true

log_success "Kubernetes tooling installed."
EOF

cat > modules/06-network.sh <<'EOF'
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
EOF

cat > modules/07-security.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_DIR}/lib/common.sh"

log_step "Security tooling"

# Trivy
sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/trivy.gpg ]]; then
    curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key |
        sudo gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
    sudo chmod 0644 /etc/apt/keyrings/trivy.gpg
fi

cat <<TRIVY_SOURCES_EOF | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main
TRIVY_SOURCES_EOF

sudo apt-get update
install_apt_packages trivy age

# SOPS
if ! command_exists sops; then
    SOPS_VERSION="$(curl -fsSL https://api.github.com/repos/getsops/sops/releases/latest |
        jq -r '.tag_name')"

    [[ "${SOPS_VERSION}" != "null" && -n "${SOPS_VERSION}" ]] ||
        die "Could not determine latest SOPS version."

    SOPS_TMP="$(mktemp -d)"
    curl -fsSL \
        "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
        -o "${SOPS_TMP}/sops"

    chmod 0755 "${SOPS_TMP}/sops"
    sudo install -m 0755 "${SOPS_TMP}/sops" /usr/local/bin/sops
    rm -rf "${SOPS_TMP}"
fi

trivy --version
sops --version
age --version

log_success "Security tooling installed."
EOF

cat > modules/08-ssh.sh <<'EOF'
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
EOF

cat > modules/09-desktop.sh <<'EOF'
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
EOF

chmod +x install.sh modules/*.sh

echo
echo "Repository created successfully:"
echo "  $REPO_DIR"
echo
echo "Files:"
find "$REPO_DIR" -maxdepth 2 -type f -print | sort
echo
echo "Next:"
echo "  cd \"$REPO_DIR\""
echo "  ./install.sh"
