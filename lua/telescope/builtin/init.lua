---@tag telescope.builtin

---@brief [[
--- Telescope Builtins is a collection of community maintained pickers to support common workflows. It can be used as
--- reference when writing PRs, Telescope extensions, your own custom pickers, or just as a discovery tool for all of
--- the amazing pickers already shipped with Telescope!
---
--- Any of these functions can just be called directly by doing:
---
--- :lua require('telescope.builtin').$NAME_OF_PICKER()
---
--- To use any of Telescope's default options or any picker-specific options, call your desired picker by passing a lua
--- table to the picker with all of the options you want to use. Here's an example with the live_grep picker:
---
--- <pre>
--- :lua require('telescope.builtin').live_grep({
---    prompt_title = 'find string in open buffers...',
---    grep_open_files = true
---  })
--- </pre>
---
--- This will use the default configuration options. Other configuration options are still in flux at the moment
---@brief ]]

if 1 ~= vim.fn.has('nvim-0.5') then
  vim.api.nvim_err_writeln("This plugins requires neovim 0.5")
  vim.api.nvim_err_writeln("Please update your neovim.")
  return
end

local builtin = {}


--------------------------------------------------
--
-- File-related Pickers
--
--------------------------------------------------
--- Search for a string in your current working directory and get results live as you type (respecting .gitignore)
---@param opts table: options to pass to the picker
---@field grep_open_files boolean: restrict search to open files only, mutually exclusive with `search_dirs`
---@field search_dirs table: directory/directories to search in, mutually exclusive with `grep_open_files`
builtin.live_grep = require('telescope.builtin.files').live_grep

--- Searches for the string under your cursor in your current working directory
---@param opts table: options to pass to the picker
---@field search string: the query to search
---@field search_dirs table: directory/directories to search in
builtin.grep_string = require('telescope.builtin.files').grep_string

--- Lists files in your current working directory, respects .gitignore
---@param opts table: options to pass to the picker
---@field find_command table: command line arguments for `find_files` to use for the search, overrides default config
--TODO @field follow boolean:
---@field hidden boolean: determines whether to show hidden files or not
---@field search_dirs table: directory/directories to search in
builtin.find_files = require('telescope.builtin.files').find_files

builtin.fd = builtin.find_files

--- Lists files and folders in your current working directory, open files, navigate your filesystem, and create new
--- files and folders
--- - Default keymaps:
---   - <cr> type: opens the currently selected file, or navigates to the currently selected directory
---   - <C-e> type: creates new file in current directory, creates new directory if the name contains a trailing '/'
---@param opts table: options to pass to the picker
---@field search_dirs table: directory/directories to search in
builtin.file_browser = require('telescope.builtin.files').file_browser

--- Lists function names, variables, and other symbols from treesitter queries
--TODO @field show_line type:
builtin.treesitter = require('telescope.builtin.files').treesitter

--- Live fuzzy search inside of the currently open buffer
---@param opts table: options to pass to the picker
builtin.current_buffer_fuzzy_find = require('telescope.builtin.files').current_buffer_fuzzy_find

--- Lists tags in current directory with tag location file preview (users are required to run ctags -R to generate tags
--- or update when introducing new changes)
---@param opts table: options to pass to the picker
---@field ctags_file string: specify a particular ctags file to use
builtin.tags = require('telescope.builtin.files').tags

--- Lists all of the tags for the currently open buffer, with a preview
---@param opts table: options to pass to the picker
builtin.current_buffer_tags = require('telescope.builtin.files').current_buffer_tags


--------------------------------------------------
--
-- Git-related Pickers
--
--------------------------------------------------
--- Fuzzy search through the output of `git ls-files` command, respects .gitignore, optionally ignores untracked files
---@param opts table: options to pass to the picker
---@field show_untracked boolean: if true, adds the `--others` flag to the search (default true)
---@field recurse_submodules boolean: if true, adds the `--recurse-submodules` flag to the search (default false)
builtin.git_files = require('telescope.builtin.git').files

--- Lists commits for current directory, with diff preview and checkout on <cr>
---@param opts table: options to pass to the picker
builtin.git_commits = require('telescope.builtin.git').commits

--- Lists commits for current buffer, with diff preview and checkout on <cr>
---@param opts table: options to pass to the picker
builtin.git_bcommits = require('telescope.builtin.git').bcommits

--- List branches for current directory, with log preview
--- - Default keymaps:
---   - <C-t>: tracks currently selected branch
---   - <C-r>: rebases currently selected branch
---   - <C-a>: creates a new branch, with confirmation prompt before creation
---   - <C-d>: deletes the currently selected branch, with confirmation prompt before deletion
---@param opts table: options to pass to the picker
builtin.git_branches = require('telescope.builtin.git').branches

--- Lists git status for current directory
--- - Default keymaps:
---   - <Tab>: stages or unstages the currently selected file
---@param opts table: options to pass to the picker
builtin.git_status = require('telescope.builtin.git').status


--------------------------------------------------
--
-- Internal and Vim-related Pickers
--
--------------------------------------------------
--- Lists all of the community maintained pickers built into Telescope
---@param opts table: options to pass to the picker
builtin.builtin = require('telescope.builtin.internal').builtin

--- Use the telescope...
---@param opts table: options to pass to the picker
builtin.planets = require('telescope.builtin.internal').planets

