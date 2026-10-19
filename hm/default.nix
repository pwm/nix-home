{ pkgs, config }:
{
  fonts.fontconfig.enable = config.desktop;

  home = import ./home { inherit pkgs config; };

  nix = import ./nix { inherit pkgs config; };

  programs = import ./programs { inherit pkgs config; };

  xdg = import ./xdg;
}
