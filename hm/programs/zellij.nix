{
  enable = true;

  # fish.nix starts zellij itself, so the start can be turned off at runtime
  enableFishIntegration = false;

  # config handled in xdg as Nix don't have a proper .kdl parser yet
}
