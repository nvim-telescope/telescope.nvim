# Telescope.nvim

> **Telescope**: An arrangement of lenses or mirrors or both that gathers
> light, permitting direct observation or photographic recording of distant
> objects.  -- thefreedictionary 

`Telescope.nvim` is a next generation library for creating floating pickers 
with advance features. It is written in lua and it is built on top of latest
awesome features from nvim core. Telescope is centered around modularity *to the
extend that* the promotes can be customized in isolation from one another
(such presentation, algorithm, mappings ... etc). In addition, Telescope is a
plugin that comes with a growing number of community driven [builtin pickers
](#builtin-pickers) covering a wide range of use cases and tools.

- [Getting Started](#getting-started): To get started and run your first built-in prompt.
- [customization](#): To learn how to configure and customize your telescope.
- [builtin-pickers](#): To explore the cool builtin pickers.
- [API](#): To learn more about how to build your first demo picker.
- [community Gallery](https://github.com/nvim-lua/telescope.nvim/wiki/Gallery): To see screenshots and example UI.
- [Media](#media): To see live demos and overview from @tjdevries
- [FAQ](#faq)
- [Contribution](#contribution):

## Getting Started
---

[Neovim Nightly (0.5)](https://github.com/neovim/neovim/releases/tag/nightly)
is required for telescope to work.

#### Optional dependences 
- [sharkdp/bat](https://github.com/sharkdp/bat) (preview) [Optional]
- [sharkdp/fd](https://github.com/sharkdp/fd) (finder) [Optional]
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) (finder) [Optional]
- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (finder/preview) [Optional]
- [neovim LSP]( https://neovim.io/doc/user/lsp.html) (picker) [Optional]
- [devicons](https://github.com/kyazdani42/nvim-web-devicons) (icons) [Optional]


#### Installation

Using [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-lua/telescope.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)

```viml
call dein#add('nvim-lua/popup.nvim')
call dein#add('nvim-lua/plenary.nvim')
call dein#add('nvim-lua/telescope.nvim')
```
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua 
use {
  'nvim-lua/telescope.nvim',
  requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
}
```

#### Usage

To test if `telescope.nvim` is installed correctly try `:Telescope find_files<cr>`. 

```viml
" Find files using Telescope command-line sugar.
nn <leader>ff <cmd>Telescope find_files<cr>
nn <leader>fg <cmd>Telescope live_grep<cr>
nn <leader>fb <cmd>Telescope buffers<cr>
nn <leader>fh <cmd>Telescope help_tags<cr>

" Using lua functions
nn <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
nn <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
nn <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
nn <leader>ff <cmd>lua require('telescope.builtin').help_tags()<cr>
```
For a complete list of the builtin functions, see [builtin pickers](#builtin-pickers)


<!-- Section -->


## Customization

Customization can be globally added in telescope's setup method or individually
through passing the options to the builtin pickers .

|  [Presentation](#presentation) | [Sorting](#sorting) | [Mappings](#mappings)

#### Presentation

| Description                                           | Keys                   | Options                    |
|-------------------------------------------------------|------------------------|----------------------------|
| Where the prompt should be located.                   | `prompt_position`      | top/bottom                 |
| What should the prompt prefix be.                     | `prompt_prefix`        | string                     |
| Where first selection should be located.              | `sorting_strategy`     | descending/ascending       |
| How the telescope is drawn.                           | `layout_strategy`      | center/horizontal/vertical |
| How transparent is the telescope window should be.    | `winblend`             | NUM                        |
| Layout specific configuration ........ TODO           | `layout_defaults`      | TODO                       |
| TODO                                                  | `width`                | NUM                        |
| TODO                                                  | `preview_cutoff`       | NUM                        |
| TODO                                                  | `results_height`       | NUM                        |
| TODO                                                  | `results_width`        | NUM                        |
| The border chars, it gives border telescope window    | `borderchars`          | dict                       | 
| Whether to color devicons or not                      | `color_devicons`       | boolean                    |
| Whether to use less or bat .. TODO                    | `use_less`             | boolean                    |

#### Sorting

| Description                                           | Keys                   | Options                    |
|-------------------------------------------------------|------------------------|----------------------------|
| The sorter for file lists.                            | `file_sorter`          | [see sorters](#builtin-sorters)    |
| The sorter for everything else.                       | `generic_sorter`       | [see sorters](#builtin-sorters)    |
| The command line argument for grep search ... TODO.   | `vimgrep_arguments`    | dict                               |
| ... TODO                                              | `selection_strategy`   | follow/reset/row                   | 
| Pattern to be ignored `{ "scratch/.*", "%.env"}`      | `file_ignore_patterns` | dict                               | 
| Whether to shorten paths or not.                      | `shorten_path`         | boolean                            |


#### Defaults

To make the following code snippet work in vim filetype (.vim), wrap it in `lua << EOF code-snippet EOF`.

```lua
require('telescope').setup{
  defaults = {
    vimgrep_arguments = {
      'rg', 
      '--color=never', 
      '--no-heading', 
      '--with-filename', 
      '--line-number', 
      '--column', 
      '--smart-case'
    },
    prompt_position = "bottom",
    prompt_prefix = ">",
    selection_strategy = "reset",
    sorting_strategy = "descending",
    layout_strategy = "horizontal",
    layout_defualts = {
      -- TODO add builtin options.
    },
    file_sorter =  require'telescope.sorters'.get_fuzzy_file ,
    file_ignore_patterns = {},
    generic_sorter =  require'telescope.sorters'.get_generic_fuzzy_sorter,
    shorten_path = true,
    winblend = 0,
    width = 0.75,
    preview_cutoff = 120,
    results_height = 1,
    results_width = 0.8,
    border = {},
    borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰'},
    color_devicons = true,
    use_less = true,
  }
}
```

#### Mappings

Mappings are fully customizable. Many familiar mapping patterns are setup as defaults.

| Action                           | Mappings       |
|----------------------------------|----------------|
| Next item                        | `<C-n>/<Down>` |
| Previous item                    | `<C-p>/<Up>`   |
| Next/previous (in normal mode)   | `j/k`          |
| Confirm selection                | `<CR>`         |
| go to file selection as a split  | `<C-x>`        |
| go to file selection as a vsplit | `<C-v>`        |
| go to a file in a new tab        | `<C-t>`        |
| scroll up in preview window      | `<C-u>`        |
| scroll down in preview window    | `<C-d>`        |
| close telescope                  | `<C-c>`        |
| close telescope (in normal mode) | `<Esc>`        |

To see the full list of mappings, check out `lua/telescope/mappings.lua` and
the `default_mappings` table.  

To change default mapping globally, then change default->mappings dict
<!-- TODO should be in the wiki -->

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
        -- To disable a keymap, put [map] = false
        -- So, to not map "<C-n>", just put
        ["<c-x>"] = false,
        -- Otherwise, just set the mapping to the function that you want it to be.
        ["<C-i>"] = actions.goto_file_selection_split,
        -- Add up multiple actions
        ["<CR>"] = actions.goto_file_selection_edit + actions.center,
        -- You can perform as many actions in a row as you like
        ["<CR>"] = actions.goto_file_selection_edit + actions.center + test_action,
      },
      n = {
        ["<esc>"] = actions.close
      },
    },
  }
}

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

To change a builtin function mappings, then change attach_mappings to a function:

```lua 
require'telescope.builtin'.fd({
  attach_mappings = function(prompt_bufnr, map)
    map('i', '<esc>', actions.close)
  end
})
```


## FAQ
<!-- Any question answered in issues should be written here -->

### How to change some defaults in builtin functions?

All options available from setup function (see [Configuration options]()) and
some other functions can be easily changed in custom pickers or builtin
functions. 
<!-- TODO: insert a list of available options like previewer and prompt prefix -->


```lua 
-- Disable preview for find files 
nn <leader>ff :lua require('telescope.builtin').find_files({previewer = false})<CR>

-- Change change prompt prefix for find_files builtin function:
nn <leader>fg :lua require('telescope.builtin').live_grep({ prompt_prefix=🔍 })<CR>
nn <leader>fg :Telescope live_grep prompt_prefix=🔍<CR>
```

### How to change Telescope Highlights group?

There are 10 highlights group you can play around with in order to meet your needs:

```viml
hi TelescopeSelection guifg=#D79921 gui=bold " selected item
hi TelescopeSelectionCaret guifg=#CC241D     " selection caret
hi TelescopeMultiSelection guifg=#928374     " multisections
hi TelescopeNormal guibg=#00000       " floating windows created by telescope.

" Border highlight groups.
hi TelescopeBorder guifg=#ffffff 
hi TelescopePromptBorder guifg=#ffffff 
hi TelescopeResultsBorder guifg=#ffffff  
hi TelescopePreviewBorder guifg=#ffffff 

" Used for highlighting characters that you match.
hi TelescopeMatching guifg=blue

" Used for the prompt prefix
hi TelescopePromptPrefix guifg=red
```

To checkout the default values of the highlight groups, checkout `plugin/telescope.vim`

### How to add autocmds to telescope prompt ?

`TelescopePrompt` is the prompt Filetype. You can customize the Filetype as you would normally.

## API 

#### Sorters 

| Sorters                            | Description                                                     | Status |
|------------------------------------|-----------------------------------------------------------------|--------|
| `sorters.get_fuzzy_file`           | Telescope's default sorter for files                            | ...    |
| `sorters.get_generic_fuzzy_sorter` | Telescope's default sorter for everything else                  | ...    |
| `sorters.get_levenshtein_sorter`   | Using Levenshtein distance algorithm (don't use :D)             | ...    |
| `sorters.get_fzy_sorter`           | Using fzy algorithm                                             | ...    |
| `sorters.fuzzy_with_index_bias`    | Used to list stuff with consideration to when the item is added | WIP    |
| .................................. | Your next awesome sorter here :D                                | PR     |


A `Sorter` is called by the `Picker` on each item returned by the `Finder`. It return a number, which is equivalent to the "distance" between the current `prompt` and the `entry` returned by a `finder`.

- Currently, it's not possible to delay calling the `Sorter` until the end of the execution, it is called on each item as we receive them.
- This was done this way so that long running / expensive searches can be instantly searchable and we don't have to wait til it completes for things to start being worked on.
- However, this prevents using some tools, like FZF easily.
- In the future, I'll probably add a mode where you can delay the sorting til the end, so you can use more traditional sorting tools.

#### Functions

Builtin function ready to be bound :D.

| Functions                           | Description                                                      | Status |
|-------------------------------------|------------------------------------------------------------------|--------|
| `builtin.planets`                   | Demo showcasing how simple to create prompts with telescope.     | ...    |
| `builtin.builtin`                   | Prompts a list to select a built-in function and run it.         | WIP    |
| `builtin.find_files`                | Prompts a list of files in current directory.                    | ...    |
| `builtin.git_files`                 | Prompts a list of git files in current directory.                | WIP    |
| `builtin.buffers`                   | Prompts a list of open buffers.                                  | ...    |
| `builtin.current_buffer_fuzzy_find` | Prompts a list of lines from current buffer lines.               | ...    |
| `builtin.oldfiles`                  | Prompts a list of previously open files.                         | ...    |
| `builtin.commands`                  | Prompts a list of available plugin/user commands and run it.     | ...    |
| `builtin.command_history`           | Prompts a sorted list of command previously ran and run it.      | ...    |
| `builtin.help_tags`                 | Prompts a list of available help tags and open help document     | ...    |
| `builtin.man_pages`                 | Prompts a list of man entries.                                   | ...    |
| `builtin.marks`                     | Prompts a list of markers and their value.                       | ...    |
| `builtin.colorscheme`               | Prompts a list of colorscheme and switch to it on enter.         | ...    |
| `builtin.treesitter`                | Prompts a list of function names, variables, from Treesitter!    | ...    |
| `builtin.live_grep`                 | Searches all your files (respecting .gitignore)                  | WIP    | 
| `builtin.grep_string`               | Searches for a string under the cursor in current directory.     | ...    |
| `builtin.lsp_references`            | Searches in LSP references.                                      | ...    |
| `builtin.lsp_document_symbols`      | Searches in LSP Document Symbols in the current document.        | WIP    |
| `builtin.lsp_workspace_symbols`     | Searches in LSP all workspace symbols.                           | WIP    |
| `builtin.lsp_code_actions`          | Prompts a list of LSP action to be trigged on enter              | WIP    |
| `builtin.quickfix`                  | Prompts a list from quickfix                                     | ...    |
| `builtin.loclist`                   | Prompts a list from current window's location list.              | ...    |
| `builtin.reloader`                  | Prompts a list of lua modules to be reloaded on enter            | ...    |
| `builtin.vim_options`               | Prompts a list of vim options and on enter edit the options      | WIP    |
| ..................................  | Your next awesome finder function here :D                        | PR     |

#### Themes

Common groups of settings can be setup to allow for themes. We have some built
in themes but are looking for more cool options. 

| Themes                   | Description                                                      | Status |
|--------------------------|------------------------------------------------------------------|--------|
| `themes.get_dropdown`    | A list like centered list. [example](https://i.imgur.com/SorAcXv.png)                                       | ...    |
| ..................................  | Your next awesome theme here :D                       | PR     |


To use a theme, simply append it to a builtin function:
```vim
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({}))<cr>
-- Change an option
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({ winblend = 10 }))<cr>
```

Themes should work with every `telescope.builtin` function.  If you wish to
make theme, check out `lua/telescope/themes.lua`. If you need more features,
make an issue :).

#### Finders

```lua
-- lua/telescope/finders.lua
Finder:new{
  entry_maker     = function(line) end,
  fn_command      = function() { command = "", args  = { "ls-files" } } end,
  static          = false,
  maximum_results = false
}
```

#### Picker
<!-- TODO: this section need some love, an in-depth explanation will be appreciated it need some in depth explanation --> 
This section is an overview of how custom pickers can be created any configured. 


```lua
-- lua/telescope/pickers.lua
Picker:new{
  prompt_title       = "", -- REQUIRED
  finder             = FUNCTION, -- see lua/telescope/finder.lua
  sorter             = FUNCTION, -- see lua/telescope/sorter.lua
  previewer          = FUNCTION, -- see lua/telescope/previewer.lua
  selection_strategy = "reset", -- follow, reset, row
  border             = {},
  borderchars        = {"─", "│", "─", "│", "┌", "┐", "┘", "└"},
  preview_cutoff     = 120,
}
```

##### Examples

###### Override mappings

To override only SOME of the default mappings, you can use the
`attach_mappings` key in the `setup` table. For example:

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

###### Planets example 

see `lua/builtins.lua/planents`

#### Layout (display)
<!-- TODO need some work -->

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

#### Command-line `WIP`

All `Telescope` functions are wrapped in vim commands for easy access, its
supports tab completions and settings options.

```viml
:Telescope find_files |<tab> 
:Telescope find_files prompt_prefix=🔍 

" If option is table type in lua code ,you can use `,` connect each command string eg:
" find_command,vimgrep_arguments they are both table type. so config it in commandline like
:Telecope find_files find_command=rg,--ignore,--hidden,--files prompt_prefix=🔍
```

## Media 

- [What is Telescope? (Video)](https://www.twitch.tv/teej_dv/clip/RichDistinctPlumberPastaThat)
- [More advanced configuration (Video)](https://www.twitch.tv/videos/756229115)
- [Example video](https://www.youtube.com/watch?v=65AVwHZflsU)

## Configuration Recipes 

Here a few simple recipes to simply configuration  telescope builtin and powered function.

### Having to different themes and applying them selectively.

```lua 
-- in lua/finders.lua
local finders = {}

-- Dropdown list theme using a builtin theme definations :
local center_list = require'telescope.themes'.get_dropdown({
  winblend = 10,
  width = 0.5,
  prompt = " ",
  results_height = 15,
  previewer = false,
})

-- Settings for with preview option
local with_preview = {
  winblend = 10,
  show_line = false,
  results_title = false,
  preview_title = false,
  layout_config = {
    preview_width = 0.5,
  },
}

-- Find in neovim config with center theme
finders.fd_in_nvim = function()
  local opts = vim.deepcopy(center_list)
  opts.prompt_prefix = 'Nvim>'
  opts.cwd = vim.fn.stdpath("config")
  require'telescope.builtin'.fd(opts)
end

-- Find files with_preview settings
function fd()
  local opts = vim.deepcopy(with_preview)
  opts.prompt_prefix = 'FD>'
  require'telescope.builtin'.fd(opts)
end

return finders

-- make sure to map it:
-- nn <leader>ff :lua require'finders'.fd_in_nvim()<cr> 
-- nn <leader>ff :lua require'finders'.fd()<cr>
```

### Having a factory-like function based on a dict (may become a builtin function)

```lua
local center_list  -- check the above snippet
local with_preview -- check the above snippet
local main = {}
local telescopes = {
  fd_nvim = {
    prompt_prefix = 'Nvim>',
    fun = "fd",
    theme = center_list,
    cwd = vim.fn.stdpath("config")
    -- .. other options
  } 
  fd = {
    prompt_prefix = 'Files>',
    fun = "fd",
    theme = with_preview,
    cwd = vim.fn.stdpath("config")
    -- .. other options
  } 
}

main.run = function(str, theme)
  local base, fun, opts
  if not telescopes[str] then 
    fun = str
    opts = theme or {}
    --return print("Sorry not found")
  else 
    base = telescopes[str]
    fun = base.fun; theme = base.theme
    base.theme = nil; base.fun = nil
    opts = vim.tbl_extend("force", theme, base) 
  end
  if str then
    return require'telescope.builtin'[fun](opts)
  else 
    return print("You need to a set a default function")
    -- return require'telescope.builtin'.find_files(opts)
  end
end

return main
-- make sure to map it:
-- nn <leader>ff :lua require'main'.run('fd')<cr>
-- nn <leader>ff :lua require'main'.run('fd_in_nvim')<cr>
```

## Contribution 

All contribution are welcomed through opening PR, notice that any change on
source code or addition of new sorters, finders, or buitlins must be reflected
when approbate in the docs and README.md. 

