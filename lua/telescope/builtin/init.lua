---@diagnostic disable: undefined-doc-param

---@brief
--- Telescope Builtins is a collection of community maintained pickers to support common workflows. It can be used as
--- reference when writing PRs, Telescope extensions, your own custom pickers, or just as a discovery tool for all of
--- the amazing pickers already shipped with Telescope!
---
--- Any of these functions can just be called directly by doing:
--- ```vim
--- :lua require('telescope.builtin').$NAME_OF_PICKER()
--- ```
---
--- To use any of Telescope's default options or any picker-specific options, call your desired picker by passing a lua
--- table to the picker with all of the options you want to use. Here's an example with the live_grep picker:
--- ```lua
--- require('telescope.builtin').live_grep({
---   prompt_title = 'find string in open buffers...',
---   grep_open_files = true
--- })
--- -- or with dropdown theme
--- require("telescope.builtin").find_files(
---   require("telescope.themes").get_dropdown { previewer = false }
--- )
--- ```

local builtin = {}

-- Ref: https://github.com/tjdevries/lazy.nvim
local function require_on_exported_call(mod)
  return setmetatable({}, {
    __index = function(_, picker)
      return function(...)
        return require(mod)[picker](...)
      end
    end,
  })
end

--
--
-- File-related Pickers
--
--

---@inlinedocdoc
---@class telescope.builtin.live_grep.opts : telescope.builtin.base_opts
---@field cwd? string root dir to search from (default: cwd, use utils.buffer_dir() to search relative to open buffer)
---@field grep_open_files? boolean if true, restrict search to open files only, mutually exclusive with `search_dirs`
---@field search_dirs? table directory/directories/files to search, mutually exclusive with `grep_open_files`
---@field glob_pattern? (string|string[]) argument to be used with `--glob`, e.g. `*.toml`, can use the opposite `!*.toml`
---@field type_filter? string argument to be used with `--type`, e.g. "rust", see `rg --type-list`
---@field additional_args? (fun(opts: table): string[])|table: additional arguments to be passed on.
---@field disable_coordinates? boolean don't show the line & row numbers (default: `false`)
---@field file_encoding? string file encoding for the entry & previewer

--- Search for a string and get results live as you type, respects .gitignore
---@param opts? telescope.builtin.live_grep.opts table: options to pass to the picker
builtin.live_grep = require_on_exported_call("telescope.builtin.__files").live_grep

---@inlinedocdoc
---@class telescope.builtin.grep_string.opts : telescope.builtin.base_opts
---@field cwd? string root dir to search from (default: cwd, use utils.buffer_dir() to search relative to open buffer)
---@field search? string the query to search
---@field grep_open_files? boolean if true, restrict search to open files only, mutually exclusive with `search_dirs`
---@field search_dirs? table directory/directories/files to search, mutually exclusive with `grep_open_files`
---@field use_regex? boolean if true, special characters won't be escaped, allows for using regex (default: `false`)
---@field word_match? string can be set to `-w` to enable exact word matches
---@field additional_args? (fun(opts: table): string[])|table: additional arguments to be passed on.
---@field disable_coordinates? boolean don't show the line and row numbers (default: `false`)
---@field only_sort_text? boolean only sort the text, not the file, line or row (default: `false`)
---@field file_encoding? string file encoding for the entry & previewer

--- Searches for the string under your cursor or the visual selection in your current working directory
---@param opts? telescope.builtin.grep_string.opts: options to pass to the picker
builtin.grep_string = require_on_exported_call("telescope.builtin.__files").grep_string

---@inlinedoc
---@class telescope.builtin.find_files.opts : telescope.builtin.base_opts
---@field cwd? string root dir to search from (default: cwd, use utils.buffer_dir() to search relative to open buffer)
---@field find_command? (function|table) cmd to use for the search. Can be a fn(opts) -> tbl (default: autodetect)
---@field file_entry_encoding? string encoding of output of `find_command`
---@field follow? boolean if true, follows symlinks (i.e. uses `-L` flag for the `find` command) (default: `false`)
---@field hidden? boolean determines whether to show hidden files or not (default: `false`)
---@field no_ignore? boolean show files ignored by .gitignore, .ignore, etc. (default: `false`)
---@field no_ignore_parent? boolean show files ignored by .gitignore, .ignore, etc. in parent dirs. (default: `false`)
---@field search_dirs? table directory/directories/files to search
---@field search_file? string specify a filename to search for
---@field file_encoding? string file encoding for the previewer

--- Search for files (respecting .gitignore)
---@param opts? telescope.builtin.find_files.opts: options to pass to the picker
builtin.find_files = require_on_exported_call("telescope.builtin.__files").find_files

