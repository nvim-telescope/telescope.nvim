---@tag telescope.actions

-- TODO: Add @module to make it so we can have the prefix.
--@module telescope.actions

---@brief [[
--- Actions functions that are useful for people creating their own mappings.
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
    -- TODO(conni2461): Remove deprecated messages
    if k:find('goto_file_selection') then
      error("`" .. k .. "` is removed and no longer usable. " ..
        "Use `require('telescope.actions').select_` instead. Take a look at developers.md for more Information.")
    elseif k == '_goto_file_selection' then
      error("`_goto_file_selection` is deprecated and no longer replaceable. " ..
        "Use `require('telescope.actions.set').edit` instead. Take a look at developers.md for more Information.")
    end

    error("Key does not exist for 'telescope.actions': " .. tostring(k))
  end
})

-- TODO(conni2461): Remove deprecated messages
local action_is_deprecated = function(name, err)
  local messager = err and error or log.info

  return messager(
    string.format("`actions.%s()` is deprecated."
      .. "Use require('telescope.actions.state').%s() instead",
      name,
      name
    )
  )
end

function actions.get_selected_entry()
  -- TODO(1.0): Remove
  action_is_deprecated("get_selected_entry")
  return action_state.get_selected_entry()
end

function actions.get_current_line()
  -- TODO(1.0): Remove
  action_is_deprecated("get_current_line")
  return action_state.get_current_line()
end

function actions.get_current_picker(prompt_bufnr)
  -- TODO(1.0): Remove
  action_is_deprecated("get_current_picker")
  return action_state.get_current_picker(prompt_bufnr)
end

--- Move the selection to the next entry
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_next(prompt_bufnr)
  action_set.shift_selection(prompt_bufnr, 1)
end

--- Move the selection to the previous entry
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_previous(prompt_bufnr)
  action_set.shift_selection(prompt_bufnr, -1)
end

--- Move the selection to the entry that has a worse score
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_worse(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  action_set.shift_selection(prompt_bufnr, p_scroller.worse(picker.sorting_strategy))
end

--- Move the selection to the entry that has a better score
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_better(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  action_set.shift_selection(prompt_bufnr, p_scroller.better(picker.sorting_strategy))
end

--- Move to the top of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_top(prompt_bufnr)
  local current_picker = actions.get_current_picker(prompt_bufnr)
  current_picker:set_selection(p_scroller.top(current_picker.sorting_strategy,
    current_picker.max_results,
    current_picker.manager:num_results()
  ))
end

--- Move to the middle of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_middle(prompt_bufnr)
  local current_picker = actions.get_current_picker(prompt_bufnr)
  current_picker:set_selection(p_scroller.middle(
    current_picker.sorting_strategy,
    current_picker.max_results,
    current_picker.manager:num_results()
  ))
end

--- Move to the bottom of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_bottom(prompt_bufnr)
  local current_picker = actions.get_current_picker(prompt_bufnr)
  current_picker:set_selection(p_scroller.bottom(current_picker.sorting_strategy,
    current_picker.max_results,
    current_picker.manager:num_results()
  ))
end

--- Add current entry to multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.add_selection(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:add_selection(current_picker:get_selection_row())
end

--- Remove current entry from multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.remove_selection(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:remove_selection(current_picker:get_selection_row())
end

--- Toggle current entry status for multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.toggle_selection(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:toggle_selection(current_picker:get_selection_row())
end

function actions.preview_scrolling_up(prompt_bufnr)
  action_set.scroll_previewer(prompt_bufnr, -1)
end

function actions.preview_scrolling_down(prompt_bufnr)
  action_set.scroll_previewer(prompt_bufnr, 1)
end

function actions.center(_)
  vim.cmd(':normal! zz')
end

function actions.select_default(prompt_bufnr)
  return action_set.select(prompt_bufnr, "default")
end

function actions.select_horizontal(prompt_bufnr)
  return action_set.select(prompt_bufnr, "horizontal")
end

function actions.select_vertical(prompt_bufnr)
  return action_set.select(prompt_bufnr, "vertical")
end

function actions.select_tab(prompt_bufnr)
  return action_set.select(prompt_bufnr, "tab")
end

-- TODO: consider adding float!
-- https://github.com/nvim-telescope/telescope.nvim/issues/365

function actions.file_edit(prompt_bufnr)
  return action_set.edit(prompt_bufnr, "edit")
end

function actions.file_split(prompt_bufnr)
  return action_set.edit(prompt_bufnr, "new")
end

function actions.file_vsplit(prompt_bufnr)
  return action_set.edit(prompt_bufnr, "vnew")
end

function actions.file_tab(prompt_bufnr)
  return action_set.edit(prompt_bufnr, "tabedit")
end

function actions.close_pum(_)
  if 0 ~= vim.fn.pumvisible() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-y>", true, true, true), 'n', true)
  end
end

actions._close = function(prompt_bufnr, keepinsert)
  local picker = action_state.get_current_picker(prompt_bufnr)
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
  actions._close(prompt_bufnr, false)
end

actions.edit_command_line = function(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes(":" .. entry.value , true, false, true), "t", true)
end

actions.set_command_line = function(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)

  actions.close(prompt_bufnr)
  vim.fn.histadd("cmd", entry.value)
  vim.cmd(entry.value)
end

actions.edit_search_line = function(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. entry.value , true, false, true), "t", true)
end

actions.set_search_line = function(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)

  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. entry.value .. "<CR>", true, false, true), "t", true)
end

actions.edit_register = function(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)

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
  local entry = action_state.get_selected_entry(prompt_bufnr)

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
  local entry = action_state.get_selected_entry(prompt_bufnr)

actions._close(prompt_bufnr, true)
  require('telescope.builtin')[entry.text]()
end

actions.insert_symbol = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  vim.api.nvim_put({selection.value[1]}, '', true, true)
end

-- TODO: Think about how to do this.
actions.insert_value = function(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)

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

--- Applies an existing git stash
---@param prompt_bufnr number: The prompt bufnr
actions.git_apply_stash = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'stash', 'apply', '--index', selection.value })
  if ret == 0 then
    print("applied: " .. selection.value)
  else
    print(string.format(
      'Error when applying: %s. Git returned: "%s"',
      selection.value,
      table.concat(stderr, '  ')
    ))
  end
