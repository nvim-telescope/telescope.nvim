-- Don't wrap textwidth things
vim.opt_local.formatoptions:remove "t"
vim.opt_local.formatoptions:remove "c"

-- Don't include `showbreak` when calculating strdisplaywidth
vim.opt_local.wrap = false

-- There's also no reason to enable textwidth here anyway
vim.opt_local.textwidth = 0
