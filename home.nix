{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "pwm";
    homeDirectory = "/Users/pwm";

    packages = with builtins; with pkgs.lib;
      (map (n: getAttrFromPath (splitString "." n) pkgs) (fromJSON (readFile ./pkgs.json)));

    file = { 
      ".config/fish/functions/fish_prompt.fish".source = fish/functions/fish_prompt.fish;
      "/Users/pwm/Library/Application Support/Code/User/settings.json".source = vscode/settings.json;
      "/Users/pwm/Library/Application Support/Code/User/keybindings.json".source = vscode/keybindings.json;
    };

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
      shellAliases = {
        hm = "home-manager";
        ne = "nix-env";
        ll = "exa -la --git";
        cat = "bat -p --paging=never";
        grep = "rg";
        rgh = "rg -g '*.{hs}'";
        tf = "terraform";
        ar = "assume-role";
      };
      shellInit = ''
        set NIX_PATH ~/nix
        set -p PATH ~/.local/bin
      '';
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
      extensions = with builtins; with pkgs.vscode-utils;
        (extensionsFromVscodeMarketplace (fromJSON (readFile ./vscode/extensions.json)));
    };
  };
}
