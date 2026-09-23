# nix-home

My home environment. Packages are pinned using [niv](https://github.com/nmattia/niv).

## Setup/Install

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

## VSCode extensions

Running the following:

```
vscode-update-extensions
```

will look at the current extensions used (via `code --list-extensions`), download their latest version and write it out to `hm/programs/vscode/extensions.json`.

then, as usual, run:

```
hm switch
```
