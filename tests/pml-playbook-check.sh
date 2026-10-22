#!/usr/bin/env bash
# Offline controls for the PML server playbook (pml/): every script's syntax
# and lint (with shellcheck, where installed), the settings example, OMP's bank names,
# and the migration scripts run for real against fake home folders on this
# machine, twice: with DEST_SSH empty (local folders) and through a stand-in ssh
# that reads its standard input like ssh does. run-on.sh and user/agents.sh run
# with stand-in ssh, claude, codex and direnv. Nothing connects anywhere.
# Run: tests/pml-playbook-check.sh
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
pml=$root/pml
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
# claude records its arguments; codex and direnv do nothing.
stubs=$work/stubs
mkdir -p "$stubs"
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
cat >"$stubs/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$work/claude-calls"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/codex"
printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/direnv"
chmod +x "$stubs"/*

# Runs a migration script against fake homes; sets $status and $out.
dest_ssh=""
migrate() {
  local script=$1
  shift
  set +e
  out=$(env DEST_SSH="$dest_ssh" PATH="$stubs:$PATH" PROJECT=work/pml "$@" "$pml/migrate/$script" 2>&1)
  status=$?
  set -e
}

key() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# --- syntax --------------------------------------------------------------
while IFS= read -r f; do
  ok "bash -n ${f#"$root"/}" "$(yes_if bash -n "$f")"
done < <(find "$pml" -name '*.sh' | sort)
ok "omp-bank-name.py parses" "$(yes_if python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$pml/migrate/omp-bank-name.py")"
if command -v shellcheck >/dev/null; then
  ok "shellcheck pml/ and this check" "$(cd "$root" && yes_if shellcheck -x pml/*.sh pml/*/*.sh tests/pml-playbook-check.sh)"
else
  echo "shellcheck not on PATH: skipped" >&2
fi

# --- settings example and bank names ---------------------------------------
# shellcheck disable=SC2016 # expanded by the inner Bash
ok "config.example.env sets every required setting" "$(yes_if bash -c '
  set -a; . "$1"; set +a
  for v in HOST_NAME USER_NAME DEST_SSH DEST_HOME NIX_VERSION NIX_INSTALL_SHA256 NIX_HOME_URL GIT_NAME GIT_EMAIL PROJECT PML_REPO DOCS_DIR DOCS_REPO; do
    [[ -n ${!v:-} ]] || exit 1
  done' _ "$pml/config.example.env")"
ok "omp-bank-name.py reproduces the bank name OMP created" "$(yes_if python3 "$pml/migrate/omp-bank-name.py" --self-test)"
ok "omp-bank-name.py refuses a folder name OMP may clean" \
  "$(if ! python3 "$pml/migrate/omp-bank-name.py" /x/My_Project >/dev/null 2>&1; then echo true; fi)"

# --- migrations, in both modes -------------------------------------------------
migration_suite() {
  local base=$work/$1
  dest_ssh=$2
  label="[$1] "
  mkdir -p "$base"
  # --- Claude Code ------------------------------------------------------------
  src=$base/claude-src
  dest=$base/claude-dest
  sp=$src/.claude/projects/$(key "$src/work/pml")
  dp=$dest/.claude/projects/$(key "$dest/work/pml")
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
  p3=$s3/.claude/projects/$(key "$s3/work/pml")
  mkdir -p "$p3" "$base/claude-dest-open"
  printf '{"n":1}\n{"n":2' >"$p3/open.jsonl"
  migrate claude.sh SRC_HOME="$s3" DEST_HOME="$base/claude-dest-open"
  ok "claude: refuses a transcript that ends in an incomplete line" \
    "$(yes_if test "$status" != 0 -a ! -e "$base/claude-dest-open/.claude/projects/$(key "$base/claude-dest-open/work/pml")/open.jsonl")"

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

[projects."$src/work/pml"]
trust_level = "trusted"
EOF
  cat >"$dest/.codex/config.toml" <<'EOF'
model = "old"

[mcp_servers.pml]
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
  src_bank=$(python3 "$pml/migrate/omp-bank-name.py" "$src/work/pml")
  dest_bank=$(python3 "$pml/migrate/omp-bank-name.py" "$dest/work/pml")
  mkdir -p "$sa/sessions/-work-pml/s1" "$sa/memories/mnemopi/banks/$src_bank" "$da"
  printf '{"cwd":"%s/work/pml"}\n' "$src" >"$sa/sessions/-work-pml/s1.jsonl"
  printf '{}\n' >"$sa/sessions/-work-pml/s1/child.jsonl"
  printf 'theme: dark\nnote: %s/work/pml\n' "$src" >"$sa/config.yml"
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
              [("shared prompt", f"{home}/work/pml"), ("mac prompt", f"{home}/work/pml")])
