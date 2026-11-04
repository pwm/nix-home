# Install Claude Code from the upstream release manifest instead of the
# version packaged in the nixpkgs pin. nixpkgs master usually follows Claude
# Code within a day, but the pin only moves when it is updated by hand.
#
# The nixpkgs derivation takes its version and per-platform checksums from a
# `manifest` argument (the upstream manifest.zst.json), so this only swaps
# that file in. The prebuilt binary download, wrapper and install check are
# reused from nixpkgs. On darwin one more wrapper goes around the nixpkgs one
# (see `certStore` below). `pkgs` must be the nixpkgs tree that has the
# claude-code derivation (the claude-code-nixpkgs-pin).
#
# To bump, run bin/bump-claude and then `hm switch`. To do it by hand,
# download
#   https://downloads.claude.ai/claude-code-releases/<version>/manifest.zst.json
# over pkgs/claude-code-manifest.zst.json. See readme.md, "Coding agents".
{ pkgs }:
let
  # bin/bump-claude replaces this file with the upstream one, verbatim.
  manifest = pkgs.lib.importJSON ./claude-code-manifest.zst.json;

  # Fail when the pin has moved past the manifest. Without this the override
  # would silently hold Claude Code back at an old version.
  notBehindPin = pkgs.lib.assertMsg (pkgs.lib.versionAtLeast manifest.version pkgs.claude-code.version)
    "pkgs/claude-code-manifest.zst.json pins claude-code ${manifest.version} but the nixpkgs pin already has ${pkgs.claude-code.version}. Run bin/bump-claude, or drop the override.";

  base = pkgs.claude-code.override { inherit manifest; };

  # The nixpkgs wrapper defaults CLAUDE_CODE_CERT_STORE to `system`, which
  # drops Claude Code's bundled root certificates. On macOS the system store
  # is the keychain, and it does not hold Apple's built-in roots, so TLS to
  # api.anthropic.com fails with "unable to get local issuer certificate".
  # The nixpkgs fallback (NODE_EXTRA_CA_CERTS=$NIX_SSL_CERT_FILE) only works
  # when NIX_SSL_CERT_FILE is set. `bundled,system` gives back the bundled
  # roots and keeps the keychain for locally added CAs. This outer wrapper
  # runs first, so the inner `--set-default` keeps its value, and a value
  # already in the environment still wins. Linux keeps the nixpkgs package
  # as it is.
  certStore = base.overrideAttrs (prev: {
    postFixup = (prev.postFixup or "") + ''
      wrapProgram $out/bin/claude --set-default CLAUDE_CODE_CERT_STORE bundled,system
    '';
  });
in
assert notBehindPin;
if pkgs.stdenv.hostPlatform.isDarwin then certStore else base
