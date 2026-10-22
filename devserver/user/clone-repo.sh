#!/usr/bin/env bash
# Clone a project checkout on the new server and, when the project keeps
# private documentation in a separate repository, clone that too and link it
# into the checkout. Run as the account through devserver/run-on.sh with the
# project's settings file first, after the server's GitHub key is on GitHub.
# Safe to run again. Builds belong to the project's own scripts.
#
#   REPO_URL, REPO_DIR    the repository and its folder below the home folder
#   DOCS_URL, DOCS_DIR    optional: the documentation repository and its folder
#   DOCS_LINK             optional: the link's name inside the checkout (.docs)
set -euo pipefail
: "${REPO_URL:?}" "${REPO_DIR:?}"
DOCS_URL=${DOCS_URL-}
DOCS_DIR=${DOCS_DIR-}
DOCS_LINK=${DOCS_LINK-}
given=0
for v in "$DOCS_URL" "$DOCS_DIR" "$DOCS_LINK"; do
  if [ -n "$v" ]; then given=$((given + 1)); fi
done
if [ "$given" != 0 ] && [ "$given" != 3 ]; then
  echo "Set DOCS_URL, DOCS_DIR and DOCS_LINK together, or none of them" >&2
  exit 1
fi
export PATH=$HOME/.nix-profile/bin:$PATH

step() { printf '\n== %s\n' "$*"; }

step "clone $REPO_DIR"
cd "$HOME"
[ -d "$REPO_DIR/.git" ] || git clone -q "$REPO_URL" "$REPO_DIR"
git -C "$REPO_DIR" log --oneline -1

if [ -n "$DOCS_URL" ]; then
  step "documentation $DOCS_DIR, linked as $REPO_DIR/$DOCS_LINK"
  [ -d "$DOCS_DIR/.git" ] || git clone -q "$DOCS_URL" "$DOCS_DIR"
  git -C "$DOCS_DIR" log --oneline -1
  rel=$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$HOME/$DOCS_DIR" "$HOME/$REPO_DIR")
  link=$REPO_DIR/$DOCS_LINK
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$rel" ] || {
      echo "$link points at $(readlink "$link"), not $rel" >&2
      exit 1
    }
  elif [ -e "$link" ]; then
    echo "$link exists and is not a link" >&2
    exit 1
  else
    ln -s "$rel" "$link"
  fi
  ls -ld "$link"
fi

if [ -f "$REPO_DIR/.envrc" ]; then
  step "direnv"
  (cd "$HOME/$REPO_DIR" && direnv allow .)
  echo "allowed $REPO_DIR/.envrc; private keys it reads (such as .envrc.private) are created by hand"
fi

step "done"
