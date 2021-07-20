# Developers

## Introduction

You wanna develop your own picker and or extension? Then you are right here.
This file will present a more information introduction in doing this first and
then will present a technical interface of picker, finder, actions and
previewer. You will find more information in specific help pages and we might
move some of the technical stuff in vim pages in the future.

## Guide to your first Picker

## Technical

### Picker

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
    - The most "user-facing" of the files, which has the actions we provide builtin
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
