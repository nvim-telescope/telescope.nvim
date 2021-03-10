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

-- TODO(conni2461): Making this ascending for now. I have to decide later if this
-- is better or worse
---@config { ['function_order'] = 'ascending' }

if 1 ~= vim.fn.has('nvim-0.5') then
  vim.api.nvim_err_writeln("This plugins requires neovim 0.5")
  vim.api.nvim_err_writeln("Please update your neovim.")
  return
end

local builtin = {}

--- Live grep means grep as you type.
builtin.live_grep = require('telescope.builtin.files').live_grep

builtin.grep_string = require('telescope.builtin.files').grep_string

--- Lists files in current directory using `fd`, `ripgrep` or `find`.
--- It will not show directories or gitignored files (when using `fd` or `ripgrep`).
--- Later can be enabled with a different `find_command`.
---@param opts table: Configure behavior of `find_files`.
---@field find_command table: Specify your find command as a table of strings.
---@field hidden boolean: Enable or disable hidden files. Default is false.
---@field follow boolean: Enable or disable if symbolic links should be followed. Default is false.
---@field cwd string: Specify the path on which find_files should run.
---@field search_dirs table: Specify multiple search directories as table of paths.
---@field entry_maker function: How entries are generated. Can be changed if you want a different display output.
---@field disable_devicons boolen: Enable or disable devicons in front of each entry. Default is true if nvim-web-devicons is installed.
---@field shorten_path boolean: Enable or disable if paths should be shortened. Default is false.
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

builtin.lsp_references = require('telescope.builtin.lsp').references
builtin.lsp_definitions = require('telescope.builtin.lsp').definitions
builtin.lsp_document_symbols = require('telescope.builtin.lsp').document_symbols
builtin.lsp_code_actions = require('telescope.builtin.lsp').code_actions
builtin.lsp_document_diagnostics = require('telescope.builtin.lsp').diagnostics
builtin.lsp_workspace_diagnostics = require('telescope.builtin.lsp').workspace_diagnostics
builtin.lsp_range_code_actions = require('telescope.builtin.lsp').range_code_actions
builtin.lsp_workspace_symbols = require('telescope.builtin.lsp').workspace_symbols

return builtin
