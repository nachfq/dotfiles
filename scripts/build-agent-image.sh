#!/usr/bin/env bash
# Run on the Incus host, or stream over SSH. Never publish a logged-in environment.
set -euo pipefail
revision=${1:?Pass the dotfiles Git commit to build}
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { printf 'Expected a full Git commit.\n' >&2; exit 1; }
builder="agent-image-build-$(date +%Y%m%d%H%M%S)"
alias_name="agent-base-$(date +%Y%m%d)-${revision:0:8}"
incus launch images:ubuntu/24.04 "$builder" -p agent-pilot -c security.nesting=true \
  -c user.agent-image-builder=true
printf 'Building %s from dotfiles %s\n' "$builder" "$revision"
# Keep a failed builder for diagnosis. It never receives credentials or project files.
trap 'printf "Build stopped. Inspect builder: %s\n" "$builder" >&2' ERR
incus exec "$builder" -- env DEBIAN_FRONTEND=noninteractive bash -s <<'ROOT'
set -euo pipefail
touch /etc/agent-base-builder
id dev >/dev/null 2>&1 || useradd --create-home --uid 1001 --user-group --shell /bin/bash dev
apt-get update -qq
apt-get install -y -qq --no-install-recommends git curl ca-certificates
runuser -u dev -- git clone https://github.com/nachfq/dotfiles.git /home/dev/dotfiles
ROOT
incus exec "$builder" -- runuser -u dev -- git -C /home/dev/dotfiles checkout --detach "$revision"
incus exec "$builder" -- bash /home/dev/dotfiles/setup-agent.sh install-tools
incus exec "$builder" -- bash /home/dev/dotfiles/setup-agent.sh grant-sudo
incus exec "$builder" -- runuser -u dev -- env \
  HOME=/home/dev PATH=/home/dev/.local/bin:/home/dev/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin \
  bash -s <<'USER'
set -euo pipefail
cd /home/dev/dotfiles
./setup-agent.sh apply
./setup-agent.sh install-runtimes
./setup-agent.sh install-codex
./setup-agent.sh configure-codex
./setup-agent.sh install-herdr
./setup-agent.sh plugins
sudo -n true
for tool in git gh codex herdr nvim node npm mise uv fzf bat zoxide btop dua rsync pkg-config; do
  command -v "$tool"
done
! command -v rustc
! command -v cargo
USER
incus exec "$builder" -- bash -s <<'ROOT'
set -euo pipefail
cat > /etc/ssh/sshd_config.d/20-agent-access.conf <<'SSH'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers dev
SSH
systemctl enable ssh.service
python3 - <<'PY'
from pathlib import Path
import json, shutil
assert Path('/etc/agent-base-builder').exists()
home = Path('/home/dev')
for forbidden in [home/'.codex/auth.json', home/'.config/gh/hosts.yml', home/'.ssh/authorized_keys']:
    assert not forbidden.exists(), f'Unexpected credential/access file: {forbidden}'
for path in [home/'.cache', Path('/root/.cache'), Path('/var/lib/apt/lists')]:
    if path.exists():
        shutil.rmtree(path)
for path in [home/'.bash_history', Path('/root/.bash_history')]:
    path.unlink(missing_ok=True)
for path in Path('/etc/ssh').glob('ssh_host_*'):
    path.unlink()
Path('/etc/machine-id').write_text('')
Path('/var/lib/dbus/machine-id').unlink(missing_ok=True)
Path('/var/lib/dbus/machine-id').symlink_to('/etc/machine-id')
Path('/etc/agent-base-builder').unlink()
PY
apt-get clean
ROOT
incus stop "$builder" --timeout 30
incus publish "$builder" --alias "$alias_name" --compression gzip \
  "description=Common agent tools; no project, Rust toolchain or credentials" \
  "user.dotfiles.revision=$revision"
fingerprint=$(incus image info "$alias_name" | sed -n 's/^Fingerprint: //p')
if incus image alias list --format csv | cut -d, -f1 | grep -qx agent-base; then
  incus image alias delete agent-base
fi
incus image alias create agent-base "$fingerprint"
incus delete "$builder"
trap - ERR
printf 'Ready: agent-base (%s), immutable alias %s\n' "$fingerprint" "$alias_name"
