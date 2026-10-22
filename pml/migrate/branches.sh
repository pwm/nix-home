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
# changes is reported and not recreated. An existing destination path is
# accepted only as a linked worktree of the same repository, on the requested
# branch at that branch's commit; anything else is refused and left as it is.
# Recreated worktrees are checkouts only: prepare them with
# scripts/worktree.py ... setup before using them. A repeat run with nothing new
# to send only compares the branches.
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
  for r in "${refs[@]}"; do printf '%s %s\n' "$r" "$(git -C "$src" rev-parse "refs/heads/$r")"; done >"$tmp/refs"
  if [[ $(git -C "$src" rev-list --count "${refs[@]/#/refs/heads/}" "${base[@]}") == 0 ]]; then
    echo "nothing new to send: the destination has every commit; comparing the branches"
  else
    git -C "$src" bundle create -q "$tmp/move.bundle" "${refs[@]/#/refs/heads/}" "${base[@]}"
    remote_bundle=$(on_dest "mktemp")
    on_dest_in "cat > $(q "$remote_bundle")" <"$tmp/move.bundle"
    on_dest_in "set -euo pipefail; cd $(q "$dest"); b=$(q "$remote_bundle"); trap 'rm -f \"\$b\"' EXIT
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
  fi
  mismatch=0
  while read -r name sha; do
    got=$(on_dest "git -C $(q "$dest") rev-parse --verify --quiet $(q "refs/heads/$name")") || got=missing
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
  wt=$dest/.worktrees/$name
  if on_dest "test -e $(q "$wt") || test -L $(q "$wt")"; then
    # The path must be its own worktree (not a folder inside the main checkout)
    # of this repository, on the branch, at the branch's commit.
    if on_dest "cd $(q "$wt") 2>/dev/null &&
      [[ \$(git rev-parse --show-toplevel 2>/dev/null) == \$(pwd -P) ]] &&
      [[ \$(git rev-parse --path-format=absolute --git-common-dir) == \$(git -C $(q "$dest") rev-parse --path-format=absolute --git-common-dir) ]] &&
      [[ \$(git symbolic-ref --short HEAD 2>/dev/null) == $(q "$branch") ]] &&
      [[ \$(git rev-parse HEAD) == \$(git -C $(q "$dest") rev-parse $(q "refs/heads/$branch")) ]]"; then
      echo "already there: .worktrees/$name on $branch"
      continue
    fi
    die "$wt exists on the destination but is not this repository's worktree on $branch at its commit; left as it is"
  fi
  on_dest "git -C $(q "$dest") worktree add -q $(q ".worktrees/$name") $(q "$branch")"
  echo "recreated .worktrees/$name on $branch (not set up)"
done
