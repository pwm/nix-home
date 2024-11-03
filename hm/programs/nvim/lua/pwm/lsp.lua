-- https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/
-- to hover: :lua vim.lsp.buf.hover()
-- to format: :lua vim.lsp.buf.format()

-- TODO: finish setup

local lspconfig = require("lspconfig")

local function is_executable(command)
  return vim.fn.executable(command) == 1
end

-- vim.lsp.start({
--   name = "haskell-language-server",
--   cmd = { "haskell-language-server", "--lsp" },
--   root_dir = lspconfig.util.root_pattern("*.cabal", "stack.yaml", "cabal.project", "package.yaml", "hie.yaml"),
-- })
-- vim.api.nvim_create_autocmd('LspAttach', {
--   callback = function(args)
--     local client = vim.lsp.get_client_by_id(args.data.client_id)
--     if client.server_capabilities.hoverProvider then
--       vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = args.buf })
--     end
--   end,
-- })

local on_attach = function(_client, _bufnr)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
  vim.keymap.set('n', '<leader>p', vim.lsp.buf.format, {})
end

-- vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
--   vim.lsp.handlers.hover,
--   {border = 'rounded'}
-- )

-- Haskell
-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/hls.lua
if is_executable("haskell-language-server") then
  lspconfig.hls.setup({
    on_attach = on_attach,
    cmd = { "haskell-language-server", "--lsp" },
  })
end
-- Nix
-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/nil_ls.lua
if is_executable("nil") then
  lspconfig.nil_ls.setup({
    on_attach = on_attach,
    cmd = { "nil" },
  })
end

-- Lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/lua_ls.lua
if is_executable("lua-language-server") then
  lspconfig.lua_ls.setup({
    on_attach = on_attach,
    cmd = { "lua-language-server" },
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
  })
end
