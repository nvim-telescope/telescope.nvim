# Developers

- [Introduction](#introduction)
- [Guide to your first Picker](#guide-to-your-first-picker)
  - [Requires](#requires)
  - [First Picker](#first-picker)
  - [Replacing Actions](#replacing-actions)
  - [Entry Maker](#entry-maker)
  - [Previewer](#previewer)
  - [Oneshot Job](#oneshot-job)
  - [More examples](#more-examples)
  - [Bundling as extension](#bundling-as-extension)
- [Technical](#technical)
  - [Picker](#picker)
  - [Finders](#finders)
  - [Actions](#actions)
  - [Previewers](#previewers)
  - [Async and logging](#async-and-logging)

## Introduction

This document is for authors of custom pickers and telescope extensions. The
first part is a step-by-step guide to writing a picker and bundling it as an
extension; the second part describes the components involved (pickers, finders,
actions and previewers) in more detail.

For an overview of how these components fit together, see the architecture
diagram in `:help telescope.nvim`. The API itself is documented in the help
pages (`:help telescope.builtin`, `:help telescope.actions`,
`:help telescope.previewers`, ...).

This document assumes familiarity with Lua and Neovim's Lua API. The Neovim
documentation covers both:
- [Lua reference manual](https://neovim.io/doc/user/luaref.html) (`:help luaref`)
- [Lua guide](https://neovim.io/doc/user/lua-guide.html) (`:help lua-guide`)
- [Lua API](https://neovim.io/doc/user/lua.html) (`:help lua`)
- [Lua plugin development](https://neovim.io/doc/user/lua-plugin.html) (`:help lua-plugin`)

## Guide to your first Picker

To guide you along the way to your first picker we will open an empty Lua
scratch file, in which we will develop the picker and run it each time using
`:source %`. Later we will bundle this file as an extension.

### Requires

The most important includes are the following modules:
```lua
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
```

- `pickers`: main module which is used to create a new picker.
- `finders`: provides interfaces to fill the picker with items.
- `config`: `values` table which holds the user's configuration.
So to make it easier we access this table directly in `conf`.

### First Picker

We will now make the simplest color picker. (We will approach this example step by step;
you will still need to have the previous requires section above this code.)

```lua
-- our picker function: colors
local colors = function(opts)
  opts = opts or {}
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

Running this code with `:source %` should open a telescope picker with the entries `red`,
`green`, `blue`. Selecting a color and pressing Enter will open a new file. In this case
it's not what we want, so we will address this after explaining this snippet.

We will define a new function `colors` which accepts a table `opts`. This is good
practice because now the user can change how telescope behaves by passing in their
own `opts` table when calling `colors`.

For example the user can pass in a configuration in `opts` which allows them to change
the theme used for the picker. To allow this, we make sure to pass the `opts` table
as the first argument to `pickers.new`. The second argument is a table
which defines the default behavior of the picker.

We have defined a `prompt_title`, but this isn't required; it defaults to the
text `Prompt` if not set.

`finder` is a required field that needs to be set to the result of a `finders`
function. In this case we take `new_table` which allows us to define a static
set of values, `results`, which is an array of elements, in this case our colors
as strings. It doesn't have to be an array of strings, it can also be an array of
tables. More on this later.

`sorter`, on the other hand, is not a required field, but it's good practice to
define it, because the default value will set it to `empty()`, meaning no sorter
is attached and you can't filter the results. Good practice is to set the sorter
to either `conf.generic_sorter(opts)` or `conf.file_sorter(opts)`.

Setting it to a value from `conf` will respect the user's configuration, so if a user has set up
`fzf-native` as the sorter then this decision will be respected and the `fzf-native` sorter
will be attached. It's also suggested to pass in `opts` here because the sorter
could make use of it. As an example the default sorter (and the fzf sorter) can
be configured to be case sensitive or insensitive (`case_mode`). A user can set up
a default behavior and then alter this behavior with the `opts` table.

After the picker is defined you need to call `find()` to actually start the
picker.

### Replacing Actions

Now calling `colors()` will result in the opening of telescope with the values:
`red`, `green` and `blue`. The default theme isn't optimal for this picker so we
want to change it and thanks to the acceptance of `opts` we can. We will replace
the last line with the following to open the picker with the `dropdown` theme.

```lua
colors(require("telescope.themes").get_dropdown{})
```

Now let's address the issue that selecting a color opens a new buffer. For that
we need to replace the default select action. The benefit of replacing rather than
mapping a new function to `<CR>` is that it will respect the user's configuration. So
if a user has remapped `select_default` to another key then this decision will
be respected and it works as expected for the user.

To make this work we need more requires at the top of the file.

```lua
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
```

- `actions`: holds all actions that can be mapped by a user. We also need it to
  access the default action so we can replace it. Also see `:help
  telescope.actions`

- `action_state`: gives us a few utility functions we can use to get the
  current picker, current selection or current line. Also see `:help
  telescope.actions_state`

So let's replace the default action. For that we need to define a new key-value
pair in our table that we pass into `pickers.new`, for example after `sorter`.

```lua
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        -- vim.print(selection)
        vim.api.nvim_put({ selection[1] }, "", false, true)
      end)
      return true
    end,
```

We do this by setting the `attach_mappings` key to a function. This function
needs to return either `true` or `false`. If it returns false it means that only
the actions defined in the function should be attached (and the `mappings` a user
configured for this picker); the default mappings and the user's
`defaults.mappings` are skipped. In this case it would remove the default actions
to move the selected item in the picker, `move_selection_{next,previous}`. So in
most cases you'll want to return `true`. If the function does not return anything
then an error is thrown.

The `attach_mappings` function has two parameters, `prompt_bufnr` is the buffer number
of the prompt buffer, which we can use to get the picker object, and `map` is a function
we can use to map actions or functions to arbitrary key sequences.

Now we are replacing `select_default`, the default action, which is mapped to `<CR>`
by default. To do this we need to call `actions.select_default:replace` and
pass in a new function.

In this new function we first close the picker with `actions.close` and then
get the `selection` with `action_state`. It's important
to notice that you can still get the selection and current prompt input
(`action_state.get_current_line()`) with `action_state` even after the picker is
closed.

You can look at the selection with `vim.print(selection)` and see that it differs from our input
(a string); this is because internally we pack it into a table with different
keys. You can specify this behavior and we'll talk about that in the next
section. Now all that is left is to do something with the selection we have. In
this case we just put the text in the current buffer with `vim.api.nvim_put`.

### Entry Maker

An entry maker is a function used to transform an item from the finder to an
internal entry table, which has a few required keys. It allows us to display
one string but match something completely different. It also allows us to set
an absolute path when working with files (so the file will always be found)
and a relative file path for display and sorting. This means the relative file
path doesn't even need to be valid in the context of the current working directory.

We will now try to define our entry maker for our example by providing an
`entry_maker` to `finders.new_table` and changing our table to be a little bit
more interesting. We will end up with the following new code for `finders.new_table`:

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

With the new snippet, we no longer have an array of strings but an array of
tables. Each table has a color name and the color's hex value.

`entry_maker` is a function that will receive each table and then we can set the
values we need. It's best practice to have a `value` reference to the
original entry, that way we will always have access to the complete table in our
action.

The `display` key is required and is either a string or a `function(tbl)`,
where `tbl` is the table returned by `entry_maker`. So in this example `tbl` would
give our `display` function access to `value` and `ordinal`.

If our picker will have a lot of values, it's suggested to use a function for `display`,
especially if you are modifying the text to display. This way the function will only be executed
for the entries being displayed. For an example of an entry maker take a look at
`lua/telescope/make_entry.lua`.

A good way to make your `display` more like a table is to use a `displayer` which can be found in
`lua/telescope/pickers/entry_display.lua`. A simpler example of `displayer` is the
function `gen_from_git_commits` in `make_entry.lua`.

The `ordinal` is also required, which is used for sorting. As already mentioned
this allows us to have different display and sorting values. This allows `display`
to be more complex with icons and special indicators but `ordinal` could be a simpler
sorting key.

There are other important keys which can be set, but do not make sense in the
current context as we are not dealing with files:
- `path`: to set the absolute path of the file to make sure it's always found
- `filename`: the file the default action opens (if there is no `path`)
- `bufnr`: a buffer the default action switches to
- `lnum`, `col`: to specify a line number (and column) in the file. This will
  allow the `conf.grep_previewer` to show that line and the default action to
  jump to that line.

An entry maker can return `nil` (or an entry with `valid = false`) to skip an
item. See `:help telescope.make_entry` for more.

### Previewer

We will not write a previewer for this picker because it isn't required for
basic colors and is a more advanced topic. It's already well documented in `:help
telescope.previewers` so you can read this section if you want to write your
own `previewer`. If your entries are files, use `conf.file_previewer(opts)`, or
`conf.grep_previewer(opts)` if they have a `lnum`; this respects the user's
configuration.

### Oneshot Job

The `oneshot_job` finder can be used to have an asynchronous external process which will
find results and call `entry_maker` for each line of its output. An example usage would be
`find`.

```lua
finder = finders.new_oneshot_job({ "find" }, opts),
```

`opts.entry_maker` (default: each line as an entry) and `opts.cwd` are used; the
process runs once, and the results are then filtered by the sorter.

### More examples

A good way to find more examples is to look into the [lua/telescope/builtin](https://github.com/nvim-telescope/telescope.nvim/tree/master/lua/telescope/builtin)
directory which contains all of the builtin pickers. Another way to find more examples
is to take a look at the [extension wiki page](https://github.com/nvim-telescope/telescope.nvim/wiki/Extensions)
as this provides many extensions people have already written which use these concepts.

If you still have any questions after reading this guide, please open a
[Discussion](https://github.com/nvim-telescope/telescope.nvim/discussions).

### Bundling as extension

If you now want to bundle your picker as an extension, so it is available as a
picker via the `:Telescope` command, the following has to be done.

Structure your plugin as follows, so it can be found by telescope:

```
.
└── lua
    ├── plugin_name             # Your actual plugin code
    │   ├── init.lua
    │   └── some_file.lua
    └── telescope
        └── _extensions         # The underscore is significant
            └── plugin_name.lua # Init and register your extension
```

The `lua/telescope/_extensions/plugin_name.lua` file needs to return the
following: (see `:help telescope.register_extension()`)

```lua
return require("telescope").register_extension {
  setup = function(ext_config, config)
    -- access extension config and user config
  end,
  exports = {
    stuff = require("plugin_name").stuff
  },
  health = function()
    -- optional: checks for `:checkhealth telescope`, using `vim.health`
    vim.health.ok("everything is fine")
  end,
}
```

The setup function can be used to access the extension config and set up
extension-specific global configuration. You also have access to the user
telescope default config, so you can override specific internal functions, for
example sorters, if you have an extension that provides a replacement sorter,
like
[telescope-fzf-native](https://github.com/nvim-telescope/telescope-fzf-native.nvim).

The exports table declares the exported pickers that can then be accessed via
`Telescope plugin_name stuff`. If you only provide one export, it is suggested
that you name the key like the plugin, so you can access it with `Telescope
plugin_name`. Exported functions whose names don't start with an underscore are
also listed by `builtin.builtin({ include_extensions = true })`.

The extension is loaded (and `setup` called) on the first access of
`require("telescope").extensions.plugin_name` or with
`require("telescope").load_extension("plugin_name")`.


## Technical

### Picker

This section is an overview of how custom pickers can be created and configured.

```lua
-- lua/telescope/pickers.lua
pickers.new(opts, {
  prompt_title            = "Prompt", -- false hides the title
  results_title           = "Results",
  finder                  = finder, -- required, see "Finders" below
  sorter                  = sorter, -- default: no sorting; use conf.generic_sorter(opts) or conf.file_sorter(opts)
  previewer               = previewer, -- or a list of previewers to cycle through, see :help telescope.previewers
  attach_mappings         = function(prompt_bufnr, map) return true end, -- see "Replacing Actions" above
  default_text            = "", -- initial prompt text
  default_selection_index = 1, -- index of the initial selection
  selection_strategy      = "reset", -- reset, follow, row, closest, none
  on_close                = function() end, -- called without arguments after the picker is closed,
                                            -- however it is closed (also when leaving it)
}):find()
```

`pickers.new(opts, defaults)` merges `opts` over `defaults`; every option of
`:help telescope.defaults` (`layout_strategy`, `layout_config`, `border`,
`borderchars`, `sorting_strategy`, `initial_mode`, ...) can be set here and
defaults to the user's configuration.

Inside actions, the picker is available with
`require("telescope.actions.state").get_current_picker(prompt_bufnr)`. Useful
methods include `:get_multi_selection()`, `:delete_selection(fn)`,
`:set_prompt(text)` and `:refresh(finder, { reset_prompt = true })` (replace the
finder, e.g. to show different results).

### Finders

A finder produces the results of a picker. `lua/telescope/finders.lua` provides:

```lua
-- a static list (filtered by the sorter)
finders.new_table { results = { "a", "b" }, entry_maker = function(item) end }
-- the output lines of a command, run once (filtered by the sorter)
finders.new_oneshot_job({ "git", "ls-files" }, { entry_maker = function(line) end, cwd = "..." })
-- the output lines of a command, run again for each prompt (e.g. live_grep)
finders.new_job(function(prompt) return { "rg", "--vimgrep", prompt } end, entry_maker, nil, cwd)
finders.new_async_job { command_generator = function(prompt) end, entry_maker = ..., cwd = ..., env = ... }
-- the results of a function, called for each prompt
finders.new_dynamic { fn = function(prompt) return { "a", "b" } end, entry_maker = function(item) end }
```

A command generator returns the command as a list (or `nil` to show no results,
e.g. for an empty prompt).

A finder can also be written by hand: a callable table with a `close()` method,
which the picker calls as `finder(prompt, process_result, process_complete)`:

```lua
local finder = setmetatable({ close = function() end }, {
  __call = function(_, prompt, process_result, process_complete)
    for _, item in ipairs(get_items(prompt)) do
      if process_result(make_entry(item)) then
        return -- the prompt changed: these results are no longer needed
      end
    end
    process_complete()
  end,
})
```

- Pass each entry to `process_result`; it returns `true` when the results are
  stale (the prompt has changed), and the finder should stop.
- Call `process_complete()` once all results are passed.
- The finder runs in a [`vim.async`](https://neovim.io/doc/user/lua-async.html)
  task, so it can wait for asynchronous work (`vim.async.await(...)`,
  `vim.async.sleep(ms)`, `vim.async.await(3, vim.system, cmd, {})`)
  without blocking the editor. When the prompt changes, the task is closed. A
  finder that produces many results without waiting should yield now and then
  (`vim.async.await(1, vim.schedule)`) to keep the UI responsive.
- `close()` is called when the picker closes (stop processes, timers, ...).
- A finder whose results don't depend on the prompt can set
  `prompt_independent = true`; when the prompt is extended, the picker then only
  scores the previous matches instead of all results of the finder.

### Actions

#### Overriding actions/action_set

How to override what different functions/keys do.

An action is a function that takes the prompt buffer number, wrapped so that it
can be combined and changed. The builtin actions in `actions` (e.g.
`select_default`, `select_horizontal`, ...) mostly call an action of an
*action set* (`actions.set`, e.g. `action_set.select`), so replacing the set's
action once changes all actions that use it.

##### Relevant Files

- `lua/telescope/actions/init.lua`
    - The most "user-facing" of the files, which has the builtin actions that we provide
- `lua/telescope/actions/set.lua`
    - The second most "user-facing" of the files. This provides actions that are consumed by several builtin actions, which allows for only overriding ONE item, instead of copying the same configuration / function several times.
- `lua/telescope/actions/state.lua`
    - Provides APIs for interacting with the state of telescope from within actions.
    - These are useful for writing your own actions and interacting with telescope.
- `lua/telescope/actions/mt.lua`
    - You probably don't need to look at this, but it defines the behavior of actions.

Replacements and enhancements only apply to the picker in which they are made
(e.g. in `attach_mappings`); they are cleared when the next picker opens.

##### Combining actions

Actions can be combined with `+`; they then run in order:

```lua
map({ "i", "n" }, "<C-q>", actions.send_to_qflist + actions.open_qflist)
```

Your own functions become such actions with `transform_mod`:

```lua
local transform_mod = require("telescope.actions.mt").transform_mod
local my_actions = transform_mod({
  print_selection = function(prompt_bufnr)
    vim.print(action_state.get_selected_entry())
  end,
})
map("i", "<C-p>", my_actions.print_selection + actions.close)
```

##### `:replace(function)`

Directly override an action with a new function.

```lua
local actions = require('telescope.actions')
actions.select_default:replace(git_checkout_function)
```

##### `:replace_if(condition, function)`

Override an action only when `condition` returns true; otherwise the original
action runs. Both functions get the arguments of the action (`prompt_bufnr`, and
for `action_set.select` the selection type).

```lua
local action_set = require('telescope.actions.set')
local action_state = require('telescope.actions.state')
action_set.select:replace_if(function()
  local entry = action_state.get_selected_entry()
  return entry and vim.fn.isdirectory(entry.path) == 1
end, function(prompt_bufnr, type)
  -- type is one of "default", "horizontal", "vertical", "tab"
  local path = action_state.get_selected_entry().path
  action_state.get_current_picker(prompt_bufnr):refresh(make_finder(path), { reset_prompt = true })
end)
```

##### `:replace_map(configuration)`

Several conditional replacements at once: the keys are conditions, the values
the functions to run (the first matching condition wins).

```lua
local action_set = require('telescope.actions.set')
action_set.select:replace_map {
  [function() return vim.bo.filetype == 'lua' end] = function(prompt_bufnr) ... end,
  [function() return vim.bo.filetype == 'python' end] = function(prompt_bufnr) ... end,
}
```

##### `:enhance({ pre = function, post = function })`

Run functions before and/or after an action, without replacing it:

```lua
actions.select_default:enhance {
  post = function()
    vim.cmd("normal! zz")
  end,
}
```

### Previewers

See `:help telescope.previewers`.

### Async and logging

Telescope uses Neovim's own APIs: [`vim.async`](https://neovim.io/doc/user/lua-async.html)
for asynchronous work (see "Finders" above) and `vim.log` for logging
(`require("telescope.log")` is telescope's logger; an extension can create its
own with `vim.log.new()`). Telescope does not depend on plenary.nvim.
