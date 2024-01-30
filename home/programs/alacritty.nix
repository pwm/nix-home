{pkgs}:
{
  enable = true;

  settings = pkgs.lib.importTOML ./alacritty/alacritty.toml;
}
