---@tag telescope.actions

-- TODO: Add @module to make it so we can have the prefix.
--@module telescope.actions

---@brief [[
--- Actions functions that are useful for people creating their own mappings.
---
--- All actions follow the same signature:
---     function(prompt_bufnr, entry)
---
---         prompt_bufnr: The bufnr for the prompt
---         entry: The entry to perform the action on.
---
---
---@brief ]]

local a = vim.api

local log = require('telescope.log')
local state = require('telescope.state')
local utils = require('telescope.utils')
local p_scroller = require('telescope.pickers.scroller')

local action_state = require('telescope.actions.state')
local action_set = require('telescope.actions.set')

local transform_mod = require('telescope.actions.mt').transform_mod

local actions = setmetatable({}, {
  __index = function(_, k)
    error("Key does not exist for 'telescope.actions': " .. tostring(k))
  end
})

--- Move the selection to the next entry
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_next(prompt_bufnr, entry)
  action_set.shift_selection(prompt_bufnr, entry, 1)
end

--- Move the selection to the previous entry
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_previous(prompt_bufnr, entry)
  action_set.shift_selection(prompt_bufnr, entry, -1)
end

--- Move the selection to the entry that has a worse score
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_worse(prompt_bufnr, entry)
  local picker = action_state.get_current_picker()
  action_set.shift_selection(prompt_bufnr, entry, p_scroller.worse(picker.sorting_strategy))
end

--- Move the selection to the entry that has a better score
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_better(prompt_bufnr, entry)
  local picker = action_state.get_current_picker()
  action_set.shift_selection(prompt_bufnr, entry, p_scroller.better(picker.sorting_strategy))
end

--- Move to the top of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_top(prompt_bufnr)
  local picker = action_state.get_current_picker()
  picker:set_selection(p_scroller.top(picker.sorting_strategy,
    picker.max_results,
    picker.manager:num_results()
  ))
end

--- Move to the middle of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_middle(prompt_bufnr)
  local current_picker = action_state.get_current_picker()
  current_picker:set_selection(p_scroller.middle(
    current_picker.sorting_strategy,
    current_picker.max_results,
    current_picker.manager:num_results()
  ))
end

--- Move to the bottom of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_bottom(prompt_bufnr)
  local current_picker = action_state.get_current_picker()
  current_picker:set_selection(p_scroller.bottom(current_picker.sorting_strategy,
    current_picker.max_results,
    current_picker.manager:num_results()
  ))
end

--- Add current entry to multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.add_selection(prompt_bufnr)
  local current_picker = action_state.get_current_picker()
  current_picker:add_selection(current_picker:get_selection_row())
end

--- Remove current entry from multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.remove_selection(prompt_bufnr)
  local current_picker = action_state.get_current_picker()
  current_picker:remove_selection(current_picker:get_selection_row())
end

--- Toggle current entry status for multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.toggle_selection(prompt_bufnr)
  local current_picker = action_state.get_current_picker()
  current_picker:toggle_selection(current_picker:get_selection_row())
end

function actions.preview_scrolling_up(prompt_bufnr, entry)
  action_set.scroll_previewer(prompt_bufnr, entry, -1)
end

function actions.preview_scrolling_down(prompt_bufnr, entry)
  action_set.scroll_previewer(prompt_bufnr, entry, 1)
end

function actions.center(_)
  vim.cmd(':normal! zz')
end

--- THIS DOESNT ACTUALLY EXIST YET
function actions.select_multi_default(prompt_bufnr)
  local picker = action_state.get_current_picker()
  local manager = picker.manager

  for entry in manager:iter() do
    action_set.select(prompt_bufnr, entry)
  end

  actions.close(prompt_bufnr)
end

function actions.select_default(prompt_bufnr, entry)
  return action_set.select(prompt_bufnr, entry, "default")
end

function actions.select_horizontal(prompt_bufnr, entry)
  return action_set.select(prompt_bufnr, entry, "horizontal")
end

function actions.select_vertical(prompt_bufnr, entry)
  return action_set.select(prompt_bufnr, entry, "vertical")
end

function actions.select_tab(prompt_bufnr, entry)
  return action_set.select(prompt_bufnr, entry, "tab")
end

-- TODO: consider adding float!
-- https://github.com/nvim-telescope/telescope.nvim/issues/365

function actions.file_edit(prompt_bufnr, entry)
  return action_set.edit(prompt_bufnr, entry, "edit")
end

function actions.file_split(prompt_bufnr, entry)
  return action_set.edit(prompt_bufnr, entry, "new")
end

function actions.file_vsplit(prompt_bufnr, entry)
  return action_set.edit(prompt_bufnr, entry, "vnew")
