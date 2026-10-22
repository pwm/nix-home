#!/usr/bin/env bash
# Offline controls for the PML add-on of the devserver playbook (pml/): every
# script's syntax and lint (with shellcheck, where installed), PML's settings
# file, and pml/mcp.sh run with stand-in claude, codex and direnv, composed as
# devserver/run-on.sh composes it. Nothing connects anywhere.
# Run: tests/pml-addon-check.sh
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
addon=$root/pml
ds=$root/devserver
# shellcheck source=tests/agent-stubs.sh
. "$root/tests/agent-stubs.sh"
# The values the checks expect, read from the file under test (not exported)
# once it is known to hold only comments and the add-on's own plain settings.
settings='REPO_URL|REPO_DIR|DOCS_URL|DOCS_DIR|DOCS_LINK|PML_MCP_URL|PML_CLAUDE_CLIENT_ID|PML_CODEX_CLIENT_ID|PML_LOCAL_PORT'
if grep -vE "^(#.*|($settings)=[^[:space:]\$\`;&|]*)?\$" "$addon/project.env" >&2; then
  echo "FAIL: pml/project.env holds more than comments and the add-on's plain settings (lines above)" >&2
  exit 1
fi
# shellcheck source=pml/project.env
. "$addon/project.env"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
failed=0
ok() {
  if [[ $2 == true ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $1" >&2
  fi
}
yes_if() { if "$@" >/dev/null 2>&1; then echo true; fi; }

stubs=$work/stubs
agent_stubs "$stubs"

# --- syntax and settings ----------------------------------------------------------
for f in "$addon"/*.sh; do
  ok "bash -n ${f#"$root"/}" "$(yes_if bash -n "$f")"
done
if command -v shellcheck >/dev/null; then
  ok "shellcheck pml/ and this check" "$(cd "$root" && yes_if shellcheck -x pml/*.sh tests/pml-addon-check.sh)"
else
  echo "shellcheck not on PATH: skipped" >&2
fi
# shellcheck disable=SC2016 # expanded by the inner Bash
ok "project.env sets every setting the add-on reads" "$(yes_if bash -c '
  set -a; . "$1"; set +a
  for v in ${2//|/ }; do
    [[ -n ${!v:-} ]] || exit 1
  done' _ "$addon/project.env" "$settings")"

# --- pml/mcp.sh, with stand-in agents ------------------------------------------------
ah=$work/home
checkout=$ah/$REPO_DIR
tsx=$checkout/runtime/node_modules/.bin/tsx
pml_mcp() {
  {
    echo 'set -a'
    cat "$addon/project.env"
    echo 'set +a'
    cat "$ds/user/mcp-lib.sh" "$addon/mcp.sh"
  } >"$work/run.sh"
  set +e
  out=$(HOME=$ah PATH="$stubs:$PATH" bash "$work/run.sh" 2>&1 </dev/null)
  status=$?
  set -e
}

mkdir -p "$checkout" "$ah/.codex"
printf 'model = "kept"\n' >"$ah/.codex/config.toml"
: >"$stubs/claude-calls"
pml_mcp
ok "mcp: refuses before pml/build.sh and registers nothing" \
  "$(if [[ $status != 0 && ! -s $stubs/claude-calls && $(cat "$ah/.codex/config.toml") == 'model = "kept"' ]] && grep -q 'run pml/build.sh first' <<<"$out"; then echo true; fi)"

mkdir -p "$(dirname "$tsx")"
printf '#!/usr/bin/env bash\n' >"$tsx"
chmod +x "$tsx"
pml_mcp
calls=$(cat "$stubs/claude-calls")
ok "mcp: runs" "$(yes_if test "$status" = 0)"
ok "mcp: registers Claude Code's pml with its client id and callback port 8765" \
  "$(yes_if grep -q "mcp add-json -s user pml .*\"url\": \"$PML_MCP_URL\".*\"clientId\": \"$PML_CLAUDE_CLIENT_ID\", \"callbackPort\": 8765" <<<"$calls")"
ok "mcp: registers Claude Code's pml-local for the checkout, through direnv and the bridge" \
  "$(yes_if grep -qx "mcp add -s local pml-local -e PML_PORT=$PML_LOCAL_PORT -- $stubs/direnv exec $checkout $tsx $checkout/runtime/mcp-bridge.ts" <<<"$calls")"
ok "mcp: Claude Code holds pml-local under the checkout only" \
  "$(yes_if python3 -c '
import json, os, sys
d = json.load(open(sys.argv[1]))
assert "pml-local" not in (d.get("mcpServers") or {})
assert "pml-local" in d["projects"][os.path.realpath(sys.argv[2])]["mcpServers"]
' "$ah/.claude.json" "$checkout")"
ok "mcp: adds Codex's pml and pml-local, keeping its other settings" \
  "$(yes_if python3 -c '
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
url, client, port, direnv, checkout, tsx = sys.argv[2:]
s = d["mcp_servers"]
assert s["pml"] == {"url": url, "oauth": {"client_id": client, "callback_url": "http://127.0.0.1/callback"}}
assert s["pml-local"] == {"command": direnv, "args": ["exec", checkout, tsx, checkout + "/runtime/mcp-bridge.ts"], "env": {"PML_PORT": port}}
assert d["model"] == "kept"
' "$ah/.codex/config.toml" "$PML_MCP_URL" "$PML_CODEX_CLIENT_ID" "$PML_LOCAL_PORT" "$stubs/direnv" "$checkout" "$tsx")"
ok "mcp: prints the sign-ins left to do" \
  "$(yes_if grep -q 'codex mcp login pml --scopes pml,offline_access --no-browser' <<<"$out")"
cfg=$(cat "$ah/.codex/config.toml")
pml_mcp
ok "mcp: a second run calls Claude Code for nothing and changes nothing in Codex" \
  "$(yes_if test "$status" = 0 -a "$calls" = "$(cat "$stubs/claude-calls")" -a "$cfg" = "$(cat "$ah/.codex/config.toml")")"

echo "pml add-on check: $passed passed, $failed failed"
((failed == 0))
