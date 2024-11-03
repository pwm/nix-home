{
  enable = true;

  # We're explicitly not setting path here, which would take precedence in the hm script.
  #
  # Rather, we set <nixpkgs> and <home-manager>, which the hm script uses.
  # (Which are in NIX_PATH, set in nix.nixPath as well as in bin/{hm-install,hm-run})
  #
  # This is so that we can always inject the latest from our niv pin,
  # including after we did a "niv update".
  path = null;
}
