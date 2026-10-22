#!/usr/bin/env bash
# Offline controls for the agentic dev server playbook (devserver/): every
# script's syntax and lint (with shellcheck, where installed), the settings
# example, OMP's bank names, and the migration scripts run for real against fake
# home folders on this machine, twice: with DEST_SSH empty (local folders) and
# through a stand-in ssh that reads its standard input like ssh does. run-on.sh,
# user/clone-repo.sh, user/mcp-lib.sh, user/agents.sh and
# user/litellm-session.sh run with stand-in ssh, claude, codex, direnv and
# zellij. Nothing connects anywhere.
# Run: tests/devserver-check.sh
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
ds=$root/devserver
# shellcheck source=tests/agent-stubs.sh
. "$root/tests/agent-stubs.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_AUTHOR_NAME=check GIT_AUTHOR_EMAIL=check@example.invalid GIT_COMMITTER_NAME=check GIT_COMMITTER_EMAIL=check@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

passed=0
failed=0
label=""
ok() {
  if [[ $2 == true ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $label$1" >&2
  fi
}
yes_if() { if "$@" >/dev/null 2>&1; then echo true; fi; }

# Stand-in commands. ssh runs the remote command here; like ssh, without -n it
# reads all of its standard input first, whether the command uses it or not.
# claude, codex and direnv come from tests/agent-stubs.sh; tool and fff-mcp are
# commands for MCP entries to resolve.
stubs=$work/stubs
agent_stubs "$stubs"
cat >"$stubs/ssh" <<'EOF'
#!/usr/bin/env bash
n=false
while (($# > 1)); do
  case $1 in
  -n) n=true; shift ;;
  -o) shift 2 ;;
  -*) shift ;;
  *) break ;;
  esac
done
shift
if $n; then exec bash -c "$*" </dev/null; fi
input=$(mktemp)
cat >"$input"
bash -c "$*" <"$input"
rc=$?
rm -f "$input"
exit $rc
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/tool"
printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/fff-mcp"
chmod +x "$stubs/ssh" "$stubs/tool" "$stubs/fff-mcp"

# Runs a migration script against fake homes; sets $status and $out.
dest_ssh=""
migrate() {
  local script=$1
  shift
  set +e
  out=$(env DEST_SSH="$dest_ssh" PATH="$stubs:$PATH" PROJECTS=work/app "$@" "$ds/migrate/$script" 2>&1)
  status=$?
  set -e
}

key() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# --- syntax --------------------------------------------------------------
while IFS= read -r f; do
  ok "bash -n ${f#"$root"/}" "$(yes_if bash -n "$f")"
done < <(find "$ds" -name '*.sh' | sort)
ok "omp-bank-name.py parses" "$(yes_if python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$ds/migrate/omp-bank-name.py")"
if command -v shellcheck >/dev/null; then
  ok "shellcheck devserver/ and this check" "$(cd "$root" && yes_if shellcheck -x devserver/*.sh devserver/*/*.sh tests/devserver-check.sh tests/agent-stubs.sh)"
else
  echo "shellcheck not on PATH: skipped" >&2
fi

# --- settings example and bank names ---------------------------------------
# shellcheck disable=SC2016 # expanded by the inner Bash
ok "config.example.env sets every required setting" "$(yes_if bash -c '
  set -a; . "$1"; set +a
  for v in HOST_NAME USER_NAME DEST_SSH DEST_HOME NIX_VERSION NIX_INSTALL_SHA256 NIX_HOME_URL GIT_NAME GIT_EMAIL PROJECTS WORKTREES_DIR ZAI_KEY_FILE; do
    [[ -n ${!v:-} ]] || exit 1
  done' _ "$ds/config.example.env")"
ok "omp-bank-name.py reproduces the bank name OMP created" "$(yes_if python3 "$ds/migrate/omp-bank-name.py" --self-test)"
ok "omp-bank-name.py refuses a folder name OMP may clean" \
  "$(if ! python3 "$ds/migrate/omp-bank-name.py" /x/My_Project >/dev/null 2>&1; then echo true; fi)"

