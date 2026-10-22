#!/usr/bin/env bash
# Move the PML checkout's unpublished Git work to the new server: every local
# branch that no remote branch contains, the checked-out branch included. Run
# on the old machine. The new server's checkout must exist (user/clone-pml.sh)
# and be clean. Nothing is pushed anywhere.
#
#   WORKTREES="NAME:BRANCH ..."   linked worktrees to recreate as .worktrees/NAME
#                                 (default: each clean linked worktree under
#                                 .worktrees/ here whose branch moves)
#
# Uncommitted work does not move: commit it first. A worktree with uncommitted
# changes is reported and not recreated. Recreated worktrees are checkouts
# only: prepare them with scripts/worktree.py ... setup before using them.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=pml/migrate/lib.sh
. "$here/lib.sh"
src=$SRC_HOME/$PROJECT
dest=$DEST_HOME/$PROJECT
git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || die "No Git checkout at $src"
dest_head=$(on_dest "git -C $(q "$dest") rev-parse HEAD") || die "No Git checkout at $dest on the destination"
dest_branch=$(on_dest "git -C $(q "$dest") symbolic-ref --short HEAD") || die "The destination checkout is not on a branch"
[[ -z $(on_dest "git -C $(q "$dest") status --porcelain") ]] || die "The destination checkout has uncommitted changes"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

step "branches no remote branch contains"
refs=()
while IFS= read -r b; do
  [[ -n $(git -C "$src" branch -r --contains "refs/heads/$b" 2>/dev/null) ]] || refs+=("$b")
done < <(git -C "$src" for-each-ref --format='%(refname:short)' refs/heads)
if ((${#refs[@]} == 0)); then
  echo "none: every branch is on a remote"
else
  printf '%s\n' "${refs[@]}"
  base=()
  git -C "$src" cat-file -e "$dest_head^{commit}" 2>/dev/null && base=("^$dest_head")
  git -C "$src" bundle create -q "$tmp/move.bundle" "${refs[@]/#/refs/heads/}" "${base[@]}"
  for r in "${refs[@]}"; do printf '%s %s\n' "$r" "$(git -C "$src" rev-parse "refs/heads/$r")"; done >"$tmp/refs"
  remote_bundle=$(on_dest "mktemp")
  on_dest "cat > $(q "$remote_bundle")" <"$tmp/move.bundle"
  on_dest "set -euo pipefail; cd $(q "$dest"); b=$(q "$remote_bundle"); trap 'rm -f \"\$b\"' EXIT
    git bundle verify -q \"\$b\" >/dev/null
    while read -r name sha; do
      if [[ \$name == $(q "$dest_branch") ]]; then
        git fetch -q \"\$b\" \"refs/heads/\$name:refs/playbook/incoming\"
        git merge -q --ff-only refs/playbook/incoming
        git update-ref -d refs/playbook/incoming
      elif git show-ref --verify --quiet \"refs/heads/\$name\"; then
        [[ \$(git rev-parse \"refs/heads/\$name\") == \"\$sha\" ]] || { echo \"\$name exists there at another commit\" >&2; exit 1; }
      else
        git fetch -q \"\$b\" \"refs/heads/\$name:refs/heads/\$name\"
      fi
    done" <"$tmp/refs"
  mismatch=0
  while read -r name sha; do
    got=$(on_dest "git -C $(q "$dest") rev-parse $(q "refs/heads/$name")")
    if [[ $got == "$sha" ]]; then echo "same commit there: $name ${sha:0:8}"; else
      echo "DIFFERENT there: $name (here $sha, there $got)"
      mismatch=1
    fi
  done <"$tmp/refs"
  ((mismatch == 0)) || die "Some branches differ on the destination"
fi

step "worktrees"
if [[ -z ${WORKTREES-} ]]; then
  WORKTREES=$(git -C "$src" worktree list --porcelain | awk -v root="$src/.worktrees/" '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { b = substr($0, 19); if (index(path, root) == 1) print substr(path, length(root) + 1) ":" b }')
fi
for w in $WORKTREES; do
  name=${w%%:*}
  branch=${w#*:}
  if [[ -d $src/.worktrees/$name && -n $(git -C "$src/.worktrees/$name" status --porcelain) ]]; then
    echo "not recreated, uncommitted changes here: .worktrees/$name"
    continue
  fi
  if ! on_dest "git -C $(q "$dest") show-ref --verify --quiet $(q "refs/heads/$branch")"; then
    echo "not recreated, branch $branch is not there: .worktrees/$name"
    continue
  fi
  if on_dest "test -e $(q "$dest/.worktrees/$name")"; then
    echo "already there: .worktrees/$name"
    continue
  fi
  on_dest "git -C $(q "$dest") worktree add -q $(q ".worktrees/$name") $(q "$branch")"
  echo "recreated .worktrees/$name on $branch (not set up)"
done
