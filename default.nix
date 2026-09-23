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
      # Pin the coding agents to latest nixpkgs to get the latest versions.
      # codex is also built from the upstream release tag, see pkgs/codex.nix.
      # The pin is imported once, each import evaluates a full nixpkgs.
      (_final: _prev:
        let
          agents = import sources.claude-code-nixpkgs-pin { inherit system; };
        in
        {
          inherit (agents) claude-code pi-coding-agent;
          codex = import ./pkgs/codex.nix { pkgs = agents; };
        })
      # Pin yt-dlp to latest nixpkgs to get the latest version
      (_final: _prev: {
        yt-dlp = (import sources.yt-dlp-nixpkgs-pin { inherit system; }).yt-dlp;
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