end

--- Checkout an existing git branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_checkout = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
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

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Switch to git branch
-- If the branch already exists in local, switch to that.
-- If the branch is only in remote, create new branch tracking remote and switch to new one.
--@param prompt_bufnr number: The prompt bufnr
actions.git_switch_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  local pattern = '^refs/remotes/%w+/'
  local branch = selection.value
  if string.match(selection.refname, pattern) then
    branch = string.gsub(selection.refname, pattern, '')
  end
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'switch', branch }, cwd)
  if ret == 0 then
    print("Switched to: " .. branch)
  else
    print(string.format(
      'Error when switching to: %s. Git returned: "%s"',
      selection.value,
      table.concat(stderr, '  ')
    ))
  end
end

--- Tell git to track the currently selected remote branch in Telescope
---@param prompt_bufnr number: The prompt bufnr
actions.git_track_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'checkout', '--track', selection.value }, cwd)
  if ret == 0 then
    print("Tracking branch: " .. selection.value)
  else
    print(string.format(
      'Error when tracking branch: %s. Git returned: "%s"',
      selection.value,
      table.concat(stderr, '  ')
    ))
  end
end

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Delete the currently selected branch
-- @param prompt_bufnr number: The prompt bufnr
actions.git_delete_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()

  local confirmation = vim.fn.input('Do you really wanna delete branch ' .. selection.value .. '? [Y/n] ')
  if confirmation ~= '' and string.lower(confirmation) ~= 'y' then return end

  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'branch', '-D', selection.value }, cwd)
  if ret == 0 then
    print("Deleted branch: " .. selection.value)
  else
    print(string.format(
      'Error when deleting branch: %s. Git returned: "%s"',
      selection.value,
      table.concat(stderr, '  ')
    ))
  end
end

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Rebase to selected git branch
-- @param prompt_bufnr number: The prompt bufnr
actions.git_rebase_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()

  local confirmation = vim.fn.input('Do you really wanna rebase branch ' .. selection.value .. '? [Y/n] ')
  if confirmation ~= '' and string.lower(confirmation) ~= 'y' then return end

  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ 'git', 'rebase', selection.value }, cwd)
  if ret == 0 then
    print("Rebased branch: " .. selection.value)
  else
    print(string.format(
      'Error when rebasing branch: %s. Git returned: "%s"',
      selection.value,
      table.concat(stderr, '  ')
    ))
  end
end

-- TODO: add this function header back once the treesitter max-query bug is resolved
-- Stage/unstage selected file
-- @param prompt_bufnr number: The prompt bufnr
actions.git_staging_toggle = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()

  if selection.status:sub(2) == ' ' then
    utils.get_os_command_output({ 'git', 'restore', '--staged', selection.value }, cwd)
  else
    utils.get_os_command_output({ 'git', 'add', selection.value }, cwd)
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
  local picker = action_state.get_current_picker(prompt_bufnr)
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

actions.complete_tag = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
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
