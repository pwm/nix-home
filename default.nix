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
  # Install fonts from pkgs to $HOME/Library/Fonts/HomeManager/*
  fonts.fontconfig.enable = true;

  home = import ./home/home.nix { inherit user pkgs hm; };

  nix = import ./home/nix.nix { inherit pkgs; };

  programs = import ./home/programs.nix { inherit user pkgs; };

  xdg = import ./home/xdg.nix;
}
