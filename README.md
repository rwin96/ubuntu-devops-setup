# Ubuntu DevOps Setup

Opinionated, idempotent bootstrap scripts that turn a fresh Ubuntu workstation into a ready-to-go DevOps environment — shell, git, Docker, Kubernetes tooling, security tools, SSH, and a few desktop extras — in one run.

## Why

Reinstalling Ubuntu (or spinning up a new laptop/VM) shouldn't mean an hour of manually reinstalling the same CLI tools and re-typing the same config. This repo is a small, numbered pipeline of shell modules you can run top to bottom, re-run safely, or pick apart and run individually.

## What it installs

| # | Module | Installs |
|---|--------|----------|
| 01 | `modules/01-system.sh` | Base CLI packages: `curl`, `wget`, `git`, `vim`, `zsh`, `tmux`, `jq`, `ripgrep`, `fd-find`, `fzf`, `btop`, `ncdu`, `rsync`, networking tools (`dnsutils`, `iproute2`, `mtr`, `netcat`, `lsof`...), `gnupg` |
| 02 | `modules/02-shell.sh` | Oh My Zsh, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions`, `kube-ps1`; installs a curated `~/.zshrc` and sets zsh as the default shell |
| 03 | `modules/03-git.sh` | Sane global git defaults (`main` as default branch, `rerere`, `fetch.prune`, etc.) and a base `~/.gitconfig` |
| 04 | `modules/04-docker.sh` | Docker Engine, Buildx, and the Compose plugin from Docker's official apt repo; adds your user to the `docker` group |
| 05 | `modules/05-kubernetes.sh` | `kubectl`, `helm`, `kubectx`/`kubens`, `krew` (+ `neat`, `tree` plugins), `k9s` |
| 06 | `modules/06-network.sh` | OpenVPN + NetworkManager OpenVPN integration |
| 07 | `modules/07-security.sh` | `trivy`, `sops`, `age` |
| 08 | `modules/08-ssh.sh` | Hardened `~/.ssh/config` defaults and optional Ed25519 key generation |
| 09 | `modules/09-desktop.sh` | Google Chrome, Ulauncher, and GNOME Shell extensions (Tiling Assistant, Vitals, Caffeine, Pano) |

Everything is driven by [`lib/common.sh`](lib/common.sh), a small shared library of logging helpers and guard functions (`require_ubuntu`, `require_sudo`, `backup_file`, etc.), and orchestrated by [`install.sh`](install.sh).

## Requirements

- Ubuntu 22.04, 24.04, or 26.04 (other versions will prompt before continuing — see [Compatibility](#compatibility))
- A non-root user with `sudo` access
- An internet connection

## Quick start

```bash
git clone https://github.com/<your-username>/ubuntu-devops-setup.git
cd ubuntu-devops-setup
./install.sh
```

The installer will:
1. Verify you're on a supported Ubuntu release, not running as root, and have `sudo`.
2. Ask for confirmation before making any changes.
3. Keep your `sudo` session alive for the duration of the run.
4. Run each module in `modules/` in order, logging progress as it goes.

You'll likely need to **log out and back in** afterward for the `docker` group membership, default shell change, and GNOME extensions to fully take effect.

## Running individual modules

Every module is a standalone, sourceable script. Run just the piece you need:

```bash
./modules/04-docker.sh
./modules/07-security.sh
```

## Configuration

A few things can be overridden via environment variables before running `install.sh`:

| Variable | Default | Used by |
|----------|---------|---------|
| `KUBERNETES_MINOR_VERSION` | `v1.37` | `modules/05-kubernetes.sh` — the pkgs.k8s.io release channel to track |

Static config files that get copied into place live in [`config/`](config):
- [`config/zshrc`](config/zshrc) → `~/.zshrc`
- [`config/gitconfig`](config/gitconfig) → `~/.gitconfig` (only written if one doesn't already exist)

Edit these before running the installer if you want a different prompt, aliases, or git defaults.

## Verifying an install

[`verification/verify.sh`](verification/verify.sh) checks the current machine against everything the modules are supposed to have set up — commands, apt packages, service state, git config, SSH config, zsh aliases, GNOME extensions — and prints a pass/warn/fail summary.

```bash
./verification/verify.sh
```

Exits `0` if every required check passes (warnings are non-fatal), `1` otherwise.

## Project structure

```
.
├── install.sh                 # Entry point — runs all modules in order
├── lib/
│   └── common.sh               # Shared logging/guard helpers sourced by every module
├── modules/
│   ├── 01-system.sh
│   ├── 02-shell.sh
│   ├── 03-git.sh
│   ├── 04-docker.sh
│   ├── 05-kubernetes.sh
│   ├── 06-network.sh
│   ├── 07-security.sh
│   ├── 08-ssh.sh
│   └── 09-desktop.sh
├── config/
│   ├── zshrc
│   └── gitconfig
└── verification/
    └── verify.sh                # Post-install sanity check
```

## Design notes

- **Idempotent where it matters.** Modules check for existing installs/clones/config before acting, so re-running `install.sh` after a partial failure (or just to pick up updates) is safe.
- **Existing config is preserved, not clobbered.** `~/.gitconfig` and `~/.ssh/config` are only written if absent; `~/.zshrc` is backed up (timestamped) before being overwritten.
- **Minimal by design.** The verification script intentionally checks that a short list of popular-but-unneeded tools (`bat`, `eza`, `zoxide`, `delta`) are *not* silently pulled in as dependencies — this setup stays deliberate about what it installs.
- **Fails loudly.** Every script runs under `set -Eeuo pipefail`; a missing module or failed command stops the run instead of limping along.

## Compatibility

Currently tested against Ubuntu 22.04, 24.04, and 26.04. Running on another release will prompt for confirmation rather than failing outright — most modules use upstream apt/signing-key repos that track Ubuntu's `VERSION_CODENAME`, so other LTS releases are likely to work.

## Roadmap

This is an actively evolving setup. Planned work includes broader distro/version support, additional language runtime and tooling modules, and more granular module selection (e.g. `./install.sh --only docker,kubernetes`). Issues and PRs welcome.

## Contributing

Contributions are welcome — new modules, additional packages, or compatibility fixes. Please keep new modules self-contained, idempotent, and consistent with the logging conventions in `lib/common.sh`.

## License

MIT — see [LICENSE](LICENSE).
