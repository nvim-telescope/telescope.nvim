-- TODO: Customize keymap
local a = vim.api

local mappings = {}

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

mappings.apply_keymap(42, {
  n = {
    ["<leader>x"] = "just do this string",

    ["<CR>"] = function(picker, prompt_bufnr)
      actions.close_prompt()

      local filename = ...
      vim.cmd(string.format(":e %s", filename))
    end,
  },

  i = {
  }
})
--]]
mappings.apply_keymap = function(prompt_bufnr, buffer_keymap)
  for mode, mode_map in pairs(buffer_keymap) do
    for key_bind, key_func in pairs(mode_map) do
      if type(key_func) == "string" then
        a.nvim_buf_set_keymap(
          prompt_bufnr,
          mode,
          key_bind,
          key_func,
          {
            silent = true
          }
        )
      else
        local key_id = assign_function(prompt_bufnr, key_func)
        local prefix = ""
        if mode == "i" then
          prefix = "<C-O>"
        end

        a.nvim_buf_set_keymap(
          prompt_bufnr,
          mode,
          key_bind,
          string.format(
            "%s:lua require('telescope.mappings').execute_keymap(%s, %s)<CR>",
            prefix,
            prompt_bufnr,
            key_id
          ),
          {
            silent = true
          }
        )

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
