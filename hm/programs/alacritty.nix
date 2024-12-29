{ pkgs, user }:
{
  enable = true;

  settings = (pkgs.lib.importTOML ./alacritty/alacritty.toml) // {
    terminal.shell.program = "/Users/${user}/.nix-profile/bin/fish";
  };
}
