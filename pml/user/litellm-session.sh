#!/usr/bin/env bash
# Start the LiteLLM proxy that OMP's GLM model uses (nix-home's litellm-start,
# 127.0.0.1:4000) in a background Zellij session, `litellm`, with only
# ZAI_API_KEY taken from the key file; the other keys in it stay out. Logs go to
# ~/.local/state/litellm/litellm.log. Run as the account, directly or through
# pml/run-on.sh, also after every reboot. Sends no model request.
#
#   ZAI_KEY_FILE   the file that sets ZAI_API_KEY (default ~/$PROJECT/.envrc.private)
set -euo pipefail
: "${PROJECT:=work/pml}"
ZAI_KEY_FILE=${ZAI_KEY_FILE:-$HOME/$PROJECT/.envrc.private}
export PATH=$HOME/.nix-profile/bin:$HOME/nix-home/bin:$PATH
export ZAI_KEY_FILE
[ -r "$ZAI_KEY_FILE" ] || {
  echo "No readable $ZAI_KEY_FILE" >&2
  exit 1
}
key_set=$(bash -c 'set -a; . "$ZAI_KEY_FILE" >/dev/null 2>&1; [ -n "${ZAI_API_KEY:-}" ] && echo true || echo false')
[ "$key_set" = true ] || {
  echo "$ZAI_KEY_FILE does not set ZAI_API_KEY" >&2
  exit 1
}
if zellij list-sessions --no-formatting 2>/dev/null | grep -q '^litellm '; then
  echo "The Zellij session litellm exists already; attach with: pml-dev attach litellm" >&2
  exit 1
fi
if ss -ltn | grep -q '127.0.0.1:4000 '; then
  echo "Something listens on 127.0.0.1:4000 already" >&2
  exit 1
fi
mkdir -p "$HOME/.local/state/litellm"
chmod 700 "$HOME/.local/state/litellm"
zellij attach --create-background litellm
# shellcheck disable=SC2016 # expanded by the pane's Bash, not here
zellij -s litellm run --name litellm -- bash -c 'umask 077; ZAI_API_KEY="$(set -a; . "$ZAI_KEY_FILE" >/dev/null; printf %s "$ZAI_API_KEY")"; export ZAI_API_KEY; "$HOME/nix-home/bin/litellm-start" 2>&1 | tee -a "$HOME/.local/state/litellm/litellm.log"'
for _ in $(seq 1 90); do
  ss -ltn | grep -q '127.0.0.1:4000 ' && break
  sleep 1
done
curl -s http://127.0.0.1:4000/health/liveliness && echo
curl -s http://127.0.0.1:4000/v1/models | python3 -c 'import json, sys; print("models:", [m["id"] for m in json.load(sys.stdin).get("data", [])])'
