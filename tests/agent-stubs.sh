# shellcheck shell=bash
# Stand-in agent commands for the offline playbook checks, written into DIR:
#   claude   records its arguments in DIR/claude-calls, and for `mcp add` and
#            `mcp add-json` records the server's name in ~/.claude.json as
#            Claude Code does: user scope at the top, local scope under the
#            current folder's path
#   codex    does nothing
#   direnv   records its folder and arguments in DIR/direnv-calls
agent_stubs() {
  local dir=$1
  mkdir -p "$dir"
  cat >"$dir/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$dir/claude-calls"
exec python3 - "\$@" <<'PY'
import json, os, sys
from pathlib import Path
a = sys.argv[1:]
if a[:2] not in (["mcp", "add"], ["mcp", "add-json"]) or "-s" not in a:
    sys.exit(0)
i = a.index("-s")
scope, name = a[i + 1], a[i + 2]
p = Path.home() / ".claude.json"
d = json.loads(p.read_text()) if p.exists() else {}
t = d.setdefault("projects", {}).setdefault(os.getcwd(), {}) if scope == "local" else d
t.setdefault("mcpServers", {})[name] = {}
p.write_text(json.dumps(d))
PY
EOF
  printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/codex"
  cat >"$dir/direnv" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$PWD" "\$*" >>"$dir/direnv-calls"
EOF
  chmod +x "$dir/claude" "$dir/codex" "$dir/direnv"
}
