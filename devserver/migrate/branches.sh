#!/usr/bin/env bash
# Move the unpublished Git work of each checkout in PROJECTS to the new server:
# every local branch that no remote branch contains, the checked-out branch
# included. Run on the old machine. Each checkout must exist on the new server
# (user/clone-repo.sh) and be clean; all are checked before anything moves.
# Nothing is pushed anywhere.
#
#   WORKTREES_DIR=DIR             where linked worktrees live inside a checkout
#                                 (default: .worktrees)
#   WORKTREES="NAME:BRANCH ..."   linked worktrees to recreate as DIR/NAME, with
#                                 a single project only (default: each clean
#                                 linked worktree under DIR here whose branch moves)
#
# Uncommitted work does not move: commit it first. A worktree with uncommitted
# changes is reported and not recreated. An existing destination path is
# accepted only as a linked worktree of the same repository, on the requested
# branch at that branch's commit; anything else is refused and left as it is.
# Recreated worktrees are checkouts only: run the project's own setup in them
# before use. A repeat run with nothing new to send only compares the branches.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=devserver/migrate/lib.sh
. "$here/lib.sh"
need_projects
WORKTREES_DIR=${WORKTREES_DIR:-.worktrees}
if [[ -n ${WORKTREES-} ]] && ((${#projects[@]} != 1)); then
  die "WORKTREES names worktrees of one checkout; set PROJECTS to that one checkout"
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

step "checkouts"
for project in "${projects[@]}"; do
  src=$SRC_HOME/$project
  dest=$DEST_HOME/$project
  git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || die "No Git checkout at $src"
  on_dest "git -C $(q "$dest") rev-parse HEAD" >/dev/null || die "No Git checkout at $dest on the destination"
  on_dest "git -C $(q "$dest") symbolic-ref --short HEAD" >/dev/null || die "The destination checkout $dest is not on a branch"
  [[ -z $(on_dest "git -C $(q "$dest") status --porcelain") ]] || die "The destination checkout $dest has uncommitted changes"
  echo "$project: ready on both sides"
done

move_project() {
  local project=$1 src dest dest_head dest_branch refs=() base=() w name branch wt
  src=$SRC_HOME/$project
  dest=$DEST_HOME/$project
  dest_head=$(on_dest "git -C $(q "$dest") rev-parse HEAD")
  dest_branch=$(on_dest "git -C $(q "$dest") symbolic-ref --short HEAD")

  step "$project: branches no remote branch contains"
  while IFS= read -r b; do
    [[ -n $(git -C "$src" branch -r --contains "refs/heads/$b" 2>/dev/null) ]] || refs+=("$b")
  done < <(git -C "$src" for-each-ref --format='%(refname:short)' refs/heads)
  if ((${#refs[@]} == 0)); then
    echo "none: every branch is on a remote"
  else
    printf '%s\n' "${refs[@]}"
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
    ((mismatch == 0)) || die "Some branches of $project differ on the destination"
  fi

  step "$project: worktrees"
  local worktrees=${WORKTREES-}
  if [[ -z $worktrees ]]; then
    worktrees=$(git -C "$src" worktree list --porcelain | awk -v root="$src/$WORKTREES_DIR/" '
      /^worktree / { path = substr($0, 10) }
      /^branch /   { b = substr($0, 19); if (index(path, root) == 1) print substr(path, length(root) + 1) ":" b }')
  fi
  for w in $worktrees; do
    name=${w%%:*}
    branch=${w#*:}
    if [[ -d $src/$WORKTREES_DIR/$name && -n $(git -C "$src/$WORKTREES_DIR/$name" status --porcelain) ]]; then
      echo "not recreated, uncommitted changes here: $WORKTREES_DIR/$name"
      continue
    fi
    if ! on_dest "git -C $(q "$dest") show-ref --verify --quiet $(q "refs/heads/$branch")"; then
      echo "not recreated, branch $branch is not there: $WORKTREES_DIR/$name"
      continue
    fi
    wt=$dest/$WORKTREES_DIR/$name
    if on_dest "test -e $(q "$wt") || test -L $(q "$wt")"; then
      # The path must be its own worktree (not a folder inside the main checkout)
      # of this repository, on the branch, at the branch's commit.
      if on_dest "cd $(q "$wt") 2>/dev/null &&
        [[ \$(git rev-parse --show-toplevel 2>/dev/null) == \$(pwd -P) ]] &&
        [[ \$(git rev-parse --path-format=absolute --git-common-dir) == \$(git -C $(q "$dest") rev-parse --path-format=absolute --git-common-dir) ]] &&
        [[ \$(git symbolic-ref --short HEAD 2>/dev/null) == $(q "$branch") ]] &&
        [[ \$(git rev-parse HEAD) == \$(git -C $(q "$dest") rev-parse $(q "refs/heads/$branch")) ]]"; then
        echo "already there: $WORKTREES_DIR/$name on $branch"
        continue
      fi
      die "$wt exists on the destination but is not this repository's worktree on $branch at its commit; left as it is"
    fi
    on_dest "git -C $(q "$dest") worktree add -q $(q "$WORKTREES_DIR/$name") $(q "$branch")"
    echo "recreated $WORKTREES_DIR/$name on $branch (not set up)"
  done
}

for project in "${projects[@]}"; do
  move_project "$project"
done
