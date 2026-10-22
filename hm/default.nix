{ pkgs, config }:
{
  # Remote SSH runs its extensions on the headless host. Keep the desktop
  # application and its settings on the client, with one shared set of pins.
  imports = pkgs.lib.optional (!config.desktop)
    (import ./programs/vscode-remote.nix { inherit pkgs; });

  fonts.fontconfig.enable = config.desktop;

  home = import ./home { inherit pkgs config; };

  nix = import ./nix { inherit pkgs config; };

  programs = import ./programs { inherit pkgs config; };

  xdg = import ./xdg;
}
