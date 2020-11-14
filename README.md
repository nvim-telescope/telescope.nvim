# telescope.nvim

Gaze deeply into unknown regions using the power of the moon.

## What is Telescope?

Telescope is a highly extendable fuzzy finder over lists. Items are shown in a popup with a prompt to search over.

Support for:

* LSP (references, document symbols, workspace symbols)
* Treesitter
* Grep
* Files (git, fd, rg)
* Vim (command history, quickfix, loclist)

[What is Telescope? (Video)](https://www.twitch.tv/teej_dv/clip/RichDistinctPlumberPastaThat)

[More advanced configuration (Video)](https://www.twitch.tv/videos/756229115)


![Finding Files](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/simple_rg_v1.gif)

[Example video](https://www.youtube.com/watch?v=65AVwHZflsU)

### Telescope Table of Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Examples](#examples)
- [Mappings](#mappings)
- [API](#api)
- [Goals](#goals)
- [Other Examples](#other-examples)

## Requirements

Neovim Nightly (0.5)

Best experience on Neovim Nightly with LSP configured.

## Installation

```vim
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
```

### Optional

- [bat](https://github.com/sharkdp/bat) (preview)
- [ripgrep](https://github.com/BurntSushi/ripgrep) (finder)
- Treesitter ([nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)) (finder/preview)
- fd ([sharkdp/fd](https://github.com/sharkdp/fd)) (finder)
- git (picker)
- [neovim LSP]( https://neovim.io/doc/user/lsp.html) (picker)
- [devicons](https://github.com/kyazdani42/nvim-web-devicons)

## Usage

Most actions are activated via keybinds. Attach these functions as described more in the [Examples](#Examples)

```lua
-- Fuzzy find over git files in your directory
require('telescope.builtin').git_files()

-- Grep files as you type (requires rg currently)
require('telescope.builtin').live_grep()

-- Use builtin LSP to request references under cursor. Fuzzy find over results.
require('telescope.builtin').lsp_references()

-- Convert currently quickfixlist to telescope
require('telescope.builtin').quickfix()

-- Convert currently loclist to telescope
require('telescope.builtin').loclist()
```

Options can be passed directly to the above functions, or set defaults with `telescope.setup`.

```lua
-- Optional way to set default values
require('telescope').setup{
  defaults = {
    -- Example:
    shorten_path = true -- currently the default value is true
  }
}
```

### Default Configuration Keys


- ( Missing configuration description for many items here, but I'm trying :smile: )
- `file_ignore_patterns`:
    - List of strings that are Lua patterns that, if any are matched, will make result be ignored.
    - Please note, these are Lua patterns. See: [Lua Patterns](https://www.lua.org/pil/20.2.html)
    - Example:
        - `file_ignore_patterns = { "scratch/.*", "%.env" }`
        - This will ignore anything in `scratch/` folders and any files named `.env`

## Examples

```vim
nnoremap <Leader>p <cmd>lua require'telescope.builtin'.git_files{}<CR>
```

Searches over files in a git folder. Note: This does not work outside a git repo folder.

```vim
nnoremap <Leader>p <cmd>lua require'telescope.builtin'.find_files{}<CR>
```

Search over files in your `cwd` current working directory.

```vim
nnoremap <silent> gr <cmd>lua require'telescope.builtin'.lsp_references{}<CR>
```

Search over variable references from your Language Server.

```vim
nnoremap <Leader>en <cmd>lua require'telescope.builtin'.find_files{ cwd = "~/.config/nvim/" }<CR>
```

Find all the files in your nvim config.

### Available keys for `defaults`

- `generic_sorter`:
    - Description: The sorter to be used for generic searches.
    - `default`: `require('telescope.sorters').get_generic_fuzzy_sorter
- `file_sorter`:
    - Description: The sorter to be used for file based searches.
    - `default`: `require('telescope.sorters').get_fuzzy_file

### Full Example

```vim
lua <<EOF
-- totally optional to use setup
require('telescope').setup {
  defaults = {
    shorten_path = false -- currently the default value is true
  }
}
EOF

nnoremap <c-p> :lua require'telescope.builtin'.find_files{}<CR>
nnoremap <silent> gr <cmd>lua require'telescope.builtin'.lsp_references{ shorten_path = true }<CR>
```

What this does:

* Make the paths full size by default. On LSP references we are shortening paths.
* Bind `<ctrl-p>` for a common mapping to find files.
  - Using `telescope.builtin.git_files` is better in git directories. You can make a toggle to detect if it's a git directory.
* Bind `gr` to find references in LSP.
  - `telescope.builtin.lsp_workspace_symbols` and `telescope.builtin.lsp_document_symbols` are also good to bind for LSP.

## Mappings

Mappings are fully customizable. Many familiar mapping patterns are setup as defaults.

```
<C-n>  <C-p> next | previous
<Down> <Up>  next | previous
j      k     next | previous (in normal mode)
<CR>         go to file selection

<C-x>        go to file selection as a split
<C-v>        go to file selection as a vertical split
<C-t>        go to a file in a new tab

<C-u>        scroll up in preview window
<C-d>        scroll down in preview window

<C-c>        close telescope
<Esc>        close telescope (in normal mode)
```

To see the full list of mappings, check out `lua/telescope/mappings.lua` and the `default_mappings` table.

To override ALL of the default mappings, you can use the `default_mappings` key in the `setup` table.

```lua
-- To disable a keymap, put [map] = false
-- So, to not map "<C-n>", just put
["<C-n>"] = false,
-- Into your config.

-- Otherwise, just set the mapping to the function that you want it to be.
["<C-i>"] = actions.goto_file_selection_split,

-- You can also define your own functions, which then can be mapped to a key
local function test_action(prompt_bufnr)
  print("Action was attached with prompt_bufnr: ", prompt_bufnr)
  -- Enter your function logic here. You can take inspiration from lua/telescope/actions.lua
end
["<C-i>"] = test_action,

-- If you want your function to run after another action you should define it as follows
local test_action = actions._transform_action(function(prompt_bufnr)
  print("This function ran after another action. Prompt_bufnr: " .. prompt_bufnr)
  -- Enter your function logic here. You can take inspiration from lua/telescope/actions.lua
end)
["<C-i>"] = actions.goto_file_selection_split + test_action

```

A full example:

```lua
local actions = require('telescope.actions')

-- If you want your function to run after another action you should define it as follows
local test_action = actions._transform_action(function(prompt_bufnr)
  print("This function ran after another action. Prompt_bufnr: " .. prompt_bufnr)
  -- Enter your function logic here. You can take inspiration from lua/telescope/actions.lua
end)

require('telescope').setup {
  defaults = {
    mappings = {
      i = {
        -- Disable the default <c-x> mapping
        ["<c-x>"] = false,

        -- Create a new <c-s> mapping
        ["<c-s>"] = actions.goto_file_selection_split,

        -- Add up multiple actions
        ["<CR>"] = actions.goto_file_selection_edit + actions.center,

        -- You can perform as many actions in a row as you like
        ["<CR>"] = actions.goto_file_selection_edit + actions.center + test_action,
      },
    },
  }
}
```

To override only SOME of the default mappings, you can use the `attach_mappings` key in the `setup` table. For example:

```lua
function my_custom_picker(results)
  pickers.new(opts, {
    prompt_title = 'Custom Picker',
    finder = finders.new_table(results),
    sorter = sorters.fuzzy_with_index_bias(),
    attach_mappings = function(_, map)
      -- Map "<CR>" in insert mode to the funciton, actions.set_command_line
      map('i', '<CR>', actions.set_command_line)

      return true
    end,
  }):find()
end
```

Additionally, the prompt's filetype will be `TelescopePrompt`. You can customize the filetype as you would normally.

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

Search your files in a git repo. Ignores files in your .gitignore. You can optionally override the find command.

Note: Requires the `cwd` to be a git directory.

```lua
require'telescope.builtin'.find_files{
  -- Optional
  -- cwd = "/home/tj/"
  -- find_command = { "rg", "-i", "--hidden", "--files", "-g", "!.git" }
}
```
Searches files in your working directory.

```lua
require'telescope.builtin'.grep_string{
  -- Optional
  -- search = false -- Search term or <cword>
}
```

Searches your string with a grep.
Note: Requires `rg`.

```lua
require'telescope.builtin'.live_grep{}
```

Searches all your files (respecting .gitignore) using grep.
Note: Requires `rg`

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

```lua
require'telescope.builtin.maps{}
```

Search on vim key maps.


```lua
require'telescope.builtin'.buffers{
    -- Optional
    -- show_all_buffers = true -- Show unloaded buffers aswell
}
```

Search on vim buffers list.

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

#### Treesitter

```lua
require'telescope.builtin'.treesitter{
  -- Optional
  -- bufnr = Buffer number
}
```

Search on function names, variables, from Treesitter!

Note: Requires nvim-treesitter
#### Telescope

```lua
require'telescope.builtin'.planets{}
```

Use the telescope.

## Themes

Common groups of settings can be setup to allow for themes. We have some built in themes but are looking for more cool options.

### Dropdown

![Dropdown Theme](https://i.imgur.com/SorAcXv.png)

```vim
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({}))<cr>
```

Then you can put your configuration into `get_dropdown({})`

```vim
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({ winblend = 10 }))<cr>
```

Themes should work with every `telescope.builtin` function.

If you wish to make theme, check out `lua/telescope/themes.lua`. If you need more features, make an issue :).

## Configuration

### Display

`Resolvable`:
1. 0 <= number < 1:
    - This means total height as a percentage
2. 1 <= number:
    - This means total height as a fixed number
3. function(picker, columns, lines):
    - returns one of the above options
    - `return max.min(110, max_rows * .5)`

```lua
layout_strategies.horizontal = function(self, max_columns, max_lines)
  local layout_config = validate_layout_config(self.layout_config or {}, {
    width_padding = "How many cells to pad the width",
    height_padding = "How many cells to pad the height",
    preview_width = "(Resolvable): Determine preview width",
  })
  ...
end
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
  entry_maker     = function(line) end,
  fn_command      = function() { command = "", args  = { "ls-files" } } end,
  static          = false,
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
  prompt_title       = "", -- REQUIRED
  finder             = FUNCTION, -- see lua/telescope/finder.lua
  sorter             = FUNCTION, -- see lua/telescope/sorter.lua
  previewer          = FUNCTION, -- see lua/telescope/previewer.lua
  selection_strategy = "reset", -- follow, reset, line
  border             = {},
  borderchars        = {"─", "│", "─", "│", "┌", "┐", "┘", "└"},
  preview_cutoff     = 120,
}
```

"previewer":

- sometimes built-in
- sometimes a lua callback

As an example, you could pipe your inputs into fzf, and then it can sort them for you.

### Command

Also you can use the `Telescope` command with options in vim command line. like

```vim
" Press Tab to  get completion list
:Telescope find_files
" Command with options
:Telescope find_files  prompt_prefix=🔍
" If option is table type in lua code ,you can use `,` connect each command string eg:
" find_command,vimgrep_arguments they are both table type. so config it in commandline like
:Telecope find_files find_command=rg,--ignore,--hidden,--files prompt_prefix=🔍
```


## Other Examples


![Live Grep](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/live_grep.gif)

![Command History](https://raw.githubusercontent.com/tjdevries/media.repo/master/telescope.nvim/command_history.gif)
