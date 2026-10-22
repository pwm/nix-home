#!/usr/bin/env bash
# MCP servers for Claude Code and Codex on the new server, as on the old one:
#   pml         the hosted service, with each agent's public OAuth client id
#   pml-local   the local application (scripts/local.sh, port 7334) through
#               PML's stdio bridge, entered with direnv because Node is not on
#               the plain PATH
#   Mermaid     with the key read from MERMAID_API_KEY, never written down
#   fff         file search (Claude Code)
# and the PML checkout trusted by Codex. Existing entries of the same name are
# left as they are. Run as the account through pml/run-on.sh after the agents'
# logins. The sign-ins it prints are done by hand.
set -euo pipefail
: "${PROJECT:?}"
PML_MCP_URL=${PML_MCP_URL:-https://pml.artificial.sh/mcp}
CLAUDE_CLIENT_ID=${CLAUDE_CLIENT_ID:-TsuQbB56IDgC3unYdbC6U0GhhOt9VOyyz5fDyKMGvI8}
CODEX_CLIENT_ID=${CODEX_CLIENT_ID:-KlhMO27GsiuGJLG3xTSPgdYDCbzgiLE7zeOMUsHYorw}
export PATH=$HOME/.nix-profile/bin:$PATH
checkout=$HOME/$PROJECT
direnv_bin=$(command -v direnv)
tsx=$checkout/runtime/node_modules/.bin/tsx
bridge=$checkout/runtime/mcp-bridge.ts
[ -x "$tsx" ] || {
  echo "No $tsx: run user/clone-pml.sh first" >&2
  exit 1
}

step() { printf '\n== %s\n' "$*"; }

step "Claude Code"
# Names already registered: user scope, and local scope for the checkout.
have=$(
  python3 - "$checkout" <<'PY'
import json, sys
from pathlib import Path
p = Path.home() / ".claude.json"
d = json.loads(p.read_text()) if p.exists() else {}
names = set(d.get("mcpServers") or {})
names |= {"local:" + n for n in ((d.get("projects") or {}).get(sys.argv[1]) or {}).get("mcpServers") or {}}
print(" ".join(sorted(names)))
PY
)
has() { [[ " $have " == *" $1 "* ]]; }
if has pml; then echo "pml: already there"; else
  claude mcp add-json -s user pml "{\"type\":\"http\",\"url\":\"$PML_MCP_URL\",\"oauth\":{\"clientId\":\"$CLAUDE_CLIENT_ID\",\"callbackPort\":8765}}" | tail -1
fi
if has mermaid-mcp; then echo "mermaid-mcp: already there"; else
  # shellcheck disable=SC2016 # Claude Code expands ${MERMAID_API_KEY} itself, at start
  claude mcp add-json -s user mermaid-mcp '{"type":"http","url":"https://mcp.mermaid.ai/mcp","headers":{"Authorization":"${MERMAID_API_KEY}"}}' | tail -1
fi
if has fff; then echo "fff: already there"; elif command -v fff-mcp >/dev/null; then
  claude mcp add -s user fff -- "$(command -v fff-mcp)" --no-update-check | tail -1
fi
if has local:pml-local; then echo "pml-local: already there"; else
  (cd "$checkout" && claude mcp add -s local pml-local -e PML_PORT=7334 -- "$direnv_bin" exec "$checkout" "$tsx" "$bridge" | tail -1)
fi

step "Codex"
mkdir -p "$HOME/.codex"
python3 - "$HOME/.codex/config.toml" "$PML_MCP_URL" "$CODEX_CLIENT_ID" "$direnv_bin" "$checkout" "$tsx" "$bridge" <<'PY'
"""Add the MCP sections and the checkout's trust to Codex's config.toml, keeping a backup."""
import datetime, json, os, shutil, sys, tomllib

path, url, client, direnv, checkout, tsx, bridge = sys.argv[1:]
text = open(path).read() if os.path.exists(path) else ""
have = tomllib.loads(text)
servers = have.get("mcp_servers") or {}
add = []
if "pml" not in servers:
    add.append(f'[mcp_servers.pml]\nurl = {json.dumps(url)}\n\n[mcp_servers.pml.oauth]\nclient_id = {json.dumps(client)}\ncallback_url = "http://127.0.0.1/callback"\n')
if "pml-local" not in servers:
    add.append(f'[mcp_servers.pml-local]\ncommand = {json.dumps(direnv)}\nargs = {json.dumps(["exec", checkout, tsx, bridge])}\nenv = {{ PML_PORT = "7334" }}\n')
if "mermaid" not in servers:
    add.append('[mcp_servers.mermaid]\nurl = "https://mcp.mermaid.ai/mcp"\nenv_http_headers = { Authorization = "MERMAID_API_KEY" }\n')
if checkout not in (have.get("projects") or {}):
    add.append(f'[projects.{json.dumps(checkout)}]\ntrust_level = "trusted"\n')
if not add:
    print("all sections already there")
    sys.exit(0)
new = (text.rstrip("\n") + "\n\n" if text.strip() else "") + "\n".join(add)
tomllib.loads(new)
if text:
    shutil.copy2(path, f"{path}.bak-{datetime.datetime.now():%Y-%m-%d-%H%M%S}")
with open(path, "w") as f:
    f.write(new)
os.chmod(path, 0o600)
print("added:", ", ".join(a.split("]")[0].lstrip("[") for a in add))
PY
codex mcp list 2>/dev/null | grep -E '^(Name|pml|mermaid)' || true

step "by hand"
cat <<EOF
Sign in to the hosted pml once per agent:
  Claude Code: on the Mac run 'pml-dev forward 8765', then /mcp in Claude Code here, choose pml, authenticate.
  Codex:       codex mcp login pml --scopes pml,offline_access --no-browser
               (open the link on the Mac, paste the final http://127.0.0.1/... address back)
pml-local connects while scripts/local.sh runs in $checkout.
EOF
