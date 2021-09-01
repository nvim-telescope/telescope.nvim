# telescope.nvim

[![Gitter](https://badges.gitter.im/nvim-telescope/community.svg)](https://gitter.im/nvim-telescope/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Gaze deeply into unknown regions using the power of the moon.

## What Is Telescope?

`telescope.nvim` is a highly extendable fuzzy finder over lists. Built on the latest
awesome features from `neovim` core. Telescope is centered around modularity,
allowing for easy customization.

Community driven built-in [pickers](#pickers), [sorters](#sorters) and [previewers](#previewers).

### Built-in Support:

- [Vim](#vim-pickers)
- [Files](#file-pickers)
- [Git](#git-pickers)
- [LSP](#neovim-lsp-pickers)
- [Treesitter](#treesitter-picker)

![Preview](https://i.imgur.com/TTTja6t.gif)
<sub>For more showcases of Telescope, please visit the [Showcase section](https://github.com/nvim-telescope/telescope.nvim/wiki/Showcase) in the Telescope Wiki</sub>

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
- [Contributing](#contributing)

## Getting Started

This section should guide you to run your first built-in pickers :smile:.

[Neovim (v0.5)](https://github.com/neovim/neovim/releases/tag/v0.5.0) or newer
  is required for `telescope.nvim` to work.

### Optional dependencies

- [sharkdp/bat](https://github.com/sharkdp/bat) (preview)
- [sharkdp/fd](https://github.com/sharkdp/fd) (finder)
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) (finder)
- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (finder/preview)
- [neovim LSP]( https://neovim.io/doc/user/lsp.html) (picker)
- [devicons](https://github.com/kyazdani42/nvim-web-devicons) (icons)


### Installation

Using [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)

```viml
call dein#add('nvim-lua/plenary.nvim')
call dein#add('nvim-telescope/telescope.nvim')
```
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'nvim-telescope/telescope.nvim',
  requires = { {'nvim-lua/plenary.nvim'} }
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

" Using Lua functions
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>
```

See [built-in pickers](#pickers) for a list of all built-in functions.

## Customization

This section should help you explore available options to configure and
customize your `telescope.nvim`.

Unlike most vim plugins, `telescope.nvim` can be customized by either applying
customizations globally, or individually per picker.

- **Global Customization** affecting all pickers can be done through the
  main `setup()` method (see defaults below)
- **Individual Customization** affecting a single picker by passing `opts`
  built-in pickers (e.g. `builtin.fd(opts)`) see [Configuration recipes](https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes) wiki page for ideas.

### Telescope Defaults

As an example of using the `setup()` method, the following code configures
`telescope.nvim` to its default settings:

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
    prompt_prefix = "> ",
    selection_caret = "> ",
    entry_prefix = "  ",
    initial_mode = "insert",
    selection_strategy = "reset",
    sorting_strategy = "descending",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        mirror = false,
      },
      vertical = {
        mirror = false,
      },
    },
    file_sorter =  require'telescope.sorters'.get_fuzzy_file,
    file_ignore_patterns = {},
    generic_sorter =  require'telescope.sorters'.get_generic_fuzzy_sorter,
    winblend = 0,
    border = {},
    borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
    color_devicons = true,
    use_less = true,
    path_display = {},
    set_env = { ['COLORTERM'] = 'truecolor' }, -- default = nil,
    file_previewer = require'telescope.previewers'.vim_buffer_cat.new,
    grep_previewer = require'telescope.previewers'.vim_buffer_vimgrep.new,
    qflist_previewer = require'telescope.previewers'.vim_buffer_qflist.new,

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

<!-- TODO: move some options to Options affecting behavior -->

### Options affecting Presentation

| Keys                   | Description                                           | Options                     |
|------------------------|-------------------------------------------------------|-----------------------------|
| `prompt_prefix`        | What should the prompt prefix be.                     | string                      |
| `selection_caret`      | What should the selection caret be.                   | string                      |
| `entry_prefix`         | What should be shown in front of every entry. (current selection excluded) | string |
| `initial_mode`         | The initial mode when a prompt is opened.             | insert/normal               |
| `layout_strategy`      | How the telescope is drawn.                           | [supported layouts](https://github.com/nvim-telescope/telescope.nvim/wiki/Layouts) |
| `layout_config`        | Extra settings for fine-tuning how your layout looks  | [supported settings](https://github.com/nvim-telescope/telescope.nvim/wiki/Layouts#layout-defaults) |
| `sorting_strategy`     | Where first selection should be located.              | descending/ascending        |
| `scroll_strategy`      | How to behave when the when there are no more item next/prev | cycle, nil           |
| `winblend`             | How transparent is the telescope window should be.    | number                      |
| `borderchars`          | The border chars, it gives border telescope window    | dict                        |
| `disable_devicons`     | Whether to display devicons or not                    | boolean                     |
| `color_devicons`       | Whether to color devicons or not                      | boolean                     |
| `use_less`             | Whether to use less with bat or less/cat if bat not installed | boolean             |
| `set_env`              | Set environment variables for previewer               | dict                        |
| `path_display`         | How file paths are displayed                          | [supported settings](https://github.com/nvim-telescope/telescope.nvim/wiki/Path-Display-Configuration) |
| `file_previewer`       | What telescope previewer to use for files.            | [Previewers](#previewers)   |
| `grep_previewer`       | What telescope previewer to use for grep and similar  | [Previewers](#previewers)   |
| `qflist_previewer`     | What telescope previewer to use for qflist            | [Previewers](#previewers)   |


### Options for extension developers

| Keys                     | Description                                           | Options                    |
|--------------------------|-------------------------------------------------------|----------------------------|
| `buffer_previewer_maker` | How a file gets loaded and which highlighter will be used. Extensions will change it | function |

### Options affecting Sorting

| Keys                   | Description                                           | Options                  |
|------------------------|-------------------------------------------------------|--------------------------|
| `file_sorter`          | The sorter for file lists.                            | [Sorters](#sorters)      |
| `generic_sorter`       | The sorter for everything else.                       | [Sorters](#sorters)      |
| `vimgrep_arguments`    | The command-line argument for grep search ... TODO.   | dict                     |
| `selection_strategy`   | What happens to the selection if the list changes.    | follow/reset/row/closest |
| `file_ignore_patterns` | Pattern to be ignored `{ "scratch/.*", "%.env" }`     | dict                     |

### Customize Default Builtin behavior

You can customize each default builtin behavior by adding the preferred options
into the table that is passed into `require("telescope").setup()`.

Example:

```lua
require("telescope").setup {
  defaults = {
    -- Your defaults config goes in here
  },
  pickers = {
    -- Your special builtin config goes in here
    buffers = {
      sort_lastused = true,
      theme = "dropdown",
      previewer = false,
      mappings = {
        i = {
          ["<c-d>"] = require("telescope.actions").delete_buffer,
          -- Right hand side can also be the name of the action as a string
          ["<c-d>"] = "delete_buffer",
        },
        n = {
          ["<c-d>"] = require("telescope.actions").delete_buffer,
        }
      }
    },
    find_files = {
      theme = "dropdown"
    }
  },
  extensions = {
    -- Your extension config goes in here
  }
}
```

## Mappings

Mappings are fully customizable.
Many familiar mapping patterns are setup as defaults.

| Mappings       | Action                                                       |
|----------------|--------------------------------------------------------------|
| `<C-n>/<Down>` | Next item                                                    |
| `<C-p>/<Up>`   | Previous item                                                |
| `j/k`          | Next/previous (in normal mode)                               |
| `<cr>`         | Confirm selection                                            |
| `<C-q>`        | Confirm selection and open quickfix window                   |
| `<C-x>`        | Go to file selection as a split                              |
| `<C-v>`        | Go to file selection as a vsplit                             |
| `<C-t>`        | Go to a file in a new tab                                    |
| `<C-u>`        | Scroll up in preview window                                  |
| `<C-d>`        | Scroll down in preview window                                |
| `<C-/>/?`      | Show picker mappings (in insert & normal mode, respectively) |
| `<C-c>`        | Close telescope                                              |
| `<Esc>`        | Close telescope (in normal mode)                             |

To see the full list of mappings, check out `lua/telescope/mappings.lua` and
the `default_mappings` table.


Much like [built-in pickers](#pickers), there are a number of
[actions](https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua)
you can pick from to remap your telescope buffer mappings, or create a new custom action:

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
        ["<C-n>"] = false,

        -- Otherwise, just set the mapping to the function that you want it to be.
        ["<C-i>"] = actions.select_horizontal,

        -- Add up multiple actions
        ["<cr>"] = actions.select_default + actions.center,

        -- You can perform as many actions in a row as you like
        ["<cr>"] = actions.select_default + actions.center + my_cool_custom_action,
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
its `attach_mappings` key to a function, like so:

```lua
local actions = require('telescope.actions')
local action_set = require('telescope.actions.set')
local action_state = require('telescope.actions.state')
-- Picker specific remapping
------------------------------
require('telescope.builtin').fd({ -- or new custom picker's attach_mappings field:
  attach_mappings = function(prompt_bufnr)
    -- This will replace select no matter on which key it is mapped by default
    action_set.select:replace(function(prompt_bufnr, type)
      local entry = action_state.get_selected_entry()
      actions.close(prompt_bufnr)
      print(vim.inspect(entry))
      -- Code here
    end)

    -- You can also enhance an action with pre and post action, which will run before of after an action
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
------------------------------
-- More practical example of adding a new mapping
require'telescope.builtin'.git_branches({ attach_mappings = function(_, map)
  map('i', '<c-d>', actions.git_delete_branch) -- this action already exist
  map('n', '<c-d>', actions.git_delete_branch) -- this action already exist
  -- For more actions look at lua/telescope/actions/init.lua
  return true
end})
```

For more info, see [./developers.md](./developers.md)

## Pickers

Built-in functions. Ready to be bound to any key you like. :smile:

```vim
:lua require'telescope.builtin'.planets{}

:nnoremap <Leader>pp :lua require'telescope.builtin'.planets{}
```

### File Pickers

| Functions                           | Description                                                                                                                       |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `builtin.find_files`                | Lists files in your current working directory, respects .gitignore                                                                |
| `builtin.git_files`                 | Fuzzy search through the output of `git ls-files` command, respects .gitignore, optionally ignores untracked files                |
| `builtin.grep_string`               | Searches for the string under your cursor in your current working directory                                                       |
| `builtin.live_grep`                 | Search for a string in your current working directory and get results live as you type (respecting .gitignore)                    |
| `builtin.file_browser`              | Lists files and folders in your current working directory, open files, navigate your filesystem, and create new files and folders |

#### Options for builtin.live_grep

| Keys                   | Description                                                                        | Options |
|------------------------|------------------------------------------------------------------------------------|---------|
| `grep_open_files`      | Restrict live_grep to currently open files, mutually exclusive with `search_dirs`  | boolean |
| `search_dirs`          | List of directories to search in, mutually exclusive with `grep_open_files`        | list    |

### Vim Pickers

| Functions                           | Description                                                                                                                                                 |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `builtin.buffers`                   | Lists open buffers in current neovim instance                                                                                                               |
| `builtin.oldfiles`                  | Lists previously open files                                                                                                                                 |
| `builtin.commands`                  | Lists available plugin/user commands and runs them on `<cr>`                                                                                                |
| `builtin.tags`                      | Lists tags in current directory with tag location file preview (users are required to run ctags -R to generate tags or update when introducing new changes) |
| `builtin.command_history`           | Lists commands that were executed recently, and reruns them on `<cr>`                                                                                       |
| `builtin.search_history`            | Lists searches that were executed recently, and reruns them on `<cr>`                                                                                       |
| `builtin.help_tags`                 | Lists available help tags and opens a new window with the relevant help info on `<cr>`                                                                      |
| `builtin.man_pages`                 | Lists manpage entries, opens them in a help window on `<cr>`                                                                                                |
| `builtin.marks`                     | Lists vim marks and their value                                                                                                                             |
| `builtin.colorscheme`               | Lists available colorschemes and applies them on `<cr>`                                                                                                     |
| `builtin.quickfix`                  | Lists items in the quickfix list                                                                                                                            |
| `builtin.loclist`                   | Lists items from the current window's location list                                                                                                         |
| `builtin.vim_options`               | Lists vim options, allows you to edit the current value on `<cr>`                                                                                           |
| `builtin.registers`                 | Lists vim registers, pastes the contents of the register on `<cr>`                                                                                          |
| `builtin.autocommands`              | Lists vim autocommands and goes to their declaration on `<cr>`                                                                                              |
| `builtin.spell_suggest`             | Lists spelling suggestions for the current word under the cursor, replaces word with selected suggestion on `<cr>`                                          |
| `builtin.keymaps`                   | Lists normal mode keymappings                                                                                                                               |
| `builtin.filetypes`                 | Lists all available filetypes                                                                                                                               |
| `builtin.highlights`                | Lists all available highlights                                                                                                                              |
| `builtin.current_buffer_fuzzy_find` | Live fuzzy search inside of the currently open buffer                                                                                                       |
| `builtin.current_buffer_tags`       | Lists all of the tags for the currently open buffer, with a preview                                                                                         |
| `builtin.resume`                    | Lists the results incl. multi-selections of the previous picker                                                                                             |
| `builtin.pickers`                   | Lists the previous pickers incl. multi-selections (see `:h telescope.defaults.cache_picker`)                                                                |

### Neovim LSP Pickers

| Functions                                   | Description                                                                                                       |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| `builtin.lsp_references`                    | Lists LSP references for word under the cursor                                                                    |
| `builtin.lsp_document_symbols`              | Lists LSP document symbols in the current buffer                                                                  |
| `builtin.lsp_workspace_symbols`             | Lists LSP document symbols in the current workspace                                                               |
| `builtin.lsp_dynamic_workspace_symbols`     | Dynamically Lists LSP for all workspace symbols                                                                   |
| `builtin.lsp_code_actions`                  | Lists any LSP actions for the word under the cursor, that can be triggered with `<cr>`                            |
| `builtin.lsp_range_code_actions`            | Lists any LSP actions for a given range, that can be triggered with `<cr>`                                        |
| `builtin.lsp_document_diagnostics`          | Lists LSP diagnostics for the current buffer                                                                      |
| `builtin.lsp_workspace_diagnostics`         | Lists LSP diagnostics for the current workspace if supported, otherwise searches in all open buffers              |
| `builtin.lsp_implementations`               | Goto the implementation of the word under the cursor if there's only one, otherwise show all options in Telescope |
| `builtin.lsp_definitions`                   | Goto the definition of the word under the cursor, if there's only one, otherwise show all options in Telescope    |

#### Pre-filtering option for LSP pickers

For the `*_symbols` and `*_diagnostics` LSP pickers, there is a special filtering that you can use to specify your
search. When in insert mode while the picker is open, type `:` and then press `<C-l>` to get an autocomplete menu
filled with all of the possible filters you can use.

I.e. while using the `lsp_document_symbols` picker, adding `:methods:` to your query filters out any
document symbols not recognized as methods by treesitter.

### Git Pickers

| Functions                           | Description                                                                                                |
|-------------------------------------|------------------------------------------------------------------------------------------------------------|
| `builtin.git_commits`               | Lists git commits with diff preview, checkout action `<cr>`, reset mixed `<C-r>m`, reset soft `<C-r>s` and reset hard `<C-r>h` |
| `builtin.git_bcommits`              | Lists buffer's git commits with diff preview and checks them out on `<cr>`                                 |
| `builtin.git_branches`              | Lists all branches with log preview, checkout action `<cr>`, track action `<C-t>` and rebase action`<C-r>` |
| `builtin.git_status`                | Lists current changes per file with diff preview and add action. (Multi-selection still WIP)               |
| `builtin.git_stash`                 | Lists stash items in current repository with ability to apply them on `<cr>`                               |

### Treesitter Picker

| Functions                           | Description                                       |
|-------------------------------------|---------------------------------------------------|
| `builtin.treesitter`                | Lists Function names, variables, from Treesitter! |

### Lists Picker

| Functions                           | Description                                                                                                                                                                               |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `builtin.planets`                   | Use the telescope...                                                                                                                                                                      |
| `builtin.builtin`                   | Lists Built-in pickers and run them on `<cr>`.                                                                                                                                            |
| `builtin.reloader`                  | Lists Lua modules and reload them on `<cr>`.                                                                                                                                              |
| `builtin.symbols`                   | Lists symbols inside a file `data/telescope-sources/*.json` found in your rtp. More info and symbol sources can be found [here](https://github.com/nvim-telescope/telescope-symbols.nvim) |

## Previewers

| Previewers                         | Description                                                     |
|------------------------------------|-----------------------------------------------------------------|
| `previewers.vim_buffer_cat.new`    | Default previewer for files. Uses vim buffers                   |
| `previewers.vim_buffer_vimgrep.new`| Default previewer for grep and similar. Uses vim buffers        |
| `previewers.vim_buffer_qflist.new` | Default previewer for qflist. Uses vim buffers                  |
| `previewers.cat.new`               | Deprecated previewer for files. Uses `cat`/`bat`                |
| `previewers.vimgrep.new`           | Deprecated previewer for grep and similar. Uses `cat`/`bat`     |
| `previewers.qflist.new`            | Deprecated previewer for qflist. Uses `cat`/`bat`               |

The default previewers are from now on `vim_buffer_` previewers. They use vim buffers for displaying files
and use tree-sitter or regex for file highlighting.
These previewers are guessing the filetype of the selected file, so there might be cases where they miss,
leading to wrong highlights. This is because we can't determine the filetype in the traditional way:
We don't do `bufload` and instead read the file asynchronously with `vim.loop.fs_` and attach only a
highlighter; otherwise the speed of the previewer would slow down considerably.
If you want to configure more filetypes, take a look at
[plenary wiki](https://github.com/nvim-lua/plenary.nvim#plenaryfiletype).

If you want to configure the `vim_buffer_` previewer (e.g. you want the line to wrap), do this:

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

A `Sorter` is called by the `Picker` on each item returned by the `Finder`. It
returns a number, which is equivalent to the "distance" between the current
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

| Themes                   | Description                                                                                 |
|--------------------------|---------------------------------------------------------------------------------------------|
| `themes.get_dropdown`    | A list like centered list. [dropdown](https://i.imgur.com/SorAcXv.png)                      |
| `themes.get_cursor`      | [A cursor relative list.](https://github.com/nvim-telescope/telescope.nvim/pull/878)                                                                      |
| `themes.get_ivy`         | Bottom panel overlay. [Ivy #771](https://github.com/nvim-telescope/telescope.nvim/pull/771) |

To use a theme, simply append it to a built-in function:

```vim
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({}))<cr>
" Change an option
nnoremap <Leader>f :lua require'telescope.builtin'.find_files(require('telescope.themes').get_dropdown({ winblend = 10 }))<cr>
```

Or use with a command:

```vim
Telescope find_files theme=get_dropdown
```

Themes should work with every `telescope.builtin` function. If you wish to make a theme,
check out `lua/telescope/themes.lua`.

## Autocmds

Telescope user autocmds:

| Event                           | Description                                             |
|---------------------------------|---------------------------------------------------------|
| `User TelescopeFindPre`         | Do it before Telescope creates all the floating windows |
| `User TelescopePreviewerLoaded` | Do it after Telescope previewer window is created       |

## Extensions

Telescope provides the capabilities to create & register extensions, which improve telescope in a
variety of ways.

Some extensions provide integration with external tools, outside of the scope of `builtins`.
Others provide performance enhancements by using compiled C and interfacing directly with Lua.

### Loading extensions

To load an extension, use the `load_extension` function as shown in the example below:

```lua
-- This will load fzy_native and have it override the default file sorter
require('telescope').load_extension('fzy_native')
```

You may skip explicitly loading extensions (they will then be lazy-loaded), but tab completions will
not be available right away.

### Accessing pickers from extensions

Pickers from extensions are added to the `:Telescope` command under their respective name.
For example:

```viml
" Run the `configurations` picker from nvim-dap
:Telescope dap configurations
```

They can also be called directly from Lua:

```lua
-- Run the `configurations` picker from nvim-dap
require('telescope').extensions.dap.configurations()
```

### Community Extensions

For a list of community extensions, please consult the Wiki: [Extensions](https://github.com/nvim-telescope/telescope.nvim/wiki/Extensions)

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
This section is an overview of how custom pickers can be created and configured.

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
      -- Map "<cr>" in insert mode to the function, actions.set_command_line
      map('i', '<cr>', actions.set_command_line)

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

Layout can be configured by choosing a specific `layout_strategy` and
specifying a particular `layout_config` for that strategy.
For more details on available strategies and configuration options,
see `:help telescope.layout`.

Some options for configuring sizes in layouts are "resolvable".
This means that they can take different forms, and will be interpreted differently according
to which form they take.
For example, if we wanted to set the `width` of a picker using the `vertical`
layout strategy to 50% of the screen width, we would specify that width
as `0.5`, but if we wanted to specify the `width` to be exactly 80
characters wide, we would specify it as `80`.
For more details on resolving sizes, see `:help telescope.resolve`.

As an example, if we wanted to specify the layout strategy and width,
but only for this instance, we could do something like:

```
:lua require('telescope.builtin').find_files({layout_strategy='vertical',layout_config={width=0.5}})
```

If we wanted to change the width for every time we use the `vertical`
layout strategy, we could add the following to our `setup()` call:

```lua
require('telescope').setup({
  defaults = {
    layout_config = {
      vertical = { width = 0.5 }
      -- other layout configuration here
    },
    -- other defaults configuration here
  },
  -- other configuration values here
})
```

## Vim Commands

All `telescope.nvim` functions are wrapped in `vim` commands for easy access,
tab completions and setting options.

```viml
" Show all builtin pickers
:Telescope

" Tab completion
:Telescope |<tab>
:Telescope find_files

" Setting options
:Telescope find_files prompt_prefix=🔍

" If option is table type in Lua code, you can use `,` to connect each command string, e.g.:
" find_command,vimgrep_arguments are both table type. So configure it on command-line like so:
:Telescope find_files find_command=rg,--ignore,--hidden,--files prompt_prefix=🔍
```

## Media

- [What is Telescope? (Video)](https://www.twitch.tv/teej_dv/clip/RichDistinctPlumberPastaThat)
- [More advanced configuration (Video)](https://www.twitch.tv/videos/756229115)
- [Example video](https://www.youtube.com/watch?v=65AVwHZflsU)

## FAQ
<!-- Any question answered in issues should be written here -->

### How to change some defaults in built-in functions?

All options available from the setup function (see [Configuration options](#customization)
and some other functions can be easily changed in custom pickers or built-in functions.
<!-- TODO: insert a list of available options like previewer and prompt prefix -->

```lua
-- Disable preview for find_files
nnoremap <leader>ff :lua require('telescope.builtin').find_files({previewer = false})<cr>

-- Change prompt prefix for find_files builtin function:
nnoremap <leader>fg :lua require('telescope.builtin').live_grep({ prompt_prefix=🔍 })<cr>
nnoremap <leader>fg :Telescope live_grep prompt_prefix=🔍<cr>
```

### How to change Telescope Highlights group?

There are 10 highlight groups you can play around with in order to meet your needs:

```viml
highlight TelescopeSelection      guifg=#D79921 gui=bold " Selected item
highlight TelescopeSelectionCaret guifg=#CC241D          " Selection caret
highlight TelescopeMultiSelection guifg=#928374          " Multisections
highlight TelescopeNormal         guibg=#00000           " Floating windows created by telescope

" Border highlight groups
highlight TelescopeBorder         guifg=#ffffff
highlight TelescopePromptBorder   guifg=#ffffff
highlight TelescopeResultsBorder  guifg=#ffffff
highlight TelescopePreviewBorder  guifg=#ffffff

" Highlight characters your input matches
highlight TelescopeMatching       guifg=blue

" Color the prompt prefix
highlight TelescopePromptPrefix   guifg=red
```

To checkout the default values of the highlight groups, check out `plugin/telescope.vim`

### How to add autocmds to telescope prompt ?

`TelescopePrompt` is the prompt Filetype. You can customize the Filetype as you would normally.

## Contributing

All contributions are welcome! Just open a pull request.
Please read [CONTRIBUTING.md](./CONTRIBUTING.md)

## Related Projects

- [fzf.vim](https://github.com/junegunn/fzf.vim)
- [denite.nvim](https://github.com/Shougo/denite.nvim)
- [vim-clap](https://github.com/liuchengxu/vim-clap)
