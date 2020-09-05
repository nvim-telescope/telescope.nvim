-- Actions functions that are useful for people creating their own mappings.

local a = vim.api

local state = require('telescope.state')

local actions = setmetatable({}, {
  __index = function(t, k)
    error("Actions does not have a value: " .. tostring(k))
  end
})

--- Get the current picker object for the prompt
function actions.get_current_picker(prompt_bufnr)
  return state.get_status(prompt_bufnr).picker
end

--- Move the current selection of a picker {change} rows.
--- Handles not overflowing / underflowing the list.
function actions.shift_current_selection(prompt_bufnr, change)
  actions.get_current_picker(prompt_bufnr):move_selection(change)
end

function actions.move_selection_next(prompt_bufnr)
  actions.shift_current_selection(prompt_bufnr, 1)
end

function actions.move_selection_previous(prompt_bufnr)
  actions.shift_current_selection(prompt_bufnr, -1)
end

--- Get the current entry
function actions.get_selected_entry(prompt_bufnr)
  return actions.get_current_picker(prompt_bufnr):get_selection()
end

-- TODO: It seems sometimes we get bad styling.
local function goto_file_selection(prompt_bufnr, command)
  local picker = actions.get_current_picker(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

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
    else
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

    actions.close(prompt_bufnr)

    local original_win_id = picker.original_win_id or 0
    local entry_bufnr = entry.bufnr

    -- TODO: Sometimes we open something with missing line numbers and stuff...
    a.nvim_set_current_win(original_win_id)
    if entry_bufnr then
      a.nvim_win_set_buf(original_win_id, entry_bufnr)
    else
      vim.cmd(string.format(":%s %s", command, filename))

      local bufnr = vim.api.nvim_get_current_buf()
      a.nvim_buf_set_option(bufnr, 'buflisted', true)
      if row and col then
        a.nvim_win_set_cursor(0, {row, col})
      end
    end

    vim.cmd [[stopinsert]]
  end
end

function actions.goto_file_selection_edit(prompt_bufnr)
  goto_file_selection(prompt_bufnr, "e")
end

function actions.goto_file_selection_split(prompt_bufnr)
  goto_file_selection(prompt_bufnr, "sp")
end

function actions.goto_file_selection_vsplit(prompt_bufnr)
  goto_file_selection(prompt_bufnr, "vsp")
end

function actions.goto_file_selection_tabedit(prompt_bufnr)
  goto_file_selection(prompt_bufnr, "tabe")
end

actions.close = function(prompt_bufnr)
  vim.cmd(string.format([[bwipeout! %s]], prompt_bufnr))
end

actions.set_command_line = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  actions.close(prompt_bufnr)

  vim.cmd(entry.value)
end

-- TODO: Think about how to do this.
actions.insert_value = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  vim.schedule(function()
    actions.close(prompt_bufnr)
  end)

  return entry.value
end

return actions
