user: { config, ... }:
let
  sources = import ./nix/sources.nix;
  hm = import sources.home-manager { };
  pkgs = import sources.nixpkgs { };
  #  overlays = [
  #    (self: super: {
  #      git = super.git.overrideAttrs (old: rec {
  #        name = "git-2.30.2";
  #        version = "2.30.2";
  #        src = builtins.fetchurl {
  #          url = "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.xz";
  #          sha256 = "1ajz6lng6yldqm66lhrjfgbbxk09rq8cngv7hz9nqizrf46dkxs1";
  #        };
  #      });
  #    })
  #  ];
  #};
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
        rga = "rg -g '*.{art}'";
        rgn = "rg -g '*.{nix}'";
        rgs = "rg -g '*.{sql}'";
        rgt = "rg -g '*.{tf}'";
        tf = "terraform";
        ar = "assume-role";
        hub-pr = "hub pull-request --no-edit";
        gf = "git commit -a --fixup=(git rev-parse HEAD | cut -c 1-8)";
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
        d = "diff";
        dh = "diff -- '*.hs'";
        dn = "diff -- '*.nix'";
        ds = "diff -- '*.sql'";
        dt = "diff -- '*.tf'";
      };
      extraConfig = {
        branch.autosetuprebase = "always";
        push.recurseSubmodules = "no";
        rebase.autosquash = "true";
        submodule.recurse = "true";

        delta.features = "side-by-side line-numbers";
        delta.whitespace-error-style = "22 reverse";
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";
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
