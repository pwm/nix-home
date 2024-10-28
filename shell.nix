{system ? builtins.currentSystem, ...}:
let
  sources = import ./nix/sources.nix;

  packages = [
    pkgs.lua-language-server
    pkgs.nil
    pkgs.niv
    pkgs.nixfmt-rfc-style
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.treefmt
  ];

  nix-home = {
    shell = pkgs.buildEnv {
      name = "nix-home-env";
      paths = packages;
    };
  };

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [(final: prev: {inherit nix-home;})];
  };
in
  pkgs.mkShell {
    buildInputs = [
      pkgs.nix-home.shell
    ];
    shellHook = ''
    '';
  }