# --- migrations, in both modes -------------------------------------------------
migration_suite() {
  local base=$work/$1
  dest_ssh=$2
  label="[$1] "
  mkdir -p "$base"
  # --- Claude Code ------------------------------------------------------------
  src=$base/claude-src
  dest=$base/claude-dest
  sp=$src/.claude/projects/$(key "$src/work/app")
  dp=$dest/.claude/projects/$(key "$dest/work/app")
  mkdir -p "$sp/a1/subagents" "$sp/memory" "$dest"
  printf '{"n":1}\n' >"$sp/a1.jsonl"
  printf '{"n":2}\n' >"$sp/a1/subagents/s.jsonl"
  printf '{"n":3}\n' >"$sp/b2.jsonl"
  printf '{"n":4}\n' >"$sp/run9.jsonl"
  printf 'index\n' >"$sp/memory/MEMORY.md"
  printf 'fact\n' >"$sp/memory/fact.md"
  printf '{"cleanupPeriodDays": 3650, "env": {"ANTHROPIC_API_KEY": "sk-not-real"}, "apiKeyHelper": "/x"}\n' >"$src/.claude/settings.json"

  migrate claude.sh SRC_HOME="$src" DEST_HOME="$dest" EXCLUDE=run9
  ok "claude: copies conversations, their folders and memory" \
    "$(yes_if test "$status" = 0 -a -f "$dp/a1.jsonl" -a -f "$dp/a1/subagents/s.jsonl" -a -f "$dp/b2.jsonl" -a -f "$dp/memory/fact.md")"
  ok "claude: reports matching hashes" "$(yes_if grep -q 'every SHA-256 matches' <<<"$out")"
  ok "claude: leaves out the excluded conversation" "$(yes_if test ! -e "$dp/run9.jsonl")"
  ok "claude: copies settings before any transcript" \
    "$(yes_if python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))["cleanupPeriodDays"] == 3650' "$dest/.claude/settings.json")"
  ok "claude: leaves credential settings behind" \
    "$(if ! grep -q -e sk-not-real -e apiKeyHelper "$dest/.claude/settings.json"; then echo true; fi)"
  ok "claude: names the destination folder after the destination path" "$(yes_if test "$sp" != "$dp" -a -d "$dp")"
  migrate claude.sh SRC_HOME="$src" DEST_HOME="$dest"
  ok "claude: refuses when entries are already there" "$(yes_if test "$status" != 0 -a ! -e "$dp/run9.jsonl")"
  migrate claude.sh SRC_HOME="$src" DEST_HOME="$dest" ONLY=run9
  ok "claude: ONLY copies just that conversation, without memory" "$(yes_if test "$status" = 0 -a -f "$dp/run9.jsonl")"

  d2=$base/claude-dest-short
  mkdir -p "$d2/.claude"
  printf '{"cleanupPeriodDays": 30}\n' >"$d2/.claude/settings.json"
  migrate claude.sh SRC_HOME="$src" DEST_HOME="$d2"
  ok "claude: refuses while the destination would clean up old transcripts" \
    "$(yes_if test "$status" != 0 -a ! -d "$d2/.claude/projects")"

  s3=$base/claude-src-open
  p3=$s3/.claude/projects/$(key "$s3/work/app")
  mkdir -p "$p3" "$base/claude-dest-open"
  printf '{"n":1}\n{"n":2' >"$p3/open.jsonl"
  migrate claude.sh SRC_HOME="$s3" DEST_HOME="$base/claude-dest-open"
  ok "claude: refuses a transcript that ends in an incomplete line" \
    "$(yes_if test "$status" != 0 -a ! -e "$base/claude-dest-open/.claude/projects/$(key "$base/claude-dest-open/work/app")/open.jsonl")"

  # Two checkouts: a clash in either stops both before any copy; then both move.
  src=$base/claude-two-src
  dest=$base/claude-two-dest
  for name in app two; do
    mkdir -p "$src/.claude/projects/$(key "$src/work/$name")"
    printf '{"n":1}\n' >"$src/.claude/projects/$(key "$src/work/$name")/c-$name.jsonl"
  done
  mkdir -p "$dest/.claude/projects/$(key "$dest/work/two")"
  printf '{"other":1}\n' >"$dest/.claude/projects/$(key "$dest/work/two")/c-two.jsonl"
  migrate claude.sh SRC_HOME="$src" DEST_HOME="$dest" PROJECTS="work/app work/two"
  ok "claude: a clash in the second checkout stops the first before any copy" \
    "$(if [[ $status != 0 && ! -e $dest/.claude/projects/$(key "$dest/work/app") ]] && grep -qx 'c-two.jsonl' <<<"$out"; then echo true; fi)"
  rm "$dest/.claude/projects/$(key "$dest/work/two")/c-two.jsonl"
  migrate claude.sh SRC_HOME="$src" DEST_HOME="$dest" PROJECTS="work/app work/two"
  ok "claude: moves every checkout in PROJECTS" \
    "$(yes_if test "$status" = 0 -a -f "$dest/.claude/projects/$(key "$dest/work/app")/c-app.jsonl" -a -f "$dest/.claude/projects/$(key "$dest/work/two")/c-two.jsonl")"
  migrate claude.sh SRC_HOME="$src" DEST_HOME="$base/claude-none-dest" PROJECTS=""
  ok "claude: refuses without PROJECTS" \
    "$(if [[ $status != 0 && ! -e $base/claude-none-dest ]] && grep -q 'set PROJECTS' <<<"$out"; then echo true; fi)"

  # --- Codex --------------------------------------------------------------------
  src=$base/codex-src
  dest=$base/codex-dest
  day=$src/.codex/sessions/2026/10/01
  mkdir -p "$day" "$dest/.codex"
  printf '{"id":"main-1111"}\n' >"$day/rollout-2026-10-01T10-00-00-main-1111.jsonl"
  printf '{"id":"kid-2222","parent":"main-1111"}\n' >"$day/rollout-2026-10-01T11-00-00-kid-2222.jsonl"
  printf '{"id":"other-3333"}\n' >"$day/rollout-2026-10-01T12-00-00-other-3333.jsonl"
  printf 'Read %s/.codex/AGENTS.md first.\n' "$src" >"$src/.codex/AGENTS.override.md"
  cat >"$src/.codex/config.toml" <<EOF
model = "m1"
notify = ["$src/bin/notify"]

[features]
fast_mode = true

[mcp_servers.mermaid]
url = "https://mcp.mermaid.ai/mcp"
http_headers = { Authorization = "SECRET-TOKEN" }

[projects."$src/work/app"]
trust_level = "trusted"
EOF
  cat >"$dest/.codex/config.toml" <<'EOF'
model = "old"

[mcp_servers.dest_server]
url = "https://example.invalid/mcp"
EOF
  migrate codex.sh SRC_HOME="$src" DEST_HOME="$dest" THREAD=main-1111 IGNORE_RUNNING=1
  dday=$dest/.codex/sessions/2026/10/01
  ok "codex: copies the thread and its child thread" \
    "$(yes_if test "$status" = 0 -a -f "$dday/rollout-2026-10-01T10-00-00-main-1111.jsonl" -a -f "$dday/rollout-2026-10-01T11-00-00-kid-2222.jsonl")"
  ok "codex: leaves other threads" "$(yes_if test ! -e "$dday/rollout-2026-10-01T12-00-00-other-3333.jsonl")"
  ok "codex: rewrites the home path in AGENTS.override.md" \
    "$(yes_if grep -q "^Read $dest/.codex/AGENTS.md" "$dest/.codex/AGENTS.override.md")"
  cfg=$(cat "$dest/.codex/config.toml")
  ok "codex: takes the preferences from the source" "$(yes_if grep -q '^model = "m1"' <<<"$cfg")"
  ok "codex: keeps the destination's server sections" "$(yes_if grep -q 'example.invalid' <<<"$cfg")"
  ok "codex: never copies the source's server or project sections" \
    "$(if ! grep -q -e SECRET-TOKEN -e "projects.\"$src" <<<"$cfg"; then echo true; fi)"
  ok "codex: rewrites home paths in the preferences" "$(yes_if grep -q "\"$dest/bin/notify\"" <<<"$cfg")"
  ok "codex: keeps a backup of the replaced config" "$(yes_if compgen -G "$dest/.codex/config.toml.bak-*")"

  # --- OMP ----------------------------------------------------------------------
  src=$base/omp-src
  dest=$base/omp-dest
  sa=$src/.omp/agent
  da=$dest/.omp/agent
  src_bank=$(python3 "$ds/migrate/omp-bank-name.py" "$src/work/app")
  dest_bank=$(python3 "$ds/migrate/omp-bank-name.py" "$dest/work/app")
  mkdir -p "$sa/sessions/-work-app/s1" "$sa/memories/mnemopi/banks/$src_bank" "$da"
  printf '{"cwd":"%s/work/app"}\n' "$src" >"$sa/sessions/-work-app/s1.jsonl"
  printf '{}\n' >"$sa/sessions/-work-app/s1/child.jsonl"
  printf 'theme: dark\nnote: %s/work/app\n' "$src" >"$sa/config.yml"
  python3 - "$sa" "$da" "$src" <<'PY'
