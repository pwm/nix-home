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
    "/nix/var/nix/profiles/default/bin"
  ];

  # Written to .nix-profile/etc/profile.d/hm-session-vars.sh
  sessionVariables = {
    NIX_PATH = "home-manager=${hm.path} nixpkgs=${pkgs.path}";
    NIX_PROFILES = "/nix/var/nix/profiles/default /Users/${user}/.nix-profile";
    SHELL = "/Users/${user}/.nix-profile/bin/fish";
    XDG_CONFIG_HOME = "/Users/${user}/.config";
    TERMINAL = "alacritty";
    EDITOR = "vim";
  };

  packages = import ./packages.nix {inherit pkgs;};
}