--- This is an alias for the `find_files` picker
builtin.fd = builtin.find_files

---@inlinedoc
---@class telescope.builtin.treesitter.opts : telescope.builtin.base_opts
---@field show_line? boolean if true, shows the row:column that the result is found at (default: `true`)
---@field bufnr? number specify the buffer number where treesitter should run. (default: current buffer)
---@field symbol_width? number defines the width of the symbol section (default: `25`)
---@field symbols? (string|table) filter results by symbol kind(s)
---@field ignore_symbols? (string|table) list of symbols to ignore
---@field symbol_highlights? table string -> string. Matches symbol with hl_group
---@field file_encoding? string file encoding for the previewer

--- Lists function names, variables, and other symbols from treesitter queries
---
--- Default keymaps:
---   - `<C-l>`: show autocompletion menu to prefilter your query by kind of ts node you want to see (i.e. `:var:`)
---@param opts? telescope.builtin.treesitter.opts: options to pass to the picker
builtin.treesitter = require_on_exported_call("telescope.builtin.__files").treesitter

---@inlinedoc
---@class telescope.builtin.current_buffer_fuzzy_find.opts : telescope.builtin.base_opts
---@field skip_empty_lines? boolean if true we don't display empty lines (default: `false`)
---@field results_ts_highlight? boolean highlight result entries with treesitter (default: `true`)
---@field file_encoding? string file encoding for the previewer

--- Live fuzzy search inside of the currently open buffer
---@param opts? telescope.builtin.current_buffer_fuzzy_find.opts: options to pass to the picker
builtin.current_buffer_fuzzy_find = require_on_exported_call("telescope.builtin.__files").current_buffer_fuzzy_find

---@inlinedoc
---@class telescope.builtin.tags.opts : telescope.builtin.base_opts
---@field cwd? string root dir to search from (default: cwd, use utils.buffer_dir() to search relative to open buffer)
---@field ctags_file? string specify a particular ctags file to use
---@field show_line? boolean if true, shows the content of the line the tag is found on in the picker (default: `true`)
---@field show_kind? boolean if true and kind info is available, show the kind of the tag (default: `true`)
---@field only_sort_tags? boolean if true we will only sort tags (default: `false`)
---@field fname_width? number defines the width of the filename section (default: `30`)

--- Lists tags in current directory with tag location file preview (users are required to run ctags -R to generate tags
--- or update when introducing new changes)
---@param opts? telescope.builtin.tags.opts: options to pass to the picker
builtin.tags = require_on_exported_call("telescope.builtin.__files").tags

---@inlinedoc
---@class telescope.builtin.current_buffer_tags.opts : telescope.builtin.base_opts
---@field cwd? string root dir to search from (default: cwd, use utils.buffer_dir() to search relative to open buffer)
---@field ctags_file? string specify a particular ctags file to use
---@field show_line? boolean if true, shows the content of the line the tag is found on in the picker (default: `true`)
---@field show_kind? boolean if true and kind info is available, show the kind of the tag (default: `true`)
---@field only_sort_tags? boolean if true we will only sort tags (default: `false`)
---@field fname_width? number defines the width of the filename section (default: `30`)

--- Lists all of the tags for the currently open buffer, with a preview
---@param opts? telescope.builtin.current_buffer_tags.opts: options to pass to the picker
builtin.current_buffer_tags = require_on_exported_call("telescope.builtin.__files").current_buffer_tags

--
--
-- Git-related Pickers
--
--

---@inlinedoc
---@class telescope.builtin.git_opts : telescope.builtin.base_opts
---@field _is_bare boolean: if the repo is a bare repo
---@field cwd? string the path of the repo
---@field use_file_path? boolean if we should use the current buffer git root (default: `false`)
---@field use_git_root? boolean if we should use git root as cwd or the cwd (important for submodule) (default: `true`)

---@inlinedoc
---@class telescope.builtin.git_files.opts : telescope.builtin.git_opts
---@field show_untracked? boolean if true, adds `--others` flag to command and shows untracked files (default: `false`)
---@field recurse_submodules? boolean if true, adds the `--recurse-submodules` flag to command (default: `false`)
---@field git_command? table command that will be executed. (default: `{"git", "-c", "core.quotepath=false", "ls-files", "--exclude-standard", "--cached" }`)
---@field file_encoding? string file encoding for the previewer

--- Fuzzy search for files tracked by Git. This command lists the output of the `git ls-files` command,
--- respects .gitignore
---
--- Default keymaps:
---   - `<cr>`: opens the currently selected file
---@param opts? telescope.builtin.git_files.opts: options to pass to the picker
builtin.git_files = require_on_exported_call("telescope.builtin.__git").files

