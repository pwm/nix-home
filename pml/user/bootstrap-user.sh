#!/usr/bin/env bash
# The account's headless nix-home profile on the new server. Run as the account
# through pml/run-on.sh, after the server's GitHub key is on GitHub when
# NIX_HOME_URL is an SSH address. Safe to run again.
set -euo pipefail
: "${NIX_HOME_URL:?}" "${GIT_NAME:?}" "${GIT_EMAIL:?}"
NIX_HOME_REV=${NIX_HOME_REV-}

step() { printf '\n== %s\n' "$*"; }

step "nix"
nix --version

step "nix-home"
if [ ! -d "$HOME/nix-home/.git" ]; then
  git clone --quiet "$NIX_HOME_URL" "$HOME/nix-home"
fi
head=$(git -C "$HOME/nix-home" rev-parse HEAD)
if [ -n "$NIX_HOME_REV" ] && [ "$head" != "$NIX_HOME_REV" ]; then
  echo "nix-home is at $head, expected $NIX_HOME_REV" >&2
  exit 1
fi
git -C "$HOME/nix-home" log --oneline -1

step "Home Manager configuration"
cd "$HOME/nix-home"
bin/hm-install -n "$GIT_NAME" -e "$GIT_EMAIL" --headless
grep -E 'import|homeDirectory|desktop|user =' "$HOME/.config/home-manager/home.nix"

step "build without activating"
bin/hm-run home-manager build
readlink -f result

step "activate"
bin/hm-run home-manager switch -b backup

step "installed tools"
export PATH=$HOME/.nix-profile/bin:$PATH
for tool in fish zellij nvim direnv git claude codex omp litellm; do
  printf '%-8s %s\n' "$tool" "$(command -v "$tool" || echo missing)"
done
claude --version
codex --version
omp --version

step "done"
