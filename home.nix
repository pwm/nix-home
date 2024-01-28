{
  user,
  system ? builtins.currentSystem,
  ...
}:
with builtins; let
  sources = import ./nix/sources.nix;
  hm = import sources.home-manager {};

  pkgs = import sources.nixpkgs {
    inherit system;
    overlays = [
      (_final: _prev: {
        # Pin VSCode to a specific nixpkgs hash to be extra safe
        vscode = (import sources.vscode-nixpkgs-pin {inherit system;}).vscode;
      })
    ];
  };
in {
  nix = {
    package = pkgs.nix;

    extraOptions = ''
      experimental-features = nix-command flakes
      substituters = https://cache.nixos.org https://rqube.cachix.org https://haskell-language-server.cachix.org https://ghc-nix.cachix.org https://amazonka.cachix.org https://nix-tools.cachix.org
      trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= rqube.cachix.org-1:POl2bnMMKa9/iw4KKBQHr0iysHG/iKOnHN62UMyxNxI= haskell-language-server.cachix.org-1:juFfHrwkOxqIOZShtC4YC1uT1bBcq2RSvC7OMKx0Nz8= ghc-nix.cachix.org-1:wI8l3tirheIpjRnr2OZh6YXXNdK2fVQeOI4SVz/X8nA= amazonka.cachix.org-1:S6NXE+2p2Hemjyq2iCW3fS+khmnpQ0R0UGUBRxWavaQ= nix-tools.cachix.org-1:ebBEBZLogLxcCvipq2MTvuHlP7ZRdkazFSQsbs0Px1A=
    '';
  };

  # Doesn't seem to be picked up... use NIXPKGS_ALLOW_UNFREE=1
  nixpkgs.config.allowUnfree = true;

  home = {
    stateVersion = "21.11";

    username = "${user}";

    homeDirectory = "/Users/${user}";

    packages = with pkgs.lib;
      map
      (pkg: getAttrFromPath (splitString "." pkg) pkgs)
      (fromJSON (readFile ./pkgs.json));

    file = {
      ".config/fish/fish_variables".source = fish/fish_variables;
      ".config/fish/functions/fish_prompt.fish".source = fish/functions/fish_prompt.fish;
      ".config/fish/functions/zellij_tab_names.fish".source = fish/functions/zellij_tab_names.fish;
      ".config/alacritty/alacritty.toml".source = alacritty/alacritty.toml;
      ".config/zellij/config.kdl".source = zellij/config.kdl;
      "Library/Application Support/Code/User/settings.json".source = vscode/settings.json;
      "Library/Application Support/Code/User/keybindings.json".source = vscode/keybindings.json;
    };

    # Source the Nix profile
    sessionVariablesExtra = ''
      . "${pkgs.nix}/etc/profile.d/nix.sh"
    '';
  };

  # https://github.com/NixOS/nixpkgs/issues/196651#issuecomment-1283814322
  manual.manpages.enable = false;

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
        set -x SHELL /Users/pwm/.nix-profile/bin/fish
        set -x EDITOR vim
        set -p PATH ~/nix-home/bin ~/.local/bin ~/.docker/bin /nix/var/nix/profiles/default/bin

        zellij_tab_names
      '';
      shellAliases = {
        hm = "run home-manager";
        h = "history | fzy";
        f = "fd | fzy";
        ll = "exa -la --git";
        cat = "bat -pp";
        rga = "rg -g '*.{art}'";
        rgb = "rg -g '*.{sh}'";
        rgh = "rg -g '*.{hs}'";
        rgj = "rg -g '*.{js,ts,tsx}'";
        rgjs = "rg -g '*.{json}'";
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
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraConfig = ''
        set termguicolors
	set clipboard=unnamedplus
        set mouse=a
        set number
        colorscheme gruvbox
        let g:blamer_enabled = 1
        let g:blamer_delay = 500
        let g:blamer_template = '<author> | <author-time> | <commit-short> | <summary>'
	nnoremap <F5> :Files<CR>
	nnoremap <F6> :NERDTreeToggle<CR>
      '';

      plugins = with pkgs.vimPlugins; [
        gruvbox-community # theme
        editorconfig-vim # .editorconfig
        blamer-nvim # git blame
        vim-airline # status line
        fzf-vim # fuzzy search
	nerdtree # tree viewer  
	(nvim-treesitter.withPlugins (
          plugins: with plugins; [
            nix
            haskell
          ]
        ))
	haskell-tools-nvim
      ];
    };

    vscode = {
      enable = true;
      package = pkgs.vscode; # Use our version

      # error: The option `home.file.Library/Application Support/Code/User/settings.json.source' has conflicting definition values:
      #enableUpdateCheck = false;
      #enableExtensionUpdateCheck = false;

      # To update extensions.json run: bin/vscode_extensions.sh
      extensions =
        pkgs.vscode-utils.extensionsFromVscodeMarketplace
        (fromJSON (readFile ./vscode/extensions.json));
    };

    zellij = {
      enable = true;
      enableFishIntegration = true;
      # Settings are copied from zellij/config.kdl
    };
  };

  # Issues:
  # https://github.com/target/lorri/issues/96#issuecomment-545152525
  # https://github.com/target/lorri/issues/96#issuecomment-588563793
  #services = {
  #  lorri.enable = true;
  #};
}
