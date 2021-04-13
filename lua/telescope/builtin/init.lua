---@tag telescope.builtin

---@brief [[
--- A collection of builtin pickers for telescope.
---
--- Meant for both example and for easy startup.
---
--- Any of these functions can just be called directly by doing:
---
--- :lua require('telescope.builtin').$NAME()
---
--- This will use the default configuration options.
---   Other configuration options are still in flux at the moment
---@brief ]]

if 1 ~= vim.fn.has('nvim-0.5') then
  vim.api.nvim_err_writeln("This plugins requires neovim 0.5")
  vim.api.nvim_err_writeln("Please update your neovim.")
  return
end

local builtin = {}

--- Live grep means grep as you type.
builtin.live_grep = require('telescope.builtin.files').live_grep

builtin.grep_string = require('telescope.builtin.files').grep_string
builtin.find_files = require('telescope.builtin.files').find_files
builtin.fd = builtin.find_files
builtin.file_browser = require('telescope.builtin.files').file_browser
builtin.treesitter = require('telescope.builtin.files').treesitter
builtin.current_buffer_fuzzy_find = require('telescope.builtin.files').current_buffer_fuzzy_find
builtin.tags = require('telescope.builtin.files').tags
builtin.current_buffer_tags = require('telescope.builtin.files').current_buffer_tags

builtin.git_files = require('telescope.builtin.git').files
builtin.git_commits = require('telescope.builtin.git').commits
builtin.git_bcommits = require('telescope.builtin.git').bcommits
builtin.git_branches = require('telescope.builtin.git').branches
builtin.git_status = require('telescope.builtin.git').status

builtin.builtin = require('telescope.builtin.internal').builtin

builtin.planets = require('telescope.builtin.internal').planets
builtin.symbols = require('telescope.builtin.internal').symbols
builtin.commands = require('telescope.builtin.internal').commands
builtin.quickfix = require('telescope.builtin.internal').quickfix
builtin.loclist = require('telescope.builtin.internal').loclist
builtin.oldfiles = require('telescope.builtin.internal').oldfiles
builtin.command_history = require('telescope.builtin.internal').command_history
builtin.vim_options = require('telescope.builtin.internal').vim_options
builtin.help_tags = require('telescope.builtin.internal').help_tags
builtin.man_pages = require('telescope.builtin.internal').man_pages
builtin.reloader = require('telescope.builtin.internal').reloader
builtin.buffers = require('telescope.builtin.internal').buffers
builtin.colorscheme = require('telescope.builtin.internal').colorscheme
builtin.marks = require('telescope.builtin.internal').marks
builtin.registers = require('telescope.builtin.internal').registers
builtin.keymaps = require('telescope.builtin.internal').keymaps
builtin.filetypes = require('telescope.builtin.internal').filetypes
builtin.highlights = require('telescope.builtin.internal').highlights
builtin.autocommands = require('telescope.builtin.internal').autocommands
builtin.spell_suggest = require('telescope.builtin.internal').spell_suggest
builtin.tagstack = require('telescope.builtin.internal').tagstack

builtin.lsp_references = require('telescope.builtin.lsp').references
builtin.lsp_definitions = require('telescope.builtin.lsp').definitions
builtin.lsp_document_symbols = require('telescope.builtin.lsp').document_symbols
builtin.lsp_code_actions = require('telescope.builtin.lsp').code_actions
builtin.lsp_document_diagnostics = require('telescope.builtin.lsp').diagnostics
builtin.lsp_workspace_diagnostics = require('telescope.builtin.lsp').workspace_diagnostics
builtin.lsp_range_code_actions = require('telescope.builtin.lsp').range_code_actions
builtin.lsp_workspace_symbols = require('telescope.builtin.lsp').workspace_symbols
builtin.lsp_dynamic_workspace_symbols = require('telescope.builtin.lsp').dynamic_workspace_symbols

return builtin
