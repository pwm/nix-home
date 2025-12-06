-- https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/
-- to hover: :lua vim.lsp.buf.hover()
-- to format: :lua vim.lsp.buf.format()

-- Neovim 0.11+ LSP configuration using vim.lsp.config
-- See :help lspconfig-nvim-0.11

local function is_executable(command)
  return vim.fn.executable(command) == 1
end

-- Set up keymaps when an LSP attaches to a buffer
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = args.buf })
    vim.keymap.set('n', '<leader>p', vim.lsp.buf.format, { buffer = args.buf })
  end,
})

-- Haskell
-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/hls.lua
if is_executable("haskell-language-server") then
  vim.lsp.config.hls = {
    cmd = { "haskell-language-server", "--lsp" },
    filetypes = { "haskell", "lhaskell" },
    root_markers = { "*.cabal", "stack.yaml", "cabal.project", "package.yaml", "hie.yaml" },
  }
  vim.lsp.enable('hls')
end

-- Nix
-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/nil_ls.lua
if is_executable("nil") then
  vim.lsp.config.nil_ls = {
    cmd = { "nil" },
    filetypes = { "nix" },
    root_markers = { "flake.nix", ".git" },
  }
  vim.lsp.enable('nil_ls')
end

-- Lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/lua_ls.lua
if is_executable("lua-language-server") then
  vim.lsp.config.lua_ls = {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml", ".git" },
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
        },
      },
    },
  }
  vim.lsp.enable('lua_ls')
end
