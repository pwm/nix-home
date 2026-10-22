#!/usr/bin/env bash
# The PML checkout and the private docs on the new server, linked as PML's
# .docs, then the first builds: runtime and Explorer packages, the Explorer
# page and the engine. Run as the account through pml/run-on.sh, after the
# server's GitHub key is on GitHub. Safe to run again. The builds take some
# minutes.
set -euo pipefail
: "${PROJECT:?}" "${PML_REPO:?}" "${DOCS_DIR:?}" "${DOCS_REPO:?}"
export PATH=$HOME/.nix-profile/bin:$PATH

step() { printf '\n== %s\n' "$*"; }

step "clones"
cd "$HOME"
[ -d "$PROJECT/.git" ] || git clone -q "$PML_REPO" "$PROJECT"
[ -d "$DOCS_DIR/.git" ] || git clone -q "$DOCS_REPO" "$DOCS_DIR"
git -C "$PROJECT" log --oneline -1
git -C "$DOCS_DIR" log --oneline -1

step ".docs link"
rel=$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$HOME/$DOCS_DIR" "$HOME/$PROJECT")
if [ -L "$PROJECT/.docs" ]; then
  [ "$(readlink "$PROJECT/.docs")" = "$rel" ] || {
    echo "$PROJECT/.docs points at $(readlink "$PROJECT/.docs"), not $rel" >&2
    exit 1
  }
elif [ -e "$PROJECT/.docs" ]; then
  echo "$PROJECT/.docs exists and is not a link" >&2
  exit 1
else
  ln -s "$rel" "$PROJECT/.docs"
fi
ls -ld "$PROJECT/.docs"

step "direnv"
cd "$HOME/$PROJECT"
direnv allow .
if [ -f .envrc.private ]; then
  echo ".envrc.private present (mode $(stat -c %a .envrc.private))"
else
  echo "No .envrc.private yet: create it by hand, mode 600, with the keys PML and the agents need (see pml/README.md)."
fi

step "first builds"
# shellcheck disable=SC2016 # expanded by the inner Bash
direnv exec . bash -c '
  set -euo pipefail
  (cd runtime && npm ci --no-audit --no-fund >/dev/null && echo "runtime packages installed")
  (cd explorer && npm ci --no-audit --no-fund >/dev/null && npm run build >/dev/null && echo "Explorer page built")
  scripts/comp.sh -s >/dev/null
  echo "engine: $(cabal --project-dir=engine list-bin pml-engine)"
'

step "done"
