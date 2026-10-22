#!/usr/bin/env bash
# Run playbook files on a server: the settings file, then the given files in
# order (settings files, function libraries, and last the script itself), go
# there as one temporary file, which a login Bash runs (so the account's Nix
# profile is on PATH) with no standard input, then removes.
#
#   devserver/run-on.sh SSH_DESTINATION FILE...
#   DEVSERVER_CONFIG   the settings file (default ~/.config/devserver.env)
#
# Example: devserver/run-on.sh devbox ~/work/app/devserver/project.env devserver/user/clone-repo.sh
# Files ending in .env are read as settings (exported), others as Bash.
set -euo pipefail
if (($# < 2)); then
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
config=${DEVSERVER_CONFIG:-$HOME/.config/devserver.env}
[[ -f $config ]] || {
  echo "No settings at $config: copy devserver/config.example.env there and fill it in." >&2
  exit 2
}
destination=$1
shift
for f in "$@"; do
  [[ -f $f ]] || {
    echo "No file $f" >&2
    exit 2
  }
done
{
  echo 'set -a'
  cat "$config"
  echo 'set +a'
  for f in "$@"; do
    case $f in
    *.env)
      echo 'set -a'
      cat "$f"
      echo 'set +a'
      ;;
    *) cat "$f" ;;
    esac
  done
} | ssh -o BatchMode=yes "$destination" 'f=$(mktemp) && cat >"$f" && bash -l "$f" </dev/null; rc=$?; rm -f "$f"; exit $rc'