---@inlinedoc
---@class telescope.builtin.git_commits.opts : telescope.builtin.git_opts
---@field git_command? table command that will be executed. (default: `{"git","log","--pretty=oneline","--abbrev-commit","--","."}`)

--- Lists commits for current directory with diff preview
---
--- Default keymaps:
---   - `<cr>`: checks out the currently selected commit
---   - `<C-r>m`: resets current branch to selected commit using mixed mode
---   - `<C-r>s`: resets current branch to selected commit using soft mode
---   - `<C-r>h`: resets current branch to selected commit using hard mode
---@param opts? telescope.builtin.git_commits.opts: options to pass to the picker
builtin.git_commits = require_on_exported_call("telescope.builtin.__git").commits

---@inlinedoc
---@class telescope.builtin.git_bcommits.opts : telescope.builtin.git_opts
---@field current_file? string specify the current file that should be used for bcommits (default: current buffer)
---@field git_command? table command that will be executed. (default: `{"git","log","--pretty=oneline","--abbrev-commit"}`)

--- Lists commits for current buffer with diff preview
---
--- Default keymaps or your overridden `select_` keys:
---   - `<cr>`: checks out the currently selected commit
---   - `<c-v>`: opens a diff in a vertical split
---   - `<c-x>`: opens a diff in a horizontal split
---   - `<c-t>`: opens a diff in a new tab
---@param opts? telescope.builtin.git_bcommits.opts: options to pass to the picker
builtin.git_bcommits = require_on_exported_call("telescope.builtin.__git").bcommits

---@inlinedoc
---@class telescope.builtin.git_bcommits_range.opts : telescope.builtin.git_bcommits.opts
---@field from? number the first line number in the range (default: current line)
---@field to? number the last line number in the range (default: the value of `from`)
---@field operator? boolean select lines in operator-pending mode (default: `false`)

--- Lists commits for a range of lines in the current buffer with diff preview
--- In visual mode, lists commits for the selected lines
--- With operator mode enabled, lists commits inside the text object/motion
---
--- Default keymaps or your overridden `select_` keys:
---   - `<cr>`: checks out the currently selected commit
---   - `<c-v>`: opens a diff in a vertical split
---   - `<c-x>`: opens a diff in a horizontal split
---   - `<c-t>`: opens a diff in a new tab
---@param opts? telescope.builtin.git_bcommits_range.opts: options to pass to the picker
builtin.git_bcommits_range = require_on_exported_call("telescope.builtin.__git").bcommits_range

---@inlinedoc
---@class telescope.builtin.git_branches.opts : telescope.builtin.git_opts
---@field show_remote_tracking_branches? boolean show remote tracking branches like origin/main (default: `true`)
---@field pattern? string specify the pattern to match all refs

--- List branches for current directory, with output from `git log --oneline` shown in the preview window
---
--- Default keymaps:
---   - `<cr>`: checks out the currently selected branch
---   - `<C-t>`: tracks currently selected branch
---   - `<C-r>`: rebases currently selected branch
---   - `<C-a>`: creates a new branch, with confirmation prompt before creation
---   - `<C-d>`: deletes the currently selected branch, with confirmation prompt before deletion
---   - `<C-y>`: merges the currently selected branch, with confirmation prompt before deletion
---@param opts? telescope.builtin.git_branches.opts: options to pass to the picker
builtin.git_branches = require_on_exported_call("telescope.builtin.__git").branches

---@inlinedoc
---@class telescope.builtin.git_status.opts : telescope.builtin.git_opts
---@field git_icons? table string -> string. Matches name with icon (see source code, make_entry.lua git_icon_defaults)
---@field expand_dir? boolean pass flag `-uall` to show files in untracked directories (default: `true`)

--- Lists git status for current directory
---
--- Default keymaps:
---   - `<Tab>`: stages or unstages the currently selected file
---   - `<cr>`: opens the currently selected file
---@param opts? telescope.builtin.git_status.opts: options to pass to the picker
builtin.git_status = require_on_exported_call("telescope.builtin.__git").status

---@inlinedoc
---@class telescope.builtin.git_stash.opts : telescope.builtin.git_opts
---@field show_branch? boolean if we should display the branch name for git stash entries (default: `true`)

--- Lists stash items in current repository
---
--- Default keymaps:
---   - `<cr>`: runs `git apply` for currently selected stash
---@param opts? table: options to pass to the picker
builtin.git_stash = require_on_exported_call("telescope.builtin.__git").stash