s.execute("insert into session_titles values ('s1', 'title', 1)")
s.execute("insert into session_recaps(session_id, cwd, recap, created_at) values ('s1', ?, 'recap', 1)", (f"{home}/work/pml",))
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
    "$(yes_if test "$status" = 0 -a -f "$da/sessions/-work-pml/s1.jsonl" -a -f "$da/sessions/-work-pml/s1/child.jsonl")"
  ok "omp: copies the settings with home paths rewritten" "$(yes_if grep -q "^note: $dest/work/pml" "$da/config.yml")"
  ok "omp: renames the memory bank for the destination path" \
    "$(yes_if test "$src_bank" != "$dest_bank" -a -f "$da/memories/mnemopi/banks/$dest_bank/mnemopi.db")"
  hist=$(
    python3 - "$da/history.db" "$dest" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
prompts = c.execute("select count(*) from history").fetchone()[0]
moved = c.execute("select count(*) from history where cwd = ?", (sys.argv[2] + "/work/pml",)).fetchone()[0]
titles = c.execute("select count(*) from session_titles").fetchone()[0]
recaps = c.execute("select count(*) from session_recaps where cwd = ?", (sys.argv[2] + "/work/pml",)).fetchone()[0]
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

  # --- Git branches and worktrees -------------------------------------------------
  origin=$base/origin.git
  src=$base/git-src
  dest=$base/git-dest
  git init -q --bare -b master "$origin"
  git clone -q "$origin" "$src/work/pml" 2>/dev/null
  (
    cd "$src/work/pml"
    git commit -q --allow-empty -m base
    git push -q origin master
    git commit -q --allow-empty -m "not pushed"
    git branch feature
    git branch dirty
    git worktree add -q .worktrees/clean feature
    git worktree add -q .worktrees/messy dirty
    echo change >.worktrees/messy/file
  )
  git clone -q "$origin" "$dest/work/pml" 2>/dev/null
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest"
  ok "branches: fast-forwards the checked-out branch to the unpushed commit" \
    "$(yes_if test "$status" = 0 -a "$(git -C "$dest/work/pml" rev-parse master)" = "$(git -C "$src/work/pml" rev-parse master)")"
  ok "branches: brings local-only branches at the same commit" \
    "$(yes_if test "$(git -C "$dest/work/pml" rev-parse feature 2>/dev/null)" = "$(git -C "$src/work/pml" rev-parse feature)")"
  ok "branches: compares every moved branch" "$(yes_if test "$(grep -c '^same commit there:' <<<"$out")" = 3)"
  ok "branches: recreates a clean worktree" "$(yes_if test "$(git -C "$dest/work/pml/.worktrees/clean" symbolic-ref --short HEAD 2>/dev/null)" = feature)"
  ok "branches: leaves a worktree with uncommitted changes and says so" \
    "$(if [[ ! -e $dest/work/pml/.worktrees/messy ]] && grep -q 'uncommitted changes here: .worktrees/messy' <<<"$out"; then echo true; fi)"

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
  mkdir -p "$src/.omp/agent/sessions/-work-pml" "$dest"
  printf '{}\n' >"$src/.omp/agent/sessions/-work-pml/c1.jsonl"
  printf 'theme: dark\nmnemopi:\n  llmApiKey: sk-not-real\n' >"$src/.omp/agent/config.yml"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1
  ok "omp: refuses settings that hold a credential, copying nothing" \
    "$(if [[ $status != 0 && ! -e $dest/.omp ]] && grep -q 'mnemopi.llmApiKey is a credential' <<<"$out"; then echo true; fi)"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 OMP_SETTINGS=skip
  ok "omp: with OMP_SETTINGS=skip it moves the rest and leaves the settings" \
    "$(if [[ $status == 0 && -f $dest/.omp/agent/sessions/-work-pml/c1.jsonl && ! -e $dest/.omp/agent/config.yml ]]; then echo true; fi)"

  src=$base/omp-bank-src
  dest=$base/omp-bank-dest
  mkdir -p "$src/.omp/agent/sessions/-work-pml" "$dest"
  printf '{}\n' >"$src/.omp/agent/sessions/-work-pml/b1.jsonl"
  printf 'mnemopi:\n  bank: team\n' >"$src/.omp/agent/config.yml"
  migrate omp.sh SRC_HOME="$src" DEST_HOME="$dest" IGNORE_RUNNING=1 OMP_SETTINGS=skip
  ok "omp: refuses a configured memory bank, even with OMP_SETTINGS=skip" \
    "$(if [[ $status != 0 && ! -e $dest/.omp ]] && grep -q 'non-default memory bank' <<<"$out"; then echo true; fi)"

  # A repository like PML's: .worktrees/ ignored, an unpushed commit, a branch
  # with a clean worktree. Sets src and dest.
  git_case() {
    local origin=$base/$1/origin.git
    src=$base/$1/src
    dest=$base/$1/dest
    git init -q --bare -b master "$origin"
    git clone -q "$origin" "$src/work/pml" 2>/dev/null
    (
      cd "$src/work/pml"
      printf '.worktrees/\n' >.gitignore
      git add .gitignore
      git commit -q -m base
      git push -q origin master
      git commit -q --allow-empty -m "not pushed"
      git branch feature
      git worktree add -q .worktrees/clean feature
    )
    git clone -q "$origin" "$dest/work/pml" 2>/dev/null
  }
  git_case wrong-branch
  git -C "$dest/work/pml" branch unrelated
  git -C "$dest/work/pml" worktree add -q .worktrees/clean unrelated
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  ok "branches: refuses an existing worktree on another branch and leaves it" \
    "$(if [[ $status != 0 && $(git -C "$dest/work/pml/.worktrees/clean" symbolic-ref --short HEAD) == unrelated ]] && grep -q "is not this repository's worktree" <<<"$out"; then echo true; fi)"
  git_case plain-folder
  mkdir -p "$dest/work/pml/.worktrees/clean"
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  ok "branches: refuses a plain folder where the worktree belongs" \
    "$(if [[ $status != 0 && ! -e $dest/work/pml/.worktrees/clean/.git ]] && grep -q "is not this repository's worktree" <<<"$out"; then echo true; fi)"
  git_case repeat
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  migrate branches.sh SRC_HOME="$src" DEST_HOME="$dest" WORKTREES=clean:feature
  ok "branches: a repeat run succeeds and accepts the worktree it made" \
    "$(if [[ $status == 0 ]] && grep -q 'nothing new to send' <<<"$out" && grep -q 'already there: .worktrees/clean on feature' <<<"$out"; then echo true; fi)"
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
  got=$(python3 "$pml/migrate/omp-settings.py" "$work/omp-$setting.yml" 2>&1)
  rc=$?
  set -e
  ok "omp-settings: refuses $setting as a credential" \
    "$(if [[ $rc == 1 && $got == *"credential: "*"$setting is a credential"* ]]; then echo true; fi)"
done
printf 'composer:\n  tokenRate: 1\ndisplay:\n  showTokenUsage: true\nmemory:\n  backend: "off"\nnote: |\n  token: inside a text\n' >"$work/omp-plain.yml"
ok "omp-settings: accepts settings without credentials or a bank" \
  "$(yes_if python3 "$pml/migrate/omp-settings.py" "$work/omp-plain.yml")"

# --- LiteLLM session: fresh, running and exited ----------------------------------
lit=$work/litellm
mkdir -p "$lit/bin" "$lit/home"
printf 'export ZAI_API_KEY=not-real\n' >"$lit/key"
cat >"$lit/bin/zellij" <<EOF
#!/usr/bin/env bash
case \$1 in
list-sessions) cat "$lit/sessions" 2>/dev/null ;;
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
  rm -f "$lit/calls" "$lit/listening"
  set +e
  out=$(HOME=$lit/home PATH="$lit/bin:$PATH" ZAI_KEY_FILE=$lit/key PROJECT=work/pml bash "$pml/user/litellm-session.sh" 2>&1)
  status=$?
  set -e
  calls=$(cat "$lit/calls" 2>/dev/null || true)
}
litellm_case ""
ok "litellm: starts when there is no session" "$(if [[ $status == 0 && $calls == *run* ]]; then echo true; fi)"
litellm_case $'litellm [Created 1m ago] \n'
ok "litellm: refuses a running session and starts nothing" "$(if [[ $status != 0 && $calls != *run* ]]; then echo true; fi)"
litellm_case $'litellm [Created 5m ago] (EXITED - attach to resurrect)\n'
ok "litellm: replaces an exited session after a reboot" \
  "$(if [[ $status == 0 && $calls == *"delete litellm"*run* ]]; then echo true; fi)"

