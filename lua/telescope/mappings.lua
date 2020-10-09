-- TODO: Customize keymap
local a = vim.api

local actions = require('telescope.actions')
local config = require('telescope.config')

local mappings = {}

mappings.default_mappings = config.values.default_mappings or {
    i = {
      ["<C-n>"] = actions.move_selection_next,
      ["<C-p>"] = actions.move_selection_previous,

      ["<C-c>"] = actions.close,

      ["<Down>"] = actions.move_selection_next,
      ["<Up>"] = actions.move_selection_previous,

      ["<CR>"] = actions.goto_file_selection_edit,
      ["<C-x>"] = actions.goto_file_selection_split,
      ["<C-v>"] = actions.goto_file_selection_vsplit,
      ["<C-t>"] = actions.goto_file_selection_tabedit,

      ["<C-u>"] = actions.preview_scrolling_up,
      ["<C-d>"] = actions.preview_scrolling_down,

      -- TODO: When we implement multi-select, you can turn this back on :)
      -- ["<Tab>"] = actions.add_selection,
    },

    n = {
      ["<esc>"] = actions.close,
      ["<CR>"] = actions.goto_file_selection_edit,
      ["<C-x>"] = actions.goto_file_selection_split,
      ["<C-v>"] = actions.goto_file_selection_vsplit,
      ["<C-t>"] = actions.goto_file_selection_tabedit,

      -- TODO: This would be weird if we switch the ordering.
      ["j"] = actions.move_selection_next,
      ["k"] = actions.move_selection_previous,

      ["<Down>"] = actions.move_selection_next,
      ["<Up>"] = actions.move_selection_previous,

      ["<C-u>"] = actions.preview_scrolling_up,
      ["<C-d>"] = actions.preview_scrolling_down,
    },
  }

local keymap_store = setmetatable({}, {
  __index = function(t, k)
    rawset(t, k, {})

    return rawget(t, k)
  end
})

local _mapping_key_id = 0
local get_next_id = function()
  _mapping_key_id = _mapping_key_id + 1
  return _mapping_key_id
end

local assign_function = function(prompt_bufnr, func)
  local func_id = get_next_id()

  keymap_store[prompt_bufnr][func_id] = func

  return func_id
end


--[[
Usage:

mappings.apply_keymap(42, <function>, {
  n = {
    ["<leader>x"] = "just do this string",

    ["<CR>"] = function(picker, prompt_bufnr)
      actions.close_prompt()

>     local filename = ...
      vim.cmd(string.format(":e %s", filename))
    end,
  },

  i = {
  }
})
--]]
local telescope_map = function(prompt_bufnr, mode, key_bind, key_func, opts)
  if not key_func then
    return
  end

  opts = opts or {
    silent = true
  }

  if type(key_func) == "string" then
    a.nvim_buf_set_keymap(
      prompt_bufnr,
      mode,
      key_bind,
      key_func,
      opts or {
        silent = true
      }
    )
  else
    local key_id = assign_function(prompt_bufnr, key_func)
    local prefix = ""

    local map_string
    if opts.expr then
      map_string = string.format(
        [[luaeval("require('telescope.mappings').execute_keymap(%s, %s)")]],
        prompt_bufnr,
        key_id
      )
    else
      if mode == "i" and not opts.expr then
        prefix = "<cmd>"
      end

      map_string = string.format(
        "%s:lua require('telescope.mappings').execute_keymap(%s, %s)<CR>",
        prefix,
        prompt_bufnr,
        key_id
      )
    end

    a.nvim_buf_set_keymap(
      prompt_bufnr,
      mode,
      key_bind,
      map_string,
      opts
    )
  end
end

mappings.apply_keymap = function(prompt_bufnr, attach_mappings, buffer_keymap)
  local applied_mappings = { n = {}, i = {} }

  local map = function(mode, key_bind, key_func, opts)
    mode = string.lower(mode)
    local key_bind_internal = a.nvim_replace_termcodes(key_bind, true, true, true)
    applied_mappings[mode][key_bind_internal] = true

    telescope_map(prompt_bufnr, mode, key_bind, key_func, opts)
  end

  if attach_mappings and not attach_mappings(prompt_bufnr, map) then
    return
  end

  for mode, mode_map in pairs(buffer_keymap or {}) do
    mode = string.lower(mode)

    for key_bind, key_func in pairs(mode_map) do
      local key_bind_internal = a.nvim_replace_termcodes(key_bind, true, true, true)
      if not applied_mappings[mode][key_bind_internal] then
        applied_mappings[mode][key_bind_internal] = true
        telescope_map(prompt_bufnr, mode, key_bind, key_func)
      end
    end
  end

  -- TODO: Probalby should not overwrite any keymaps
  for mode, mode_map in pairs(mappings.default_mappings) do
    mode = string.lower(mode)

    for key_bind, key_func in pairs(mode_map) do
      local key_bind_internal = a.nvim_replace_termcodes(key_bind, true, true, true)
      if not applied_mappings[mode][key_bind_internal] then
        applied_mappings[mode][key_bind_internal] = true
        telescope_map(prompt_bufnr, mode, key_bind, key_func)
      end
    end
  end

  vim.cmd(string.format(
    [[autocmd BufDelete %s :lua require('telescope.mappings').clear(%s)]],
    prompt_bufnr,
    prompt_bufnr
  ))
end

mappings.execute_keymap = function(prompt_bufnr, keymap_identifier)
  local key_func = keymap_store[prompt_bufnr][keymap_identifier]

  assert(
    key_func,
    string.format(
      "Unsure of how we got this failure: %s %s",
      prompt_bufnr,
      keymap_identifier
    )
  )

  key_func(prompt_bufnr)
end

mappings.clear = function(prompt_bufnr)
  keymap_store[prompt_bufnr] = nil
end

return mappings
