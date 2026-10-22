# shellcheck shell=bash
# Functions that register MCP servers with Claude Code and Codex for the
# account, and trust a checkout in Codex. An entry that exists already under the
# same name is left as it is. devserver/run-on.sh sends this file before the
# script that calls them, for example:
#   devserver/run-on.sh devbox devserver/user/mcp-lib.sh devserver/user/agents.sh
#
#   mcp_http NAME URL [--claude-client ID [--claude-port N]] [--codex-client ID]
#            [--auth-env VAR] [--claude-name NAME] [--agents claude,codex]
#       an HTTP server, signed in with each agent's OAuth client, or sending
#       `Authorization` from the environment variable VAR (never written down)
#   mcp_stdio NAME [--scope user|local] [--project DIR] [--env KEY=VALUE]...
#             [--agents claude,codex] -- COMMAND [ARGUMENT...]
#       a local command; local scope (Claude Code) registers it for DIR only;
#       a bare COMMAND is resolved to its absolute path
#   mcp_trust DIR       Codex trusts the checkout DIR

export PATH=$HOME/.nix-profile/bin:$PATH

_mcp_claude_has() { # NAME [PROJECT_DIR]: whether Claude Code has it (local scope with a DIR)
  python3 - "$@" <<'PY'
import json, os, sys
from pathlib import Path
p = Path.home() / ".claude.json"
d = json.loads(p.read_text()) if p.exists() else {}
name = sys.argv[1]
if len(sys.argv) > 2:
    # Claude Code keys a folder by its path as the process sees it.
    projects = d.get("projects") or {}
    tables = [projects.get(k) or {} for k in {sys.argv[2], os.path.realpath(sys.argv[2])}]
    names = {n for t in tables for n in (t.get("mcpServers") or {})}
else:
    names = d.get("mcpServers") or {}
sys.exit(0 if name in names else 1)
PY
}

_mcp_codex() { # JSON: {"servers": {NAME: {...}}, "projects": [DIR]}
  mkdir -p "$HOME/.codex"
  python3 - "$HOME/.codex/config.toml" "$1" <<'PY'
"""Add MCP server sections and project trust to Codex's config.toml."""
import datetime, json, os, re, shutil, sys, tomllib

path, spec = sys.argv[1], json.loads(sys.argv[2])
text = open(path).read() if os.path.exists(path) else ""
have = tomllib.loads(text)
servers = have.get("mcp_servers") or {}
projects = have.get("projects") or {}


def key(name):
    return name if re.fullmatch(r"[A-Za-z0-9_-]+", name) else json.dumps(name)


def inline(table):
    return "{ " + ", ".join(f"{key(k)} = {json.dumps(v)}" for k, v in table.items()) + " }"


add = []
for name, s in spec.get("servers", {}).items():
    if name in servers:
        print(f"codex {name}: already there")
        continue
    lines = [f"[mcp_servers.{key(name)}]"]
    for field in ("url", "command", "args"):
        if field in s:
            lines.append(f"{field} = {json.dumps(s[field])}")
    for field in ("env", "env_http_headers"):
        if s.get(field):
            lines.append(f"{field} = {inline(s[field])}")
    block = "\n".join(lines) + "\n"
    if s.get("client_id"):
        block += f'\n[mcp_servers.{key(name)}.oauth]\nclient_id = {json.dumps(s["client_id"])}\ncallback_url = "http://127.0.0.1/callback"\n'
    add.append(block)
for d in spec.get("projects", []):
    if d in projects:
        print(f"codex trust {d}: already there")
    else:
        add.append(f'[projects.{json.dumps(d)}]\ntrust_level = "trusted"\n')
if not add:
    sys.exit(0)
new = (text.rstrip("\n") + "\n\n" if text.strip() else "") + "\n".join(add)
tomllib.loads(new)
backup = f"{path}.bak-{datetime.date.today()}"
if text and not os.path.exists(backup):
    shutil.copy2(path, backup)
with open(path, "w") as f:
    f.write(new)
os.chmod(path, 0o600)
print("codex added:", ", ".join(a.split("]")[0].lstrip("[") for a in add))
PY
}

