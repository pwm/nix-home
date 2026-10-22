# shellcheck shell=bash
# Shared helpers for the migration scripts. They run on the old machine (the
# source) and write to the new server (the destination) over SSH. With DEST_SSH
# empty, the destination is a directory on this machine; the offline checks use
# that.

# The settings file supplies DEST_HOME and the rest unless DEST_HOME is set
# already (the offline checks set everything themselves).
if [[ -z ${DEST_HOME-} && -f ${DEVSERVER_CONFIG:-$HOME/.config/devserver.env} ]]; then
  set -a
  # shellcheck source=/dev/null
  . "${DEVSERVER_CONFIG:-$HOME/.config/devserver.env}"
  set +a
fi
: "${SRC_HOME:=$HOME}"
: "${DEST_HOME:?set DEST_HOME, the account home on the new server (for example /home/me)}"
DEST_SSH=${DEST_SSH-}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

step() { printf '\n== %s\n' "$*"; }

q() { printf '%q' "$1"; }

# Run a Bash command on the destination with no standard input. ssh reads its
# standard input even when the remote command does not, so a call inside a
# `while read` loop would otherwise swallow the rest of the loop's input.
on_dest() {
  if [[ -n $DEST_SSH ]]; then
    ssh -n -o BatchMode=yes "$DEST_SSH" "bash -c $(q "$1")"
  else
    bash -c "$1" </dev/null
  fi
}

# The same, passing this script's standard input to the command.
on_dest_in() {
  if [[ -n $DEST_SSH ]]; then
    ssh -o BatchMode=yes "$DEST_SSH" "bash -c $(q "$1")"
  else
    bash -c "$1"
  fi
}

# The folder name Claude Code and OMP derive from a path: every character other
# than a letter or a digit becomes '-'.
path_key() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

homes_differ() { [[ $SRC_HOME != "$DEST_HOME" ]]; }

# The checkouts to move, relative to the home folder, one per word. Each must
# be a plain relative path, listed once. Claude Code and OMP name a checkout's
# folders after path_key of its path, so two checkouts whose paths differ only
# in characters other than letters and digits (work/api-server and
# work/api/server) would share them: refused too. All of this is checked before
# anything is copied.
need_projects() {
  [[ -n ${PROJECTS-} ]] || die 'set PROJECTS, the checkouts to move relative to the home folder (for example "work/app work/tools")'
  local list i j
  read -ra list <<<"$PROJECTS"
  ((${#list[@]} > 0)) || die "PROJECTS names no checkout"
  for ((i = 0; i < ${#list[@]}; i++)); do
    case /${list[i]}/ in
    //* | *//* | */./* | */../* | *[][*?]*)
      die "Nothing copied: the PROJECTS entry ${list[i]} is not a plain path relative to the home folder (no leading or trailing /, no . or .. parts, no * ? [ ])"
      ;;
    esac
    for ((j = 0; j < i; j++)); do
      [[ ${list[j]} != "${list[i]}" ]] || die "Nothing copied: PROJECTS lists ${list[i]} twice"
      [[ $(path_key "${list[j]}") != "$(path_key "${list[i]}")" ]] ||
        die "Nothing copied: the PROJECTS entries ${list[j]} and ${list[i]} would share the folder name $(path_key "/${list[i]}") that Claude Code and OMP use"
    done
  done
}

# "sha256 relative-path" lines for the regular files under DIR's ENTRIES (one
# path per line, relative to DIR), sorted bytewise so both machines agree.
hashes_src() {
  local dir=$1 entries=$2 sum=(sha256sum)
  command -v sha256sum >/dev/null || sum=(shasum -a 256)
  (cd "$dir" && while IFS= read -r e; do find "$e" -type f -print0; done <"$entries" | xargs -0 -r "${sum[@]}") |
    sed -E 's/^([0-9a-f]{64}) [ *]/\1 /' | LC_ALL=C sort
}

hashes_dest() {
  local dir=$1 entries=$2
  on_dest_in "cd $(q "$dir") && while IFS= read -r e; do find \"\$e\" -type f -print0; done | xargs -0 -r sha256sum" <"$entries" |
    sed -E 's/^([0-9a-f]{64}) [ *]/\1 /' | LC_ALL=C sort
}

# Refuse JSON Lines files whose last line is incomplete: an agent may still be
# writing them. Close it, or leave the file out.
check_complete_lines() {
  local dir=$1 entries=$2 bad
  bad=$(cd "$dir" && while IFS= read -r e; do find "$e" -type f -name '*.jsonl' -print0; done <"$entries" |
    while IFS= read -r -d '' f; do
      if [[ -s $f && $(tail -c 1 "$f" | wc -l) -eq 0 ]]; then printf '%s\n' "$f"; fi
    done)
  [[ -z $bad ]] || die "These files end in an incomplete line, so an agent may still be writing them. Close it or leave them out:
$bad"
}

# Refuse when any of ENTRIES already exists in DEST_DIR on the destination.
refuse_clashes() {
  local dest=$1 entries=$2 clash
  clash=$(on_dest_in "cd $(q "$dest") 2>/dev/null || exit 0; while IFS= read -r e; do if [[ -e \$e || -L \$e ]]; then printf '%s\n' \"\$e\"; fi; done" <"$entries")
  [[ -z $clash ]] || die "Already on the destination, so nothing was copied:
$clash"
}

# Copy ENTRIES (paths relative to SRC_DIR) into DEST_DIR on the destination.
# Nothing is copied when any entry already exists there. Every copied file's
# SHA-256 is then compared on both sides.
copy_checked() {
  local src=$1 dest=$2 entries=$3 count
  count=$(grep -c . "$entries" || true)
  [[ $count -gt 0 ]] || die "nothing to copy from $src"
  check_complete_lines "$src" "$entries"
  refuse_clashes "$dest" "$entries"
  on_dest "mkdir -p $(q "$dest")"
  (cd "$src" && COPYFILE_DISABLE=1 tar -czf - -T "$entries") | on_dest_in "cd $(q "$dest") && tar -xzpf -"
  local tmp
  tmp=$(mktemp -d)
  hashes_src "$src" "$entries" >"$tmp/src"
  hashes_dest "$dest" "$entries" >"$tmp/dest"
  if cmp -s "$tmp/src" "$tmp/dest"; then
    echo "copied $count entries, $(wc -l <"$tmp/src" | tr -d ' ') files; every SHA-256 matches"
    rm -rf "$tmp"
  else
    diff "$tmp/src" "$tmp/dest" | head -5 >&2
    rm -rf "$tmp"
    die "the copy differs from the source (see above)"
  fi
}
