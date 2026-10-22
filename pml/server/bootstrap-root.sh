#!/usr/bin/env bash
# Root bootstrap of a new Ubuntu 24.04 server for PML work: hostname, a few
# packages, no automatic reboots, the account with root's SSH keys and lingering
# processes, and multi-user Nix with the account as a trusted user. Run as root
# through pml/run-on.sh (it supplies the settings). Safe to run again: each step
# checks its current state first. Password login is turned off separately, after
# a key login as the account has worked (harden-ssh.sh).
#
# A trusted Nix user can use its own substituters and is therefore
# root-equivalent through the Nix daemon; that is the accepted cost of building
# with the account's caches.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
: "${HOST_NAME:?}" "${USER_NAME:?}" "${NIX_VERSION:?}" "${NIX_INSTALL_SHA256:?}"
LOCALE=${LOCALE:-en_GB.UTF-8}

step() { printf '\n== %s\n' "$*"; }

step "hostname $HOST_NAME"
old=$(hostname)
if [ "$old" != "$HOST_NAME" ]; then
  hostnamectl set-hostname "$HOST_NAME"
  old_re=$(printf '%s' "$old" | sed 's/[][\.*^$/]/\\&/g')
  sed -i "s/\\b${old_re}\\b/${HOST_NAME}/g" /etc/hosts
fi
hostname
grep -n "$HOST_NAME" /etc/hosts

step "packages: terminfo, locale, Nix installer tools"
apt-get update -q
apt-get install -y -q ncurses-term locales xz-utils curl git ca-certificates python3
locale-gen "$LOCALE"
locale -a | grep -i "${LOCALE%%.*}"

step "updates never reboot automatically"
cat >/etc/apt/apt.conf.d/52pml-no-automatic-reboot <<'EOF'
// Agents run long jobs here; reboot by hand when work is idle.
Unattended-Upgrade::Automatic-Reboot "false";
EOF
apt-config dump | grep -i 'Automatic-Reboot '

step "account $USER_NAME"
if ! id "$USER_NAME" >/dev/null 2>&1; then
  useradd --create-home --home-dir "/home/$USER_NAME" --shell /bin/bash --user-group "$USER_NAME"
fi
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
if [ ! -s "/home/$USER_NAME/.ssh/authorized_keys" ]; then
  install -m 600 -o "$USER_NAME" -g "$USER_NAME" /root/.ssh/authorized_keys "/home/$USER_NAME/.ssh/authorized_keys"
fi
awk '{print $1, $NF}' "/home/$USER_NAME/.ssh/authorized_keys"
id "$USER_NAME"
# Keep the account's processes after its last session ends.
loginctl enable-linger "$USER_NAME"
loginctl show-user "$USER_NAME" --property=Linger
grep -E '^#?KillUserProcesses' /etc/systemd/logind.conf || true

step "Nix $NIX_VERSION, multi-user"
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  curl -fsSL "https://releases.nixos.org/nix/nix-$NIX_VERSION/install" -o "/root/nix-$NIX_VERSION-install"
  echo "$NIX_INSTALL_SHA256  /root/nix-$NIX_VERSION-install" | sha256sum -c -
  sh "/root/nix-$NIX_VERSION-install" --daemon --yes
fi
# The daemon uses the account's substituters only for trusted users.
if ! grep -q '^trusted-users' /etc/nix/nix.conf; then
  echo "trusted-users = root $USER_NAME" >>/etc/nix/nix.conf
  systemctl restart nix-daemon
fi
grep -v '^#' /etc/nix/nix.conf | grep -v '^$'
/nix/var/nix/profiles/default/bin/nix --version
systemctl is-active nix-daemon

step "done"
