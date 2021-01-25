-- Actions functions that are useful for people creating their own mappings.

local a = vim.api

local log = require('telescope.log')
local path = require('telescope.path')
local state = require('telescope.state')

local transform_mod = require('telescope.actions.mt').transform_mod

local actions = setmetatable({}, {
  __index = function(_, k)
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

function actions.add_selection(prompt_bufnr)
  local current_picker = actions.get_current_picker(prompt_bufnr)
  current_picker:add_selection(current_picker:get_selection_row())
end

function actions.remove_selection(prompt_bufnr)
  local current_picker = actions.get_current_picker(prompt_bufnr)
  current_picker:remove_selection(current_picker:get_selection_row())
end

function actions.toggle_selection(prompt_bufnr)
  local current_picker = actions.get_current_picker(prompt_bufnr)
  current_picker:toggle_selection(current_picker:get_selection_row())
end

--- Get the current entry
function actions.get_selected_entry()
  return state.get_global_key('selected_entry')
end

function actions.get_current_line()
  return state.get_global_key('current_line')
end

function actions.preview_scrolling_up(prompt_bufnr)
  actions.get_current_picker(prompt_bufnr).previewer:scroll_fn(-30)
end

function actions.preview_scrolling_down(prompt_bufnr)
  actions.get_current_picker(prompt_bufnr).previewer:scroll_fn(30)
end

-- TODO: It seems sometimes we get bad styling.
function actions._select(prompt_bufnr, command)
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

    actions.close(prompt_bufnr)

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

function actions.center(_)
  vim.cmd(':normal! zz')
end

function actions.select(prompt_bufnr)
  actions._select(prompt_bufnr, "edit")
end

function actions.hselect(prompt_bufnr)
  actions._select(prompt_bufnr, "new")
end

function actions.vselect(prompt_bufnr)
  actions._select(prompt_bufnr, "vnew")
end

function actions.tabselect(prompt_bufnr)
  actions._select(prompt_bufnr, "tabedit")
end

-- aliases
actions._goto_file_selection = actions._select
actions.goto_file_selection_edit = actions.select
actions.goto_file_selection_split = actions.hselect
actions.goto_file_selection_vsplit = actions.vselect
actions.goto_file_selection_tabedit = actions.tabselect

function actions.close_pum(_)
  if 0 ~= vim.fn.pumvisible() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-y>", true, true, true), 'n', true)
  end
end

local do_close = function(prompt_bufnr, keepinsert)
  local picker = actions.get_current_picker(prompt_bufnr)
  local prompt_win = state.get_status(prompt_bufnr).prompt_win
  local original_win_id = picker.original_win_id

  if picker.previewer then
    picker.previewer:teardown()
  end

  actions.close_pum(prompt_bufnr)
  if not keepinsert then
    vim.cmd [[stopinsert]]
  end

  vim.api.nvim_win_close(prompt_win, true)

  pcall(vim.cmd, string.format([[silent bdelete! %s]], prompt_bufnr))
  pcall(a.nvim_set_current_win, original_win_id)
end

function actions.close(prompt_bufnr)
  do_close(prompt_bufnr, false)
end

actions.set_command_line = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  actions.close(prompt_bufnr)
  vim.fn.histadd("cmd", entry.value)
  vim.cmd(entry.value)
end

actions.edit_register = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)
  local picker = actions.get_current_picker(prompt_bufnr)

  vim.fn.inputsave()
  local updated_value = vim.fn.input("Edit [" .. entry.value .. "] ❯ ", entry.content)
  vim.fn.inputrestore()
  if updated_value ~= entry.content then
    vim.fn.setreg(entry.value, updated_value)
    entry.content = updated_value
  end

  -- update entry in results table
  -- TODO: find way to redraw finder content
  for _, v in pairs(picker.finder.results) do
    if v == entry then
      v.content = updated_value
    end
  end
  -- print(vim.inspect(picker.finder.results))
end

actions.paste_register = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  actions.close(prompt_bufnr)

  -- ensure that the buffer can be written to
  if vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "modifiable") then
    print("Paste!")
    -- substitute "^V" for "b"
    local reg_type = vim.fn.getregtype(entry.value)
    if reg_type:byte(1, 1) == 0x16 then
      reg_type = "b" .. reg_type:sub(2, -1)
    end
    vim.api.nvim_put({entry.content}, reg_type, true, true)
  end
end

actions.run_builtin = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  do_close(prompt_bufnr, true)
  require('telescope.builtin')[entry.text]()
end

actions.insert_symbol = function(prompt_bufnr)
  local selection = actions.get_selected_entry()
  actions.close(prompt_bufnr)
  vim.api.nvim_put({selection.value[1]}, '', true, true)
end

-- TODO: Think about how to do this.
actions.insert_value = function(prompt_bufnr)
  local entry = actions.get_selected_entry(prompt_bufnr)

  vim.schedule(function()
    actions.close(prompt_bufnr)
  end)

  return entry.value
end

actions.git_checkout = function(prompt_bufnr)
  local selection = actions.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  local val = selection.value
  os.execute('git checkout ' .. val)
end

actions.git_staging_toggle = function(prompt_bufnr)
  local selection = actions.get_selected_entry(prompt_bufnr)

  -- If parts of the file are staged and unstaged at the same time, stage
  -- changes. Else toggle between staged and unstaged if the file is tracked,
  -- and between added and untracked if the file is untracked.
  if selection.status:sub(2) == ' ' then
    os.execute('git restore --staged ' .. selection.value)
  else
    os.execute('git add ' .. selection.value)
  end
  do_close(prompt_bufnr, true)
  require('telescope.builtin').git_status()
end

local entry_to_qf = function(entry)
  return {
    bufnr = entry.bufnr,
    filename = entry.filename,
    lnum = entry.lnum,
    col = entry.col,
    text = entry.value,
  }
end

actions.send_selected_to_qflist = function(prompt_bufnr)
  local picker = actions.get_current_picker(prompt_bufnr)

  local qf_entries = {}
  for entry in pairs(picker.multi_select) do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  actions.close(prompt_bufnr)

  vim.fn.setqflist(qf_entries, 'r')
  vim.cmd [[copen]]
end

actions.send_to_qflist = function(prompt_bufnr)
  local picker = actions.get_current_picker(prompt_bufnr)
  local manager = picker.manager

  local qf_entries = {}
  for entry in manager:iter() do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  actions.close(prompt_bufnr)

  vim.fn.setqflist(qf_entries, 'r')
  vim.cmd [[copen]]
end

-- ==================================================
-- Transforms modules and sets the corect metatables.
-- ==================================================
actions = transform_mod(actions)
return actions
