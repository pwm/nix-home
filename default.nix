{ ext_config # see bin/hm-install for the structure
, system ? builtins.currentSystem
, ...
}:
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [
      # Pin VSCode to a specific nixpkgs hash, as it often breaks with updates
      (_final: _prev: {
        vscode = (import sources.vscode-nixpkgs-pin { inherit system; }).vscode;
      })
      # Pin Cursor to a specific nixpkgs hash
      (_final: _prev: {
        code-cursor = (import sources.cursor-nixpkgs-pin { inherit system; }).code-cursor;
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
