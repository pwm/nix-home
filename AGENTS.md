---
title: Working on nix-home
date: 2026-10-19
---

# Working on nix-home

These instructions apply to agents working in this repository.

## Overview

This is a Nix-based home environment configuration using [home-manager](https://nix-community.github.io/home-manager/). Package versions are pinned using [niv](https://github.com/nmattia/niv).

## Commands

Apply configuration changes:
```
hm switch
```

Update pinned packages:
```
niv update nixpkgs
niv update home-manager
hm switch
```

Update VS Code extensions (keeps existing catalogue entries, adds installed
extensions and updates pins for both platforms in `hm/programs/vscode/extensions.json`):
```
vscode-update-extensions
```
Run from the connected editor's terminal, or pass `--code PATH` to its CLI.

Bump codex to the latest upstream release (rewrites `pkgs/codex.nix`, then run `hm switch`):
```
bump-codex
```

Bump Claude Code to the latest upstream release (replaces `pkgs/claude-code-manifest.zst.json`, then run `hm switch`):
```
bump-claude
```

Format code:
```
treefmt
```

Check both platform configurations without building or activating:
```
NIXPKGS_ALLOW_UNFREE=1 nix-instantiate --eval --strict --json checks.nix
```

Build the current native Home Manager generation without activating:
```
bin/hm-run home-manager build
```

Check the `pml-dev` connection helper offline (ssh, scp and pbcopy are stubbed):
```
tests/pml-dev-check.sh
```

Check remote VS Code extension registration and the catalogue updater:
```
python3 tests/vscode-remote-check.py
tests/vscode-update-extensions-check.sh
```
The registry check accepts `--code-server PATH` to exercise the installed
server's real scanner in temporary directories, without touching a live editor.

Check the dev server playbook offline (the migration scripts run against local folders, ssh and the agent CLIs are stubbed):
```
tests/devserver-check.sh
```

## Architecture

- `default.nix` - Entry point; imports pinned nixpkgs via niv, applies overlays (VSCode, coding agents, yt-dlp pins), and passes config to `hm/`
- `hm/default.nix` - Home-manager module root; enables fonts for desktop profiles and imports home, nix, programs, and xdg submodules
- `hm/programs/` - Individual program configurations (alacritty, fish, git, neovim, vscode, etc.)
- `hm/programs/vscode/extensions.json` and `extensions.nix` - One extension catalogue and platform selection for desktop and Remote SSH; native variants share a version and have per-platform hashes
- `hm/programs/vscode-remote.nix` - Headless extension links and activation; `vscode/remote-extensions.py` preserves unrelated entries in the writable remote registry
- `hm/home/packages.nix` - List of packages to install
- `pkgs/claude-code.nix` - Installs Claude Code from the upstream release manifest `pkgs/claude-code-manifest.zst.json` by overriding the nixpkgs derivation (see readme.md, "Coding agents")
- `pkgs/codex.nix` - Builds codex from the upstream GitHub release tag by overriding the nixpkgs derivation (see readme.md, "Coding agents")
- `nix/sources.nix` - Niv-generated file for pinned dependencies (do not edit manually)
- `nix/sources.json` - Niv-managed pins (edited via `niv` commands)
- `bin/hm-run` - Wrapper that sets NIX_PATH from niv sources before running home-manager
- `pkgs/omp.nix` - Pinned official macOS/Linux binaries, with Linux-only ELF fixups
- `checks.nix` - Home Manager evaluation checks for Mac desktop, Linux headless and home/profile overrides
- `bin/hm-install` - Initial setup script requiring `-n <git_name> -e <git_email>`, with optional `--headless`; uses the actual home and checkout paths
- `bin/pml-dev` - Mac helper for the remote PML workstation (another server through `DEVSERVER_HOST` and `DEVSERVER_SESSION`): attach to its Zellij session, forward a loopback port, copy files, upload a screenshot to `~/shots` and put its server path on the clipboard for an agent prompt; `tests/pml-dev-check.sh` holds its offline controls
- `bin/pml-db` - Mac helper that serves the remote PML PostgreSQL at `127.0.0.1:15432` through the `pml-db` SSH host alias (socat, one ssh session per connection)
- `bin/pml-dash` - Mac helper that runs `~/pml-load/publish.sh` then `~/pml-load/browse.sh` on `pml-dev`, forwarding remote `127.0.0.1:8766` to the same local port
- `devserver/` - Generic playbook for setting up a new Linux server for work with coding agents and moving the work of the checkouts in `PROJECTS` there (server and account setup, clones, MCP registration functions, Git, Claude Code, Codex and OMP migration); it names no project, and each project keeps its own steps in its own repository (PML: `scripts/devserver/`); `devserver/README.md` gives the order, `tests/devserver-check.sh` its offline controls, with the stand-in agent commands of `tests/agent-stubs.sh`

## Configuration Flow

External config (user, git name/email, optional homeDirectory and desktop) is passed via `ext_config` in `~/.config/home-manager/home.nix`, which imports this repo and merges with defaults in `default.nix`. macOS defaults to desktop and `/Users/<user>`; Linux defaults to headless and `/home/<user>`. Keep shared agent package definitions and pins in one place. Mutable agent settings and credentials stay outside Home Manager. Validate both profiles when changing shared modules; native Linux builds and runtime checks still need a Linux machine.
