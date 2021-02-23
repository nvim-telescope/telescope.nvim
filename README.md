# telescope.nvim
[![Gitter](https://badges.gitter.im/nvim-telescope/community.svg)](https://gitter.im/nvim-telescope/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Gaze deeply into unknown regions using the power of the moon.

## What Is Telescope?

`telescope.nvim` is a highly extendable fuzzy finder over lists. Built on the latest
awesome features from `neovim` core. Telescope is centered around
modularity, allowing for easy customization.

Community driven built-in [pickers](#pickers), [sorters](#sorters) and [previewers](#previewers).

### Built-in Support:
- [Vim](#vim-pickers)
- [Files](#file-pickers)
- [Git](#git-pickers)
- [LSP](#lsp-pickers)
- [Treesitter](#treesitter-picker)

![by @glepnir](https://user-images.githubusercontent.com/41671631/100819597-6f737900-3487-11eb-8621-37ec1ffabe4b.gif)


<!-- You can read this documentation from start to finish, or you can look at the -->
<!-- outline and directly jump to the section that interests you most. -->

## Telescope Table of Contents
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Customization](#customization)
- [Mappings](#mappings)
- [Pickers](#pickers)
- [Sorters](#sorters)
- [Previewers](#previewers)
- [Themes](#themes)
- [Extensions](#extensions)
- [API](#api)
- [Media](#media)
- [Gallery](https://github.com/nvim-telescope/telescope.nvim/wiki/Gallery)
- [FAQ](#faq)
- [Configuration recipes](https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes)
- [Contributing](#contribution)

## Getting Started

This section should guide to run your first built-in pickers :smile:.

[Neovim Nightly (0.5)](https://github.com/neovim/neovim/releases/tag/nightly)
  is required for `telescope.nvim` to work.

### Optional dependences
- [sharkdp/bat](https://github.com/sharkdp/bat) (preview)
- [sharkdp/fd](https://github.com/sharkdp/fd) (finder)
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) (finder)
- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (finder/preview)
- [neovim LSP]( https://neovim.io/doc/user/lsp.html) (picker)
- [devicons](https://github.com/kyazdani42/nvim-web-devicons) (icons)


### Installation

Using [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)

```viml
call dein#add('nvim-lua/popup.nvim')
call dein#add('nvim-lua/plenary.nvim')
call dein#add('nvim-telescope/telescope.nvim')
```
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'nvim-telescope/telescope.nvim',
  requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
}
```

## Usage

Try the command `:Telescope find_files<cr>`
  to see if `telescope.nvim` is installed correctly.

```viml
" Find files using Telescope command-line sugar.
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" Using lua functions
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>
```

See [built-in pickers](#pickers) for the list of all built-in
functions.


## Customization

This section should help you explore available options to configure and
customize your `telescope.nvim`.

Unlike most vim plugins, `telescope.nvim` can be customized either by applying
customizations globally or individual pre picker.

- **Global Customization** affecting all pickers can be done through the
  main `setup()` method (see defaults below)
- **Individual Customization** affecting a single picker through passing `opts`
  built-in pickers (e.g. `builtin.fd(opts)`) see [Configuration recipes](https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes) wiki page for ideas.


### Telescope Defaults

As an example of using the `setup()` method, the following code configures
`telescope.nvim` to its default settings.

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
    initial_mode = "insert",
    selection_strategy = "reset",
    sorting_strategy = "descending",
    layout_strategy = "horizontal",
    layout_defaults = {
      -- TODO add builtin options.
    },
    file_sorter =  require'telescope.sorters'.get_fuzzy_file,
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
    set_env = { ['COLORTERM'] = 'truecolor' }, -- default = nil,
    file_previewer = require'telescope.previewers'.cat.new, -- For buffer previewer use `require'telescope.previewers'.vim_buffer_cat.new`
    grep_previewer = require'telescope.previewers'.vimgrep.new, -- For buffer previewer use `require'telescope.previewers'.vim_buffer_vimgrep.new`
    qflist_previewer = require'telescope.previewers'.qflist.new, -- For buffer previewer use `require'telescope.previewers'.vim_buffer_qflist.new`

    -- Developer configurations: Not meant for general override
    buffer_previewer_maker = require'telescope.previewers'.buffer_previewer_maker
  }
}
```

To embed the above code snippet in a `.vim` file
  (for example in `after/plugin/telescope.nvim.vim`),
  wrap it in `lua << EOF code-snippet EOF`:

```lua
lua << EOF
require('telescope').setup{
  -- ...
}
EOF
```

<!-- TODO: move some options to Options affecting Behaviour -->

### Options affecting Presentation

| Keys                   | Description                                           | Options                    |
|------------------------|-------------------------------------------------------|----------------------------|
| `prompt_position`      | Where the prompt should be located.                   | top/bottom                 |
| `prompt_prefix`        | What should the prompt prefix be.                     | string                     |
| `initial_mode`         | The initial mode when a prompt is opened.             | insert/normal              |
| `sorting_strategy`     | Where first selection should be located.              | descending/ascending       |
| `layout_strategy`      | How the telescope is drawn.                           | [supported layouts](https://github.com/nvim-telescope/telescope.nvim/wiki/Layouts) |
| `winblend`             | How transparent is the telescope window should be.    | NUM                        |
| `layout_defaults`      | Layout specific configuration ........ TODO           | TODO                       |
| `width`                | TODO                                                  | NUM                        |
| `preview_cutoff`       | TODO                                                  | NUM                        |
| `results_height`       | TODO                                                  | NUM                        |
| `results_width`        | TODO                                                  | NUM                        |
| `borderchars`          | The border chars, it gives border telescope window    | dict                       |
| `color_devicons`       | Whether to color devicons or not                      | boolean                    |
| `use_less`             | Whether to use less with bat or less/cat if bat not installed | boolean                    |
| `set_env`              | Set environment variables for previewer               | dict                       |
| `scroll_strategy`      | How to behave when the when there are no more item next/prev | cycle, nil          |
| `file_previewer`       | What telescope previewer to use for files.            | [Previewers](#previewers)  |
| `grep_previewer`       | What telescope previewer to use for grep and similar  | [Previewers](#previewers)  |
| `qflist_previewer`     | What telescope previewer to use for qflist            | [Previewers](#previewers)  |


### Options for extension developers
| Keys                   | Description                                           | Options                    |
|------------------------|-------------------------------------------------------|----------------------------|
| `buffer_previewer_maker` | How a file gets loaded and which highlighter will be used. Extensions will change it | function             |

### Options affecting Sorting

| Keys                   | Description                                           | Options                    |
|------------------------|-------------------------------------------------------|----------------------------|
| `file_sorter`          | The sorter for file lists.                            | [Sorters](#sorters)        |
| `generic_sorter`       | The sorter for everything else.                       | [Sorters](#sorters)        |
| `vimgrep_arguments`    | The command line argument for grep search ... TODO.   | dict                       |
| `selection_strategy`   | What happens to the selection if the list changes.    | follow/reset/row           |
| `file_ignore_patterns` | Pattern to be ignored `{ "scratch/.*", "%.env"}`      | dict                       |
| `shorten_path`         | Whether to shorten paths or not.                      | boolean                    |

## Mappings

Mappings are fully customizable.
Many familiar mapping patterns are setup as defaults.

| Mappings       | Action                           |
|----------------|----------------------------------|
| `<C-n>/<Down>` | Next item                        |
| `<C-p>/<Up>`   | Previous item                    |
| `j/k`          | Next/previous (in normal mode)   |
| `<CR>`         | Confirm selection                |
| `<C-x>`        | go to file selection as a split  |
| `<C-v>`        | go to file selection as a vsplit |
| `<C-t>`        | go to a file in a new tab        |
| `<C-u>`        | scroll up in preview window      |
| `<C-d>`        | scroll down in preview window    |
| `<C-c>`        | close telescope                  |
| `<Esc>`        | close telescope (in normal mode) |

To see the full list of mappings, check out `lua/telescope/mappings.lua` and
the `default_mappings` table.


Much like [built-in pickers](#pickers), there are a number of
[actions](https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua) you can pick from to remap your telescope buffer mappings or create a new custom action:
<!-- TODO: add custom action in addition to a function that gets ran after a given action--->
```lua
-- Built-in actions
local transform_mod = require('telescope.actions.mt').transform_mod

-- or create your custom action
local my_cool_custom_action = transform_mod({
  x = function()
    print("This function ran after another action. Prompt_bufnr: " .. prompt_bufnr)
    -- Enter your function logic here. You can take inspiration from lua/telescope/actions.lua
  end,
})
```

To remap telescope mappings and make them apply to all pickers:

```lua
local actions = require('telescope.actions')
-- Global remapping
------------------------------
require('telescope').setup{
  defaults = {
    mappings = {
      i = {
        -- To disable a keymap, put [map] = false
        -- So, to not map "<C-n>", just put
        ["<c-x>"] = false,

        -- Otherwise, just set the mapping to the function that you want it to be.
        ["<C-i>"] = actions.select_horizontal,

        -- Add up multiple actions
        ["<CR>"] = actions.select_default + actions.center,

        -- You can perform as many actions in a row as you like
        ["<CR>"] = actions.select_default+ actions.center + my_cool_custom_action,
      },
      n = {
        ["<esc>"] = actions.close,
        ["<C-i>"] = my_cool_custom_action,
      },
    },
  }
}
```

For a [picker](#pickers) specific remapping, it can be done by setting
its `attach_mappings` key to a function, like this

```lua
local actions = require('telescope.actions')
local action_set = require('telescope.actions.set')
-- Picker specific remapping
------------------------------
require('telescope.builtin').fd({ -- or new custom picker's attach_mappings field:
  attach_mappings = function(prompt_bufnr)
    -- This will replace select no mather on which key it is mapped by default
    action_set.select:replace(function(prompt_bufnr, type)
      local entry = action_state.get_selected_entry()
      actions.close(prompt_bufnr)
      print(vim.inspect(entry))
      -- Code here
    end)

    -- You can also enhance an action with pre and post action which will run before of after an action
    action_set.select:enhance({
      pre = function()
          -- Will run before actions.select_default
      end,
      post = function()
          -- Will run after actions.select_default
      end,
    })

    -- Or replace for all commands: default, horizontal, vertical, tab
    action_set.select:replace(function(_, type)
      print(cmd) -- Will print edit, new, vnew or tab depending on your keystroke
    end)

    return true
  end,
})
```

For more info, see [./developers.md](./developers.md)

## Pickers

Built-in functions. Ready to be bound to any key you like. :smile:

```vim
:lua require'telescope.builtin'.planets{}

:nnoremap <Leader>pp :lua require'telescope.builtin'.planets{}
```

### File Pickers

| Functions                           | Description                                                                                 |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| `builtin.find_files`                | Lists Files in current directory.                                                           |
| `builtin.git_files`                 | Lists Git files in current directory.                                                       |
| `builtin.grep_string`               | Searches for a string under the cursor in current directory.                                |
| `builtin.live_grep`                 | Searches in current directory files. (respecting .gitignore)                                |
| `builtin.file_browser`              | Ivy-like file explorer. Creates files by typing in filename and pressing <C-e>. Press <C-e> without prompt for more info |

### Vim Pickers

| Functions                           | Description                                                                                 |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| `builtin.buffers`                   | Lists Open buffers in the current vim instance.                                             |
| `builtin.oldfiles`                  | Lists Previously open files.                                                                |
| `builtin.commands`                  | Lists Available plugin/user commands and run it.                                            |
| `builtin.tags`                      | Lists Tags in current directory with preview (ctags -R)                                     |
| `builtin.command_history`           | Lists Commands previously ran and run it on enter.                                          |
| `builtin.help_tags`                 | Lists Available help tags and open help document.                                           |
| `builtin.man_pages`                 | Lists Man entries.                                                                          |
| `builtin.marks`                     | Lists Markers and their value.                                                              |
| `builtin.colorscheme`               | Lists Colorscheme and switch to it on enter.                                                |
| `builtin.quickfix`                  | Lists items from quickfix.                                                                  |
| `builtin.loclist`                   | Lists items from current window's location list.                                            |
| `builtin.vim_options`               | Lists vim options and on enter edit the options value.                                      |
| `builtin.registers`                 | Lists vim registers and edit or paste selection.                                            |
| `builtin.autocommands`              | Lists vim autocommands and go to their declaration.                                         |
| `builtin.spell_suggest`             | Lists spelling suggestions for <cword>.                                                     |
| `builtin.keymaps`                   | Lists normal-mode mappings.                                                                 |
| `builtin.filetypes`                 | Lists all filetypes.                                                                        |
| `builtin.highlights`                | Lists all highlights.                                                                       |
| `builtin.current_buffer_fuzzy_find` | Searches in current buffer lines.                                                           |
| `builtin.current_buffer_tags`       | Lists Tags in current buffer.                                                               |
| ..................................  | Your next awesome picker function here :D                                                   |

### LSP Pickers

| Functions                           | Description                                                                                 |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| `builtin.lsp_references`            | Searches in LSP references.                                                                 |
| `builtin.lsp_document_symbols`      | Searches in LSP Document Symbols in the current document.                                   |
| `builtin.lsp_workspace_symbols`     | Searches in LSP all workspace symbols.                                                      |
| `builtin.lsp_code_actions`          | Lists LSP action to be trigged on enter.                                                    |
| `builtin.lsp_range_code_actions`    | Lists LSP range code action to be trigged on enter.                                         |
| ..................................  | Your next awesome picker function here :D                                                   |

### Git Pickers

| Functions                           | Description                                                                                 |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| `builtin.git_commits`               | Lists git commits with diff preview and on enter checkout the commit.                       |
| `builtin.git_bcommits`              | Lists buffer's git commits with diff preview and checkouts it out on enter.                 |
| `builtin.git_branches`              | Lists all branches with log preview and checkout action.                                    |
| `builtin.git_status`                | Lists current changes per file with diff preview and add action. (Multiselection still WIP) |
| ..................................  | Your next awesome picker function here :D                                                   |

### Treesitter Picker

| Functions                           | Description                                                                                 |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| `builtin.treesitter`                | Lists Function names, variables, from Treesitter!                                           |
| ..................................  | Your next awesome picker function here :D                                                   |

### Lists Picker

| Functions                           | Description                                                                                 |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| `builtin.planets`                   | Use the telescope.                                                                          |
| `builtin.builtin`                   | Lists Built-in pickers and run them on enter.                                               |
| `builtin.reloader`                  | Lists lua modules and reload them on enter.                                                 |
| `builtin.symbols`                   | Lists symbols inside a file `data/telescope-sources/*.json` found in your rtp. More info and symbol sources can be found [here](https://github.com/nvim-telescope/telescope-symbols.nvim) |
| ..................................  | Your next awesome picker function here :D                                                   |

## Previewers

| Previewers                         | Description                                                     |
|------------------------------------|-----------------------------------------------------------------|
| `previewers.cat.new`               | Default previewer for files. Uses `cat`/`bat`                   |
| `previewers.vimgrep.new`           | Default previewer for grep and similar. Uses `cat`/`bat`        |
| `previewers.qflist.new`            | Default previewer for qflist. Uses `cat`/`bat`                  |
| `previewers.vim_buffer_cat.new`    | Experimental previewer for files. Uses vim buffers              |
| `previewers.vim_buffer_vimgrep.new`| Experimental previewer for grep and similar. Uses vim buffers   |
| `previewers.vim_buffer_qflist.new` | Experimental previewer for qflist. Uses vim buffers             |
| .................................. | Your next awesome previewer here :D                             |

By default, telescope.nvim uses `cat`/`bat` for preview. However after telescope's new experimental previewers
are stable this will change. The new experimental previewers use tree-sitter and vim buffers, provide much
better performance and are ready for daily usage, but there might be cases where it can't detect a Filetype
correctly, thus leading to wrong highlights. This is because we can't determine the filetype in the traditional way
(we don't do `bufload`. We read the file async with `vim.loop.fs_` and attach only a highlighter), because we can't
execute autocommands, otherwise the speed of the previewer would slow down considerably.
If you want to configure more filetypes take a look at
[plenary wiki](https://github.com/nvim-lua/plenary.nvim#plenaryfiletype).

If you want to configure the `vim_buffer_` previewer, e.g. you want the line to wrap do this:
```vim
autocmd User TelescopePreviewerLoaded setlocal wrap
```

## Sorters

| Sorters                            | Description                                                     |
|------------------------------------|-----------------------------------------------------------------|
| `sorters.get_fuzzy_file`           | Telescope's default sorter for files                            |
| `sorters.get_generic_fuzzy_sorter` | Telescope's default sorter for everything else                  |
| `sorters.get_levenshtein_sorter`   | Using Levenshtein distance algorithm (don't use :D)             |
| `sorters.get_fzy_sorter`           | Using fzy algorithm                                             |
| `sorters.fuzzy_with_index_bias`    | Used to list stuff with consideration to when the item is added |
| .................................. | Your next awesome sorter here :D                                |

A `Sorter` is called by the `Picker` on each item returned by the `Finder`. It
return a number, which is equivalent to the "distance" between the current
`prompt` and the `entry` returned by a `finder`.

<!-- TODO review -->
<!-- - Currently, it's not possible to delay calling the `Sorter` until the end of the execution, it is called on each item as we receive them. -->
<!-- - This was done this way so that long running / expensive searches can be instantly searchable and we don't have to wait til it completes for things to start being worked on. -->
<!-- - However, this prevents using some tools, like FZF easily. -->
<!-- - In the future, I'll probably add a mode where you can delay the sorting til the end, so you can use more traditional sorting tools. -->

## Themes

Common groups of settings can be set up to allow for themes.
We have some built in themes but are looking for more cool options.

![dropdown](https://i.imgur.com/SorAcXv.png)

| Themes                   | Description                                                           |
|--------------------------|-----------------------------------------------------------------------|
| `themes.get_dropdown`    | A list like centered list. [dropdown](https://i.imgur.com/SorAcXv.png)|
| ...                      | Your next awesome theme here :D                                       |


To use a theme, simply append it to a built-in function:
```vim
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({}))<cr>
" Change an option
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({ winblend = 10 }))<cr>
```
or use with command:
```vim
Telescope find_files theme=get_dropdown
```

Themes should work with every `telescope.builtin` function.  If you wish to
make a theme, check out `lua/telescope/themes.lua`.

## Autocmds

Telescope user autocmds:

| Event                           | Description                                        |
|---------------------------------|----------------------------------------------------|
| `User TelescopeFindPre`         | Do it before create Telescope all the float window |
| `User TelescopePreviewerLoaded` | Do it after Telescope previewer window create      |


## Extensions

Telescope provides the capabilties to create & register extensions, which improve telescope in a variety of ways.

Some extensions provide integration with external tools, outside of the scope of `builtins`. Others provide performance
enhancements by using compiled C and interfacing directly with Lua.

### Loading extensions

To load an extension, use the `load_extension` function as shown in the example below:
```lua
-- This will load fzy_native and have it override the default file sorter
require('telescope').load_extension('fzy_native')
```

You may skip explicitly loading extensions (they will then be lazy-loaded), but tab completions will not be available right away.

### Accessing pickers from extensions

Pickers from extensions are added to the `:Telescope` command under their respective name.
For example:
```viml
" Run the `configurations` picker from nvim-dap
:Telescope dap configurations
```

They can also be called directly from lua:
```lua
-- Run the `configurations` picker from nvim-dap
require('telescope').extensions.dap.configurations()
```

### Community Extensions

For a list of community extensions, please consult the wiki: [Extensions](https://github.com/nvim-telescope/telescope.nvim/wiki/Extensions)

## API
<!-- TODO: need to provide working examples for every api -->

### Finders
<!-- TODO what is finders -->
```lua
-- lua/telescope/finders.lua
Finder:new{
  entry_maker     = function(line) end,
  fn_command      = function() { command = "", args  = { "ls-files" } } end,
  static          = false,
  maximum_results = false
}
```

### Picker
<!-- TODO: this section need some love, an in-depth explanation will be appreciated it need some in depth explanation -->
<!-- TODO what is pickers -->
This section is an overview of how custom pickers can be created any configured.


```lua
-- lua/telescope/pickers.lua
Picker:new{
  prompt_title            = "", -- REQUIRED
  finder                  = FUNCTION, -- see lua/telescope/finder.lua
  sorter                  = FUNCTION, -- see lua/telescope/sorter.lua
  previewer               = FUNCTION, -- see lua/telescope/previewer.lua
  selection_strategy      = "reset", -- follow, reset, row
  border                  = {},
  borderchars             = {"─", "│", "─", "│", "┌", "┐", "┘", "└"},
  preview_cutoff          = 120,
  default_selection_index = 1, -- Change the index of the initial selection row
}
```

To override only *some* of the default mappings, you can use the
`attach_mappings` key in the `setup` table. For example:

```lua
function my_custom_picker(results)
  pickers.new(opts, {
    prompt_title = 'Custom Picker',
    finder = finders.new_table(results),
    sorter = sorters.fuzzy_with_index_bias(),
    attach_mappings = function(_, map)
      -- Map "<CR>" in insert mode to the function, actions.set_command_line
      map('i', '<CR>', actions.set_command_line)

      -- If the return value of `attach_mappings` is true, then the other
      -- default mappings are still applies.
      --
      -- Return false if you don't want any other mappings applied.
      --
      -- A return value _must_ be returned. It is an error to not return anything.
      return true
    end,
  }):find()
end
```

### Layout (display)
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

## Vim Commands

All `telescope.nvim` functions are wrapped in `vim` commands for easy access, its
supports tab completions and settings options.

```viml
" Tab completion
:Telescope |<tab>
:Telescope find_files

" Setting options
:Telescope find_files prompt_prefix=🔍

" If option is table type in lua code ,you can use `,` connect each command string eg:
" find_command,vimgrep_arguments they are both table type. so config it in commandline like
:Telescope find_files find_command=rg,--ignore,--hidden,--files prompt_prefix=🔍
```

## Media

- [What is Telescope? (Video)](https://www.twitch.tv/teej_dv/clip/RichDistinctPlumberPastaThat)
- [More advanced configuration (Video)](https://www.twitch.tv/videos/756229115)
- [Example video](https://www.youtube.com/watch?v=65AVwHZflsU)

## FAQ
<!-- Any question answered in issues should be written here -->

### How to change some defaults in built-in functions?

All options available from the setup function (see [Configuration options]()) and
some other functions can be easily changed in custom pickers or built-in
functions.
<!-- TODO: insert a list of available options like previewer and prompt prefix -->

```lua
-- Disable preview for find files
nnoremap <leader>ff :lua require('telescope.builtin').find_files({previewer = false})<CR>

-- Change change prompt prefix for find_files builtin function:
nnoremap <leader>fg :lua require('telescope.builtin').live_grep({ prompt_prefix=🔍 })<CR>
nnoremap <leader>fg :Telescope live_grep prompt_prefix=🔍<CR>
```

### How to change Telescope Highlights group?

There are 10 highlights group you can play around with in order to meet your needs:

```viml
highlight TelescopeSelection      guifg=#D79921 gui=bold " selected item
highlight TelescopeSelectionCaret guifg=#CC241D " selection caret
highlight TelescopeMultiSelection guifg=#928374 " multisections
highlight TelescopeNormal         guibg=#00000  " floating windows created by telescope.

" Border highlight groups.
highlight TelescopeBorder         guifg=#ffffff
highlight TelescopePromptBorder   guifg=#ffffff
highlight TelescopeResultsBorder  guifg=#ffffff
highlight TelescopePreviewBorder  guifg=#ffffff

" Used for highlighting characters that you match.
highlight TelescopeMatching       guifg=blue

" Used for the prompt prefix
highlight TelescopePromptPrefix   guifg=red
```

To checkout the default values of the highlight groups, checkout `plugin/telescope.vim`

### How to add autocmds to telescope prompt ?

`TelescopePrompt` is the prompt Filetype. You can customize the Filetype as you would normally.


## Contributing

All contributions are welcome! Just open a pull request.
<!-- TODO: add plugin documentation -->
When approved,
  changes in the user interface and new built-in functions
  will need to be reflected in the documentation and in `README.md`.
