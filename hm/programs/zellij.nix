{ config }:
{
  enable = true;

  enableFishIntegration = config.desktop;

  # config handled in xdg as Nix don't have a proper .kdl parser yet
}
