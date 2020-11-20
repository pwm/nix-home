user: { config, ... }:
let
  sources = import ./nix/sources.nix;
  hm = import sources.home-manager { };
  pkgs = import sources.nixpkgs {
    overlays = [
      (final: prev: {
        inherit (import sources.ormolu { pkgs = final; }) ormolu;
      })
    ];
  };
in
with builtins; {
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${user}";
    homeDirectory = "/Users/${user}";

    packages = with pkgs.lib;
      (map (n: getAttrFromPath (splitString "." n) pkgs) (fromJSON (readFile ./pkgs.json)));

    file = {
      ".config/fish/functions/fish_prompt.fish".source = fish/functions/fish_prompt.fish;
      "Library/Application Support/Code/User/settings.json".source = vscode/settings.json;
      "Library/Application Support/Code/User/keybindings.json".source = vscode/keybindings.json;
    };

    # FIXME: OSX does not pick these up if symlinked hence real copy
    # TODO: check if the source (.../truetype/) exists
    extraProfileCommands = ''
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Bold.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Bold.ttf"
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Light.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Light.ttf"
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Medium.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Medium.ttf"
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Regular.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Regular.ttf"
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Retina.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Retina.ttf"
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-SemiBold.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-SemiBold.ttf"
      cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-VF.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-VF.ttf"
      # Need to make them writable so that we can overwrrite them
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-Bold.ttf"
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-Light.ttf"
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-Medium.ttf"
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-Regular.ttf"
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-Retina.ttf"
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-SemiBold.ttf"
      chmod 666 "${config.home.homeDirectory}/Library/Fonts/FiraCode-VF.ttf"
    '';

    # Source the Nix profile
    sessionVariablesExtra = ''
      . "${pkgs.nix}/etc/profile.d/nix.sh"
    '';
  };

  programs = {
    home-manager.enable = true;

    bat.enable = true;
    direnv.enable = true;

    fish = {
      enable = true;
      shellInit = ''
        set NIX_PATH home-manager=${hm.path} nixpkgs=${pkgs.path}
        set -p PATH ~/nix-home/bin ~/.local/bin
        set EDITOR vim
      '';
      shellAliases = {
        hm = "run home-manager";
        ne = "nix-env";
        f = "fd | fzy";
        t = "git ls-tree -r --name-only HEAD 2>/dev/null | tree -C --fromfile";
        ll = "exa -la --git";
        cat = "bat -p --paging=never";
        rgh = "rg -g '*.{hs}'";
        rgn = "rg -g '*.{nix}'";
        tf = "terraform";
        ar = "assume-role";
        hub-pr = "hub pull-request";
      };
    };

    git = {
      enable = true;
      userName = "Zsolt Szende";
      userEmail = "zsolt@artificial.io";
      ignores = [
        ".DS_Store"
        "*.niu"
        ".local"
      ];
      aliases = {
        p = "pull";
        co = "checkout";
        c = "commit";
        s = "status";
        b = "branch";
        d = "icdiff";
        dh = "icdiff -- '*.hs'";
      };
      extraConfig = {
        push.recurseSubmodules = "no";
        submodule.recurse = "true";
        icdiff.options = "--highlight --line-numbers";
        branch.autosetuprebase = "always";
      };
    };

    htop.enable = true;
    jq.enable = true;

    vscode = {
      enable = true;
      # Note: to generate the list of installed extensions run the following in nixpkgs:
      # pkgs/misc/vscode-extensions/update_installed_exts.sh
      extensions = with pkgs.vscode-utils;
        (extensionsFromVscodeMarketplace (fromJSON (readFile ./vscode/extensions.json)));
    };
  };
}
