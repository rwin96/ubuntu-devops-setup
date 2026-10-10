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