--
--
-- Internal and Vim-related Pickers
--
--

---@inlinedoc
---@class telescope.builtin.builtin.opts : telescope.builtin.base_opts
---@field include_extensions? boolean if true will show the pickers of the installed extensions (default: `false`)
---@field use_default_opts? boolean if the selected picker should use its default options (default: `false`)

--- Lists all of the community maintained pickers built into Telescope
---@param opts? telescope.builtin.builtin.opts: options to pass to the picker
builtin.builtin = require_on_exported_call("telescope.builtin.__internal").builtin

---@inlinedoc
---@class telescope.builtin.resume.opts : telescope.builtin.base_opts
---@field cache_index? number what picker to resume, where 1 denotes most recent (default: `1`)

--- Opens the previous picker in the identical state (incl. multi selections)
---@note Requires `cache_picker` in setup or when having invoked pickers, see |telescope.defaults.cache_picker|
---@param opts? telescope.builtin.resume.opts: options to pass to the picker
builtin.resume = require_on_exported_call("telescope.builtin.__internal").resume

---@inlinedoc
---@class telescope.builtin.pickers.opts : telescope.builtin.base_opts

--- Opens a picker over previously cached pickers in their preserved states (incl. multi selections)
---
--- Default keymaps:
---   - `<C-x>`: delete the selected cached picker
---@note Requires `cache_picker` in setup or when having invoked pickers, see |telescope.defaults.cache_picker|
---@param opts? telescope.builtin.pickers.opts: options to pass to the picker
builtin.pickers = require_on_exported_call("telescope.builtin.__internal").pickers

---@inlinedoc
---@class telescope.builtin.planets.opts : telescope.builtin.base_opts
---@field show_pluto? boolean we love Pluto (default: `false`, because its a hidden feature)
---@field show_moon? boolean we love the Moon (default: `false`, because its a hidden feature)

--- Use the telescope...
---@param opts? telescope.builtin.planets.opts: options to pass to the picker
builtin.planets = require_on_exported_call("telescope.builtin.__internal").planets

---@inlinedoc
---@class telescope.builtin.symbol.opts : telescope.builtin.base_opts
---@field symbol_path? string specify the second path. Default: `stdpath("data")/telescope/symbols/*.json`
---@field sources? table specify a table of sources you want to load this time

--- Lists symbols inside of `data/telescope-sources/*.json` found in your runtime path
--- or found in `stdpath("data")/telescope/symbols/*.json`. The second path can be customized.
--- We provide a couple of default symbols which can be found in
--- https://github.com/nvim-telescope/telescope-symbols.nvim. This repos README also provides more
--- information about the format in which the symbols have to be.
---@param opts? telescope.builtin.symbol.opts: options to pass to the picker
builtin.symbols = require_on_exported_call("telescope.builtin.__internal").symbols

---@inlinedoc
---@class telescope.builtin.commands.opts : telescope.builtin.base_opts
---@field show_buf_command? boolean show buf local command (default: `true`)

--- Lists available plugin/user commands and runs them on `<cr>`
---@param opts? telescope.builtin.commands.opts: options to pass to the picker
builtin.commands = require_on_exported_call("telescope.builtin.__internal").commands

---@inlinedoc
---@class telescope.builtin.quickfix.opts : telescope.builtin.base_opts
---@field show_line? boolean show results text (default: `true`)
---@field trim_text? boolean trim results text (default: `false`)
---@field nr? number specify the quickfix list number

--- Lists items in the quickfix list, jumps to location on `<cr>`
---@param opts? telescope.builtin.quickfix.opts: options to pass to the picker
builtin.quickfix = require_on_exported_call("telescope.builtin.__internal").quickfix

---@inlinedoc
---@class telescope.builtin.quickfixhistory.opts : telescope.builtin.base_opts

--- Lists all quickfix lists in your history and open them with `builtin.quickfix`. It seems that neovim
--- only keeps the full history for 10 lists
---@param opts? telescope.builtin.quickfixhistory.opts: options to pass to the picker
builtin.quickfixhistory = require_on_exported_call("telescope.builtin.__internal").quickfixhistory

---@inlinedoc
---@class telescope.builtin.loclist.opts : telescope.builtin.base_opts
---@field show_line? boolean show results text (default: `true`)
---@field trim_text? boolean trim results text (default: `false`)

--- Lists items from the current window's location list, jumps to location on `<cr>`
---@param opts? telescope.builtin.loclist.opts: options to pass to the picker
builtin.loclist = require_on_exported_call("telescope.builtin.__internal").loclist

