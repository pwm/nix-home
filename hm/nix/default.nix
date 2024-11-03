{ pkgs, config }:
{
  package = pkgs.nix;

  # Add these to NIX_PATH so that tools using <nipkgs> and <home-manager>,
  # like home-manager itself, use our niv pins
  nixPath = [
    "nixpkgs=${config.paths.nixpkgs}"
    "home-manager=${config.paths.home-manager}"
  ];

  keepOldNixPath = false;

  settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://rqube.cachix.org"
      "https://haskell-language-server.cachix.org"
      "https://ghc-nix.cachix.org"
      "https://amazonka.cachix.org"
      "https://nix-tools.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "rqube.cachix.org-1:POl2bnMMKa9/iw4KKBQHr0iysHG/iKOnHN62UMyxNxI="
      "haskell-language-server.cachix.org-1:juFfHrwkOxqIOZShtC4YC1uT1bBcq2RSvC7OMKx0Nz8="
      "ghc-nix.cachix.org-1:wI8l3tirheIpjRnr2OZh6YXXNdK2fVQeOI4SVz/X8nA="
      "amazonka.cachix.org-1:S6NXE+2p2Hemjyq2iCW3fS+khmnpQ0R0UGUBRxWavaQ="
      "nix-tools.cachix.org-1:ebBEBZLogLxcCvipq2MTvuHlP7ZRdkazFSQsbs0Px1A="
    ];
  };
}