import sqlite3, sys
sa, da, home = sys.argv[1:]
SCHEMA = """
create table history (id integer primary key autoincrement, prompt text not null unique, created_at integer not null, cwd text, session_id text, use_count integer default 1);
create virtual table history_fts using fts5(prompt, content='history', content_rowid='id');
create trigger history_ai after insert on history begin insert into history_fts(rowid, prompt) values (new.id, new.prompt); end;
"""
s = sqlite3.connect(f"{sa}/history.db")
s.executescript(SCHEMA + """
create table session_titles (session_id text primary key, title text not null, updated_at integer not null);
create table session_recaps (id integer primary key autoincrement, session_id text not null, cwd text not null, recap text not null, created_at integer not null);
""")
s.executemany("insert into history(prompt, created_at, cwd, session_id) values (?, 1, ?, 's1')",
              [("shared prompt", f"{home}/work/app"), ("mac prompt", f"{home}/work/app")])
s.execute("insert into session_titles values ('s1', 'title', 1)")
s.execute("insert into session_recaps(session_id, cwd, recap, created_at) values ('s1', ?, 'recap', 1)", (f"{home}/work/app",))
s.commit()
d = sqlite3.connect(f"{da}/history.db")
d.executescript(SCHEMA)
d.execute("insert into history(prompt, created_at, cwd, session_id) values ('shared prompt', 1, '/x', 'd1')")
d.commit()
PY
  python3 -c 'import sqlite3, sys; c = sqlite3.connect(sys.argv[1]); c.execute("create table facts (f text)"); c.execute("insert into facts values (\"one\")"); c.commit()' \
    "$sa/memories/mnemopi/banks/$src_bank/mnemopi.db"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1
  ok "omp: copies the project's sessions with their folders" \
    "$(yes_if test "$status" = 0 -a -f "$da/sessions/-work-app/s1.jsonl" -a -f "$da/sessions/-work-app/s1/child.jsonl")"
  ok "omp: copies the settings with home paths rewritten" "$(yes_if grep -q "^note: $dest/work/app" "$da/config.yml")"
  ok "omp: renames the memory bank for the destination path" \
    "$(yes_if test "$src_bank" != "$dest_bank" -a -f "$da/memories/mnemopi/banks/$dest_bank/mnemopi.db")"
  hist=$(
    python3 - "$da/history.db" "$dest" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
prompts = c.execute("select count(*) from history").fetchone()[0]
moved = c.execute("select count(*) from history where cwd = ?", (sys.argv[2] + "/work/app",)).fetchone()[0]
titles = c.execute("select count(*) from session_titles").fetchone()[0]
recaps = c.execute("select count(*) from session_recaps where cwd = ?", (sys.argv[2] + "/work/app",)).fetchone()[0]
fts = c.execute("select count(*) from history_fts where history_fts match 'mac'").fetchone()[0]
print(prompts, moved, titles, recaps, fts)
PY
  )
  ok "omp: merges the prompt history without repeating a shared prompt" "$(yes_if test "${hist%% *}" = 2)"
  ok "omp: rewrites history paths, adds titles, recaps and the full-text index" "$(yes_if test "$hist" = "2 1 1 1 1")"
  ok "omp: keeps a backup of the replaced history" "$(yes_if compgen -G "$da/history.db.bak-*")"
  ok "omp: does not copy agent.db" "$(yes_if test ! -e "$da/agent.db")"
  mkdir -p "$base/omp-src-bare/.omp/agent" "$base/omp-dest-bare"
  printf 'theme: dark\n' >"$base/omp-src-bare/.omp/agent/config.yml"
  migrate omp.sh SRC_HOME="$base/omp-src-bare" DEST_HOME="$base/omp-dest-bare" IGNORE_RUNNING=1
  ok "omp: without sessions it still copies the rest" \
    "$(yes_if test "$status" = 0 -a -f "$base/omp-dest-bare/.omp/agent/config.yml")"

  # Two checkouts, each with sessions and a memory bank. A bank already at the
  # destination for the second stops both before any copy; then both move.
  src=$base/omp-two-src
  dest=$base/omp-two-dest
  for name in app two; do
    bank=$(python3 "$ds/migrate/omp-bank-name.py" "$src/work/$name")
    mkdir -p "$src/.omp/agent/sessions/-work-$name" "$src/.omp/agent/memories/mnemopi/banks/$bank"
    printf '{}\n' >"$src/.omp/agent/sessions/-work-$name/$name.jsonl"
    python3 -c 'import sqlite3, sys; c = sqlite3.connect(sys.argv[1]); c.execute("create table t (x)"); c.commit()' \
      "$src/.omp/agent/memories/mnemopi/banks/$bank/mnemopi.db"
  done
  dbanks=$dest/.omp/agent/memories/mnemopi/banks
  mkdir -p "$dbanks/$(python3 "$ds/migrate/omp-bank-name.py" "$dest/work/two")"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 PROJECTS="work/app work/two"
  ok "omp: a bank already there for the second checkout stops the first before any copy" \
    "$(if [[ $status != 0 && ! -e $dest/.omp/agent/sessions ]] && grep -q 'already has the bank' <<<"$out"; then echo true; fi)"
  rm -r "$dbanks"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 PROJECTS="work/app work/two"
  ok "omp: moves the sessions and memory bank of every checkout in PROJECTS" \
    "$(yes_if test "$status" = 0 -a -f "$dest/.omp/agent/sessions/-work-app/app.jsonl" -a -f "$dest/.omp/agent/sessions/-work-two/two.jsonl" \
      -a -f "$dbanks/$(python3 "$ds/migrate/omp-bank-name.py" "$dest/work/app")/mnemopi.db" \
      -a -f "$dbanks/$(python3 "$ds/migrate/omp-bank-name.py" "$dest/work/two")/mnemopi.db")"

  # --- Git branches and worktrees -------------------------------------------------
  origin=$base/origin.git
  src=$base/git-src
  dest=$base/git-dest
  git init -q --bare -b master "$origin"
  git clone -q "$origin" "$src/work/app" 2>/dev/null
  (
    cd "$src/work/app"
    git commit -q --allow-empty -m base
    git push -q origin master
    git commit -q --allow-empty -m "not pushed"
    git branch feature
    git branch dirty
    git worktree add -q .worktrees/clean feature
    git worktree add -q .worktrees/messy dirty
    echo change >.worktrees/messy/file
  )
  git clone -q "$origin" "$dest/work/app" 2>/dev/null
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest"
  ok "branches: fast-forwards the checked-out branch to the unpushed commit" \
    "$(yes_if test "$status" = 0 -a "$(git -C "$dest/work/app" rev-parse master)" = "$(git -C "$src/work/app" rev-parse master)")"
  ok "branches: brings local-only branches at the same commit" \
    "$(yes_if test "$(git -C "$dest/work/app" rev-parse feature 2>/dev/null)" = "$(git -C "$src/work/app" rev-parse feature)")"
  ok "branches: compares every moved branch" "$(yes_if test "$(grep -c '^same commit there:' <<<"$out")" = 3)"
  ok "branches: recreates a clean worktree" "$(yes_if test "$(git -C "$dest/work/app/.worktrees/clean" symbolic-ref --short HEAD 2>/dev/null)" = feature)"
  ok "branches: leaves a worktree with uncommitted changes and says so" \
    "$(if [[ ! -e $dest/work/app/.worktrees/messy ]] && grep -q 'uncommitted changes here: .worktrees/messy' <<<"$out"; then echo true; fi)"

  # Two checkouts, worktrees under wt/. Every checkout is checked before any
  # move, WORKTREES needs a single checkout, and then both move.
  src=$base/git-two/src
  dest=$base/git-two/dest
  for name in app two; do
    git init -q --bare -b master "$base/git-two/$name.git"
    git clone -q "$base/git-two/$name.git" "$src/work/$name" 2>/dev/null
    (
      cd "$src/work/$name"
      printf 'wt/\n' >.gitignore
      git add .gitignore
      git commit -q -m base
      git push -q origin master
      git commit -q --allow-empty -m "not pushed"
      git branch side
      git worktree add -q wt/side side
    )
  done
  git clone -q "$base/git-two/app.git" "$dest/work/app" 2>/dev/null
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" PROJECTS="work/app work/two" WORKTREES_DIR=wt
  ok "branches: a missing second checkout stops the first before any move" \
    "$(if [[ $status != 0 && $(git -C "$dest/work/app" rev-parse master) != "$(git -C "$src/work/app" rev-parse master)" ]] && grep -q "No Git checkout at $dest/work/two" <<<"$out"; then echo true; fi)"
  git clone -q "$base/git-two/two.git" "$dest/work/two" 2>/dev/null
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" PROJECTS="work/app work/two" WORKTREES_DIR=wt WORKTREES=side:side
  ok "branches: refuses WORKTREES with more than one checkout" \
    "$(if [[ $status != 0 && $(git -C "$dest/work/app" rev-parse master) != "$(git -C "$src/work/app" rev-parse master)" ]] && grep -q 'WORKTREES names worktrees of one checkout' <<<"$out"; then echo true; fi)"
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" PROJECTS="work/app work/two" WORKTREES_DIR=wt
  ok "branches: moves the unpushed commits of every checkout in PROJECTS" \
    "$(yes_if test "$status" = 0 -a "$(git -C "$dest/work/app" rev-parse master)" = "$(git -C "$src/work/app" rev-parse master)" -a "$(git -C "$dest/work/two" rev-parse master)" = "$(git -C "$src/work/two" rev-parse master)")"
  ok "branches: recreates worktrees under WORKTREES_DIR in each checkout" \
    "$(yes_if test "$(git -C "$dest/work/app/wt/side" symbolic-ref --short HEAD 2>/dev/null)" = side -a "$(git -C "$dest/work/two/wt/side" symbolic-ref --short HEAD 2>/dev/null)" = side)"

  # --- review repairs: Codex headers, OMP settings, existing worktrees -----------
  src=$base/codex2-src
  dest=$base/codex2-dest
  mkdir -p "$src/.codex/sessions/2026/02/02" "$dest/.codex"
  printf '{"id":"t2-2222"}\n' >"$src/.codex/sessions/2026/02/02/rollout-2026-02-02T10-00-00-t2-2222.jsonl"
  cat >"$src/.codex/config.toml" <<'EOF'
