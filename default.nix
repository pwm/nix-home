{ ext_config # see bin/hm-install for the structure
, system ? builtins.currentSystem
, ...
}:
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [
      (_final: _prev: {
        # Pin VSCode to a specific nixpkgs hash, as it often breaks with updates
        vscode = (import sources.vscode-nixpkgs-pin { inherit system; }).vscode;
      })
    ];
  };

  config = {
    paths = {
      nixpkgs = pkgs.path;
      home-manager = (import sources.home-manager { }).path;
    };
    user = "";
    git = {
      name = "";
      email = "";
    };
  } // ext_config; # should override the empty fields
in
import ./hm { inherit pkgs config; }
