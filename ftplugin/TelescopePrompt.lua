-- Don't wrap textwidth things
vim.opt_local.formatoptions:remove("t")
vim.opt_local.formatoptions:remove("c")

-- Don't include `showbreak` when calculating strdisplaywidth
vim.wo[0][0].wrap = false

-- There's also no reason to enable textwidth here anyway
vim.bo.textwidth = 0
vim.wo[0][0].scrollbind = false

vim.wo[0][0].signcolumn = "no"
