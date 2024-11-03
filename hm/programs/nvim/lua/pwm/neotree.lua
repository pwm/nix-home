require("neo-tree").setup({
  window = {
    width = 30,
  },
})

vim.keymap.set('n', '<leader><leader>', function()
  vim.cmd("Neotree toggle=true reveal=true")
end, { noremap = true })
