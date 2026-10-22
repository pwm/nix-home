#!/usr/bin/env bash
# Copy Codex's conversations, personal instructions and preferences from this
# machine to the new server. Run on the old machine after closing Codex.
#
#   THREAD=ID   copy only this thread and the threads whose first line names it
#               (its subagents); default: every rollout under ~/.codex/sessions
#   IGNORE_RUNNING=1  copy although Codex runs here (only for threads it does
#               not write; a thread still being written is copied incomplete)
#
# Codex resumes a conversation from its rollout file alone and rebuilds its
# SQLite databases, so none are copied. auth.json is never copied: log in on
# the new server. Preferences: config.toml's own settings (model, features, TUI
# and the rest) replace the destination's, but its [mcp_servers.*] and
# [projects.*] sections never leave this machine (they can hold a token and
# this machine's paths); the destination keeps its own, which user/agents.sh
# writes. The merge is computed and checked before anything is copied, so a
# config.toml it refuses leaves the destination unchanged. AGENTS.override.md
# is copied once, with this home folder's path rewritten to the destination's.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=pml/migrate/lib.sh
. "$here/lib.sh"
THREAD=${THREAD-}
src=$SRC_HOME/.codex
dest=$DEST_HOME/.codex
[[ -d $src/sessions ]] || die "No Codex sessions at $src/sessions"
if [[ -z ${IGNORE_RUNNING-} ]] && pgrep -x codex >/dev/null 2>&1; then
  die "Codex runs on this machine; close it first (or set IGNORE_RUNNING=1 for threads it does not write)"
fi

step "preferences check"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [[ -f $src/config.toml ]]; then
  on_dest "cat $(q "$dest/config.toml") 2>/dev/null || true" >"$tmp/dest.toml"
  python3 - "$src/config.toml" "$tmp/dest.toml" "$tmp/merged.toml" "$SRC_HOME" "$DEST_HOME" <<'PY'
"""Merge Codex preferences: the source's settings, the destination's server and project tables.

Parsed TOML decides what each part holds, so indented and quoted table headers
are recognized. The merged file must parse to exactly: the destination's
mcp_servers and projects, and every other top-level key from the source. Any
other outcome (top-level dotted or inline mcp_servers/projects keys, a header
inside a multi-line string, a block that does not parse alone) is refused and
nothing is written.
"""
import sys
import tomllib

src_path, dest_path, out_path, src_home, dest_home = sys.argv[1:]
LOCAL = ("mcp_servers", "projects")


def refuse(why):
    sys.exit(f"config.toml not merged, nothing written: {why}")


def blocks(text):
    """The text before the first table header, then one block per header line."""
    pre, out, cur = [], [], None
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("["):
            cur = [line]
            out.append(cur)
        elif cur is None:
            pre.append(line)
        else:
            cur.append(line)
    return "".join(pre), ["".join(b) for b in out]


def top_keys(fragment, where):
    try:
        return set(tomllib.loads(fragment))
    except tomllib.TOMLDecodeError as e:
        refuse(f"a part of {where} does not parse on its own ({e})")


def split(text, where):
    pre, bs = blocks(text)
    if top_keys(pre, where) & set(LOCAL):
        refuse(f"{where} sets mcp_servers or projects with top-level keys; write them as [tables]")
    local, other = [], []
    for b in bs:
        keys = top_keys(b, where)
        (local if keys & set(LOCAL) else other).append(b)
    return pre, local, other


src_text = open(src_path).read()
dest_text = open(dest_path).read()
if src_home != dest_home:
    src_text = src_text.replace(src_home + "/", dest_home + "/")
src_pre, src_local, src_other = split(src_text, "this machine's config.toml")
dest_pre, dest_local, dest_other = split(dest_text, "the destination's config.toml")
parts = [src_pre.rstrip("\n") + "\n"] + ["\n" + b.rstrip("\n") + "\n" for b in src_other + dest_local]
merged = "".join(parts).lstrip("\n")
try:
    got = tomllib.loads(merged)
except tomllib.TOMLDecodeError as e:
    refuse(f"the merged file does not parse ({e})")
want_src = {k: v for k, v in tomllib.loads(src_text).items() if k not in LOCAL}
dest_parsed = tomllib.loads(dest_text)
want_dest = {k: dest_parsed[k] for k in LOCAL if k in dest_parsed}
if {k: v for k, v in got.items() if k not in LOCAL} != want_src:
    refuse("the merged settings differ from this machine's")
if {k: got[k] for k in LOCAL if k in got} != want_dest:
    refuse("the merged server or project tables differ from the destination's")
open(out_path, "w").write(merged)
print(f"settings tables from here: {len(src_other)}, server and project tables kept there: {len(dest_local)}, server and project tables left here: {len(src_local)}")
PY
else
  echo "no config.toml here"
fi

step "conversations"
entries=$tmp/entries
if [[ -n $THREAD ]]; then
  main=$(cd "$src/sessions" && find . -type f -name "rollout-*$THREAD*.jsonl" | sed 's|^\./||')
  [[ $(grep -c . <<<"$main") == 1 && -n $main ]] || die "Need exactly one rollout for thread $THREAD, found: ${main:-none}"
  echo "$main" >"$entries"
  (cd "$src/sessions" && find . -type f -name 'rollout-*.jsonl' ! -name "*$THREAD*" -print0 |
    while IFS= read -r -d '' f; do
      if head -c 8000 "$f" | head -n 1 | grep -q -- "$THREAD"; then printf '%s\n' "${f#./}"; fi
    done) >>"$entries"
  echo "thread $THREAD with $(($(wc -l <"$entries") - 1)) child threads"
else
  (cd "$src/sessions" && find . -type f -name 'rollout-*.jsonl' | sed 's|^\./||' | LC_ALL=C sort) >"$entries"
  echo "all rollouts: $(wc -l <"$entries" | tr -d ' ')"
fi
copy_checked "$src/sessions" "$dest/sessions" "$entries"

step "personal instructions"
if [[ ! -f $src/AGENTS.override.md ]]; then
  echo "no AGENTS.override.md here"
elif on_dest "test -e $(q "$dest/AGENTS.override.md")"; then
  echo "the destination already has AGENTS.override.md; left as it is"
else
  sed "s|$SRC_HOME/|$DEST_HOME/|g" "$src/AGENTS.override.md" | on_dest_in "mkdir -p $(q "$dest") && cat > $(q "$dest/AGENTS.override.md")"
  echo "copied AGENTS.override.md (paths under $SRC_HOME/ now under $DEST_HOME/)"
fi

step "preferences"
if [[ -f $tmp/merged.toml ]]; then
  backup=config.toml.bak-$(date +%F-%H%M%S)
  on_dest_in "mkdir -p $(q "$dest") && if [[ -e $(q "$dest/config.toml") ]]; then cp -p $(q "$dest/config.toml") $(q "$dest/$backup"); fi && cat > $(q "$dest/config.toml.new") && chmod 600 $(q "$dest/config.toml.new") && mv $(q "$dest/config.toml.new") $(q "$dest/config.toml")" <"$tmp/merged.toml"
  echo "wrote $dest/config.toml (a previous one is kept as $backup)"
fi
