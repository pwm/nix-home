#!/usr/bin/env bash
# Personal MCP servers for Claude Code and Codex on the new server, and Codex's
# trust for each checkout in PROJECTS:
#   Mermaid   the key read from MERMAID_API_KEY when an agent starts, never
#             written down (Claude Code names it mermaid-mcp)
#   fff       file search (Claude Code), when fff-mcp is installed
# Run as the account after the agents' logins, with the functions first:
#   devserver/run-on.sh devbox devserver/user/mcp-lib.sh devserver/user/agents.sh
# A project's own servers come from its own repository's scripts, which use
# the same functions.
set -euo pipefail
: "${PROJECTS:?}"

printf '\n== personal MCP servers\n'
mcp_http mermaid https://mcp.mermaid.ai/mcp --auth-env MERMAID_API_KEY --claude-name mermaid-mcp
if command -v fff-mcp >/dev/null; then
  mcp_stdio fff --agents claude -- fff-mcp --no-update-check
fi

printf '\n== Codex trusts the checkouts\n'
for project in $PROJECTS; do
  mcp_trust "$HOME/$project"
done
codex mcp list 2>/dev/null | head -20 || true