# --- run-on.sh and user/agents.sh, with stand-in commands ---------------------------
printf 'GREETING="hello there"\n' >"$work/run-on.env"
cat >"$work/run-on-script.sh" <<'EOF'
echo "greeting: $GREETING"
if read -r _; then echo "stdin: open"; else echo "stdin: none"; fi
EOF
run_on_out=$(PATH="$stubs:$PATH" PML_PLAYBOOK_CONFIG=$work/run-on.env "$pml/run-on.sh" somewhere "$work/run-on-script.sh" 2>/dev/null <<<"unexpected input" || true)
ok "run-on: the script sees the settings" "$(yes_if grep -q '^greeting: hello there$' <<<"$run_on_out")"
ok "run-on: the script reads no standard input" "$(yes_if grep -q '^stdin: none$' <<<"$run_on_out")"

ah=$work/agents-home
mkdir -p "$ah/work/pml/runtime/node_modules/.bin" "$ah/.codex"
touch "$ah/work/pml/runtime/node_modules/.bin/tsx"
chmod +x "$ah/work/pml/runtime/node_modules/.bin/tsx"
printf 'model = "kept"\n\n[features]\nfast_mode = true\n' >"$ah/.codex/config.toml"
agents() {
  set +e
  out=$(HOME=$ah PATH="$stubs:$PATH" PROJECT=work/pml bash "$pml/user/agents.sh" 2>&1)
  status=$?
  set -e
}
agents
cfg=$(cat "$ah/.codex/config.toml")
ok "agents: runs" "$(yes_if test "$status" = 0)"
ok "agents: registers Claude Code's pml with its client id and callback port" \
  "$(yes_if grep -q 'mcp add-json -s user pml .*TsuQbB56IDgC3unYdbC6U0GhhOt9VOyyz5fDyKMGvI8.*8765' "$work/claude-calls")"