end

function actions.file_tab(prompt_bufnr, entry)
  return action_set.edit(prompt_bufnr, entry, "tabedit")
end

function actions.close_pum(_)
  if 0 ~= vim.fn.pumvisible() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-y>", true, true, true), 'n', true)
  end
end

actions._close = function(prompt_bufnr, keepinsert)
  local picker = action_state.get_current_picker()
  local prompt_win = state.get_status(prompt_bufnr).prompt_win
  local original_win_id = picker.original_win_id

  -- TODO: I don't think I want this here, because it will get cleared
  -- when we do a NEW picker.
  -- picker:teardown()

  actions.close_pum(prompt_bufnr)
  if not keepinsert then
    vim.cmd [[stopinsert]]
  end

  if prompt_win and a.nvim_win_is_valid(prompt_win) then
    vim.api.nvim_win_close(prompt_win, true)
    pcall(a.nvim_set_current_win, original_win_id)
  end

  if prompt_bufnr and a.nvim_buf_is_valid(prompt_bufnr) then
    pcall(a.nvim_buf_delete, prompt_bufnr, { force = true })
  end
end

function actions.close(prompt_bufnr)
  actions._close(prompt_bufnr, false)
end

actions.edit_command_line = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes(":" .. entry.value , true, false, true), "t", true)
end

actions.set_command_line = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  actions.close(prompt_bufnr)
  vim.fn.histadd("cmd", entry.value)
  vim.cmd(entry.value)
end

actions.edit_search_line = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. entry.value , true, false, true), "t", true)
end

actions.set_search_line = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. entry.value .. "<CR>", true, false, true), "t", true)
end

actions.edit_register = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()
  local picker = action_state.get_current_picker()

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

actions.paste_register = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

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

actions.run_builtin = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  actions._close(prompt_bufnr, true)
  require('telescope.builtin')[entry.text]()
end

actions.insert_symbol = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  vim.api.nvim_put({selection.value[1]}, '', true, true)
end

-- TODO: Think about how to do this.
actions.insert_value = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  vim.schedule(function()
    actions.close(prompt_bufnr)
  end)

  return entry.value
end

--- Create and checkout a new git branch if it doesn't already exist
---@param prompt_bufnr number: The prompt bufnr
actions.git_create_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local new_branch = action_state.get_current_line()

  if new_branch == "" then
    print('Please enter the name of the new branch to create')
  else
    local confirmation = vim.fn.input(string.format('Create new branch "%s"? [y/n]: ', new_branch))
    if string.len(confirmation) == 0 or string.sub(string.lower(confirmation), 0, 1) ~= 'y' then
      print(string.format('Didn\'t create branch "%s"', new_branch))
      return
    end

    actions.close(prompt_bufnr)

    local _, ret, stderr = utils.get_os_command_output({ 'git', 'checkout', '-b', new_branch }, cwd)
    if ret == 0 then
      print(string.format('Switched to a new branch: %s', new_branch))
    else
      print(string.format(
        'Error when creating new branch: %s Git returned "%s"',
        new_branch,
        table.concat(stderr, '  ')
      ))
    end
  end
end

--- Checkout an existing git branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_checkout = function(prompt_bufnr, selection)
  selection = selection or action_state.get_selected_entry()

  local cwd = action_state.get_current_picker().cwd
  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'checkout', selection.value }, cwd)
  if ret == 0 then
    print("Checked out: " .. selection.value)
  else
    print(string.format(
      'Error when checking out: %s. Git returned: "%s"',
      selection.value,
      table.concat(stderr, '  ')
    ))
  end
end

--- Tell git to track the currently selected remote branch in Telescope
---@param prompt_bufnr number: The prompt bufnr
actions.git_track_branch = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  local cwd = action_state.get_current_picker().cwd
  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'checkout', '--track', entry.value }, cwd)
  if ret == 0 then
    print("Tracking branch: " .. entry.value)
  else
    print(string.format(
      'Error when tracking branch: %s. Git returned: "%s"',
      entry.value,
      table.concat(stderr, '  ')
    ))
  end
end

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Delete the currently selected branch
-- @param prompt_bufnr number: The prompt bufnr
actions.git_delete_branch = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  local cwd = action_state.get_current_picker().cwd

  local confirmation = vim.fn.input('Do you really wanna delete branch ' .. entry.value .. '? [Y/n] ')
  if confirmation ~= '' and string.lower(confirmation) ~= 'y' then return end

  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'branch', '-D', entry.value }, cwd)
  if ret == 0 then
    print("Deleted branch: " .. entry.value)
  else
    print(string.format(
      'Error when deleting branch: %s. Git returned: "%s"',
      entry.value,
      table.concat(stderr, '  ')
    ))
  end
