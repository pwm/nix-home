#!/usr/bin/env bash
# Run one playbook script on a server: the settings file and the script go there
# as one temporary file, which a login Bash runs (so the account's Nix profile
# is on PATH) with no standard input, then removes.
#
#   pml/run-on.sh SSH_DESTINATION SCRIPT
#   PML_PLAYBOOK_CONFIG   the settings file (default ~/.config/pml-playbook.env)
set -euo pipefail
if (($# != 2)); then
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
config=${PML_PLAYBOOK_CONFIG:-$HOME/.config/pml-playbook.env}
[[ -f $config ]] || {
  echo "No settings at $config: copy pml/config.example.env there and fill it in." >&2
  exit 2
}
[[ -f $2 ]] || {
  echo "No script $2" >&2
  exit 2
}
{
  echo 'set -a'
  cat "$config"
  echo 'set +a'
  cat "$2"
} | ssh -o BatchMode=yes "$1" 'f=$(mktemp) && cat >"$f" && bash -l "$f" </dev/null; rc=$?; rm -f "$f"; exit $rc'
