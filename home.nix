{ user, system ? builtins.currentSystem, ... }:
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [
      (_final: _prev: {
        # Pin VSCode to a specific nixpkgs hash (as it often breaks...)
        vscode = (import sources.vscode-nixpkgs-pin { inherit system; }).vscode;
      })
    ];
  };

  hm = import sources.home-manager { };
in
{
  nix = import ./home/nix.nix { inherit pkgs; };

  home = import ./home/home.nix { inherit user pkgs hm; };

  programs = import ./home/programs.nix { inherit user pkgs; };

  xdg = import ./home/xdg.nix;
}
