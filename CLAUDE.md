# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Format code:
```
treefmt
```

## Architecture

- `default.nix` - Entry point; imports pinned nixpkgs via niv, applies overlays (VSCode, Claude Code, yt-dlp pins), and passes config to `hm/`
- `hm/default.nix` - Home-manager module root; enables fonts, imports home, nix, programs, and xdg submodules
- `hm/programs/` - Individual program configurations (alacritty, fish, git, neovim, vscode, etc.)
- `hm/home/packages.nix` - List of packages to install
- `nix/sources.nix` - Niv-generated file for pinned dependencies (do not edit manually)
- `nix/sources.json` - Niv-managed pins (edited via `niv` commands)
- `bin/hm-run` - Wrapper that sets NIX_PATH from niv sources before running home-manager
- `bin/hm-install` - Initial setup script requiring `-n <git_name> -e <git_email>`

## Configuration Flow

External config (user, git name/email) is passed via `ext_config` in `~/.config/home-manager/home.nix`, which imports this repo and merges with defaults in `default.nix`.
