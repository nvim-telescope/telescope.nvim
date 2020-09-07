# telescope.nvim

Gaze deeply into unknown regions using the power of the moon.

## What is Telescope?

Telescope is a highly extendable fuzzy finder over lists. Items are shown in a popup with a prompt to search over.  

Support for:

* LSP (references, document symbols, workspace symbols)
* Treesitter 
* Grep 
* Files (git, fd) 
* Vim (command history, quickfix, loclist)

[What is Telescope?](https://www.twitch.tv/teej_dv/clip/RichDistinctPlumberPastaThat)


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
- Treesitter (nvim-treesitter)
- fd ([sharkdp/fd](https://github.com/sharkdp/fd))
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
require'telescope.builtin'.builtin{
  -- Optional
  -- hide_filename = true
  -- ignore_filename = true
}
```

Handy documentation, showcase of all tools available in Telescope.

#### Files

```lua
require'telescope.builtin'.git_files{}
```

Search your files in a git repo. Ignores files in your .gitignore.

```lua
require'telescope.builtin'.fd{
  -- Optional  
  -- cwd = "/home/tj/"  
}
```
Searches files in your working directory.

```lua
require'telescope.builtin'.grep_string{
    -- Optional 
    -- search = false -- Search term or <cword>
}
```

```lua
require'telescope.builtin'.live_grep{}
```

#### Vim

```lua
require'telescope.builtin'.oldfiles{}
```

Searches the vim oldfiles. See `:help v:oldfiles`

```lua
require'telescope.builtin'.quickfix{}
```

Search on the quickfix. See `:help quickfix`

```lua
require'telescope.builtin'.loclist{}
```

Search on the current window's location list.

```lua
require'telescope.builtin'.command_history{}
```

Search the vim command history.

#### LSP

```lua
require'telescope.builtin'.lsp_references{}
```

Search on LSP references.

```lua
require'telescope.builtin'.lsp_document_symbols{}
```

Search on LSP Document Symbols in the current document.

```lua
require'telescope.builtin'.lsp_workspace_symbols{}
```

Search on all workspace symbols.

```lua
require'telescope.builtin'.treesitter{
  -- Optional
  -- bufnr = Buffer handle
}
```

Search on function names, variables, from Treesitter!

```lua 
require'telescope.builtin'.planets{}
```

Use the telescope.

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


## Other Examples


![Live Grep](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/live_grep.gif)

![Command History](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/command_history.gif)
