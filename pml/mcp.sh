#!/usr/bin/env bash
# PML's MCP servers for Claude Code and Codex on the new server:
#   pml         the hosted service, with each agent's public OAuth client id
#   pml-local   the local application (scripts/local.sh) through PML's stdio
#               bridge, entered with direnv because Node is not on the plain
#               PATH; Claude Code offers it only in sessions started in the
#               checkout (local scope), Codex in every folder
# Run as the account after devserver/user/clone-repo.sh and pml/build.sh, with
# the functions and PML's settings first:
#   devserver/run-on.sh pml-dev devserver/user/mcp-lib.sh pml/project.env pml/mcp.sh
set -euo pipefail
: "${REPO_DIR:?}" "${PML_MCP_URL:?}" "${PML_CLAUDE_CLIENT_ID:?}" "${PML_CODEX_CLIENT_ID:?}" "${PML_LOCAL_PORT:?}"
checkout=$HOME/$REPO_DIR
[ -x "$checkout/runtime/node_modules/.bin/tsx" ] || {
  echo "No $checkout/runtime/node_modules/.bin/tsx: run pml/build.sh first" >&2
  exit 1
}

printf '\n== PML MCP servers\n'
mcp_http pml "$PML_MCP_URL" --claude-client "$PML_CLAUDE_CLIENT_ID" --codex-client "$PML_CODEX_CLIENT_ID"
mcp_stdio pml-local --scope local --project "$checkout" --env "PML_PORT=$PML_LOCAL_PORT" -- \
  direnv exec "$checkout" "$checkout/runtime/node_modules/.bin/tsx" "$checkout/runtime/mcp-bridge.ts"

cat <<EOF

Sign in to the hosted pml once per agent, by hand:
  Claude Code: on the Mac run 'pml-dev forward 8765', then /mcp in Claude Code here, choose pml, authenticate.
  Codex:       codex mcp login pml --scopes pml,offline_access --no-browser
               (open the link on the Mac, paste the final http://127.0.0.1/... address back)
pml-local connects while scripts/local.sh runs in $checkout.
EOF