model = "m2"

  [mcp_servers.source_private]
  url = "https://x.invalid"
  http_headers = { Authorization = "SECRET-INDENTED" }

["mcp_servers".quoted]
http_headers = { Authorization = "SECRET-QUOTED" }

[ "projects" . "/src/path" ]
trust_level = "trusted"

[features]
fast_mode = true
EOF
  cat >"$dest/.codex/config.toml" <<'EOF'
model = "old"

  [mcp_servers.dest_indented]
  url = "https://dest.invalid"

["projects"."/dest/y"]
trust_level = "trusted"
EOF
  migrate codex.sh SRC_HOME="$src" DEST_HOME="$dest" THREAD=t2-2222 IGNORE_RUNNING=1
  ok "codex: leaves indented and quoted server and project tables behind" \
    "$(if [[ $status == 0 ]] && ! grep -q -e SECRET -e /src/path "$dest/.codex/config.toml"; then echo true; fi)"
  ok "codex: keeps the destination's indented and quoted tables" \
    "$(yes_if python3 -c '
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
assert sorted(d["mcp_servers"]) == ["dest_indented"] and sorted(d["projects"]) == ["/dest/y"] and d["model"] == "m2"
' "$dest/.codex/config.toml")"

  src=$base/codex3-src
  dest=$base/codex3-dest
  mkdir -p "$src/.codex/sessions/2026/03/03" "$dest/.codex"
  printf '{"id":"t3-3333"}\n' >"$src/.codex/sessions/2026/03/03/rollout-2026-03-03T10-00-00-t3-3333.jsonl"
  printf 'model = "m3"\nmcp_servers.dotted.url = "https://d.invalid"\n' >"$src/.codex/config.toml"
  printf 'model = "old"\n' >"$dest/.codex/config.toml"
  migrate codex.sh SRC_HOME="$src" DEST_HOME="$dest" THREAD=t3-3333 IGNORE_RUNNING=1
  ok "codex: refuses top-level server keys before copying anything" \
    "$(if [[ $status != 0 && ! -d $dest/.codex/sessions && $(cat "$dest/.codex/config.toml") == 'model = "old"' ]] && grep -q 'top-level keys' <<<"$out"; then echo true; fi)"

  src=$base/omp-cred-src
  dest=$base/omp-cred-dest
  mkdir -p "$src/.omp/agent/sessions/-work-app" "$dest"
  printf '{}\n' >"$src/.omp/agent/sessions/-work-app/c1.jsonl"
  printf 'theme: dark\nmnemopi:\n  llmApiKey: sk-not-real\n' >"$src/.omp/agent/config.yml"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1
  ok "omp: refuses settings that hold a credential, copying nothing" \
    "$(if [[ $status != 0 && ! -e $dest/.omp ]] && grep -q 'mnemopi.llmApiKey is a credential' <<<"$out"; then echo true; fi)"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 OMP_SETTINGS=skip
  ok "omp: with OMP_SETTINGS=skip it moves the rest and leaves the settings" \
    "$(if [[ $status == 0 && -f $dest/.omp/agent/sessions/-work-app/c1.jsonl && ! -e $dest/.omp/agent/config.yml ]]; then echo true; fi)"

  src=$base/omp-bank-src
  dest=$base/omp-bank-dest
  mkdir -p "$src/.omp/agent/sessions/-work-app" "$dest"
  printf '{}\n' >"$src/.omp/agent/sessions/-work-app/b1.jsonl"
  printf 'mnemopi:\n  bank: team\n' >"$src/.omp/agent/config.yml"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 OMP_SETTINGS=skip
  ok "omp: refuses a configured memory bank, even with OMP_SETTINGS=skip" \
    "$(if [[ $status != 0 && ! -e $dest/.omp ]] && grep -q 'non-default memory bank' <<<"$out"; then echo true; fi)"

  # A repository with .worktrees/ ignored,, an unpushed commit, a branch
  # with a clean worktree. Sets src and dest.
  git_case() {
    local origin=$base/$1/origin.git
    src=$base/$1/src
    dest=$base/$1/dest
    git init -q --bare -b master "$origin"
    git clone -q "$origin" "$src/work/app" 2>/dev/null
    (
      cd "$src/work/app"
      printf '.worktrees/\n' >.gitignore
      git add .gitignore
      git commit -q -m base
      git push -q origin master
      git commit -q --allow-empty -m "not pushed"
      git branch feature
      git worktree add -q .worktrees/clean feature
    )
    git clone -q "$origin" "$dest/work/app" 2>/dev/null
  }
  git_case wrong-branch
  git -C "$dest/work/app" branch unrelated
  git -C "$dest/work/app" worktree add -q .worktrees/clean unrelated
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  ok "branches: refuses an existing worktree on another branch and leaves it" \
    "$(if [[ $status != 0 && $(git -C "$dest/work/app/.worktrees/clean" symbolic-ref --short HEAD) == unrelated ]] && grep -q "is not this repository's worktree" <<<"$out"; then echo true; fi)"
  git_case plain-folder
  mkdir -p "$dest/work/app/.worktrees/clean"
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  ok "branches: refuses a plain folder where the worktree belongs" \
    "$(if [[ $status != 0 && ! -e $dest/work/app/.worktrees/clean/.git ]] && grep -q "is not this repository's worktree" <<<"$out"; then echo true; fi)"
  git_case repeat
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  ok "branches: a repeat run succeeds and accepts the worktree it made" \
    "$(if [[ $status == 0 ]] && grep -q 'nothing new to send' <<<"$out" && grep -q 'already there: .worktrees/clean on feature' <<<"$out"; then echo true; fi)"

  # OMP settings the check must refuse before any destination change. Each
  # case: name, OMP_SETTINGS, config.yml text.
  omp_refusal() {
    local name=$1 mode=$2 text=$3
    src=$base/omp-$name-src
    dest=$base/omp-$name-dest
    mkdir -p "$src/.omp/agent/sessions/-work-app" "$dest/.omp/agent"
    printf '{}\n' >"$src/.omp/agent/sessions/-work-app/r1.jsonl"
    printf '%b' "$text" >"$src/.omp/agent/config.yml"
    printf 'theme: light\n' >"$dest/.omp/agent/config.yml"
    migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 OMP_SETTINGS="$mode"
    ok "omp: refuses $name settings ($mode) before any change there" \
      "$(if [[ $status != 0 && ! -e $dest/.omp/agent/sessions && $(cat "$dest/.omp/agent/config.yml") == "theme: light" ]] && grep -q 'Nothing copied' <<<"$out"; then echo true; fi)"
  }
  omp_refusal comment-parent-credential copy 'mnemopi: # memory settings\n  llmApiKey: not-real\n'
  omp_refusal root-flow-credential copy '{mnemopi: {llmApiKey: not-real}}\n'
  omp_refusal escaped-key-credential copy 'mnemopi:\n  "\\u006clmApiKey": not-real\n'
  omp_refusal comment-parent-bank skip 'mnemopi: # memory settings\n  bank: team\n'
  omp_refusal root-flow-bank skip '{mnemopi: {bank: team}}\n'
  omp_refusal multiline-bank skip 'mnemopi:\n  bank:\n    team\n'
  omp_refusal multiline-db-path copy 'mnemopi:\n  dbPath:\n    /x/custom.db\n'
  omp_refusal multiline-scoping copy 'mnemopi:\n  scoping:\n    global\n'
  omp_refusal non-utf8-comment-credential copy '# comment \xff\nmnemopi:\n  llmApiKey: not-real\n'

  # The check itself failing (here: an unreadable config.yml) stops the copy too.
  src=$base/omp-check-fails-src
  dest=$base/omp-check-fails-dest
  mkdir -p "$src/.omp/agent/sessions/-work-app" "$dest/.omp/agent"
  printf '{}\n' >"$src/.omp/agent/sessions/-work-app/e1.jsonl"
  printf 'theme: dark\n' >"$src/.omp/agent/config.yml"
  chmod 000 "$src/.omp/agent/config.yml"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1
  chmod 600 "$src/.omp/agent/config.yml"
  ok "omp: a failed settings check copies nothing" \
    "$(if [[ $status != 0 && ! -e $dest/.omp/agent/sessions ]] && grep -q 'could not be checked' <<<"$out"; then echo true; fi)"
  label=""
}
migration_suite local ""
migration_suite ssh stub-host
dest_ssh=""

