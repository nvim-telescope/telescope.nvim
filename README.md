# telescope.nvim

Gaze deeply into unknown regions using the power of the moon.

![Example](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/simple_rg_v1.gif)
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

-- Use builtin LSP to request references under cursor. Fuzzy find over results.
require('telescope.builtin').lsp_references()

-- Convert currently quickfixlist to telescope
require('telescope.builtin').quickfix()

-- Convert currently loclist to telescope
require('telescope.builtin').loclist()
```

### Example

```vimscript
nnoremap <Leader>p :lua require'telescope.builtin'.git_files{}<CR>
```

```vimscript
nnoremap <silent> gr <cmd>lua require'telescope.builtin'.lsp_references{}<CR>
```

## Status (Unstable API)

While the underlying API & Infrastructure (A.K.A. Spaghetti Code) is still very much WIP and
will probably change quite a bit, the functions in `builtin` should be relatively stable (as
in, you can report bugs if they don't work, you should be able to keep them around in your config
even if everything inside of those functions is rewritten. They provide pretty simple, easy to use
wrappers over common tasks).

## API

### `builtin`

```lua
require'telescope.builtin'.git_files{
    -- See Picker for additional options
    show_preview       = true, -- Show preview
    prompt             = "Git File",
    selection_strategy = "reset" -- follow, reset, line
}
```

```lua
require'telescope.builtin'.live_grep{
    -- See Picker for additional options
    prompt = "Live Grep",
}
```

```lua
require'telescope.builtin'.lsp_references{
    -- See Picker for additional options
    prompt = 'LSP References'
}
```

```lua
require'telescope.builtin'.quickfix{
    -- See Picker for additional options
    prompt = 'Quickfix'
}
```

```lua
require'telescope.builtin'.loclist{
    -- See Picker for additional options
    prompt = 'Loclist'
}
```

```lua
require'telescope.builtin'.grep_string{
    -- See Picker for additional options
    prompt = 'Find Word',
    search = false -- Search term or <cword>
}
```

```lua
require'telescope.builtin'.oldfiles{
    -- See Picker for additional options
    prompt = 'Oldfiles',
}
```

## Goals

### Pipeline Different Objects

(Please note, this section is still in progress)

"finder":

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

`Sorter`:
- A `Sorter` is called by the `Picker` on each item returned by the `Finder`.
- `Sorter`s return a number, which is equivalent to the "distance" between the current `prompt` and the `entry` returned by a `finder`.
    - Currently, it's not possible to delay calling the `Sorter` until the end of the execution, it is called on each item as we receive them.
    - This was done this way so that long running / expensive searches can be instantly searchable and we don't have to wait til it completes for things to start being worked on.
    - However, this prevents using some tools, like FZF easily.
    - In the future, I'll probably add a mode where you can delay the sorting til the end, so you can use more traditional sorting tools.

"picker":

- fzf
- sk
- does this always need to be fuzzy?
  - you'll map what you want to do with vimscript / lua mappings

Defaults:

### Picker

```lua
-- lua/telescope/pickers.lua
Picker:new{
    prompt = "Git Files", -- REQUIRED
    finder = FUNCTION, -- REQUIRED
    sorter = FUNCTION, -- REQUIRED
    previewer = FUNCTION, -- REQUIRED
    mappings = {
        i = {
            ["<C-n>"] = require'telescope.actions'.move_selection_next,
            ["<C-p>"] = require'telescope.actions'.move_selection_previous,
            ["<CR>"] = require'telescope.actions'.goto_file_selection,
        },

        n = {
            ["<esc>"] = require'telescope.actions'.close,
        }
    },
    selection_strategy = "reset", -- follow, reset, line
    border = {},
    borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└'},
    preview_cutoff = 120
}
```

"previewer":

- sometimes built-in
- sometimes a lua callback

As an example, you could pipe your inputs into fzf, and then it can sort them for you.

