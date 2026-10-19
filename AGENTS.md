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

Update VSCode extensions (reads installed extensions and updates `hm/programs/vscode/extensions.json`):
```
vscode-update-extensions
```

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

## Architecture

- `default.nix` - Entry point; imports pinned nixpkgs via niv, applies overlays (VSCode, coding agents, yt-dlp pins), and passes config to `hm/`
- `hm/default.nix` - Home-manager module root; enables fonts for desktop profiles and imports home, nix, programs, and xdg submodules
- `hm/programs/` - Individual program configurations (alacritty, fish, git, neovim, vscode, etc.)
- `hm/home/packages.nix` - List of packages to install
- `pkgs/claude-code.nix` - Installs Claude Code from the upstream release manifest `pkgs/claude-code-manifest.zst.json` by overriding the nixpkgs derivation (see readme.md, "Coding agents")
- `pkgs/codex.nix` - Builds codex from the upstream GitHub release tag by overriding the nixpkgs derivation (see readme.md, "Coding agents")
- `nix/sources.nix` - Niv-generated file for pinned dependencies (do not edit manually)
- `nix/sources.json` - Niv-managed pins (edited via `niv` commands)
- `bin/hm-run` - Wrapper that sets NIX_PATH from niv sources before running home-manager
- `pkgs/omp.nix` - Pinned official macOS/Linux binaries, with Linux-only ELF fixups
- `checks.nix` - Home Manager evaluation checks for Mac desktop, Linux headless and home/profile overrides
- `bin/hm-install` - Initial setup script requiring `-n <git_name> -e <git_email>`, with optional `--headless`; uses the actual home and checkout paths

## Configuration Flow

External config (user, git name/email, optional homeDirectory and desktop) is passed via `ext_config` in `~/.config/home-manager/home.nix`, which imports this repo and merges with defaults in `default.nix`. macOS defaults to desktop and `/Users/<user>`; Linux defaults to headless and `/home/<user>`. Keep shared agent package definitions and pins in one place. Mutable agent settings and credentials stay outside Home Manager. Validate both profiles when changing shared modules; native Linux builds and runtime checks still need a Linux machine.