end

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Rebase to selected git branch
-- @param prompt_bufnr number: The prompt bufnr
actions.git_rebase_branch = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  local cwd = action_state.get_current_picker().cwd

  local confirmation = vim.fn.input('Do you really wanna rebase branch ' .. entry.value .. '? [Y/n] ')
  if confirmation ~= '' and string.lower(confirmation) ~= 'y' then return end

  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'rebase', entry.value }, cwd)
  if ret == 0 then
    print("Rebased branch: " .. entry.value)
  else
    print(string.format(
      'Error when rebasing branch: %s. Git returned: "%s"',
      entry.value,
      table.concat(stderr, '  ')
    ))
  end
end

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Stage/unstage selected file
-- @param prompt_bufnr number: The prompt bufnr
actions.git_staging_toggle = function(prompt_bufnr, entry)
  entry = entry or action_state.get_selected_entry()

  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  if entry.status:sub(2) == ' ' then
    utils.get_os_command_output({ 'git', 'restore', '--staged', entry.value }, cwd)
  else
    utils.get_os_command_output({ 'git', 'add', entry.value }, cwd)
  end
end

local entry_to_qf = function(entry)
  return {
    bufnr = entry.bufnr,
    filename = entry.filename,
    lnum = entry.lnum,
    col = entry.col,
    text = entry.text or entry.value.text or entry.value,
  }
end

local send_selected_to_qf = function(prompt_bufnr, mode)
  local picker = action_state.get_current_picker(prompt_bufnr)

  local qf_entries = {}
  for _, entry in ipairs(picker:get_multi_selection()) do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  actions.close(prompt_bufnr)

  vim.fn.setqflist(qf_entries, mode)
end

local send_all_to_qf = function(prompt_bufnr, mode)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local manager = picker.manager

  local qf_entries = {}
  for entry in manager:iter() do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  actions.close(prompt_bufnr)

  vim.fn.setqflist(qf_entries, mode)
end

--- TODO: These would be good candidates for thinking about how to add them
--- one at a time OR with the list of items.
---
--- Very cool
actions.send_selected_to_qflist = function(prompt_bufnr)
  send_selected_to_qf(prompt_bufnr, 'r')
end

actions.add_selected_to_qflist = function(prompt_bufnr)
  send_selected_to_qf(prompt_bufnr, 'a')
end

actions.send_to_qflist = function(prompt_bufnr)
  send_all_to_qf(prompt_bufnr, 'r')
end

actions.add_to_qflist = function(prompt_bufnr)
  send_all_to_qf(prompt_bufnr, 'a')
end

local smart_send = function(prompt_bufnr, mode)
  local picker = action_state.get_current_picker()
  if table.getn(picker:get_multi_selection()) > 0 then
    send_selected_to_qf(prompt_bufnr, mode)
  else
    send_all_to_qf(prompt_bufnr, mode)
  end
end

actions.smart_send_to_qflist = function(prompt_bufnr)
  smart_send(prompt_bufnr, 'r')
end

actions.smart_add_to_qflist = function(prompt_bufnr)
  smart_send(prompt_bufnr, 'a')
end

actions.complete_tag = function()
  local current_picker = action_state.get_current_picker()
  local tags = current_picker.sorter.tags
  local delimiter = current_picker.sorter._delimiter

  if not tags then
    print('No tag pre-filtering set for this picker')
    return
  end

  -- format tags to match filter_function
  local prefilter_tags = {}
  for tag, _ in pairs(tags) do
    table.insert(prefilter_tags, string.format('%s%s%s ', delimiter, tag:lower(), delimiter))
  end

  local line = action_state.get_current_line()
  local filtered_tags = {}
  -- retrigger completion with already selected tag anew
  -- trim and add space since we can match [[:pattern: ]]  with or without space at the end
  if vim.tbl_contains(prefilter_tags, vim.trim(line) .. " ") then
    filtered_tags = prefilter_tags
  else
    -- match tag by substring
    for _, tag in pairs(prefilter_tags) do
      local start, _ = tag:find(line)
      if start then
        table.insert(filtered_tags, tag)
      end
    end
  end

  if vim.tbl_isempty(filtered_tags) then
    print('No matches found')
    return
  end

  -- incremental completion by substituting string starting from col - #line byte offset
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  vim.fn.complete(col - #line, filtered_tags)

end

--- Open the quickfix list
actions.open_qflist = function(_)
  vim.cmd [[copen]]
end

-- ==================================================
-- Transforms modules and sets the corect metatables.
-- ==================================================
actions = transform_mod(actions)
return actions