---@inlinedoc
---@class telescope.builtin.oldfiles.opts : telescope.builtin.base_opts
---@field cwd? string specify a working directory to filter oldfiles by
---@field only_cwd? boolean show only files in the cwd (default: `false`)
---@field cwd_only? boolean alias for only_cwd
---@field file_encoding? string file encoding for the previewer

--- Lists previously open files, opens on `<cr>`
---@param opts? telescope.builtin.oldfiles.opts: options to pass to the picker
builtin.oldfiles = require_on_exported_call("telescope.builtin.__internal").oldfiles

---@inlinedoc
---@class telescope.builtin.commands_history.opts : telescope.builtin.base_opts
---@field filter_fn? (fun(cmd: string): boolean) returns true if the history command should be presented.

--- Lists commands that were executed recently, and reruns them on `<cr>`
---
--- Default keymaps:
---   - `<C-e>`: open the command line with the text of the currently selected result populated in it
---@param opts? telescope.builtin.commands_history.opts: options to pass to the picker
builtin.command_history = require_on_exported_call("telescope.builtin.__internal").command_history

---@inlinedoc
---@class telescope.builtin.search_history.opts : telescope.builtin.base_opts

--- Lists searches that were executed recently, and reruns them on `<cr>`
---
--- Default keymaps:
---   - `<C-e>`: open a search window with the text of the currently selected search result populated in it
---@param opts? telescope.builtin.search_history.opts: options to pass to the picker
builtin.search_history = require_on_exported_call("telescope.builtin.__internal").search_history

---@inlinedoc
---@class telescope.builtin.vim_options.opts : telescope.builtin.base_opts

--- Lists vim options, allows you to edit the current value on `<cr>`
---@param opts? telescope.builtin.vim_options.opts: options to pass to the picker
builtin.vim_options = require_on_exported_call("telescope.builtin.__internal").vim_options

---@inlinedoc
---@class telescope.builtin.help_tags.opts : telescope.builtin.base_opts
---@field lang? string specify language (default: `vim.o.helplang`)
---@field fallback? boolean fallback to en if language isn't installed (default: `true`)

--- Lists available help tags and opens a new window with the relevant help info on `<cr>`
---@param opts? telescope.builtin.help_tags.opts: options to pass to the picker
builtin.help_tags = require_on_exported_call("telescope.builtin.__internal").help_tags

---@inlinedoc
---@class telescope.builtin.man_pages.opts : telescope.builtin.base_opts
---@field sections? string[] a list of sections to search, use `{ "ALL" }` to search in all sections (default: `{ "1" }`)
---@field man_cmd? function that returns the man command. (Default: `apropos ""` on linux, `apropos " "` on macos)

--- Lists manpage entries, opens them in a help window on `<cr>`
---@param opts? telescope.builtin.man_pages.opts: options to pass to the picker
builtin.man_pages = require_on_exported_call("telescope.builtin.__internal").man_pages

---@inlinedoc
---@class telescope.builtin.reload.opts : telescope.builtin.base_opts
---@field column_len? number define the max column len for the module name (default: dynamic, longest module name)

--- Lists lua modules and reloads them on `<cr>`
---@param opts? telescope.builtin.reload.opts: options to pass to the picker
builtin.reloader = require_on_exported_call("telescope.builtin.__internal").reloader

---@inlinedoc
---@class telescope.builtin.buffers.opts : telescope.builtin.base_opts
---@field cwd? string specify a working directory to filter buffers list by
---@field show_all_buffers? boolean if true, show all buffers, including unloaded buffers (default: `true`)
---@field ignore_current_buffer? boolean if true, don't show the current buffer in the list (default: `false`)
---@field only_cwd? boolean if true, only show buffers in the current working directory (default: `false`)
---@field cwd_only? boolean alias for only_cwd
---@field sort_lastused? boolean Sorts current and last buffer to the top and selects the lastused (default: `false`)
---@field sort_mru? boolean Sorts all buffers after most recent used. Not just the current and last one (default: `false`)
---@field bufnr_width? number Defines the width of the buffer numbers in front of the filenames  (default: dynamic)
---@field file_encoding? string file encoding for the previewer
---
---  sort fn(bufnr_a, bufnr_b). true if bufnr_a should go first. Runs after sorting by most recent (if specified)
---@field sort_buffers? (fun(buf_a: number, buf_b: number): boolean)?
---@field select_current? boolean select current buffer (default: `false`)

--- Lists open buffers in current neovim instance, opens selected buffer on `<cr>`
---
--- Default keymaps:
---   - `<M-d>`: delete the currently selected buffer
---@param opts? telescope.builtin.buffers.opts: options to pass to the picker
builtin.buffers = require_on_exported_call("telescope.builtin.__internal").buffers

