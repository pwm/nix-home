#!/usr/bin/env bash
# Copy Claude Code's PML state from this machine to the new server: the
# settings first, then the PML project's conversations (each transcript with
# its folder) and its memory. Run on the old machine after closing the
# sessions to copy. Login state (~/.claude.json, ~/.claude/.credentials.json)
# is never copied: log in on the new server instead.
#
#   EXCLUDE="ID ..."   conversation ids (or prefixes) to leave out, for example
#                      the session that runs this script
#   ONLY="ID ..."      copy only these conversations (and no memory), for example
#                      that session after it has ended
#   MEMORY=skip        leave the memory out (default: copy it, unless ONLY is set;
#                      refused when the destination already holds a memory file
#                      of the same name)
#
# Claude Code deletes transcripts older than `cleanupPeriodDays` (30 days by
# default) when it starts, so the destination's settings must keep at least the
# source's value before any old transcript arrives. Claude Code names a
# project's folder after the full checkout path, so a different home folder
# gives a different folder name; the transcripts themselves keep their old
# working directory and still resume. Copy into the main checkout's folder only:
# Claude Code refuses to resume a conversation that two project folders hold.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=pml/migrate/lib.sh
. "$here/lib.sh"
EXCLUDE=${EXCLUDE-}
ONLY=${ONLY-}
if [[ -n $ONLY ]]; then MEMORY=${MEMORY:-skip}; else MEMORY=${MEMORY:-copy}; fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
src_dir=$SRC_HOME/.claude/projects/$(path_key "$SRC_HOME/$PROJECT")
dest_dir=$DEST_HOME/.claude/projects/$(path_key "$DEST_HOME/$PROJECT")
[[ -d $src_dir ]] || die "No Claude Code project folder at $src_dir"

step "settings"
src_settings=$SRC_HOME/.claude/settings.json
dest_settings=$DEST_HOME/.claude/settings.json
src_days=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("cleanupPeriodDays", 30))' "$src_settings" 2>/dev/null || echo 30)
if on_dest "test -e $(q "$dest_settings")"; then
  dest_days=$(on_dest "cat $(q "$dest_settings")" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("cleanupPeriodDays", 30))')
  ((dest_days >= src_days)) ||
    die "The destination keeps transcripts for $dest_days days, the source for $src_days. Set cleanupPeriodDays to at least $src_days in $dest_settings first."
  echo "kept the destination's settings (cleanupPeriodDays $dest_days)"
elif [[ -f $src_settings ]]; then
  # Settings can carry credentials (an env block with API keys, credential
  # helpers): those keys stay behind. Home paths follow the destination.
  python3 - "$src_settings" "$SRC_HOME" "$DEST_HOME" >"$tmp/settings.json" <<'EOF'
import json, sys

src, old, new = sys.argv[1:]
d = json.load(open(src))
CREDENTIAL_KEYS = ("env", "apiKeyHelper", "awsCredentialExport", "awsAuthRefresh", "gcpAuthRefresh", "otelHeadersHelper")
dropped = [k for k in CREDENTIAL_KEYS if k in d]
for k in dropped:
    del d[k]
text = json.dumps(d, indent=2) + "\n"
if old != new:
    text = text.replace(old + "/", new + "/")
sys.stdout.write(text)
print("settings keys left out:", ", ".join(dropped) or "none", file=sys.stderr)
EOF
  on_dest_in "mkdir -p $(q "$DEST_HOME/.claude") && cat > $(q "$dest_settings")" <"$tmp/settings.json"
  echo "copied settings.json (cleanupPeriodDays $src_days)"
else
  ((src_days <= 30)) || die "No settings to copy"
  echo "no settings on either side; Claude Code's default applies"
fi

step "conversations and memory: $src_dir -> $dest_dir"
entries=$tmp/entries
: >"$entries"
excluded=0
for t in "$src_dir"/*.jsonl; do
  [[ -e $t ]] || continue
  id=$(basename "$t" .jsonl)
  skip=false
  for e in $EXCLUDE; do [[ $id == "$e"* ]] && skip=true; done
  if [[ -n $ONLY ]]; then
    skip=true
    for o in $ONLY; do [[ $id == "$o"* ]] && skip=false; done
  fi
  if $skip; then
    excluded=$((excluded + 1))
    continue
  fi
  echo "$id.jsonl" >>"$entries"
  [[ -d $src_dir/$id ]] && echo "$id" >>"$entries"
done
if [[ $MEMORY == copy && -d $src_dir/memory ]]; then
  (cd "$src_dir" && find memory -type f) >>"$entries"
fi
echo "conversations: $(grep -c '\.jsonl$' "$entries" || true), left out: $excluded, memory: $MEMORY"
copy_checked "$src_dir" "$dest_dir" "$entries"
echo "resume on the new server from ~/$PROJECT with: claude --resume <id>"
