{system ? builtins.currentSystem, ...}:
let
  sources = import ./nix/sources.nix;

  packages = [
    pkgs.alejandra
    pkgs.lua-language-server
    pkgs.nil
    pkgs.niv
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.treefmt
  ];

  pwm-home = {
    shell = pkgs.buildEnv {
      name = "pwm-home-env";
      paths = packages;
    };
  };

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [(final: prev: {inherit pwm-home;})];
  };
in
  pkgs.mkShell {
    buildInputs = [
      pkgs.pwm-home.shell
    ];
    shellHook = ''
    '';
  }
