vim.cmd('colorscheme vscode')

vim.g.mapleader = ' '

-- https://neovim.io/doc/user/options.html
vim.opt.clipboard = "unnamedplus"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.showmatch = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.wrap = false
vim.opt.smartindent = true
vim.opt.updatetime = 100
vim.opt.signcolumn = "yes:1"
vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 5
vim.opt.hlsearch = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = true
vim.opt.undodir = os.getenv("HOME") .. "/.nvim/undodir"

-- Keymaps (note: need zellij lock mode)
vim.keymap.set("v", "<M-Down>", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "<M-Up>", ":m '<-2<CR>gv=gv")
vim.keymap.set("v", "<S-M-Down>", ":t'><CR>gv=gv")
vim.keymap.set("v", "<S-M-Up>", ":t'<-1<CR>gv=gv")
vim.keymap.set("n", "Q", "<nop>")
-- vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