---@inlinedoc
---@class telescope.builtin.colorscheme.opts : telescope.builtin.base_opts
---@field colors? table a list of additional colorschemes to explicitly make available to telescope (default: `{}`)
---@field enable_preview? boolean if true, will preview the selected color
---@field ignore_builtins? boolean if true, builtin colorschemes are not listed

--- Lists available colorschemes and applies them on `<cr>`
---@param opts? telescope.builtin.colorscheme.opts: options to pass to the picker
builtin.colorscheme = require_on_exported_call("telescope.builtin.__internal").colorscheme

---@inlinedoc
---@class telescope.builtin.marks.opts : telescope.builtin.base_opts
---@field file_encoding? string file encoding for the previewer
---@field mark_type? "all"|"global"|"local": filter marks by type (default: `"all"`)

--- Lists vim marks and their value, jumps to the mark on `<cr>`
---@param opts? telescope.builtin.marks.opts: options to pass to the picker
builtin.marks = require_on_exported_call("telescope.builtin.__internal").marks

---@inlinedoc
---@class telescope.builtin.registers.opts : telescope.builtin.base_opts

--- Lists vim registers, pastes the contents of the register on `<cr>`
---
--- Default keymaps:
---   - `<C-e>`: edit the contents of the currently selected register
---@param opts? telescope.builtin.registers.opts: options to pass to the picker
builtin.registers = require_on_exported_call("telescope.builtin.__internal").registers

---@inlinedoc
---@class telescope.builtin.keymaps.opts : telescope.builtin.base_opts
---@field modes? table a list of short-named keymap modes to search (default: `{ "n", "i", "c", "x" }`)
---@field show_plug? boolean if true, the keymaps for which the lhs contains `<Plug>` are also shown (default: `true`)
---@field only_buf? boolean if true, only show the buffer-local keymaps (default: `false`)
---@field lhs_filter? (fun(lhs:string): boolean) return true for keymap.lhs if the keymap should be shown
---@field filter? (fun(keymap: table): boolean) return true for the keymap if it should be shown

--- Lists normal mode keymappings, runs the selected keymap on `<cr>`
---@param opts? telescope.builtin.keymaps.opts: options to pass to the picker
builtin.keymaps = require_on_exported_call("telescope.builtin.__internal").keymaps

---@inlinedoc
---@class telescope.builtin.filetypes.opts : telescope.builtin.base_opts

--- Lists all available filetypes, sets currently open buffer's filetype to selected filetype in Telescope on `<cr>`
---@param opts? telescope.builtin.filetypes.opts: options to pass to the picker
builtin.filetypes = require_on_exported_call("telescope.builtin.__internal").filetypes

---@inlinedoc
---@class telescope.builtin.highlights.opts : telescope.builtin.base_opts

--- Lists all available highlights
---@param opts? telescope.builtin.highlights.opts: options to pass to the picker
builtin.highlights = require_on_exported_call("telescope.builtin.__internal").highlights

---@inlinedoc
---@class telescope.builtin.autocommands.opts : telescope.builtin.base_opts

--- Lists vim autocommands and goes to their declaration on `<cr>`
---@param opts? telescope.builtin.autocommands.opts: options to pass to the picker
builtin.autocommands = require_on_exported_call("telescope.builtin.__internal").autocommands

---@inlinedoc
---@class telescope.builtin.spell_suggest.opts : telescope.builtin.base_opts

--- Lists spelling suggestions for the current word under the cursor, replaces word with selected suggestion on `<cr>`
---@param opts? telescope.builtin.spell_suggest.opts: options to pass to the picker
builtin.spell_suggest = require_on_exported_call("telescope.builtin.__internal").spell_suggest

---@inlinedoc
---@class telescope.builtin.tagstack.opts : telescope.builtin.base_opts
---@field show_line? boolean show results text (default: `true`)
---@field trim_text? boolean trim results text (default: `false`)

--- Lists the tag stack for the current window, jumps to tag on `<cr>`
---@param opts? telescope.builtin.tagstack.opts: options to pass to the picker
builtin.tagstack = require_on_exported_call("telescope.builtin.__internal").tagstack

---@inlinedoc
---@class telescope.builtin.jumplist.opts : telescope.builtin.base_opts
---@field show_line? boolean show results text (default: `true`)
---@field trim_text? boolean trim results text (default: `false`)

--- Lists items from Vim's jumplist, jumps to location on `<cr>`
---@param opts? telescope.builtin.jumplist.opts: options to pass to the picker
builtin.jumplist = require_on_exported_call("telescope.builtin.__internal").jumplist

