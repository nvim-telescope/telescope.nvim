local a = vim.api

local log = require('telescope.log')
local path = require('telescope.path')

local action_state = require('telescope.actions.state')

local transform_mod = require('telescope.actions.mt').transform_mod

--- Telescope action sets are used to provide an interface for managing
--- actions that all primarily do the same thing, but with slight tweaks.
---
--- For example, when editing files you may want it in the current split,
--- a vertical split, etc. Instead of making users have to overwrite EACH
--- of those every time they want to change this behavior, they can instead
--- replace the `set` itself and then it will work great and they're done.
local set = setmetatable({}, {
  __index = function(_, k)
    error("'telescope.actions.set' does not have a value: " .. tostring(k))
  end
})

--- Move the current selection of a picker {change} rows.
--- Handles not overflowing / underflowing the list.
---@param prompt_bufnr number: The prompt bufnr
---@param change number: The amount to shift the selection by
set.shift_selection = function(prompt_bufnr, change)
  local count = vim.v.count
  count = count == 0 and 1 or count
  count = a.nvim_get_mode().mode == "n" and count or 1
  action_state.get_current_picker(prompt_bufnr):move_selection(change * count)
end

--- Select the current entry. This is the action set to overwrite common
--- actions by the user.
---
--- By default maps to editing a file.
---@param prompt_bufnr number: The prompt bufnr
---@param type string: The type of selection to make
--          Valid types include: "default", "horizontal", "vertical", "tabedit"
set.select = function(prompt_bufnr, type)
  return set.edit(prompt_bufnr, action_state.select_key_to_edit_key(type))
end

local edit_buffer
do
  local map = {
    edit = 'buffer',
    new = 'sbuffer',
    vnew = 'vert sbuffer',
    tabedit = 'tab sb',
  }

  edit_buffer = function(command, bufnr)
    command = map[command]
    if command == nil then
      error('There was no associated buffer command')
    end
    vim.cmd(string.format("%s %d", command, bufnr))
  end
end

--- Edit a file based on the current selection.
---@param prompt_bufnr number: The prompt bufnr
---@param command string: The command to use to open the file.
--      Valid commands include: "edit", "new", "vedit", "tabedit"
set.edit = function(prompt_bufnr, command)
  local entry = action_state.get_selected_entry()

  if not entry then
    print("[telescope] Nothing currently selected")
    return
  end

  local filename, row, col

  if entry.filename then
    filename = entry.path or entry.filename

    -- TODO: Check for off-by-one
    row = entry.row or entry.lnum
    col = entry.col
  elseif not entry.bufnr then
    -- TODO: Might want to remove this and force people
    -- to put stuff into `filename`
    local value = entry.value
    if not value then
      print("Could not do anything with blank line...")
      return
    end

    if type(value) == "table" then
      value = entry.display
    end

    local sections = vim.split(value, ":")

    filename = sections[1]
    row = tonumber(sections[2])
    col = tonumber(sections[3])
  end

  local entry_bufnr = entry.bufnr

  require('telescope.actions').close(prompt_bufnr)

  if entry_bufnr then
    edit_buffer(command, entry_bufnr)
  else
    filename = path.normalize(vim.fn.fnameescape(filename), vim.loop.cwd())

    -- check if we didn't pick a different buffer
    -- prevents restarting lsp server
    if vim.api.nvim_get_current_buf() ~= vim.fn.bufnr(filename) then
      vim.cmd(string.format("%s %s", command, filename))
    end

    if row and col then
      local ok, err_msg = pcall(a.nvim_win_set_cursor, 0, {row, col})
      if not ok then
        log.debug("Failed to move to cursor:", err_msg, row, col)
      end
    end
  end
end

-- ==================================================
-- Transforms modules and sets the corect metatables.
-- ==================================================
set = transform_mod(set)
return set
