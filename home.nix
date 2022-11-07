user: { config, ... }: with builtins;
let
  sources = import ./nix/sources.nix;
  hm = import sources.home-manager { };
  pkgs = import sources.nixpkgs {
    overlays = [
      (final: prev: {
        vscode = prev.vscode.overrideAttrs (oldAttrs: rec {
          version = "1.73.0";
          src = (fetchTarball {
            url = "https://update.code.visualstudio.com/${version}/darwin/stable";
            sha256 = "0xpbh199xxyfyvc28rll8h8ppg5mdi9c20qxsrcriv5cpwcbg0cf";
          });
        });
      })
    ];
  };
in
{
  home = {
    stateVersion = "21.11";

    username = "${user}";

    homeDirectory = "/Users/${user}";

    packages = with pkgs.lib; map
      (pkg: getAttrFromPath (splitString "." pkg) pkgs)
      (fromJSON (readFile ./pkgs.json));

    file = {
      ".config/fish/fish_variables".source = fish/fish_variables;
      ".config/fish/functions/fish_prompt.fish".source = fish/functions/fish_prompt.fish;
      "Library/Application Support/Code/User/settings.json".source = vscode/settings.json;
      "Library/Application Support/Code/User/keybindings.json".source = vscode/keybindings.json;
    };

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
      interactiveShellInit = ''
        set -x NIX_PROFILES /nix/var/nix/profiles/default ~/.nix-profile
        set -x NIX_PATH home-manager=${hm.path} nixpkgs=${pkgs.path}
        set -x XDG_CONFIG_HOME ~/.config
        set -x EDITOR vim
        set -p PATH ~/nix-home/bin ~/.local/bin /nix/var/nix/profiles/default/bin
      '';
      shellAliases = {
        hm = "run home-manager";
        h = "history | fzy";
        f = "fd | fzy";
        ll = "exa -la --git";
        cat = "bat -p --paging=never";
        rgh = "rg -g '*.{hs}'";
        rga = "rg -g '*.{art}'";
        rgb = "rg -g '*.{sh}'";
        rgn = "rg -g '*.{nix}'";
        rgs = "rg -g '*.{sql}'";
        rgt = "rg -g '*.{tf}'";
        gt = "git ls-tree -r --name-only HEAD 2>/dev/null | tree -C --fromfile";
        gf = "git commit -a --fixup=(git rev-parse HEAD | cut -c 1-8)";
        b = "git for-each-ref refs/heads --format='%(refname:short)' --sort='refname' | fzy --query \"$argv\" | xargs git checkout";
        bm = "git checkout master";
        bd = "git for-each-ref refs/heads --format='%(refname:short)' --sort='refname' | rg -v master | fzy --query \"$argv\" | xargs git branch -D";
        p = "git push origin (git branch --show-current)";
        pr = "gh pr create --fill";
        ppr = "p && pr";
        gfp = "gf && p";
        s = "pbpaste | nc termbin.com 9999";
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
        da = "diff -- '*.art'";
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

    # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/vim.section.md
    neovim = {
      enable = true;
      extraConfig = ''
        colorscheme gruvbox
        let g:context_nvim_no_redraw = 1
        set mouse=a
        set number
        set termguicolors
        let g:blamer_enabled = 1
        let g:blamer_delay = 500
        let g:blamer_template = '<author> | <author-time> | <commit-short> | <summary>'
      '';
      plugins = with pkgs.vimPlugins;
        let
          blamer-nvim = pkgs.vimUtils.buildVimPlugin {
            name = "blamer-nvim";
            src = pkgs.fetchFromGitHub {
              owner = "APZelos";
              repo = "blamer.nvim";
              rev = "f4eb22a9013642c411725fdda945ae45f8d93181";
              sha256 = "1czjagkfjw57f2nvjjgbma1gcy1ylcd68dyfc5ivr2wc6fdw5lks";
            };
          };
        in
        [
          blamer-nvim
          editorconfig-vim
          gruvbox-community
          vim-airline
          haskell-vim
          vim-nix
        ];
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };

    vscode = {
      enable = true;
      package = pkgs.vscode; # Use our version
      # To update extensions.json run: bin/vscode_extensions.sh
      extensions =
        pkgs.vscode-utils.extensionsFromVscodeMarketplace
          (fromJSON (readFile ./vscode/extensions.json));
    };
  };

  # Issues:
  # https://github.com/target/lorri/issues/96#issuecomment-545152525
  # https://github.com/target/lorri/issues/96#issuecomment-588563793
  #services = {
  #  lorri.enable = true;
  #};
}
