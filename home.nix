user: { config, ... }:
let
  sources = import ./nix/sources.nix;
  hm = import sources.home-manager { };
  pkgs = import sources.nixpkgs {
    #collision between
    # `/nix/store/5pmji9m2582rlnz33hi3n120kfpbw83y-ormolu-0.1.0.0/lib/links/libgmpxx.4.dylib' and
    # `/nix/store/qpivxc5r63rpm88rrv8v5hz9y901m4k2-ghcide-0.2.0/lib/links/libgmpxx.4.dylib'
    # overlays = [
    #   (self: super: {
    #     inherit (import sources.ormolu { }) ormolu;
    #     ormolu = super.ormolu.override {};
    #   })
    # ];
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

    # TODO: figure out why HM does not source nix.sh itself
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
        ll = "exa -la --git";
        cat = "bat -p --paging=never";
        grep = "rg";
        rgh = "rg -g '*.{hs}'";
        rgn = "rg -g '*.{nix}'";
        tf = "terraform";
        ar = "assume-role";
      };
    };

    git = {
      enable = true;
      userName = "Zsolt Szende";
      userEmail = "zsolt@artificial.io";
      ignores = [
        ".DS_Store"
        "*.niu"
        ".envrc"
        ".local"
      ];
      aliases = {
        co = "checkout";
        ci = "commit";
        b = "branch";
        d = "icdiff";
        s = "status";
      };
      extraConfig = {
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
