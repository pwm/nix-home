user: { config, ... }:
let
  sources = import ./nix/sources.nix;
  hm = import sources.home-manager { };
  pkgs = import sources.nixpkgs { };
in
with builtins; {
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${user}";

    homeDirectory = "/Users/${user}";

    packages = with pkgs.lib;
      map (n: getAttrFromPath (splitString "." n) pkgs) (fromJSON (readFile ./pkgs.json));

    file = {
      ".config/fish/fish_variables".source = fish/fish_variables;
      ".config/fish/functions/fish_prompt.fish".source = fish/functions/fish_prompt.fish;
      "Library/Application Support/Code/User/settings.json".source = vscode/settings.json;
      "Library/Application Support/Code/User/keybindings.json".source = vscode/keybindings.json;
    };

    # FIXME: OSX does not pick these up if symlinked hence real copy
    # FIXME: Don't hardcode ~/nix-home
    extraProfileCommands = ''
      find "${config.home.homeDirectory}/nix-home/fonts/" -name "FiraCode*" -exec ls {} + | xargs -I % cp -p % "${config.home.homeDirectory}/Library/Fonts/"
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
        rgs = "rg -g '*.{sql}'";
        rgt = "rg -g '*.{tf}'";
        tf = "terraform";
        ar = "assume-role";
        hub-pr = "hub pull-request --no-edit";
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
        p = "pull -r --autostash";
        co = "checkout";
        c = "commit";
        s = "status";
        b = "branch";
        d = "icdiff";
        dh = "icdiff -- '*.hs'";
        dn = "icdiff -- '*.nix'";
        ds = "icdiff -- '*.sql'";
        dt = "icdiff -- '*.tf'";
      };
      extraConfig = {
        branch.autosetuprebase = "always";
        color.diff-highlight.oldNormal = "red bold";
        color.diff-highlight.oldHighlight = "red bold 52";
        color.diff-highlight.newNormal = "green bold";
        color.diff-highlight.newHighlight = "green bold 22";
        color.diff.meta = "11";
        color.diff.frag = "magenta bold";
        color.diff.func = "146 bold";
        color.diff.commit = "yellow bold";
        color.diff.old = "red bold";
        color.diff.new = "green bold";
        color.diff.whitespace = "red reverse";
        color.ui = "true";
        core.pager = "diff-so-fancy | less --tabs=4 -RFX";
        icdiff.options = "--highlight --line-numbers";
        icdiff.pager = "less --tabs=4 -RFX";
        interactive.diffFilter = "diff-so-fancy --patch";
        push.recurseSubmodules = "no";
        submodule.recurse = "true";
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
