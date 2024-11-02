{ user, pkgs }:
{
  enable = true;

  settings = (pkgs.lib.importTOML ./alacritty/alacritty.toml) // {
    shell.program = "/Users/${user}/.nix-profile/bin/fish";
  };
}