_mcp_wants() { [[ ",$1," == *",$2,"* ]]; }

mcp_http() {
  local name=$1 url=$2 claude_client="" claude_port=8765 codex_client="" auth_env="" claude_name="" agents=claude,codex
  shift 2
  while (($#)); do
    case $1 in
    --claude-client)
      claude_client=$2
      shift 2
      ;;
    --claude-port)
      claude_port=$2
      shift 2
      ;;
    --codex-client)
      codex_client=$2
      shift 2
      ;;
    --auth-env)
      auth_env=$2
      shift 2
      ;;
    --claude-name)
      claude_name=$2
      shift 2
      ;;
    --agents)
      agents=$2
      shift 2
      ;;
    *) echo "mcp_http: unknown option $1" >&2 && return 2 ;;
    esac
  done
  claude_name=${claude_name:-$name}
  if _mcp_wants "$agents" claude; then
    if _mcp_claude_has "$claude_name"; then
      echo "claude $claude_name: already there"
    else
      local json
      # shellcheck disable=SC2016 # the "${" is text for Claude Code to expand
      json=$(python3 -c '
import json, sys
url, client, port, env = sys.argv[1:]
d = {"type": "http", "url": url}
if client:
    d["oauth"] = {"clientId": client, "callbackPort": int(port)}
if env:
    d["headers"] = {"Authorization": "${" + env + "}"}
print(json.dumps(d))' "$url" "$claude_client" "$claude_port" "$auth_env")
      claude mcp add-json -s user "$claude_name" "$json" | tail -1
    fi
  fi
  if _mcp_wants "$agents" codex; then
    _mcp_codex "$(python3 -c '
import json, sys
name, url, client, env = sys.argv[1:]
s = {"url": url}
if client:
    s["client_id"] = client
if env:
    s["env_http_headers"] = {"Authorization": env}
print(json.dumps({"servers": {name: s}}))' "$name" "$url" "$codex_client" "$auth_env")"
  fi
}

mcp_stdio() {
  local name=$1 scope=user project="" agents=claude,codex envs=()
  shift
  while (($#)); do
    case $1 in
    --scope)
      scope=$2
      shift 2
      ;;
    --project)
      project=$2
      shift 2
      ;;
    --env)
      envs+=("$2")
      shift 2
      ;;
    --agents)
      agents=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *) echo "mcp_stdio: unknown option $1" >&2 && return 2 ;;
    esac
  done
  (($#)) || {
    echo "mcp_stdio: no command for $name" >&2
    return 2
  }
  local command=$1 given=$1
  shift
  if [[ $command != */* ]]; then
    command=$(command -v "$command") || {
      echo "mcp_stdio: $given is not on PATH; $name not registered" >&2
      return 1
    }
  fi
  if [[ $scope == local && -z $project ]]; then
    echo "mcp_stdio: local scope needs --project" >&2
    return 2
  fi
  if _mcp_wants "$agents" claude; then
    if _mcp_claude_has "$name" ${project:+"$project"}; then
      echo "claude $name: already there"
    else
      local claude_env=()
      for e in "${envs[@]}"; do claude_env+=(-e "$e"); done
      (cd "${project:-$HOME}" && claude mcp add -s "$scope" "$name" "${claude_env[@]}" -- "$command" "$@" | tail -1)
    fi
  fi
  if _mcp_wants "$agents" codex; then
    _mcp_codex "$(python3 -c '
import json, sys
name, command, n_env = sys.argv[1], sys.argv[2], int(sys.argv[3])
envs = sys.argv[4:4 + n_env]
args = sys.argv[4 + n_env:]
s = {"command": command, "args": args}
if envs:
    s["env"] = dict(e.split("=", 1) for e in envs)
print(json.dumps({"servers": {name: s}}))' "$name" "$command" "${#envs[@]}" "${envs[@]}" "$@")"
  fi
}

mcp_trust() {
  _mcp_codex "$(python3 -c 'import json, sys; print(json.dumps({"projects": [sys.argv[1]]}))' "$1")"
}
