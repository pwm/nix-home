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
# writes. AGENTS.override.md is copied once, with this home folder's path
# rewritten to the destination's.
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

step "conversations"
entries=$(mktemp)
trap 'rm -f "$entries"' EXIT
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
  sed "s|$SRC_HOME/|$DEST_HOME/|g" "$src/AGENTS.override.md" | on_dest "mkdir -p $(q "$dest") && cat > $(q "$dest/AGENTS.override.md")"
  echo "copied AGENTS.override.md (paths under $SRC_HOME/ now under $DEST_HOME/)"
fi

step "preferences"
if [[ ! -f $src/config.toml ]]; then
  echo "no config.toml here"
  exit 0
fi
tmp=$(mktemp -d)
trap 'rm -f "$entries"; rm -rf "$tmp"' EXIT
on_dest "cat $(q "$dest/config.toml") 2>/dev/null || true" >"$tmp/dest.toml"
python3 - "$src/config.toml" "$tmp/dest.toml" "$tmp/merged.toml" "$SRC_HOME" "$DEST_HOME" <<'PY'
"""Merge Codex preferences: the source's settings, the destination's server and project sections."""
import re
import sys
import tomllib

src_path, dest_path, out_path, src_home, dest_home = sys.argv[1:]
LOCAL = re.compile(r'^\[\s*(mcp_servers|projects)\b')


def blocks(text):
    """Top-level keys, then one block per table header line."""
    pre, out, cur = [], [], None
    for line in text.splitlines(keepends=True):
        if line.startswith("["):
            cur = [line]
            out.append(cur)
        elif cur is None:
            pre.append(line)
        else:
            cur.append(line)
    return "".join(pre), ["".join(b) for b in out]


src_pre, src_blocks = blocks(open(src_path).read())
dest_pre, dest_blocks = blocks(open(dest_path).read())
keep_src = [b for b in src_blocks if not LOCAL.match(b)]
keep_dest = [b for b in dest_blocks if LOCAL.match(b)]
if src_home != dest_home:
    src_pre = src_pre.replace(src_home + "/", dest_home + "/")
    keep_src = [b.replace(src_home + "/", dest_home + "/") for b in keep_src]
parts = [src_pre.rstrip("\n") + "\n"] + ["\n" + b.rstrip("\n") + "\n" for b in keep_src + keep_dest]
merged = "".join(parts).lstrip("\n")
tomllib.loads(merged)
open(out_path, "w").write(merged)
print(f"settings blocks from here: {len(keep_src)}, server and project blocks kept there: {len(keep_dest)}, left out here: {len(src_blocks) - len(keep_src)}")
PY
backup=config.toml.bak-$(date +%F-%H%M%S)
on_dest "mkdir -p $(q "$dest") && if [[ -e $(q "$dest/config.toml") ]]; then cp -p $(q "$dest/config.toml") $(q "$dest/$backup"); fi && cat > $(q "$dest/config.toml.new") && chmod 600 $(q "$dest/config.toml.new") && mv $(q "$dest/config.toml.new") $(q "$dest/config.toml")" <"$tmp/merged.toml"
echo "wrote $dest/config.toml (a previous one is kept as $backup)"
