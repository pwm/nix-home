# Build codex from the upstream GitHub release tag instead of the version
# packaged in the nixpkgs pin. nixpkgs is a few releases behind codex, and
# codex has several releases per week.
#
# This reuses the nixpkgs derivation (Rust build, prebuilt librusty_v8,
# darwin lld workaround, ripgrep wrapper, shell completions) and only swaps
# the source and the vendored crates. `pkgs` must be the nixpkgs tree that
# has the codex derivation (the claude-code-nixpkgs-pin).
#
# To bump, run bin/bump-codex and then `hm switch`. To do it by hand, set
# `version`, set both hashes to `pkgs.lib.fakeHash`, run `hm switch`, and
# copy the "got:" hash from each mismatch error in turn (source first, then
# the cargo vendor). See readme.md, "Coding agents".
{ pkgs }:
let
  # bin/bump-codex rewrites these three lines, keep their format.
  version = "0.153.4";
  srcHash = "sha256-lHiDj5SodaM3mh8goMm6esfejeAT+Y3JJWrRnyj6sJo=";
  cargoHash = "sha256-GG6kOXmCdq+bZLU2ul0DIVL8lDuweayvZvXn6+bcUZw=";

  src = pkgs.fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    tag = "rust-v${version}";
    hash = srcHash;
  };
in
pkgs.codex.overrideAttrs (old:
# Fail when the pin has moved past this file. Without this the override
# would silently hold codex back at an old version.
assert pkgs.lib.assertMsg (pkgs.lib.versionAtLeast version old.version)
  "pkgs/codex.nix pins codex ${version} but the nixpkgs pin already has ${old.version}. Run bin/bump-codex, or drop the override.";
{
  # cargoHash is set too so the derivation is identical to the one nixpkgs
  # would build for this version. It does not drive cargoDeps, see below.
  inherit version src cargoHash;

  # buildRustPackage computes cargoDeps from the cargoHash in package.nix and
  # ignores an overridden cargoHash for that, so vendor the crates for the
  # new src here with the same arguments buildRustPackage would pass.
  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
    inherit (old) pname sourceRoot;
    inherit version src;
    hash = cargoHash;
  };
})
