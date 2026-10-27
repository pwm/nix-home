---
title: nix-home
date: 2026-10-19
---

# nix-home

My home environment. Packages are pinned using [niv](https://github.com/nmattia/niv).

The same configuration supplies the terminal tools and coding agents on the
Mac and an Ubuntu server. macOS defaults to the desktop profile; Linux defaults
to headless. Both use the same agent definitions and version pins.

## Setup/Install

### macOS desktop

1. Install [Alacritty](https://alacritty.org/) on the host, which will be configured later from home-manager.

2. Install [Nix](https://nixos.org/):
```
xcode-select --install
curl -L https://nixos.org/nix/install > nix-install
chmod +x nix-install
./nix-install
nix --version
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf && sudo pkill nix-daemon
```

3. Install [home-manager](https://nix-community.github.io/home-manager/):
```
git clone git@github.com:pwm/nix-home.git ~/nix-home && cd ~/nix-home
bin/hm-install -n <git_name> -e <git_email>
bin/hm-run home-manager switch -b backup
```

### Ubuntu headless

Install [Nix using its Linux multi-user instructions](https://nixos.org/download/),
then open a shell with Nix on `PATH`. Run the following as your normal user:

```bash
git clone git@github.com:pwm/nix-home.git ~/nix-home
cd ~/nix-home
bin/hm-install -n "Your Name" -e "you@example.com" --headless
bin/hm-run home-manager build
bin/hm-run home-manager switch -b backup
```

`build` prepares the Home Manager generation without activating it. `switch`
applies it. The installer uses the actual home directory and checkout location,
and writes `~/.config/home-manager/home.nix`. It replaces that configuration
when rerun, so keep any manual additions before doing so.
Keep the working checkout at `~/nix-home`: the shared shell adds that directory's
`bin/` to `PATH` for commands such as `hm` and the package-update helpers.

The headless profile includes Claude Code, Codex, OMP, Fish, Zellij, Neovim,
direnv, the CLI tools and VS Code's remote extensions. It leaves out Alacritty,
the VS Code desktop application, Zed, desktop fonts,
Inkscape and SQLite Browser. The oMLX shim and Mac clipboard helper remain
Mac-only. Agent login, mutable settings, MCP registration, conversations and
memories are separate from this package installation and stay outside the Nix
store.

Use `~/.nix-profile/bin/fish` to enter the configured shell. This repository's
Home Manager profile does not change the account's login shell, SSH access or
operating-system services. To set up a whole server for work with coding agents,
including those and the move of agent history, follow
[the dev server playbook](devserver/README.md). Each project keeps its own
steps in its own repository; PML's are in its `scripts/devserver/`.
For remote Zellij, attach to an explicit session, for example
`zellij attach -c pml`. Headless Fish sessions do not start Zellij automatically;
desktop sessions keep automatic startup.

### Configuration options

`~/.config/home-manager/home.nix` imports this checkout with `ext_config`:

```nix
import /home/pwm/nix-home {
  ext_config = {
    user = "pwm";
    homeDirectory = "/home/pwm";
    desktop = false;
    git = {
      name = "Your Name";
      email = "you@example.com";
    };
  };
}
```

`homeDirectory` defaults to `/Users/<user>` on macOS and `/home/<user>` on Linux.
`desktop` defaults to true on macOS and false on Linux. `--headless` writes an
explicit false. The supported targets for this preparation are Apple Silicon
macOS and x86_64 Linux; the pinned agent packages may not support other targets.

## Check without activating

```bash
NIXPKGS_ALLOW_UNFREE=1 nix-instantiate --eval --strict --json checks.nix
bin/hm-run home-manager build
```

The first command checks the complete Home Manager configuration and package
derivations for both targets, a custom Linux home and an explicitly headless
Mac. It builds nothing. The second builds your native configuration without
switching to it. Linux packages still need to be built and exercised on Linux;
cross-platform evaluation on a Mac does not establish that they run.

## VS Code on the Mac and through Remote SSH

`hm/programs/vscode/extensions.json` is the shared extension catalogue. Each
extension has one version. Universal packages have one `sha256`; packages
with native variants have a `platforms` map with separate hashes for
`darwin-arm64` and `linux-x64`. Both profiles select from this same catalogue.
The Haskell extensions and `mkhl.direnv` are included on both machines.

- **Desktop:** Home Manager installs VS Code, its extensions, settings and
  keybindings as before.
- **Headless:** Home Manager installs the extension packages for Remote SSH
  without the desktop application. It owns links under
  `~/.vscode-server/extensions/.nix-home/` and updates the writable
  `extensions.json` registry. This also works before the first SSH connection;
  the VS Code client installs its own matching server when it connects.

Extensions installed manually remain available. For IDs in the catalogue,
`hm switch` selects the declared version. It does not delete manually
installed extension directories or their data. Removing a catalogue entry
removes Home Manager's registration and link. The activation preserves
unrelated registrations and their metadata, and refuses an unreadable or
malformed registry instead of replacing it. Avoid installing or uninstalling
extensions at the same time as `hm switch`.

Rollbacks between generations with this module restore the declared pins.
For a one-time rollback to a generation from before this module existed,
close the remote window, roll back, and move
`~/.vscode-server/extensions/extensions.json` outside the extensions directory
as a backup. Reconnecting rebuilds the registry from the retained manual
extension directories.

On the Mac, connect with the Remote SSH extension, for example:

```bash
code --remote ssh-remote+pml-dev /home/pwm/work/pml
```

Your desktop settings carry into that remote window. Remote-specific settings
remain editable in VS Code; Home Manager does not replace them with a copy of
the desktop settings. `direnv` loads the project's environment so language
servers match its compiler. For PML, the existing `haskell.manageHLS = PATH`
setting uses the HLS supplied by PML's Nix shell. Accept direnv's reload prompt
after its environment changes. A remote window already open during
`hm switch` may need **Developer: Reload Window** to load changed extensions;
the switch does not stop the server or your sessions.

The remote installation targets stable VS Code's default remote profile.
Custom server data directories and Insiders use different paths and are not
configured here.

Check the registry helper without changing your editor:

```bash
python3 tests/vscode-remote-check.py
```

Its optional `--code-server PATH` also tests a real VS Code Server scanner in
temporary directories. The native Home Manager build fetches and verifies the
selected extension artifacts; `checks.nix` checks both platform selections.

To update extensions, run `vscode-update-extensions` in either editor's
terminal. It considers both the existing catalogue and that editor's installed
extensions, so a smaller remote installation cannot erase desktop pins. Native
packages advance only to a version available for both supported platforms.
Use `vscode-update-extensions --code /path/to/code-server` from a plain SSH
shell. The selected CLI supplies the editor version used for compatibility
checks. Review the resulting catalogue, then apply it with `hm switch` on each
machine after syncing the repository.

## Change config

Do whatever change and then run

```
hm switch
```

## Update

```
niv update nixpkgs
niv update home-manager
hm switch
```

## Coding agents

`claude-code`, `codex` and `pi-coding-agent` come from one pin that tracks
nixpkgs `master` (not `nixos-unstable`), as `master` gets the newest agent
versions days before they land on the unstable channel. `claude-code` and
`codex` take only their build recipes from that pin, their versions are set
in `pkgs/` (see below). The `-b master` flag keeps the pin on `master` and is
idempotent, so just run:

```
niv update claude-code-nixpkgs-pin -b master
hm switch
```

### Claude Code from the upstream release manifest

nixpkgs `master` usually follows Claude Code within a day, but the pin only
moves when it is updated by hand, and each pin update also moves everything
else on it (which rebuilds codex). So `pkgs/claude-code.nix` takes the
claude-code derivation from the pin and swaps in a newer upstream release
manifest, `pkgs/claude-code-manifest.zst.json`. That is the same file nixpkgs
ships next to its own derivation. It carries the version and the checksum of
the prebuilt binary for each platform, so there are no hashes to work out and
no build, only a download.

To bump Claude Code to the latest upstream release:

```
bump-claude
hm switch
```

`bump-claude` (in `bin/`) looks up the latest version at
`https://downloads.claude.ai/claude-code-releases/latest`, downloads that
release's `manifest.zst.json`, checks that it names the expected version and
has a binary for each platform nixpkgs supports, and copies it over
`pkgs/claude-code-manifest.zst.json`. Pass a version to pick a specific
release instead, e.g. `bump-claude 2.1.281`. To do the same by hand, download
`https://downloads.claude.ai/claude-code-releases/<version>/manifest.zst.json`
over `pkgs/claude-code-manifest.zst.json`.

As with codex below, a pin update that moves nixpkgs past the manifest
version is caught at evaluation time: `hm switch` fails with a message that
says to run `bump-claude` (or to drop the override). `bump-claude` itself
refuses a version older than the pin's.

### codex from the upstream release tag

Even nixpkgs `master` is a few releases behind codex, and codex has several
releases per week. So `pkgs/codex.nix` takes the codex derivation from the
pin and swaps in the source of a newer upstream tag. Everything else (Rust
build, prebuilt `librusty_v8`, darwin `lld` workaround, `ripgrep` wrapper,
shell completions) is reused from nixpkgs. The cost is a local Rust build of
codex and its dependencies, which takes some minutes on the first build and
on each bump.

To bump codex to the latest upstream release:

```
bump-codex
hm switch
```

`bump-codex` (in `bin/`) looks up the latest release tag, checks the `v8`
crate version (see below), rewrites `version`, `srcHash` and `cargoHash` in
`pkgs/codex.nix`, and gets the two real hashes by building each fetch with a
fake hash and reading the `got:` value from the `hash mismatch` error. If
anything fails it restores `pkgs/codex.nix`. Pass a version to pick a specific
release instead, e.g. `bump-codex 0.153.4`. The `hm switch` afterwards is the
real (long) build.

To do the same by hand, in `pkgs/codex.nix`:

1. Set `version` to the new version (without the `rust-v` prefix).
2. Set `srcHash` and `cargoHash` to `pkgs.lib.fakeHash`.
3. Run `hm switch`. It fails with `hash mismatch` for the source. Copy the
   `got:` value into `srcHash`.
4. Run `hm switch` again. It fails with `hash mismatch` for
   `codex-<version>-vendor-staging`. Copy the `got:` value into `cargoHash`.
5. Run `hm switch` once more. This is the real build.

Two things can break a bump. Both are fixed by updating the pin
(`niv update claude-code-nixpkgs-pin -b master`) so that nixpkgs has the
newer version:

- The `v8` crate version in upstream `codex-rs/Cargo.lock` must match the
  `librusty_v8` version in the pin's `pkgs/by-name/co/codex/librusty_v8.nix`.
  `bump-codex` prints both and refuses to bump on a mismatch. To check by
  hand, the upstream side is
  `curl -sL https://raw.githubusercontent.com/openai/codex/rust-v<version>/codex-rs/Cargo.lock | grep -A1 'name = "v8"'`
  and the pin's local path is
  `nix-instantiate --eval --expr '(import ./nix/sources.nix).claude-code-nixpkgs-pin.outPath'`.
- The nixpkgs `postPatch` edits `lto = "thin"` and `codegen-units = 4` in the
  workspace `Cargo.toml` with `--replace-fail`, so it fails with a clear error
  if upstream changes those release profile settings.

The opposite case, a pin update that moves nixpkgs past the version in
`pkgs/codex.nix`, is caught at evaluation time: `hm switch` fails with a
message that says to run `bump-codex` (or to drop the override). Without
that check the override would silently hold codex back.

Why not just override `cargoHash`? Because `buildRustPackage` reads
`cargoHash` from the original package arguments and not from the final
attributes, so an overridden `cargoHash` does not change the vendored crates.
That is why `pkgs/codex.nix` overrides `cargoDeps` with its own
`fetchCargoVendor` call. It still sets `cargoHash` too, so the derivation is
identical to the one nixpkgs would build for that version.

### OMP from the upstream release binary

`pkgs/omp.nix` pins the official OMP release and checksums. It supports Apple
Silicon macOS and Linux x86_64 through the same package definition. The Linux
binary has its ELF interpreter and library paths fixed for Nix, with stripping
disabled to preserve the embedded Bun application. macOS keeps upstream signing
intact by skipping fixups. The install check runs `omp --version` on the build
platform and requires the pinned version.

To bump OMP to the latest upstream release:

```
bump-omp
hm switch
```

`bump-omp` (in `bin/`) looks up the latest release on GitHub and rewrites
`version` and the checksums in `pkgs/omp.nix`: the `hash` of each platform
binary the file lists, and the `sha256` of `LICENSE` and
`THIRD-PARTY-NOTICES.txt`. It takes them from the SHA-256 digests that GitHub
reports for the release assets, so it downloads nothing. `hm switch` then
downloads the binary and checks it against that hash. If anything fails,
`bump-omp` restores `pkgs/omp.nix`. Pass a version to pick a specific release
instead, e.g. `bump-omp 18.5.1`. A release without digests stops the bump. Then
update `pkgs/omp.nix` by hand from that release's assets.

### Personal and company Codex accounts

After `hm switch`, Fish provides two commands:

| Command | Codex home |
| --- | --- |
| `codex` | `~/.codex-work` |
| `codex-me` | `~/.codex-personal` |

Sign in once for each account, choosing the matching account or workspace in
the browser. Run these one at a time:

```fish
codex login
codex-me login
```

Then use either command in a project directory. Both accept the usual Codex
arguments, for example `codex-me resume` or `codex login status`,
and can run in separate terminals at the same time. On a headless server,
use `login --device-auth` when enabled for your account.

The commands use separate `CODEX_HOME` directories and select file credential
storage, as described in the official OpenAI documentation for
[environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables)
and [authentication](https://learn.chatgpt.com/docs/auth). Each command makes
its home private (mode `0700`); tokens in its `auth.json` stay outside Git and
the Nix store. Each home has its own editable `config.toml`, logins and session
history. Settings and plugins from `~/.codex` are not copied into these fresh
homes. Home Manager supplies the shared personal instructions in `AGENTS.md`.
In Fish, `codex` selects the company profile. To use the original `~/.codex`
setup, bypass the Fish function with `command codex`. These functions do not
change Codex launched from another shell or application.

### fff-mcp

`fff-mcp` (the file search MCP server from
[dmtrKovalenko/fff](https://github.com/dmtrKovalenko/fff)) rides the same pin.
Nix installs the binary, but the MCP registration lives in `~/.claude.json`,
which Claude Code rewrites at runtime, so home-manager cannot manage it. After
the first `hm switch`, register it once by hand:

```
claude mcp add -s user fff -- ~/.nix-profile/bin/fff-mcp --no-update-check
claude mcp get fff
```

Do not install nixpkgs `fff`. That is an unrelated bash file manager by a
different author that happens to share the name.
