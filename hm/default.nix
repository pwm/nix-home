{ pkgs, config }:
{
  imports = [
    # herdr's agent integrations, installed into the agents' own settings
    (import ./programs/herdr.nix { inherit pkgs; })
    # a reminder on the Mac to give a rebuilt Alacritty its Dropbox access again
    (import ./programs/alacritty-privacy.nix { inherit pkgs; })
  ]
  # Remote SSH runs its extensions on the headless host. Keep the desktop
  # application and its settings on the client, with one shared set of pins.
  ++ pkgs.lib.optional (!config.desktop)
    (import ./programs/vscode-remote.nix { inherit pkgs; });

  fonts.fontconfig.enable = config.desktop;

  home = import ./home { inherit pkgs config; };

  nix = import ./nix { inherit pkgs config; };

  programs = import ./programs { inherit pkgs config; };

  xdg = import ./xdg;
}
