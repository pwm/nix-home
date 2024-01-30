{pkgs}: {
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
      plugins:
        with plugins; [
          nix
          haskell
        ]
    ))
    nvim-lspconfig
    haskell-tools-nvim
  ];
}