ok "agents: registers Claude Code's pml-local in local scope through the bridge" \
  "$(yes_if grep -q "mcp add -s local pml-local -e PML_PORT=7334 -- .* exec $ah/work/pml .*mcp-bridge.ts" "$work/claude-calls")"
# shellcheck disable=SC2016 # the literal ${MERMAID_API_KEY} is what Claude Code expands
ok "agents: keeps the Mermaid key out of Claude Code's entry" \
  "$(yes_if grep -q 'Authorization":"\${MERMAID_API_KEY}"' "$work/claude-calls")"
ok "agents: adds Codex's pml, pml-local, mermaid and the checkout's trust" \
  "$(yes_if python3 -c '
import sys, tomllib
d = tomllib.loads(open(sys.argv[1]).read())
s = d["mcp_servers"]
assert s["pml"]["oauth"]["client_id"] == "KlhMO27GsiuGJLG3xTSPgdYDCbzgiLE7zeOMUsHYorw"
assert s["pml-local"]["env"] == {"PML_PORT": "7334"} and s["pml-local"]["args"][1] == sys.argv[2]
assert s["mermaid"]["env_http_headers"] == {"Authorization": "MERMAID_API_KEY"}
assert d["projects"][sys.argv[2]]["trust_level"] == "trusted"
assert d["model"] == "kept" and d["features"]["fast_mode"] is True
' "$ah/.codex/config.toml" "$ah/work/pml")"
ok "agents: keeps a backup of Codex's previous config" "$(yes_if compgen -G "$ah/.codex/config.toml.bak-*")"
agents
ok "agents: a second run changes nothing in Codex's config" \
  "$(yes_if test "$status" = 0 -a "$cfg" = "$(cat "$ah/.codex/config.toml")" -a "$(compgen -G "$ah/.codex/config.toml.bak-*" | wc -l)" = 1)"

echo "pml playbook check: $passed passed, $failed failed"
((failed == 0))
