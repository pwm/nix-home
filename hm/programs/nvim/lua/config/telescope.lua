local telescope = require('telescope')
local builtin = require('telescope.builtin')
local actions = require('telescope.actions')

local opts = { noremap = true }
vim.keymap.set('n', '<leader>f', builtin.find_files, opts)
vim.keymap.set('n', '<leader>/', builtin.live_grep, opts)
vim.keymap.set('n', '<leader>w', builtin.buffers, opts)
vim.keymap.set('n', '<leader>h', builtin.help_tags, opts)
vim.keymap.set('n', '<leader>c', function() vim.cmd("Telescope file_browser path=%:p:h select_buffer=true") end, opts)
vim.keymap.set('n', '<leader>u', function() vim.cmd('Telescope undo') end, opts)
vim.keymap.set('n', '<leader>s', function() builtin.lsp_document_symbols() end, opts)

telescope.setup({
  defaults = {
    layout_strategy = 'center',
    layout_config = {
      width = 0.7,
    },
    sorting_strategy = 'ascending',
    preview = {
      hide_on_startup = true,
    },
    mappings = {
      i = {
        ["<esc>"] = actions.close
      },
    },
  },
  pickers = {
    find_files = {
      theme = 'dropdown',
    }
  },
  extensions = {
    file_browser = {
      hijack_netrw = true,
      theme = "dropdown",
    },
    undo = {},
  },
})

telescope.load_extension("file_browser")
telescope.load_extension("undo")
telescope.load_extension('hoogle')
telescope.load_extension("manix")
