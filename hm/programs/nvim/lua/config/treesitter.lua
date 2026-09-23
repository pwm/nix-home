-- nvim-treesitter (main branch) only manages parsers, and nix provides those.
-- The old `configs` module with its highlight, indent and incremental_selection
-- setup is gone, so use the treesitter features built into Neovim instead.

-- Highlighting and indentation for every buffer that has a parser. start()
-- also disables regex syntax highlighting for the buffer, like the old
-- additional_vim_regex_highlighting = false did.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config.treesitter', {}),
  callback = function(args)
    if pcall(vim.treesitter.start, args.buf) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- Incremental selection with the same keymaps as before: <CR> selects the node
-- under the cursor, <TAB> (or <CR> again) grows the selection to the parent
-- node, <S-TAB> shrinks it back.
local nodes = {}

local function select_node(node)
  local srow, scol, erow, ecol = node:range() -- 0-based, end exclusive
  local end_line, end_col = erow + 1, ecol -- 1-based, end inclusive
  if end_col == 0 then
    end_line = end_line - 1
    end_col = math.max(#vim.fn.getline(end_line), 1)
  end
  if vim.fn.mode():match('[vV\22]') then
    vim.cmd('normal! \27') -- leave visual mode before starting a new selection
  end
  vim.fn.setpos('.', { 0, srow + 1, scol + 1, 0 })
  vim.cmd('normal! v')
  vim.fn.setpos('.', { 0, end_line, end_col, 0 })
end

local function init_selection()
  -- make sure the cursor line is parsed, the highlighter only parses on redraw
  local parser = vim.treesitter.get_parser(0, nil, { error = false })
  if not parser then
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  parser:parse({ row, row })
  local node = vim.treesitter.get_node()
  if not node then
    return
  end
  nodes = { node }
  select_node(node)
end

local function node_incremental()
  local node = nodes[#nodes]
  if not node then
    return init_selection()
  end
  local parent = node:parent()
  -- skip parents with the same range so every step visibly grows the selection
  while parent and vim.deep_equal({ parent:range() }, { node:range() }) do
    parent = parent:parent()
  end
  if not parent then
    return
  end
  nodes[#nodes + 1] = parent
  select_node(parent)
end

local function node_decremental()
  if #nodes > 1 then
    nodes[#nodes] = nil
  end
  if nodes[#nodes] then
    select_node(nodes[#nodes])
  end
end

vim.keymap.set('n', '<CR>', init_selection, { desc = 'Treesitter: select node' })
vim.keymap.set('x', '<CR>', node_incremental, { desc = 'Treesitter: grow selection' })
vim.keymap.set('x', '<TAB>', node_incremental, { desc = 'Treesitter: grow selection' })
vim.keymap.set('x', '<S-TAB>', node_decremental, { desc = 'Treesitter: shrink selection' })
