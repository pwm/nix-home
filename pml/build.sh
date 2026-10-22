#!/usr/bin/env bash
# PML's first builds on the new server, inside its direnv shell: the runtime
# and Explorer packages, the Explorer page and the engine. Run as the account
# after devserver/user/clone-repo.sh, with PML's settings first:
#   devserver/run-on.sh pml-dev pml/project.env pml/build.sh
# Takes some minutes. Safe to run again.
set -euo pipefail
: "${REPO_DIR:?}"
export PATH=$HOME/.nix-profile/bin:$PATH
cd "$HOME/$REPO_DIR"
if [ -f .envrc.private ]; then
  echo ".envrc.private present (mode $(stat -c %a .envrc.private))"
else
  echo "No .envrc.private yet: create it by hand, mode 600, with the keys PML and the agents need (see pml/README.md)."
fi
# shellcheck disable=SC2016 # expanded by the inner Bash
direnv exec . bash -c '
  set -euo pipefail
  (cd runtime && npm ci --no-audit --no-fund >/dev/null && echo "runtime packages installed")
  (cd explorer && npm ci --no-audit --no-fund >/dev/null && npm run build >/dev/null && echo "Explorer page built")
  scripts/comp.sh -s >/dev/null
  echo "engine: $(cabal --project-dir=engine list-bin pml-engine)"
'
