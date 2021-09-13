# Developers

- [Introduction](#introduction)
- [Guide to your first Picker](#guide-to-your-first-picker)
  - [Requires](#requires)
  - [First Picker](#first-picker)
  - [Replacing Actions](#replacing-actions)
  - [Entry Maker](#entry-maker)
  - [Oneshot job](#oneshot-job)
  - [Previewer](#previewer)
  - [More examples](#more-examples)
- [Technical](#technical)
  - [picker](#picker)
  - [finders](#finders)
  - [actions](#actions)
  - [previewers](#previewers)

## Introduction

So you want to develop your own picker and/or extension for telescope? Then you
are in the right place! This file will first present an introduction on how to
do this. After that, this document will present a technical explanation of
pickers, finders, actions, and the previewer. You will find more information
in specific help pages and we likely will move some of the technical stuff to
our vim help docs in the future.

This guide is mainly for telescope so it will assume that a lua knowledge is
present. You can find information for lua here:
- [Lua 5.1 Manual](https://www.lua.org/manual/5.1/)
- [Getting started using Lua in Neovim](https://github.com/nanotee/nvim-lua-guide)

## Guide to your first Picker

To guide you along the way to first picker we will do the following. We will
open a empty lua scratch file in which we will develop the picker and run it
each time using `:luafile %`. Later this file then be bundled as extension.

### Requires

The most important includes are the following modules:
```lua
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
```

- `pickers` is the main module which is used to create a new picker.
- `finders` provides interfaces to fill the picker with items.
- `config` which is used for user configuration and the `values` table holds
  these configurations. So to make it easier we only get this table in `conf`.

### First Picker

We will now make the most simplest color picker. (Note that the previous snippet
is also required. We will approach this example step by step).

```lua
-- our picker function: colors
local colors = function(opts)
  pickers.new(opts, {
    prompt_title = "colors",
    finder = finders.new_table {
      results = { "red", "green", "blue" }
    },
    sorter = conf.generic_sorter(opts),
  }):find()
end

-- to execute the function
colors()
```

Running this file should open a telescope picker with the entries `red`,
`green`, `blue`. Pressing enter will open a new file, depending which element is
selected, in this case this is not what we want so we will address this after
explaining this snippet.

We will define a new function which will take in a table `opts`. This is good
practice because now the user can define the behavior of the picker, for example
change the theme. That the user is able to change the theme we need to pass in
`opts` as the first argument to `pickers.new`. The second argument is a table
that defines the default behavior of the picker.

We can define a `prompt_title`, this option is not required, default will be
`Prompt` if not set.

`finder` is a required field that needs to be set to the result of a `finders`
function. In this case we take `new_table` which allows us to define a static
set of values, `results`, which is a array of elements, in this case our colors
as strings. It doesn't have to be a array of strings, it can also be a array of
tables. More to this later.

`sorter` on the other hand is not a required field but its good practice to
define it, because the default value will set it to `empty()`, meaning no sorter
is attached and you can't filter the results. Good practice is to set the sorter
to either `conf.generic_sorter(opts)` or `conf.file_sorter(opts)`. Setting it to
a `conf` value will respect user configuration, so if a user has setup
`fzf-native` as sorter then this decision will be respected and the fzf sorter
will be attached. Its also suggested to pass in opts here because the sorter
could make use of it. As an example the fzf sorter can be configured to be case
sensitive or insensitive. A user can setup a default behavior and then alter
this behavior with the `opts` table.

After the picker is defined you need to call `find()` to actually start the
picker.

### Replacing Actions

Now calling `colors()` will result in the opening of telescope with the values.
`red`, `green` and `blue`. The default theme isn't optimal for this picker so we
want to change it and thanks to the acceptance of `opts` we can. We will replace
the last line with the following to open the picker with the `dropdown` theme.

```lua
colors(require("telescope.themes").get_dropdown{})
```

Now lets address the issue that selecting a color opens a new buffer. For that
we need to replace the default select action. The benefit of replace rather than
mapping a new function to `<CR>` is that it will respect user configuration. So
if a user has remapped `select_default` to another key then this decision will
be respected and it works as expected for the user.

To make this work we need more includes at the top of the file.

```lua
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
```

- `actions` holds all actions that can be mapped by a user and we need it to
  access the default action so we can replace it. Also see `:help
  telescope.actions`

- `action_state` gives us a couple of util function we can use to get the
  current picker, current selection or current line. Also see `:help
  telescope.actions.state`

So lets replace the default action. For that we need to define a new key value
pair in our table that we pass into `pickers.new`, for example after `sorter`.

```lua
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        -- print(vim.inspect(selection))
        vim.api.nvim_put({ selection[1] }, "", false, true)
      end)
      return true
    end,
```

So we do this by setting the `attach_mappings` key to a function. This function
needs to return either `true` or `false`. If it returns false it means that only
the actions defined in the function should be attached. So no
`move_selection_{next,previous}`, so most of the cases you want that this
function returns `true`. If the function does not return anything a error is
thrown. The `attach_mappings` function will get to parameters passed in
`prompt_bufnr` the buffer number of the prompt buffer, which we can use to get
the pickers object, and `map` a function we can use to map actions or functions
to arbitrary key sequences.

Now we are replacing `select_default` the default action that happens on `<CR>`
(if not remapped). To do so we need to call `actions.select_default:replace` and
pass in a new function. In this new function we first close the picker with
`actions.close` and then get the `selection` with `action_state`. Its important
to notice that you can still get the selection and current prompt input
(`action_state.get_current_line()`) with `action_state` even tho the picker is
already closed. You can look at the selection with
`print(vim.inspect(selection))` and you will see that it differs from our input
(string), this is because we will internally pack it in a table with different
keys. You can specify this behavior and we will talk about that in the next
section. Now all that is left is to do anything with the selection we have. In
this case we just put the text in the current buffer.

### Entry Maker

Entry maker is a function that is used to transform a item from the finder to a
internal entry table, which has a couple of required keys. It allows to have a
different display and match something completly different. It also allows to set
a absolute path (so the file will always be found) and a relative file path as
display and for sorting. This allows that the relative file path doesn't even
have to be valid in the context of the current working directory.

We will now try to define a our entry maker for our example by providing a
`entry_maker` to `finders.new_table` and changing our table to be a little bit
more interesting. We will end up following new input for `finders.new_table`:

```lua
    finder = finders.new_table {
      results = {
        { "red", "#ff0000" },
        { "green", "#00ff00" },
        { "blue", "#0000ff" },
      },
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry[1],
          ordinal = entry[1],
        }
      end
    },
```

With the new snippet we now no longer have a array of strings but a array of
tables. Each table has a color name and the hex value.

`entry_maker` is a function that will receive each table and then we can set the
values we want to set. Its best practice to have a `value` reference to the
original entry, that way you can access the whole table in your action later.

The first required key is `display` and is either a string or a `function(tbl)`,
where `tbl` the table that is returned by `entry_maker`. For a lot of values its
suggested to have display as function especially if you are modifying it because
then the function will only be executed for the entries that are being
displayed. For examples of entry maker take a look at
`lua/telescope/make_entry.lua`. A good way to make your `display` more like a
table is to use `displayer` which can be found in
`lua/telescope/entry_display.lua`. A more simple example of `displayer` is the
function `gen_from_git_commits` in `make_entry.lua`.

The second required key is `ordinal`, which is used for sorting. So you can have
different display and sorting values. This allows `display` to be more fancier
with icons and special indicators and a separate sorting key.

There are more important keys which can be set but do not make sense in the
current context:
- `path`: to set the absolute path of the file to make sure its always found
- `lnum`: to specify a line number in the file. This will allow the
  `conf.grep_previewer` to show that line and the default action to jump to
  that line.

### Previewer

We will not write a previewer for this picker because it makes less sense and is
a more advanced topic. Its already documented pretty good under `:help
telescope.previewers` so you should read this section if you want to write your
own `previewer`. If you want a file previewer with or without col you should
default to `conf.file_previewer` or `conf.grep_previewer`.

### Oneshot Job

The `oneshot_job` finder can be used to have a async external process which will
produce results and call `entry_maker` on each new line. Example usage would be
`find`.

```lua
finder = finders.new_oneshot_job { "find", opts },
```

### More examples

A good way to find more examples is to look into the `lua/telescope/builtin/`
directory which contains all builtin pickers. Another way to find more examples
is to take a look at the [extension wiki page](https://github.com/nvim-telescope/telescope.nvim/wiki/Extensions)
and then at a extension some wrote.

If you still have questions after reading this guide feel free to ask us for
more information on [gitter](https://gitter.im/nvim-telescope/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
and we happily answer your questions and potentially even improve this guide. Of
course you can also improve this guide by sending a PRs.

## Technical

### Picker

This section is an overview of how custom pickers can be created and configured.

```lua
-- lua/telescope/pickers.lua
Picker:new{
  prompt_title            = "",
  finder                  = FUNCTION, -- see lua/telescope/finder.lua
  sorter                  = FUNCTION, -- see lua/telescope/sorter.lua
  previewer               = FUNCTION, -- see lua/telescope/previewer.lua
  selection_strategy      = "reset", -- follow, reset, row
  border                  = {},
  borderchars             = {"─", "│", "─", "│", "┌", "┐", "┘", "└"},
  default_selection_index = 1, -- Change the index of the initial selection row
}
```

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

### Actions

#### Overriding actions/action_set

How to override what different functions / keys do.

TODO: Talk about what actions vs actions sets are

##### Relevant Files

- `lua/telescope/actions/init.lua`
    - The most "user-facing" of the files, which has the builtin actions that we provide
- `lua/telescope/actions/set.lua`
    - The second most "user-facing" of the files. This provides actions that are consumed by several builtin actions, which allows for only overriding ONE item, instead of copying the same configuration / function several times.
- `lua/telescope/actions/state.lua`
    - Provides APIs for interacting with the state of telescope while in actions.
    - These are most useful for writing your own actions and interacting with telescope at that time
- `lua/telescope/actions/mt.lua`
    - You probably don't need to look at this, but it defines the behavior of actions.

##### `:replace(function)`

Directly override an action with a new function

```lua
local actions = require('telescope.actions')
actions.select_default:replace(git_checkout_function)
```

##### `:replace_if(conditional, function)`

Override an action only when `conditional` returns true.

```lua
local action_set = require('telescope.actions.set')
action_set.select:replace_if(
  function()
    return action_state.get_selected_entry().path:sub(-1) == os_sep
  end, function(_, type)
    -- type is { "default", "horizontal", "vertical", "tab" }
    local path = actions.get_selected_entry().path
    action_state.get_current_picker(prompt_bufnr):refresh(gen_new_finder(new_cwd), { reset_prompt = true})
  end
)
```

##### `:replace_map(configuration)`

```lua
local action_set = require('telescope.actions.set')
-- Use functions as keys to map to which function to execute when called.
action_set.select:replace_map {
  [function(e) return e > 0 end] = function(e) return (e / 10) end,
  [function(e) return e == 0 end] = function(e) return (e + 10) end,
}
```

### Previewers

See `:help telescope.previewers`
