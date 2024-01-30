{
  user,
  system ? builtins.currentSystem,
  ...
}:
with builtins; let
  sources = import ./nix/sources.nix;

  hm = import sources.home-manager {};

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [
      (_final: _prev: {
        # Pin VSCode to a specific nixpkgs hash to be extra safe
        vscode = (import sources.vscode-nixpkgs-pin {inherit system;}).vscode;
      })
    ];
  };
in {
  nix = import ./home/nix.nix {inherit pkgs;};

  home = import ./home/home.nix {inherit pkgs user hm;};

  programs = import ./home/programs.nix {inherit user pkgs hm;};

  xdg = import ./home/xdg.nix {inherit pkgs;};
}
