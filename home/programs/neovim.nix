{pkgs}: {
  enable = true;

  viAlias = true;
  vimAlias = true;
  vimdiffAlias = true;

  plugins = with pkgs.vimPlugins;
    [
      telescope-nvim
      telescope-file-browser-nvim
      telescope-undo-nvim
      telescope_hoogle
      telescope-manix
      neo-tree-nvim
      nvim-web-devicons
      nvim-treesitter.withAllGrammars
      # nvim-treesitter-textobjects
      playground
      gitsigns-nvim
      neogit
      comment-nvim
      lualine-nvim
      nvim-lspconfig
      # nvim-cmp
      # lspkind-nvim
    ]
    ++ import ./neovim-themes.nix {inherit pkgs;};
}
