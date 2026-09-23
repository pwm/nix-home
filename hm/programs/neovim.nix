{ pkgs }:
{
  enable = true;

  viAlias = true;
  vimAlias = true;
  vimdiffAlias = true;

  # No Python or Ruby remote plugins are used. These are the new home-manager
  # defaults, set explicitly as our stateVersion predates the change.
  withPython3 = false;
  withRuby = false;

  # home-manager writes its generated Lua (provider settings, Lua rock paths)
  # to ~/.config/nvim/init.lua, which our xdg-managed nvim directory would
  # shadow. Load it through the nvim wrapper instead.
  sideloadInitLua = true;

  # The config is handled in xdg

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
      # playground was archived upstream, use the built-in :InspectTree instead
      gitsigns-nvim
      neogit
      comment-nvim
      lualine-nvim
      nvim-lspconfig
      # nvim-cmp
      # lspkind-nvim
    ]
    ++ import ./nvim/themes.nix { inherit pkgs; };
}
