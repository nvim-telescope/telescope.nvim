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

function actions.goto_file_selection(prompt_bufnr)
  local picker = actions.get_current_picker(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  if not entry then
    print("[telescope] Nothing currently selected")
    return
  else
    local value = entry.value
    if not value then
      print("Could not do anything with blank line...")
      return
    end

    -- TODO: This is not great.
    if type(value) == "table" then
      value = entry.display
    end

    local sections = vim.split(value, ":")

    local filename = sections[1]
    local row = tonumber(sections[2])
    local col = tonumber(sections[3])

    vim.cmd(string.format([[bwipeout! %s]], prompt_bufnr))

    a.nvim_set_current_win(picker.original_win_id or 0)
    vim.cmd(string.format(":e %s", filename))

    local bufnr = vim.api.nvim_get_current_buf()
    a.nvim_buf_set_option(bufnr, 'buflisted', true)
    if row and col then
      a.nvim_win_set_cursor(0, {row, col})
    end

    vim.cmd [[stopinsert]]
  end
end

actions.close = function(prompt_bufnr)
  vim.cmd(string.format([[bwipeout! %s]], prompt_bufnr))
end


return actions
