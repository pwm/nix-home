{ system ? builtins.currentSystem, ... }:
let
  pkgs = import (import ./nix/sources.nix).nixpkgs { inherit system; };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.lua-language-server
    pkgs.nil
    pkgs.niv
    pkgs.nixpkgs-fmt
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.treefmt
  ];
  shellHook = ''
  '';
}
