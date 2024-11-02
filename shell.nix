{ system ? builtins.currentSystem, ... }:
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs { inherit system; };
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
