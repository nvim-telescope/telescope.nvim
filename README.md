# telescope.nvim

Gaze deeply into unknown regions using the power of the moon.

![Finding Files](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/simple_rg_v1.gif)

[Example video](https://www.youtube.com/watch?v=65AVwHZflsU)

## Installation

```vim
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-lua/telescope.nvim'
```

### Optional

- bat (preview)
- ripgrep (finder)
- git (picker)
- LSP (picker)
- [devicons](https://github.com/kyazdani42/nvim-web-devicons)

## Usage

(I will write a longer description later about how to create each of the objects described in Pipeline)

```lua
-- Fuzzy find over git files in your directory
require('telescope.builtin').git_files()

-- Grep as you type (requires rg currently)
require('telescope.builtin').live_grep()

-- Grep using a string
require('telescope.builtin').grep_string()

-- Use builtin LSP to request references under cursor. Fuzzy find over results.
require('telescope.builtin').lsp_references()

-- Convert currently quickfixlist to telescope
require('telescope.builtin').quickfix()

-- Convert currently loclist to telescope
require('telescope.builtin').loclist()
```

## Examples

```vimscript
nnoremap <Leader>p :lua require'telescope.builtin'.git_files{}<CR>
```

Open telescope with the files added to a git repository.

```vimscript
nnoremap <silent> gr <cmd>lua require'telescope.builtin'.lsp_references{}<CR>
```

Open telescope with LSP references under the cursor.

![Live Grep](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/live_grep.gif)

```vimscript
nnoremap <Leader>ggr :lua require'telescope.builtin'.live_grep{}
```

Grep as you type (requires rg currently)

## Status (Unstable API)

While the underlying API & Infrastructure (A.K.A. Spaghetti Code) is still very much WIP and
will probably change quite a bit, the functions in `builtin` should be relatively stable (as
in, you can report bugs if they don't work, you should be able to keep them around in your config
even if everything inside of those functions is rewritten. They provide pretty simple, easy to use
wrappers over common tasks).

## API

### `builtin`

Showing default values. Most builtins need no options to be passed.

```lua
require'telescope.builtin'.git_files{
    -- See Picker for additional options
    prompt             = "Git File",
}
```

```lua
require'telescope.builtin'.live_grep{
    -- See Picker for options
}
```

```lua
require'telescope.builtin'.lsp_references{
    -- See Picker for options
}
```

```lua
require'telescope.builtin'.quickfix{
    -- See Picker for options
}
```

```lua
require'telescope.builtin'.loclist{
    -- See Picker for options
}
```

```lua
require'telescope.builtin'.grep_string{
     -- See Picker for options
		search = false -- Search term or <cword>
}
```

```lua
require'telescope.builtin'.oldfiles{
    -- See Picker for options
}
```

## Goals

### Pipeline Different Objects

(Please note, this section is still in progress)

## Finder:

- executable: rg, git ls-files, ...
- things in lua already
- vim things

```lua
-- lua/telescope/finders.lua
Finder:new{
    entry_maker = function(line) end,
    fn_command = function() { command = "", args  = { "ls-files" } } end,
    static = false,
    maximum_results = false
}
```

## Sorter:

- A `Sorter` is called by the `Picker` on each item returned by the `Finder`.
- `Sorter`s return a number, which is equivalent to the "distance" between the current `prompt` and the `entry` returned by a `finder`.
  - Currently, it's not possible to delay calling the `Sorter` until the end of the execution, it is called on each item as we receive them.
  - This was done this way so that long running / expensive searches can be instantly searchable and we don't have to wait til it completes for things to start being worked on.
  - However, this prevents using some tools, like FZF easily.
  - In the future, I'll probably add a mode where you can delay the sorting til the end, so you can use more traditional sorting tools.

```lua
Sorter:new{
	scoring_function = function(sorter, prompt, line)
		--- Sorter sorts a list of results by return a single integer for a line,
		--- given a prompt
		---
		--- Lower number is better (because it's like a closer match)
		--- But, any number below 0 means you want that line filtered out.

    --- @field scoring_function function Function that has the interface:
		--      (sorter, prompt, line): number
	end
}
```

## Picker:

Pickers are your main entry point because they direct the interaction with all the telescope modules. Most builtins are pickers.

- fzf
- sk
- does this always need to be fuzzy?
  - you'll map what you want to do with vimscript / lua mappings

```lua
-- lua/telescope/pickers.lua
Picker:new{
    prompt = "Git Files", -- Sets the title of the prompt
    finder = finders.new{}, -- Uses the prompt to filter
    sorter = sorters.new{}, -- Sorts the results
    previewer = previewer.new{}, -- Previews the items in the list
    attach_mappings = function(map)
			--- map(mode, key_bind, key_func, opts)
			map('i', '<c-p>', require'telescope.actions'.move_selection_previous)
			map('i', '<c-n>', require'telescope.actions'.move_selection_next)
		end,
    selection_strategy = "reset", -- follow, reset, line
    border = {},
    borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└'},
    preview_cutoff = 120
}
```

## Previewer:

- sometimes built-in
- sometimes a lua callback

As an example, you could pipe your inputs into fzf, and then it can sort them for you.

```lua
Previewer:new{
	--- Previewer API subject to massive changes. Works with files mostly currently.
	setup = function()
		return {
			command_string = "cat " -- Terminal command to run previewer
		}
	end,
	preview_fn = function(self, entry, status)
		-- status = {
		--
	end
}
```

## Other Examples

![Command History](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/command_history.gif)
