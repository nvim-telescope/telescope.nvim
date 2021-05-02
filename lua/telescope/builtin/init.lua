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
---@param t table: some input table
--- - Picker-specific options:
---   - `grep_open_files`: boolean to restrict search to open files only, mutually exclusive with `search_dirs`
---   - `search_dirs`: table of strings containing directories to search in, mutually exclusive with `grep_open_files`
builtin.live_grep = require('telescope.builtin.files').live_grep

--- Searches for the string under your cursor in your current working directory
---@param t table: some input table
--- - Picker-specific options:
---   - `search`: the string to search
---   - `search_dirs`: table of strings containing directories to search in
builtin.grep_string = require('telescope.builtin.files').grep_string

--- Lists files in your current working directory, respects .gitignore
---@param t table: some input table
--- - Picker-specific options:
---   - `find_command`: command line arguments for `find_files` to use specifically for the search, overrides default
--    - `follow`: TODO
---   - `hidden`: boolean that determines whether to show hidden files or not
---   - `search_dirs`: table of strings containing directories to search in
builtin.find_files = require('telescope.builtin.files').find_files

builtin.fd = builtin.find_files

--- Lists files and folders in your current working directory, open files, navigate your filesystem, and create new
--- files and folders
---@param t table: some input table
--- - Picker-specific default keymaps:
---   - `<cr>`: opens the currently selected file, or navigates to the currently selected directory
---   - `<C-e>`: creates new file in the current directory, creates a new directory if the name contains a trailing '/'
--- - Picker-specific options:
---   - `search_dirs`: table of strings containing directories to search in
builtin.file_browser = require('telescope.builtin.files').file_browser

--- Lists function names, variables, and other symbols from treesitter queries
---@param t table: some input table
--  TODO: finish docs for opts.show_line
--  - Picker-specific options:
--    - `show_line`: TODO
builtin.treesitter = require('telescope.builtin.files').treesitter

--- Live fuzzy search inside of the currently open buffer
---@param t table: some input table
builtin.current_buffer_fuzzy_find = require('telescope.builtin.files').current_buffer_fuzzy_find

--- Lists tags in current directory with tag location file preview (users are required to run ctags -R to generate tags
--- or update when introducing new changes)
---@param t table: some input table
--- - Picker-specific options:
---   - `ctags_file`: specify a particular ctags file to use
builtin.tags = require('telescope.builtin.files').tags

--- Lists all of the tags for the currently open buffer, with a preview
---@param t table: some input table
builtin.current_buffer_tags = require('telescope.builtin.files').current_buffer_tags


--------------------------------------------------
--
-- Git-related Pickers
--
--------------------------------------------------
--- Fuzzy search through the output of `git ls-files` command, respects .gitignore, optionally ignores untracked files
---@param t table: some input table
--- - Picker-specific options:
---   - `show_untracked`: boolean that if true, adds the `--others` flag to the search (default true)
---   - `recurse_submodules`: boolean that if true, adds the `--recurse-submodules` flag to the search (default false)
builtin.git_files = require('telescope.builtin.git').files

--- Lists commits for current directory, with diff preview and checkout on <cr>
---@param t table: some input table
builtin.git_commits = require('telescope.builtin.git').commits

--- Lists commits for current buffer, with diff preview and checkout on <cr>
---@param t table: some input table
builtin.git_bcommits = require('telescope.builtin.git').bcommits

--- List branches for current directory, with log preview
---@param t table: some input table
--- - Picker-specific default keymaps:
---   - `<C-t>`: tracks currently selected branch
---   - `<C-r>`: rebases currently selected branch
---   - `<C-a>`: creates a new branch, with confirmation prompt before creation
---   - `<C-d>`: deletes the currently selected branch, with confirmation prompt before deletion
builtin.git_branches = require('telescope.builtin.git').branches

--- Lists git status for current directory
---@param t table: some input table
--- - Picker-specific default keymaps:
---   - `<Tab>`: stages or unstages the currently selected file
builtin.git_status = require('telescope.builtin.git').status


--------------------------------------------------
--
-- Internal and Vim-related Pickers
--
--------------------------------------------------
--- Lists all of the community maintained pickers built into Telescope
---@param t table: some input table
builtin.builtin = require('telescope.builtin.internal').builtin

--- Use the telescope...
---@param t table: some input table
builtin.planets = require('telescope.builtin.internal').planets

