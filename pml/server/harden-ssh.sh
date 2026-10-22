#!/usr/bin/env bash
# Key-only SSH with a server-side keepalive. Run as root through pml/run-on.sh,
# only after a separate key login as the account has worked. sshd keeps the
# first value it reads for a setting, and Ubuntu includes sshd_config.d/*.conf
# before its own settings, so this file sorts first.
set -euo pipefail

conf=/etc/ssh/sshd_config.d/00-pml.conf
cat >"$conf" <<'EOF'
# Key login only. Root keeps key login for deliberate admin work.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
# Ask a silent client every 30 s and drop the connection after 4 missed
# answers. Zellij sessions and their work are unaffected either way. A sleeping
# Mac can keep its connection alive, and the same connection then carries on
# after the wake.
ClientAliveInterval 30
ClientAliveCountMax 4
EOF
chmod 644 "$conf"

grep -n '^Include' /etc/ssh/sshd_config
ls /etc/ssh/sshd_config.d/
sshd -t
sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication|clientaliveinterval|clientalivecountmax) '
sshd -T | grep -q '^passwordauthentication no$'
systemctl reload ssh
systemctl is-active ssh
