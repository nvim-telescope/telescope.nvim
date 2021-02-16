local a = vim.api

local log = require('telescope.log')
local path = require('telescope.path')
local state = require('telescope.state')

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
  action_state.get_current_picker(prompt_bufnr):move_selection(change)
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

--- Edit a file based on the current selection.
---@param prompt_bufnr number: The prompt bufnr
---@param command string: The command to use to open the file.
--      Valid commands include: "edit", "new", "vedit", "tabedit"
set.edit = function(prompt_bufnr, command)
  local entry = action_state.get_selected_entry()

  if not entry then
    print("[telescope] Nothing currently selected")
    return
  else
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

    local preview_win = state.get_status(prompt_bufnr).preview_win
    if preview_win then
      a.nvim_win_set_config(preview_win, {style = ''})
    end

    local entry_bufnr = entry.bufnr

    require('telescope.actions').close(prompt_bufnr)

    if entry_bufnr then
      if command == 'edit' then
        vim.cmd(string.format(":buffer %d", entry_bufnr))
      elseif command == 'new' then
        vim.cmd(string.format(":sbuffer %d", entry_bufnr))
      elseif command == 'vnew' then
        vim.cmd(string.format(":vert sbuffer %d", entry_bufnr))
      elseif command == 'tabedit' then
        vim.cmd(string.format(":tab sb %d", entry_bufnr))
      end
    else
      filename = path.normalize(vim.fn.fnameescape(filename), vim.fn.getcwd())

      local bufnr = vim.api.nvim_get_current_buf()
      if filename ~= vim.api.nvim_buf_get_name(bufnr) then
        vim.cmd(string.format(":%s %s", command, filename))
        bufnr = vim.api.nvim_get_current_buf()
        a.nvim_buf_set_option(bufnr, "buflisted", true)
      end

      if row and col then
        local ok, err_msg = pcall(a.nvim_win_set_cursor, 0, {row, col})
        if not ok then
          log.debug("Failed to move to cursor:", err_msg, row, col)
        end
      end
    end
    vim.api.nvim_command("doautocmd filetypedetect BufRead " .. vim.fn.fnameescape(filename))
  end
end

-- ==================================================
-- Transforms modules and sets the corect metatables.
-- ==================================================
set = transform_mod(set)
return set
