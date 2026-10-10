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