--
--
-- LSP-related Pickers
--
--

---@inlinedoc
---@class telescope.builtin.lsp_opts : telescope.builtin.base_opts
---@field show_line? boolean show results text (default: `true`)
---@field file_encoding? string file encoding for the previewer

---@inlinedoc
---@class telescope.builtin.list_or_jump.opts : telescope.builtin.lsp_opts
---@field jump_type? string how to goto reference if there is only one and the definition file is different from the current file, values: "tab", "tab drop", "split", "vsplit", "never"
---@field reuse_win? boolean jump to existing window if buffer is already oplescope.builtin.lsp_opts
---@field trim_text? boolean trim results text (default: `false`)

---@inlinedoc
---@class telescope.builtin.lsp_references.opts : telescope.builtin.list_or_jump.opts
---@field include_declaration? boolean include symbol declaration in the lsp references (default: `true`)
---@field include_current_line? boolean include current line (default: `false`)

--- Lists LSP references for word under the cursor, jumps to reference on `<cr>`
---@param opts? telescope.builtin.lsp_references.opts: options to pass to the picker (default: `false`)
builtin.lsp_references = require_on_exported_call("telescope.builtin.__lsp").references

---@inlinedoc
---@class telescope.builtin.lsp_in_out_calls.opts : telescope.builtin.lsp_opts
---@field trim_text? boolean trim results text (default: `false`)

--- Lists LSP incoming calls for word under the cursor, jumps to reference on `<cr>`
---@param opts? telescope.builtin.lsp_in_out_calls.opts: options to pass to the picker
builtin.lsp_incoming_calls = require_on_exported_call("telescope.builtin.__lsp").incoming_calls

--- Lists LSP outgoing calls for word under the cursor, jumps to reference on `<cr>`
---@param opts? telescope.builtin.lsp_in_out_calls.opts: options to pass to the picker
builtin.lsp_outgoing_calls = require_on_exported_call("telescope.builtin.__lsp").outgoing_calls

--- Goto the definition of the word under the cursor, if there's only one, otherwise show all options in Telescope
---@param opts? telescope.builtin.list_or_jump.opts: options to pass to the picker
builtin.lsp_definitions = require_on_exported_call("telescope.builtin.__lsp").definitions

--- Goto the definition of the type of the word under the cursor, if there's only one,
--- otherwise show all options in Telescope
---@param opts? telescope.builtin.list_or_jump.opts: options to pass to the picker
builtin.lsp_type_definitions = require_on_exported_call("telescope.builtin.__lsp").type_definitions

--- Goto the implementation of the word under the cursor if there's only one, otherwise show all options in Telescope
---@param opts? telescope.builtin.list_or_jump.opts: options to pass to the picker
builtin.lsp_implementations = require_on_exported_call("telescope.builtin.__lsp").implementations

---@inlinedoc
---@class telescope.builtin.lsp_document_symbols.opts : telescope.builtin.lsp_opts
---@field fname_width? number defines the width of the filename section (default: `30`)
---@field symbol_width? number defines the width of the symbol section (default: `25`)
---@field symbol_type_width? number defines the width of the symbol type section (default: `8`)
---@field symbols? (string|table) filter results by symbol kind(s)
---@field ignore_symbols? (string|table) list of symbols to ignore
---@field symbol_highlights? table string -> string. Matches symbol with hl_group

--- Lists LSP document symbols in the current buffer
---
--- Default keymaps:
---   - `<C-l>`: show autocompletion menu to prefilter your query by type of symbol you want to see (i.e. `:variable:`)
---@param opts? telescope.builtin.lsp_document_symbols.opts: options to pass to the picker
builtin.lsp_document_symbols = require_on_exported_call("telescope.builtin.__lsp").document_symbols

---@inlinedoc
---@class telescope.builtin.lsp_workspace_symbols.opts : telescope.builtin.lsp_opts
---@field query? string for what to query the workspace (default: `""`)
---@field fname_width? number defines the width of the filename section (default: `30`)
---@field symbol_width? number defines the width of the symbol section (default: `25`)
---@field symbol_type_width? number defines the width of the symbol type section (default: `8`)
---@field symbols? (string|table) filter results by symbol kind(s)
---@field ignore_symbols? (string|table) list of symbols to ignore
---@field symbol_highlights? table string -> string. Matches symbol with hl_group

