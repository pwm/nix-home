#!/usr/bin/env bash
# Copy OMP's PML state from this machine to the new server: the project's
# sessions, the settings file, the project's mnemopi memory bank and the prompt
# history (merged into the destination's). Run on the old machine after closing
# OMP. Databases are read with SQLite's online backup, never as raw files.
#
#   IGNORE_RUNNING=1   copy although OMP runs here (its open session is then
#                      copied incomplete)
#   OMP_SETTINGS=skip  leave config.yml behind, for example when it holds a
#                      credential you will set by hand on the new machine
#
# Before anything is copied, omp-settings.py checks config.yml. It refuses a
# setting OMP marks as a credential (unless OMP_SETTINGS=skip) and any
# non-default memory bank setting (always: only the default project bank moves).
#
# Not copied: agent.db (it holds the login beside OMP's own memory pipeline),
# the memories/--<path>-- folder (OMP regenerates it from agent.db), temporary
# banks, caches and native files (they are rebuilt on the new system).
# OMP names the session folder after the checkout's path below the home folder,
# so it is the same on both machines. It names the memory bank after the full
# path (omp-bank-name.py), so a different home folder gives a different bank
# name. Each session records its full working directory: after a move to a
# different home folder, OMP resumes a copied session only interactively,
# offering to move it into the current project.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=pml/migrate/lib.sh
. "$here/lib.sh"
src=$SRC_HOME/.omp/agent
dest=$DEST_HOME/.omp/agent
[[ -d $src ]] || die "No OMP state at $src"
if [[ -z ${IGNORE_RUNNING-} ]] && pgrep -x omp >/dev/null 2>&1; then
  die "OMP runs on this machine; close it first"
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
OMP_SETTINGS=${OMP_SETTINGS:-copy}
[[ $OMP_SETTINGS == copy || $OMP_SETTINGS == skip ]] || die "OMP_SETTINGS is copy or skip"

step "settings check"
if [[ -f $src/config.yml ]]; then
  set +e
  reasons=$(python3 "$here/omp-settings.py" "$src/config.yml")
  rc=$?
  set -e
  ((rc <= 1)) || die "Nothing copied: config.yml could not be checked (exit $rc)"
  bank_reasons=$(grep -v '^credential:' <<<"$reasons" || true)
  [[ -z $bank_reasons ]] || die "Nothing copied: config.yml asks for what this migration does not move:
$bank_reasons"
  if [[ -n $reasons && $OMP_SETTINGS == copy ]]; then
    die "Nothing copied: config.yml holds credentials, which the playbook leaves for manual setup:
$reasons
Remove them from $src/config.yml, or run with OMP_SETTINGS=skip and set the settings by hand on the new machine."
  fi
  if [[ -n $reasons ]]; then echo "config.yml stays here (OMP_SETTINGS=skip): it holds credentials"; else echo "config.yml may be copied"; fi
fi

key=$(path_key "/$PROJECT")
step "sessions: sessions/$key"
: >"$tmp/entries"
[[ -d $src/sessions/$key ]] && (cd "$src/sessions/$key" && ls -A) >"$tmp/entries"
if [[ -s $tmp/entries ]]; then
  copy_checked "$src/sessions/$key" "$dest/sessions/$key" "$tmp/entries"
else
  echo "no sessions for $PROJECT here"
fi

step "settings"
if [[ $OMP_SETTINGS == skip ]]; then
  echo "left config.yml here (OMP_SETTINGS=skip)"
elif [[ -f $src/config.yml ]]; then
  if homes_differ; then sed "s|$SRC_HOME/|$DEST_HOME/|g" "$src/config.yml"; else cat "$src/config.yml"; fi >"$tmp/config.yml"
  backup=config.yml.bak-$(date +%F-%H%M%S)
  on_dest_in "mkdir -p $(q "$dest") && if [[ -e $(q "$dest/config.yml") ]]; then cp -p $(q "$dest/config.yml") $(q "$dest/$backup"); fi && cat > $(q "$dest/config.yml") && chmod 600 $(q "$dest/config.yml")" <"$tmp/config.yml"
  echo "copied config.yml (a previous one is kept as $backup)"
else
  echo "no config.yml here"
fi

# An online backup of a live SQLite database into a new file.
snapshot() {
  python3 - "$1" "$2" <<'PY'
import sqlite3, sys
src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
dst = sqlite3.connect(sys.argv[2])
src.backup(dst)
dst.close()
PY
}

