--[[
vim.api.nvim_buf_set_lines(0, 4, -1, false, vim.tbl_keys(require('telescope.builtin')))
--]]

require('telescope.builtin').git_files()
RELOAD('telescope'); require('telescope.builtin').oldfiles()
require('telescope.builtin').grep_string()
require('telescope.builtin').lsp_document_symbols()
RELOAD('telescope'); require('telescope.builtin').lsp_workspace_symbols()
require('telescope.builtin').lsp_references()
require('telescope.builtin').builtin()
require('telescope.builtin').fd()
require('telescope.builtin').command_history()
require('telescope.builtin').live_grep()
require('telescope.builtin').loclist()

-- TODO: make a function that puts stuff into quickfix.
--          that way we can test this better.
require('telescope.builtin').quickfix()