# --- OMP settings check: every credential setting of OMP 18.5.1 -------------------
for setting in auth.broker.token dev.autoqaPush.token hindsight.apiToken images.urls.credentials \
  mnemopi.embeddingApiKey mnemopi.llmApiKey searxng.basicPassword searxng.token; do
  yaml=$(python3 -c '
import sys
parts = sys.argv[1].split(".")
print("\n".join("  " * i + p + ":" for i, p in enumerate(parts[:-1])) + "\n" + "  " * (len(parts) - 1) + parts[-1] + ": not-real")
' "$setting")
  printf '%s\n' "$yaml" >"$work/omp-$setting.yml"
  set +e
  got=$(python3 "$ds/migrate/omp-settings.py" "$work/omp-$setting.yml" 2>&1)
  rc=$?
  set -e
  ok "omp-settings: refuses $setting as a credential" \
    "$(if [[ $rc == 3 && $got == *"credential: "*"$setting is a credential"* ]]; then echo true; fi)"
done
printf 'composer:\n  tokenRate: 1\ndisplay:\n  showTokenUsage: true\nmemory:\n  backend: "off"\ntask:\n  overrides:\n    {}\n' >"$work/omp-plain.yml"
ok "omp-settings: accepts settings without credentials or a bank" \
  "$(yes_if python3 "$ds/migrate/omp-settings.py" "$work/omp-plain.yml")"
printf 'note: |\n  token: inside a text\n' >"$work/omp-block.yml"
set +e
got=$(python3 "$ds/migrate/omp-settings.py" "$work/omp-block.yml" 2>&1)
rc=$?
set -e
ok "omp-settings: refuses a block text it does not read" "$(if [[ $rc == 3 && $got == syntax:* ]]; then echo true; fi)"

# --- LiteLLM session: fresh, running and exited ----------------------------------
lit=$work/litellm
mkdir -p "$lit/bin" "$lit/home"
printf 'export ZAI_API_KEY=not-real\n' >"$lit/key"
cat >"$lit/bin/zellij" <<EOF
#!/usr/bin/env bash
case \$1 in
list-sessions)
  if [[ -f "$lit/listing-fails" ]]; then echo "zellij: cannot reach the server" >&2; exit 2; fi
  if [[ -s "$lit/sessions" ]]; then cat "$lit/sessions"; else echo "No active zellij sessions found." >&2; exit 1; fi
  ;;
