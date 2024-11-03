{ user, system ? builtins.currentSystem, ... }:
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [
      (_final: _prev: {
        # Pin VSCode to a specific nixpkgs hash, as it often breaks with updates
        vscode = (import sources.vscode-nixpkgs-pin { inherit system; }).vscode;
      })
    ];
  };

  hm = import sources.home-manager { };
in
{
  # Install fonts defined in home.packages to $HOME/Library/Fonts/HomeManager
  fonts.fontconfig.enable = true;

  home = import ./home/home.nix { inherit user pkgs; };

  nix = import ./home/nix.nix { inherit pkgs hm; };

  programs = import ./home/programs.nix { inherit user pkgs; };

  xdg = import ./home/xdg.nix;
}