--- Lists symbols inside of data/telescope-sources/*.json found in your runtime path. Check README for more info
---@param opts table: options to pass to the picker
builtin.symbols = require('telescope.builtin.internal').symbols

--- Lists available plugin/user commands and runs them on <cr>
---@param opts table: options to pass to the picker
builtin.commands = require('telescope.builtin.internal').commands

--- Lists items in the quickfix list
---@param opts table: options to pass to the picker
builtin.quickfix = require('telescope.builtin.internal').quickfix

--- Lists items from the current window's location list
---@param opts table: options to pass to the picker
builtin.loclist = require('telescope.builtin.internal').loclist

--- Lists previously open files
---@param opts table: options to pass to the picker
builtin.oldfiles = require('telescope.builtin.internal').oldfiles

--- Lists commands that were executed recently, and reruns them on <cr>
--- - Default keymaps:
---   - <C-e>: open the command line with the text of the currently selected result populated in it
---@param opts table: options to pass to the picker
builtin.command_history = require('telescope.builtin.internal').command_history

--- Lists searches that were executed recently, and reruns them on <cr>
--- - Default keymaps:
---   - <C-e>: open a search window with the text of the currently selected search result populated in it
---@param opts table: options to pass to the picker
builtin.search_history = require('telescope.builtin.internal').search_history

--- Lists vim options, allows you to edit the current value on <cr>
---@param opts table: options to pass to the picker
builtin.vim_options = require('telescope.builtin.internal').vim_options

--- Lists available help tags and opens a new window with the relevant help info on <cr>
---@param opts table: options to pass to the picker
builtin.help_tags = require('telescope.builtin.internal').help_tags

--- Lists manpage entries, opens them in a help window on <cr>
---@param opts table: options to pass to the picker
builtin.man_pages = require('telescope.builtin.internal').man_pages

--- Lists lua modules and reloads them on <cr>
---@param opts table: options to pass to the picker
builtin.reloader = require('telescope.builtin.internal').reloader

--- Lists open buffers in current neovim instance
---@param opts table: options to pass to the picker
builtin.buffers = require('telescope.builtin.internal').buffers

--- Lists available colorschemes and applies them on <cr>
---@param opts table: options to pass to the picker
builtin.colorscheme = require('telescope.builtin.internal').colorscheme

--- Lists vim marks and their value
---@param opts table: options to pass to the picker
builtin.marks = require('telescope.builtin.internal').marks

--- Lists vim registers, pastes the contents of the register on <cr>
--- - Default keymaps:
---   - <C-e>: edit the contents of the currently selected register
---@param opts table: options to pass to the picker
builtin.registers = require('telescope.builtin.internal').registers

--- Lists normal mode keymappings
---@param opts table: options to pass to the picker
builtin.keymaps = require('telescope.builtin.internal').keymaps

--- Lists all available filetypes
---@param opts table: options to pass to the picker
builtin.filetypes = require('telescope.builtin.internal').filetypes

--- Lists all available highlights
---@param opts table: options to pass to the picker
builtin.highlights = require('telescope.builtin.internal').highlights

--- Lists vim autocommands and goes to their declaration on <cr>
---@param opts table: options to pass to the picker
builtin.autocommands = require('telescope.builtin.internal').autocommands

--- Lists spelling suggestions for the current word under the cursor, replaces word with selected suggestion on <cr>
---@param opts table: options to pass to the picker
builtin.spell_suggest = require('telescope.builtin.internal').spell_suggest

--- Lists the tag stack for the current window
---@param opts table: options to pass to the picker
builtin.tagstack = require('telescope.builtin.internal').tagstack


--------------------------------------------------
--
-- LSP-related Pickers
--
--------------------------------------------------
--- Lists LSP references for word under the cursor
---@param opts table: options to pass to the picker
---@field shorten_path boolean: if true, will shorten path shown
builtin.lsp_references = require('telescope.builtin.lsp').references

--- Goto the definition of the word under the cursor, if there's only one, otherwise show all options in Telescope
---@param opts table: options to pass to the picker
builtin.lsp_definitions = require('telescope.builtin.lsp').definitions

--- Goto the implementation of the word under the cursor if there's only one, otherwise show all options in Telescope
---@param opts table: options to pass to the picker
builtin.lsp_implementations = require('telescope.builtin.lsp').implementations

--- Lists LSP document symbols in the current buffer
---@param opts table: options to pass to the picker
---@field ignore_filename type: string with file to ignore
builtin.lsp_document_symbols = require('telescope.builtin.lsp').document_symbols

--- Lists any LSP actions for the word under the cursor, that can be triggered with <cr>
---@param opts table: options to pass to the picker
builtin.lsp_code_actions = require('telescope.builtin.lsp').code_actions

--- Lists any LSP actions for a given range, that can be triggered with <cr>
---@param opts table: options to pass to the picker
builtin.lsp_range_code_actions = require('telescope.builtin.lsp').range_code_actions

--- Lists LSP document symbols in the current workspace
---@param opts table: options to pass to the picker
---@field shorten_path boolean: if true, will shorten path shown
---@field ignore_filename string: file(s) to ignore
builtin.lsp_workspace_symbols = require('telescope.builtin.lsp').workspace_symbols

--- Lists LSP for all workspace symbols asynchronously
---@param opts table: options to pass to the picker
builtin.lsp_dynamic_workspace_symbols = require('telescope.builtin.lsp').dynamic_workspace_symbols

--- Lists LSP diagnostics for the current buffer
---@param opts table: options to pass to the picker
builtin.lsp_document_diagnostics = require('telescope.builtin.lsp').diagnostics

--- Lists LSP diagnostics for the current workspace if supported, otherwise searches in all open buffers
---@param opts table: options to pass to the picker
builtin.lsp_workspace_diagnostics = require('telescope.builtin.lsp').workspace_diagnostics

return builtin