delete-session) echo "delete \$2" >>"$lit/calls"; : >"$lit/sessions" ;;
attach) echo "attach \$*" >>"$lit/calls" ;;
-s) echo "run" >>"$lit/calls"; touch "$lit/listening" ;;
esac
EOF
cat >"$lit/bin/ss" <<EOF
#!/usr/bin/env bash
if [[ -f "$lit/listening" ]]; then echo "LISTEN 0 4096 127.0.0.1:4000 0.0.0.0:*"; fi
EOF
cat >"$lit/bin/curl" <<'EOF'
#!/usr/bin/env bash
case $* in
*liveliness*) echo '"I'"'"'m alive!"' ;;
*models*) echo '{"data": [{"id": "glm-5.3"}]}' ;;
esac
EOF
chmod +x "$lit/bin"/*
litellm_case() {
  printf '%s' "$1" >"$lit/sessions"
  rm -f "$lit/calls" "$lit/listening" "$lit/listing-fails"
  [[ -z ${2-} ]] || touch "$lit/listing-fails"
  set +e
  out=$(HOME=$lit/home PATH="$lit/bin:$PATH" ZAI_KEY_FILE=$lit/key bash "$ds/user/litellm-session.sh" 2>&1)
  status=$?
  set -e
  calls=$(cat "$lit/calls" 2>/dev/null || true)
}
litellm_case ""
ok "litellm: starts when Zellij has no sessions at all (its listing exits 1)" "$(if [[ $status == 0 && $calls == *run* ]]; then echo true; fi)"
litellm_case "" fails
ok "litellm: refuses when the sessions cannot be listed" \
  "$(if [[ $status != 0 && $calls != *run* ]] && grep -q 'Could not list the Zellij sessions' <<<"$out"; then echo true; fi)"
litellm_case $'litellm [Created 1m ago] \n'
ok "litellm: refuses a running session and starts nothing" "$(if [[ $status != 0 && $calls != *run* ]]; then echo true; fi)"
litellm_case $'litellm [Created 5m ago] (EXITED - attach to resurrect)\n'
ok "litellm: replaces an exited session after a reboot" \
  "$(if [[ $status == 0 && $calls == *"delete litellm"*run* ]]; then echo true; fi)"

set +e
out=$(env -u ZAI_KEY_FILE HOME="$lit/home" PATH="$lit/bin:$PATH" bash "$ds/user/litellm-session.sh" 2>&1)
status=$?
set -e
ok "litellm: refuses without ZAI_KEY_FILE" "$(if [[ $status != 0 ]] && grep -q 'set ZAI_KEY_FILE' <<<"$out"; then echo true; fi)"

real_zellij=$(PATH=${PATH#"$stubs:"} command -v zellij || true)
if [[ -n $real_zellij ]]; then
  mkdir -p "$lit/real-bin" "$lit/real"/{runtime,cache,config,data,sockets,home}
  cat >"$lit/real-bin/zellij" <<EOF
#!/usr/bin/env bash
if [[ \$1 == list-sessions ]]; then
  exec env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID HOME="$lit/real/home" XDG_RUNTIME_DIR="$lit/real/runtime" \\
    XDG_CACHE_HOME="$lit/real/cache" XDG_CONFIG_HOME="$lit/real/config" XDG_DATA_HOME="$lit/real/data" \\
    ZELLIJ_SOCKET_DIR="$lit/real/sockets" "$real_zellij" "\$@"
fi
"$lit/bin/zellij" "\$@"
EOF
  chmod +x "$lit/real-bin/zellij"
  rm -f "$lit/calls" "$lit/listening"
  set +e
  out=$(HOME=$lit/home PATH="$lit/real-bin:$lit/bin:$PATH" ZAI_KEY_FILE=$lit/key bash "$ds/user/litellm-session.sh" 2>&1)
  status=$?
  set -e
  calls=$(cat "$lit/calls" 2>/dev/null || true)
  ok "litellm: starts on a fresh machine, with the real Zellij's empty listing" \
    "$(if [[ $status == 0 && $calls == *run* ]]; then echo true; fi)"
else
  echo "zellij not on PATH: the real empty-listing control is skipped" >&2
fi

# --- run-on.sh, with a stand-in ssh ------------------------------------------------
printf 'GREETING="hello there"\nPLACE=config\n' >"$work/run-on.env"
printf 'PLACE="the project file"\nPROJECT_ONLY=yes\n' >"$work/project.env"
# shellcheck disable=SC2016 # the library's own "$1"
printf 'shout() { printf "%%s!\\n" "$1"; }\n' >"$work/run-on-lib.sh"
cat >"$work/run-on-script.sh" <<'EOF'
echo "greeting: $GREETING"
echo "place: $PLACE"
bash -c 'echo "exported: $PROJECT_ONLY"'
shout called
if read -r _; then echo "stdin: open"; else echo "stdin: none"; fi
EOF
run_on() {
  set +e
  run_on_out=$(PATH="$stubs:$PATH" DEVSERVER_CONFIG=$work/run-on.env "$ds/run-on.sh" "$@" 2>&1 <<<"unexpected input")
  status=$?
  set -e
}
run_on somewhere "$work/project.env" "$work/run-on-lib.sh" "$work/run-on-script.sh"
ok "run-on: the script sees the settings" "$(yes_if grep -q '^greeting: hello there$' <<<"$run_on_out")"
ok "run-on: a later settings file wins" "$(yes_if grep -q '^place: the project file$' <<<"$run_on_out")"
ok "run-on: a settings file's own settings are exported" "$(yes_if grep -q '^exported: yes$' <<<"$run_on_out")"
ok "run-on: the script calls the library sent before it" "$(yes_if grep -q '^called!$' <<<"$run_on_out")"
ok "run-on: the script reads no standard input" "$(yes_if grep -q '^stdin: none$' <<<"$run_on_out")"
run_on somewhere "$work/run-on-lib.sh" "$work/no-such-script.sh"
ok "run-on: refuses a missing file without connecting" \
  "$(if [[ $status == 2 ]] && grep -q 'No file' <<<"$run_on_out" && ! grep -q greeting <<<"$run_on_out"; then echo true; fi)"
set +e
run_on_out=$(PATH="$stubs:$PATH" DEVSERVER_CONFIG=$work/no-settings.env "$ds/run-on.sh" somewhere "$work/run-on-script.sh" 2>&1)
status=$?
set -e
ok "run-on: refuses without the settings file" \
  "$(if [[ $status == 2 ]] && grep -q 'copy devserver/config.example.env' <<<"$run_on_out"; then echo true; fi)"

# --- user/clone-repo.sh, against local repositories ---------------------------------
ch=$work/clone-home
mkdir -p "$ch"
for name in app docs; do
  git init -q --bare -b master "$work/clone-$name.git"
  git clone -q "$work/clone-$name.git" "$work/clone-$name-seed" 2>/dev/null
  (
    cd "$work/clone-$name-seed"
    if [[ $name == app ]]; then printf 'use nix\n' >.envrc && git add .envrc; fi
    git commit -q --allow-empty -m "$name base"
    git push -q origin master
  )
done
clone_repo() {
  set +e
  out=$(HOME=$ch PATH="$stubs:$PATH" REPO_URL=$work/clone-app.git REPO_DIR=work/app "$@" bash "$ds/user/clone-repo.sh" 2>&1)
  status=$?
  set -e
}
with_docs=(DOCS_URL="$work/clone-docs.git" DOCS_DIR=work/docs/app DOCS_LINK=.docs)
clone_repo env "${with_docs[@]}"
ok "clone-repo: clones the checkout and the documentation" \
  "$(yes_if test "$status" = 0 -a -d "$ch/work/app/.git" -a -d "$ch/work/docs/app/.git")"
ok "clone-repo: links the documentation into the checkout with a relative link" \
  "$(yes_if test "$(readlink "$ch/work/app/.docs")" = ../docs/app -a "$(cd "$ch/work/app/.docs" && pwd -P)" = "$(cd "$ch/work/docs/app" && pwd -P)")"
ok "clone-repo: allows the checkout's .envrc" "$(yes_if grep -q "^$ch/work/app allow \.$" "$stubs/direnv-calls")"
clone_repo env "${with_docs[@]}"
ok "clone-repo: a second run succeeds" "$(yes_if test "$status" = 0)"
rm "$ch/work/app/.docs"
ln -s ../elsewhere "$ch/work/app/.docs"
clone_repo env "${with_docs[@]}"
ok "clone-repo: refuses a documentation link that points elsewhere, and keeps it" \
  "$(if [[ $status != 0 && $(readlink "$ch/work/app/.docs") == ../elsewhere ]] && grep -q 'points at ../elsewhere' <<<"$out"; then echo true; fi)"
rm "$ch/work/app/.docs"
mkdir "$ch/work/app/.docs"
clone_repo env "${with_docs[@]}"
ok "clone-repo: refuses a folder where the documentation link belongs" \
  "$(if [[ $status != 0 && -d $ch/work/app/.docs && ! -L $ch/work/app/.docs ]] && grep -q 'is not a link' <<<"$out"; then echo true; fi)"
rm -rf "$ch"
mkdir -p "$ch"
clone_repo env DOCS_URL="$work/clone-docs.git"
ok "clone-repo: refuses part of the documentation settings before cloning" \
  "$(if [[ $status != 0 && ! -e $ch/work ]] && grep -q 'together, or none' <<<"$out"; then echo true; fi)"
clone_repo env
ok "clone-repo: without documentation settings it clones the checkout only" \
  "$(yes_if test "$status" = 0 -a -d "$ch/work/app/.git" -a ! -e "$ch/work/docs" -a ! -e "$ch/work/app/.docs")"

# --- user/mcp-lib.sh and user/agents.sh, with stand-in agents -----------------------
mh=$work/mcp-home
mkdir -p "$mh/work/app" "$mh/.codex"
printf 'model = "kept"\n\n[features]\nfast_mode = true\n' >"$mh/.codex/config.toml"
cat >"$work/mcp-calls.sh" <<'EOF'
set -euo pipefail
mcp_http alpha https://a.invalid/mcp --claude-client C1 --claude-port 8800 --codex-client X1
mcp_http beta https://b.invalid/mcp --auth-env BETA_KEY --claude-name beta-mcp
mcp_stdio gamma --scope local --project "$HOME/work/app" --env K=V --env L=W -- tool --flag
mcp_stdio delta --agents claude -- tool
mcp_trust "$HOME/work/app"
EOF
mcp_run() { # FILE...: runs the library and the files as one script, as run-on.sh does
  cat "$ds/user/mcp-lib.sh" "$@" >"$work/mcp-run.sh"
  set +e
  out=$(HOME=$mh PATH="$stubs:$PATH" PROJECTS="work/app work/two" bash "$work/mcp-run.sh" 2>&1 </dev/null)
  status=$?
  set -e
}
: >"$stubs/claude-calls"
mcp_run "$work/mcp-calls.sh"
calls=$(cat "$stubs/claude-calls")
ok "mcp-lib: runs" "$(yes_if test "$status" = 0)"
ok "mcp-lib: registers an OAuth server with Claude Code's client id and callback port" \
  "$(yes_if grep -q 'mcp add-json -s user alpha .*"clientId": "C1", "callbackPort": 8800' <<<"$calls")"
# shellcheck disable=SC2016 # the literal ${BETA_KEY} is what Claude Code expands
ok "mcp-lib: sends a key from the environment under Claude Code's own name, never its value" \
  "$(yes_if grep -q 'mcp add-json -s user beta-mcp .*"Authorization": "\${BETA_KEY}"' <<<"$calls")"
ok "mcp-lib: registers a local-scope command for its folder, with the command's full path" \
  "$(yes_if grep -qx "mcp add -s local gamma -e K=V -e L=W -- $stubs/tool --flag" <<<"$calls")"
ok "mcp-lib: --agents claude leaves Codex out" "$(yes_if grep -qx "mcp add -s user delta -- $stubs/tool" <<<"$calls")"
ok "mcp-lib: writes Codex's servers and trust, keeping its other settings" \
  "$(yes_if python3 -c '
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
s = d["mcp_servers"]
assert s["alpha"] == {"url": "https://a.invalid/mcp", "oauth": {"client_id": "X1", "callback_url": "http://127.0.0.1/callback"}}
assert s["beta"] == {"url": "https://b.invalid/mcp", "env_http_headers": {"Authorization": "BETA_KEY"}}
assert s["gamma"] == {"command": sys.argv[3], "args": ["--flag"], "env": {"K": "V", "L": "W"}}
assert "delta" not in s
assert d["projects"] == {sys.argv[2]: {"trust_level": "trusted"}}
assert d["model"] == "kept" and d["features"]["fast_mode"] is True
' "$mh/.codex/config.toml" "$mh/work/app" "$stubs/tool")"
ok "mcp-lib: keeps a backup of Codex's previous config" "$(yes_if compgen -G "$mh/.codex/config.toml.bak-*")"
cfg=$(cat "$mh/.codex/config.toml")
mcp_run "$work/mcp-calls.sh"
ok "mcp-lib: a second run calls Claude Code for nothing and changes nothing in Codex" \
  "$(yes_if test "$status" = 0 -a "$calls" = "$(cat "$stubs/claude-calls")" -a "$cfg" = "$(cat "$mh/.codex/config.toml")" -a "$(compgen -G "$mh/.codex/config.toml.bak-*" | wc -l)" = 1)"
printf 'mcp_stdio missing -- no-such-command-here\n' >"$work/mcp-missing.sh"
mcp_run "$work/mcp-missing.sh"
ok "mcp-lib: refuses a command that is not on PATH and registers nothing" \
  "$(if [[ $status != 0 && $calls == "$(cat "$stubs/claude-calls")" && $cfg == "$(cat "$mh/.codex/config.toml")" ]] && grep -q 'not on PATH' <<<"$out"; then echo true; fi)"
printf 'mcp_stdio nowhere --scope local -- tool\n' >"$work/mcp-noproject.sh"
mcp_run "$work/mcp-noproject.sh"
ok "mcp-lib: refuses local scope without a folder" \
  "$(if [[ $status == 2 && $calls == "$(cat "$stubs/claude-calls")" ]] && grep -q 'local scope needs --project' <<<"$out"; then echo true; fi)"
printf 'mcp_http odd https://o.invalid --colour blue\n' >"$work/mcp-option.sh"
mcp_run "$work/mcp-option.sh"
ok "mcp-lib: refuses an unknown option" \
  "$(if [[ $status == 2 && $calls == "$(cat "$stubs/claude-calls")" ]] && grep -q 'unknown option --colour' <<<"$out"; then echo true; fi)"

rm -rf "$mh"
mkdir -p "$mh/.codex"
printf 'model = "kept"\n' >"$mh/.codex/config.toml"
: >"$stubs/claude-calls"
mcp_run "$ds/user/agents.sh"
calls=$(cat "$stubs/claude-calls")
ok "agents: runs" "$(yes_if test "$status" = 0)"
# shellcheck disable=SC2016 # the literal ${MERMAID_API_KEY} is what Claude Code expands
ok "agents: registers Mermaid in Claude Code with the key read when it starts" \
  "$(yes_if grep -q 'mcp add-json -s user mermaid-mcp .*"Authorization": "\${MERMAID_API_KEY}"' <<<"$calls")"
ok "agents: registers fff in Claude Code only, with its full path" \
  "$(yes_if grep -qx "mcp add -s user fff -- $stubs/fff-mcp --no-update-check" <<<"$calls")"
ok "agents: adds Codex's Mermaid and trusts every checkout in PROJECTS" \
  "$(yes_if python3 -c '
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
assert sorted(d["mcp_servers"]) == ["mermaid"]
assert d["mcp_servers"]["mermaid"]["env_http_headers"] == {"Authorization": "MERMAID_API_KEY"}
assert sorted(d["projects"]) == sorted(sys.argv[2:])
assert d["model"] == "kept"
' "$mh/.codex/config.toml" "$mh/work/app" "$mh/work/two")"
cfg=$(cat "$mh/.codex/config.toml")
mcp_run "$ds/user/agents.sh"
ok "agents: a second run changes nothing" \
  "$(yes_if test "$status" = 0 -a "$calls" = "$(cat "$stubs/claude-calls")" -a "$cfg" = "$(cat "$mh/.codex/config.toml")")"

echo "devserver check: $passed passed, $failed failed"
((failed == 0))
