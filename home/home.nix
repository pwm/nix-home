{
  pkgs,
  user,
  hm,
}: {
  stateVersion = "21.11";

  username = "${user}";

  homeDirectory = "/Users/${user}";

  sessionPath = [
    "$HOME/nix-home/bin"
    "$HOME/.local/bin"
    "$HOME/.docker/bin"
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  # Written to ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  sessionVariables = {
    NIX_PATH = "home-manager=${hm.path}:nixpkgs=${pkgs.path}";
    NIX_PROFILES = "$HOME/.nix-profile:/nix/var/nix/profiles/default";
    SHELL = "$HOME/.nix-profile/bin/fish";
    TERMINAL = "alacritty";
    EDITOR = "vim";
  };

  packages = import ./packages.nix {inherit pkgs;};
}