--- Lists LSP document symbols in the current workspace
---
--- Default keymaps:
---   - `<C-l>`: show autocompletion menu to prefilter your query by type of symbol you want to see (i.e. `:variable:`)
---@param opts? telescope.builtin.lsp_workspace_symbols.opts: options to pass to the picker
builtin.lsp_workspace_symbols = require_on_exported_call("telescope.builtin.__lsp").workspace_symbols

---@inlinedoc
---@class telescope.builtin.lsp_dynamic_workspace_symbols.opts : telescope.builtin.lsp_opts
---@field fname_width? number defines the width of the filename section (default: `30`)
---@field symbols? (string|table) filter results by symbol kind(s)
---@field ignore_symbols? (string|table) list of symbols to ignore
---@field symbol_highlights? table string -> string. Matches symbol with hl_group

--- Dynamically lists LSP for all workspace symbols
---
--- Default keymaps:
---   - `<C-l>`: show autocompletion menu to prefilter your query by type of
---   symbol you want to see (i.e. `:variable:`), only works after refining to
---   fuzzy search using `<C-space>`
---@param opts? telescope.builtin.lsp_dynamic_workspace_symbols.opts: options to pass to the picker
builtin.lsp_dynamic_workspace_symbols = require_on_exported_call("telescope.builtin.__lsp").dynamic_workspace_symbols

--
--
-- Diagnostics Pickers
--
--

---@inlinedoc
---@class telescope.builtin.diagnostics.opts : telescope.builtin.base_opts
---@field bufnr? number Buffer number to get diagnostics from. Use 0 for current buffer or nil for all buffers
---@field severity? (string|number) filter diagnostics by severity name (string) or id (number)
---@field severity_limit? (string|number) keep diagnostics equal or more severe wrt severity name (string) or id (number)
---@field severity_bound? (string|number) keep diagnostics equal or less severe wrt severity name (string) or id (number)
---@field root_dir? (string|boolean) if set to string, get diagnostics only for buffers under this dir otherwise cwd
---@field no_unlisted? boolean if true, get diagnostics only for listed buffers
---@field no_sign? boolean hide DiagnosticSigns from Results (default: `false`)
---@field line_width? (string|number) set length of diagnostic entry text in Results. Use 'full' for full untruncated text
---@field namespace? number limit your diagnostics to a specific namespace
---@field disable_coordinates? boolean don't show the line & row numbers (default: `false`)
--- sort order of the diagnostics results (default: `"buffer"`)
---   - "buffer": order by bufnr (prioritizing current bufnr), severity, lnum
---   - "severity": order by severity, bufnr (prioritizing current bufnr), lnum
---@field sort_by? "buffer"|"severity"

--- Lists diagnostics
---
--- All severity flags can be passed as `string` or `number` as per `vim.diagnostic.severity`.
---
--- Default keymaps:
---   - `<C-l>`: show autocompletion menu to prefilter your query with the diagnostic you want to see (i.e. `warning`)
---@param opts? telescope.builtin.diagnostics.opts: options to pass to the picker
builtin.diagnostics = require_on_exported_call("telescope.builtin.__diagnostics").get

---@nodoc
---@class telescope.builtin.base_opts
---@field bufnr number: buffer number to use for the picker (default: current buffer)
---@field winnr number: window number to use for the picker (default: current window)

local apply_config = function(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      local pickers_conf = require("telescope.config").pickers

      opts = opts or {}
      opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
      opts.winnr = opts.winnr or vim.api.nvim_get_current_win()
      local pconf = pickers_conf[k] or {}
      local defaults = (function()
        if pconf.theme then
          return require("telescope.themes")["get_" .. pconf.theme](pconf)
        end
        return vim.deepcopy(pconf)
      end)()

      if pconf.mappings then
        defaults.attach_mappings = function(_, map)
          for mode, tbl in pairs(pconf.mappings) do
            for key, action in pairs(tbl) do
              map(mode, key, action)
            end
          end
          return true
        end
      end

      if pconf.attach_mappings and opts.attach_mappings then
        local opts_attach = opts.attach_mappings
        opts.attach_mappings = function(prompt_bufnr, map)
          pconf.attach_mappings(prompt_bufnr, map)
          return opts_attach(prompt_bufnr, map)
        end
      end

      if defaults.attach_mappings and opts.attach_mappings then
        local opts_attach = opts.attach_mappings
        opts.attach_mappings = function(prompt_bufnr, map)
          defaults.attach_mappings(prompt_bufnr, map)
          return opts_attach(prompt_bufnr, map)
        end
      end

      v(vim.tbl_extend("force", defaults, opts))
    end
  end

  return mod
end

-- We can't do this in one statement because tree-sitter-lua docgen gets confused if we do
builtin = apply_config(builtin)
return builtin
