{ user, pkgs, hm }:
{
  stateVersion = "21.11";

  username = "${user}";

  homeDirectory = "/Users/${user}";

  # home.{sessionPath,sessionVariables} are written to
  # ~/.nix-profile/etc/profile.d/hm-session-vars.sh which
  # in turn is sourced at the top of ~/.config/fish/config.fish
  #
  # Note:
  #   1. The "at the top" part is important because programs like zellij
  #      rely on the PATH being set before they hook into the shell.
  #   2. For now we also have to set PATH in fish.interactiveShellInit
  #      as sessionPath here _appends_ not _prepends_ to the PATH. This
  #      is being fixed here:
  #        https://github.com/nix-community/home-manager/issues/3324
  #        https://github.com/nix-community/home-manager/pull/4582/commits/0b25ac41ee
  sessionPath = [
    "$HOME/nix-home/bin"
    "$HOME/.local/bin"
    "$HOME/.docker/bin"
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  sessionVariables = {
    NIX_PATH = "home-manager=${hm.path}:nixpkgs=${pkgs.path}";
    NIX_PROFILES = "$HOME/.nix-profile:/nix/var/nix/profiles/default";
    SHELL = "$HOME/.nix-profile/bin/fish";
    TERMINAL = "alacritty";
    EDITOR = "nvim";
  };

  packages = import ./packages.nix { inherit pkgs; };
}