step "memory bank"
src_bank=$(python3 "$here/omp-bank-name.py" "$SRC_HOME/$PROJECT")
dest_bank=$(python3 "$here/omp-bank-name.py" "$DEST_HOME/$PROJECT")
if [[ -f $src/memories/mnemopi/banks/$src_bank/mnemopi.db ]]; then
  bank_dir=$dest/memories/mnemopi/banks/$dest_bank
  on_dest "test ! -e $(q "$bank_dir")" || die "The destination already has the bank $dest_bank; nothing copied"
  snapshot "$src/memories/mnemopi/banks/$src_bank/mnemopi.db" "$tmp/bank.db"
  on_dest_in "mkdir -p $(q "$bank_dir") && cat > $(q "$bank_dir/mnemopi.db")" <"$tmp/bank.db"
  on_dest "python3 -c 'import sqlite3, sys; c = sqlite3.connect(sys.argv[1]); print(\"integrity\", c.execute(\"pragma integrity_check\").fetchone()[0])' $(q "$bank_dir/mnemopi.db")"
  echo "copied bank $src_bank as $dest_bank"
else
  echo "no memory bank $src_bank here"
fi

step "prompt history"
if [[ -f $src/history.db ]]; then
  snapshot "$src/history.db" "$tmp/history.db"
  remote_snap=$(on_dest "mktemp")
  on_dest_in "cat > $(q "$remote_snap")" <"$tmp/history.db"
  old_prefix=""
  new_prefix=""
  if homes_differ; then
    old_prefix=$SRC_HOME/
    new_prefix=$DEST_HOME/
  fi
  on_dest_in "python3 - $(q "$dest/history.db") $(q "$remote_snap") $(q "$old_prefix") $(q "$new_prefix"); rc=\$?; rm -f $(q "$remote_snap"); exit \$rc" <<'PY'
"""Merge another machine's OMP prompt history into this one's, keeping a backup."""
import datetime, os, shutil, sqlite3, sys

target, snap, old, new = sys.argv[1:]


def fix(path_expr):
    return f"replace({path_expr}, ?, ?)" if old else path_expr


if not os.path.exists(target):
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copyfile(snap, target)
    h = sqlite3.connect(target)
    with h:
        if old:
            for table in ("history", "session_recaps"):
                if h.execute("select count(*) from sqlite_master where name = ?", (table,)).fetchone()[0]:
                    h.execute(f"update {table} set cwd = replace(cwd, ?, ?)", (old, new))
    print("history: placed the copy, none was here")
else:
    h = sqlite3.connect(target, timeout=30)
    backup = sqlite3.connect(f"{target}.bak-{datetime.datetime.now():%Y-%m-%d-%H%M%S}")
    h.backup(backup)
    backup.close()
    h.execute("attach database ? as other", (snap,))
    before = h.execute("select count(*) from history").fetchone()[0]
    args = (old, new) if old else ()
    with h:
        for name, sql in h.execute("select name, sql from other.sqlite_master where name in ('session_titles', 'session_recaps', 'idx_session_recaps_session')").fetchall():
            if not h.execute("select count(*) from main.sqlite_master where name = ?", (name,)).fetchone()[0]:
                h.execute(sql)
        h.execute(f"insert or ignore into history(prompt, created_at, cwd, session_id, use_count) select prompt, created_at, {fix('cwd')}, session_id, use_count from other.history order by id", args)
        if h.execute("select count(*) from other.sqlite_master where name = 'session_titles'").fetchone()[0]:
            h.execute("insert or ignore into session_titles(session_id, title, updated_at) select session_id, title, updated_at from other.session_titles")
        if h.execute("select count(*) from other.sqlite_master where name = 'session_recaps'").fetchone()[0]:
            h.execute(f"insert into session_recaps(session_id, cwd, recap, created_at) select session_id, {fix('cwd')}, recap, created_at from other.session_recaps order by id", args)
    h.execute("detach database other")
    after = h.execute("select count(*) from history").fetchone()[0]
    print(f"history: {before} -> {after} prompts (prompts already here are not repeated); a backup is beside it")
with h:
    h.execute("insert into history_fts(history_fts) values('integrity-check')")
print("history integrity:", h.execute("pragma integrity_check").fetchone()[0], "| full-text index ok")
h.close()
PY
else
  echo "no history.db here"
fi
