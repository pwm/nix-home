{ pkgs, config }:
{
  # Install fonts defined in home.packages to $HOME/Library/Fonts/HomeManager
  fonts.fontconfig.enable = true;

  home = import ./home { inherit pkgs config; };

  nix = import ./nix { inherit pkgs config; };

  programs = import ./programs { inherit pkgs config; };

  xdg = import ./xdg;
}