--- Lists symbols inside of data/telescope-sources/*.json found in your runtime path. Check README for more info
---@param t table: some input table
builtin.symbols = require('telescope.builtin.internal').symbols

--- Lists available plugin/user commands and runs them on <cr>
---@param t table: some input table
builtin.commands = require('telescope.builtin.internal').commands

--- Lists items in the quickfix list
---@param t table: some input table
builtin.quickfix = require('telescope.builtin.internal').quickfix

--- Lists items from the current window's location list
---@param t table: some input table
builtin.loclist = require('telescope.builtin.internal').loclist

--- Lists previously open files
---@param t table: some input table
builtin.oldfiles = require('telescope.builtin.internal').oldfiles

--- Lists commands that were executed recently, and reruns them on <cr>
---@param t table: some input table
--- - Picker-specific keymaps:
---   - `<C-e>`: open the command line with the text of the currently selected result populated in it
builtin.command_history = require('telescope.builtin.internal').command_history

--- Lists searches that were executed recently, and reruns them on <cr>
---@param t table: some input table
--- - Picker-specific keymaps:
---   - `<C-e>`: open a search window with the text of the currently selected search result populated in it
builtin.search_history = require('telescope.builtin.internal').search_history

--- Lists vim options, allows you to edit the current value on <cr>
---@param t table: some input table
builtin.vim_options = require('telescope.builtin.internal').vim_options

--- Lists available help tags and opens a new window with the relevant help info on <cr>
---@param t table: some input table
builtin.help_tags = require('telescope.builtin.internal').help_tags

--- Lists manpage entries, opens them in a help window on <cr>
---@param t table: some input table
builtin.man_pages = require('telescope.builtin.internal').man_pages

--- Lists lua modules and reloads them on <cr>
---@param t table: some input table
builtin.reloader = require('telescope.builtin.internal').reloader

--- Lists open buffers in current neovim instance
---@param t table: some input table
builtin.buffers = require('telescope.builtin.internal').buffers

--- Lists available colorschemes and applies them on <cr>
---@param t table: some input table
builtin.colorscheme = require('telescope.builtin.internal').colorscheme

--- Lists vim marks and their value
---@param t table: some input table
builtin.marks = require('telescope.builtin.internal').marks

--- Lists vim registers, pastes the contents of the register on <cr>
---@param t table: some input table
--- - Picker-specific keymaps:
---   - `<C-e>`: edit the contents of the currently selected register
builtin.registers = require('telescope.builtin.internal').registers

--- Lists normal mode keymappings
---@param t table: some input table
builtin.keymaps = require('telescope.builtin.internal').keymaps

--- Lists all available filetypes
---@param t table: some input table
builtin.filetypes = require('telescope.builtin.internal').filetypes

--- Lists all available highlights
---@param t table: some input table
builtin.highlights = require('telescope.builtin.internal').highlights

--- Lists vim autocommands and goes to their declaration on <cr>
---@param t table: some input table
builtin.autocommands = require('telescope.builtin.internal').autocommands

--- Lists spelling suggestions for the current word under the cursor, replaces word with selected suggestion on <cr>
---@param t table: some input table
builtin.spell_suggest = require('telescope.builtin.internal').spell_suggest

--- Lists the tag stack for the current window
---@param t table: some input table
builtin.tagstack = require('telescope.builtin.internal').tagstack


--------------------------------------------------
--
-- LSP-related Pickers
--
--------------------------------------------------
--- Lists LSP references for word under the cursor
---@param t table: some input table
--- - Picker-specific options:
---   - `shorten_path`: boolean where if true, will shorten path shown
builtin.lsp_references = require('telescope.builtin.lsp').references

--- Goto the definition of the word under the cursor, if there's only one, otherwise show all options in Telescope
---@param t table: some input table
builtin.lsp_definitions = require('telescope.builtin.lsp').definitions

--- Goto the implementation of the word under the cursor if there's only one, otherwise show all options in Telescope
---@param t table: some input table
builtin.lsp_implementations = require('telescope.builtin.lsp').implementations

--- Lists LSP document symbols in the current buffer
---@param t table: some input table
--- - Picker-specific options:
---   - `ignore_filename`: string with file to ignore
builtin.lsp_document_symbols = require('telescope.builtin.lsp').document_symbols

--- Lists any LSP actions for the word under the cursor, that can be triggered with <cr>
---@param t table: some input table
builtin.lsp_code_actions = require('telescope.builtin.lsp').code_actions

--- Lists any LSP actions for a given range, that can be triggered with <cr>
---@param t table: some input table
builtin.lsp_range_code_actions = require('telescope.builtin.lsp').range_code_actions

--- Lists LSP document symbols in the current workspace
---@param t table: some input table
--- - Picker-specific options:
---   - `shorten_path`: boolean where if true, will shorten path shown
---   - `ignore_filename`: string with file to ignore
builtin.lsp_workspace_symbols = require('telescope.builtin.lsp').workspace_symbols

--- Lists LSP for all workspace symbols asynchronously
---@param t table: some input table
builtin.lsp_dynamic_workspace_symbols = require('telescope.builtin.lsp').dynamic_workspace_symbols

--- Lists LSP diagnostics for the current buffer
---@param t table: some input table
builtin.lsp_document_diagnostics = require('telescope.builtin.lsp').diagnostics

--- Lists LSP diagnostics for the current workspace if supported, otherwise searches in all open buffers
---@param t table: some input table
builtin.lsp_workspace_diagnostics = require('telescope.builtin.lsp').workspace_diagnostics

return builtin
