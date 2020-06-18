user: { config, ...}:

let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  hm = import sources.home-manager { };
in
{
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${user}";
    homeDirectory = "/Users/${user}";

    packages = with builtins; with pkgs.lib;
      (map (n: getAttrFromPath (splitString "." n) pkgs) (fromJSON (readFile ./pkgs.json)));

    file = {
      ".config/fish/functions/fish_prompt.fish".source = fish/functions/fish_prompt.fish;
      "Library/Application Support/Code/User/settings.json".source = vscode/settings.json;
      "Library/Application Support/Code/User/keybindings.json".source = vscode/keybindings.json;
    };
    
    # FIXME: OSX does not pick these up if symlinked hence real copy
    extraProfileCommands = ''
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-Bold.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Bold.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Bold.ttf"
      fi
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-Light.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Light.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Light.ttf"
      fi
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-Medium.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Medium.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Medium.ttf"
      fi
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-Regular.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Regular.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Regular.ttf"
      fi
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-Retina.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-Retina.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-Retina.ttf"
      fi
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-SemiBold.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-SemiBold.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-SemiBold.ttf"
      fi
      if [[ ! -f "${config.home.homeDirectory}/Library/Fonts/FiraCode-VF.ttf" ]]; then
        cp "${config.home.profileDirectory}/share/fonts/truetype/FiraCode-VF.ttf" "${config.home.homeDirectory}/Library/Fonts/FiraCode-VF.ttf"
      fi
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
      extensions = with builtins; with pkgs.vscode-utils;
        (extensionsFromVscodeMarketplace (fromJSON (readFile ./vscode/extensions.json)));
    };
  };
}
