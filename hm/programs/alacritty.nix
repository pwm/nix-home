{ pkgs, user }:
{
  enable = true;

  # recursiveUpdate, as a plain // would replace the whole [terminal] table
  # from the toml (and with it terminal.osc52) with just shell.program.
  settings = pkgs.lib.recursiveUpdate (pkgs.lib.importTOML ./alacritty/alacritty.toml) {
    terminal.shell.program = "/Users/${user}/.nix-profile/bin/fish";
  };
}
