---@tag telescope.actions

-- TODO: Add @module to make it so we can have the prefix.
--@module telescope.actions

---@brief [[
--- Actions functions that are useful for people creating their own mappings.
---@brief ]]

local a = vim.api

local config = require "telescope.config"
local state = require "telescope.state"
local utils = require "telescope.utils"
local popup = require "plenary.popup"
local p_scroller = require "telescope.pickers.scroller"

local action_state = require "telescope.actions.state"
local action_utils = require "telescope.actions.utils"
local action_set = require "telescope.actions.set"
local entry_display = require "telescope.pickers.entry_display"
local from_entry = require "telescope.from_entry"

local transform_mod = require("telescope.actions.mt").transform_mod
local resolver = require "telescope.config.resolve"

local actions = setmetatable({}, {
  __index = function(_, k)
    error("Key does not exist for 'telescope.actions': " .. tostring(k))
  end,
})

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
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:set_selection(
    p_scroller.top(current_picker.sorting_strategy, current_picker.max_results, current_picker.manager:num_results())
  )
end

--- Move to the middle of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_middle(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:set_selection(
    p_scroller.middle(current_picker.sorting_strategy, current_picker.max_results, current_picker.manager:num_results())
  )
end

--- Move to the bottom of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_bottom(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:set_selection(
    p_scroller.bottom(current_picker.sorting_strategy, current_picker.max_results, current_picker.manager:num_results())
  )
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

--- Multi select all entries.
--- - Note: selected entries may include results not visible in the results popup.
---@param prompt_bufnr number: The prompt bufnr
function actions.select_all(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  action_utils.map_entries(prompt_bufnr, function(entry, _, row)
    if not current_picker._multi:is_selected(entry) then
      current_picker._multi:add(entry)
      if current_picker:can_select_row(row) then
        current_picker.highlighter:hi_multiselect(row, current_picker._multi:is_selected(entry))
      end
    end
  end)
end

--- Drop all entries from the current multi selection.
---@param prompt_bufnr number: The prompt bufnr
function actions.drop_all(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  action_utils.map_entries(prompt_bufnr, function(entry, _, row)
    current_picker._multi:drop(entry)
    if current_picker:can_select_row(row) then
      current_picker.highlighter:hi_multiselect(row, current_picker._multi:is_selected(entry))
    end
  end)
end

--- Toggle multi selection for all entries.
--- - Note: toggled entries may include results not visible in the results popup.
---@param prompt_bufnr number: The prompt bufnr
function actions.toggle_all(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  action_utils.map_entries(prompt_bufnr, function(entry, _, row)
    current_picker._multi:toggle(entry)
    if current_picker:can_select_row(row) then
      current_picker.highlighter:hi_multiselect(row, current_picker._multi:is_selected(entry))
    end
  end)
end

function actions.preview_scrolling_up(prompt_bufnr)
  action_set.scroll_previewer(prompt_bufnr, -1)
end

function actions.preview_scrolling_down(prompt_bufnr)
  action_set.scroll_previewer(prompt_bufnr, 1)
end

function actions.results_scrolling_up(prompt_bufnr)
  action_set.scroll_results(prompt_bufnr, -1)
end

function actions.results_scrolling_down(prompt_bufnr)
  action_set.scroll_results(prompt_bufnr, 1)
end

function actions.center(_)
  vim.cmd ":normal! zz"
end

actions.select_default = {
  pre = function(prompt_bufnr)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr)
    )
  end,
  action = function(prompt_bufnr)
    return action_set.select(prompt_bufnr, "default")
  end,
}

actions.select_horizontal = {
  pre = function(prompt_bufnr)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr)
    )
  end,
  action = function(prompt_bufnr)
    return action_set.select(prompt_bufnr, "horizontal")
  end,
}

actions.select_vertical = {
  pre = function(prompt_bufnr)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr)
    )
  end,
  action = function(prompt_bufnr)
    return action_set.select(prompt_bufnr, "vertical")
  end,
}

actions.select_tab = {
  pre = function(prompt_bufnr)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr)
    )
  end,
  action = function(prompt_bufnr)
    return action_set.select(prompt_bufnr, "tab")
  end,
}

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
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-y>", true, true, true), "n", true)
  end
end

actions._close = function(prompt_bufnr, keepinsert)
  action_state.get_current_history():reset()
  local picker = action_state.get_current_picker(prompt_bufnr)
  local prompt_win = state.get_status(prompt_bufnr).prompt_win
  local original_win_id = picker.original_win_id

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
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes(":" .. selection.value, true, false, true), "t", true)
end

actions.set_command_line = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  vim.fn.histadd("cmd", selection.value)
  vim.cmd(selection.value)
end

actions.edit_search_line = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. selection.value, true, false, true), "t", true)
end

actions.set_search_line = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. selection.value .. "<CR>", true, false, true), "t", true)
end

actions.edit_register = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  local picker = action_state.get_current_picker(prompt_bufnr)

  vim.fn.inputsave()
  local updated_value = vim.fn.input("Edit [" .. selection.value .. "] ❯ ", selection.content)
  vim.fn.inputrestore()
  if updated_value ~= selection.content then
    vim.fn.setreg(selection.value, updated_value)
    selection.content = updated_value
  end

  -- update entry in results table
  -- TODO: find way to redraw finder content
  for _, v in pairs(picker.finder.results) do
    if v == selection then
      v.content = updated_value
    end
  end
  -- print(vim.inspect(picker.finder.results))
end

actions.paste_register = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end

  actions.close(prompt_bufnr)

  -- ensure that the buffer can be written to
  if vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "modifiable") then
    print "Paste!"
    vim.api.nvim_paste(selection.content, true, -1)
  end
end

actions.insert_symbol = function(prompt_bufnr)
  local symbol = action_state.get_selected_entry().value[1]
  actions.close(prompt_bufnr)
  vim.api.nvim_put({ symbol }, "", true, true)
end

actions.insert_symbol_i = function(prompt_bufnr)
  local symbol = action_state.get_selected_entry().value[1]
  actions._close(prompt_bufnr, true)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_text(0, cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2], { symbol })
  vim.schedule(function()
    vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + #symbol })
    vim.cmd [[startinsert!]]
  end)
end

-- TODO: Think about how to do this.
actions.insert_value = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end

  vim.schedule(function()
    actions.close(prompt_bufnr)
  end)

  return selection.value
end

--- Create and checkout a new git branch if it doesn't already exist
---@param prompt_bufnr number: The prompt bufnr
actions.git_create_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local new_branch = action_state.get_current_line()

  if new_branch == "" then
    print "Please enter the name of the new branch to create"
  else
    local confirmation = vim.fn.input(string.format('Create new branch "%s"? [y/n]: ', new_branch))
    if string.len(confirmation) == 0 or string.sub(string.lower(confirmation), 0, 1) ~= "y" then
      print(string.format('Didn\'t create branch "%s"', new_branch))
      return
    end

    actions.close(prompt_bufnr)

    local _, ret, stderr = utils.get_os_command_output({ "git", "checkout", "-b", new_branch }, cwd)
    if ret == 0 then
      print(string.format("Switched to a new branch: %s", new_branch))
    else
      print(
        string.format('Error when creating new branch: %s Git returned "%s"', new_branch, table.concat(stderr, "  "))
      )
    end
  end
end

--- Applies an existing git stash
---@param prompt_bufnr number: The prompt bufnr
actions.git_apply_stash = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output { "git", "stash", "apply", "--index", selection.value }
  if ret == 0 then
    print("applied: " .. selection.value)
  else
    print(string.format('Error when applying: %s. Git returned: "%s"', selection.value, table.concat(stderr, "  ")))
  end
end

--- Checkout an existing git branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_checkout = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ "git", "checkout", selection.value }, cwd)
  if ret == 0 then
    print("Checked out: " .. selection.value)
  else
    print(string.format('Error when checking out: %s. Git returned: "%s"', selection.value, table.concat(stderr, "  ")))
  end
end

--- Switch to git branch.<br>
--- If the branch already exists in local, switch to that.
--- If the branch is only in remote, create new branch tracking remote and switch to new one.
---@param prompt_bufnr number: The prompt bufnr
actions.git_switch_branch = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  local pattern = "^refs/remotes/%w+/"
  local branch = selection.value
  if string.match(selection.refname, pattern) then
    branch = string.gsub(selection.refname, pattern, "")
  end
  local _, ret, stderr = utils.get_os_command_output({ "git", "switch", branch }, cwd)
  if ret == 0 then
    print("Switched to: " .. branch)
  else
    print(string.format('Error when switching to: %s. Git returned: "%s"', selection.value, table.concat(stderr, "  ")))
  end
end

local function make_git_branch_action(opts)
  return function(prompt_bufnr)
    local cwd = action_state.get_current_picker(prompt_bufnr).cwd
    local selection = action_state.get_selected_entry()
    if selection == nil then
      print "[telescope] Nothing currently selected"
      return
    end

    local should_confirm = opts.should_confirm
    if should_confirm then
      local confirmation = vim.fn.input(string.format(opts.confirmation_question, selection.value))
      if confirmation ~= "" and string.lower(confirmation) ~= "y" then
        return
      end
    end

    actions.close(prompt_bufnr)
    local _, ret, stderr = utils.get_os_command_output(opts.command(selection.value), cwd)
    if ret == 0 then
      print(string.format(opts.success_message, selection.value))
    else
      print(string.format(opts.error_message, selection.value, table.concat(stderr, "  ")))
    end
  end
end

--- Tell git to track the currently selected remote branch in Telescope
---@param prompt_bufnr number: The prompt bufnr
actions.git_track_branch = make_git_branch_action {
  should_confirm = false,
  success_message = "Tracking branch: %s",
  error_message = 'Error when tracking branch: %s. Git returned: "%s"',
  command = function(branch_name)
    return { "git", "checkout", "--track", branch_name }
  end,
}

--- Delete the currently selected branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_delete_branch = make_git_branch_action {
  should_confirm = true,
  confirmation_question = "Do you really wanna delete branch %s? [Y/n] ",
  success_message = "Deleted branch: %s",
  error_message = 'Error when deleting branch: %s. Git returned: "%s"',
  command = function(branch_name)
    return { "git", "branch", "-D", branch_name }
  end,
}

--- Merge the currently selected branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_merge_branch = make_git_branch_action {
  should_confirm = true,
  confirmation_question = "Do you really wanna merge branch %s? [Y/n] ",
  success_message = "Merged branch: %s",
  error_message = 'Error when merging branch: %s. Git returned: "%s"',
  command = function(branch_name)
    return { "git", "merge", branch_name }
  end,
}

--- Rebase to selected git branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_rebase_branch = make_git_branch_action {
  should_confirm = true,
  confirmation_question = "Do you really wanna rebase branch %s? [Y/n] ",
  success_message = "Rebased branch: %s",
  error_message = 'Error when rebasing branch: %s. Git returned: "%s"',
  command = function(branch_name)
    return { "git", "rebase", branch_name }
  end,
}

local git_reset_branch = function(prompt_bufnr, mode)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end

  local confirmation = vim.fn.input("Do you really wanna " .. mode .. " reset to " .. selection.value .. "? [Y/n] ")
  if confirmation ~= "" and string.lower(confirmation) ~= "y" then
    return
  end

  actions.close(prompt_bufnr)
  local _, ret, stderr = utils.get_os_command_output({ "git", "reset", mode, selection.value }, cwd)
  if ret == 0 then
    print("Reset to: " .. selection.value)
  else
    print(string.format('Error when resetting to: %s. Git returned: "%s"', selection.value, table.concat(stderr, "  ")))
  end
end

--- Reset to selected git commit using mixed mode
---@param prompt_bufnr number: The prompt bufnr
actions.git_reset_mixed = function(prompt_bufnr)
  git_reset_branch(prompt_bufnr, "--mixed")
end

--- Reset to selected git commit using soft mode
---@param prompt_bufnr number: The prompt bufnr
actions.git_reset_soft = function(prompt_bufnr)
  git_reset_branch(prompt_bufnr, "--soft")
end

--- Reset to selected git commit using hard mode
---@param prompt_bufnr number: The prompt bufnr
actions.git_reset_hard = function(prompt_bufnr)
  git_reset_branch(prompt_bufnr, "--hard")
end

actions.git_checkout_current_buffer = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  actions.close(prompt_bufnr)
  utils.get_os_command_output({ "git", "checkout", selection.value, "--", selection.file }, cwd)
end

--- Stage/unstage selected file
---@param prompt_bufnr number: The prompt bufnr
actions.git_staging_toggle = function(prompt_bufnr)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local selection = action_state.get_selected_entry()
  if selection == nil then
    print "[telescope] Nothing currently selected"
    return
  end
  if selection.status:sub(2) == " " then
    utils.get_os_command_output({ "git", "restore", "--staged", selection.value }, cwd)
  else
    utils.get_os_command_output({ "git", "add", selection.value }, cwd)
  end
end

local entry_to_qf = function(entry)
  local text = entry.text

  if not text then
    if type(entry.value) == "table" then
      text = entry.value.text
    else
      text = entry.value
    end
  end

  return {
    bufnr = entry.bufnr,
    filename = from_entry.path(entry, false),
    lnum = vim.F.if_nil(entry.lnum, 1),
    col = vim.F.if_nil(entry.col, 1),
    text = text,
  }
end

local send_selected_to_qf = function(prompt_bufnr, mode, target)
  local picker = action_state.get_current_picker(prompt_bufnr)

  local qf_entries = {}
  for _, entry in ipairs(picker:get_multi_selection()) do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  actions.close(prompt_bufnr)

  if target == "loclist" then
    vim.fn.setloclist(picker.original_win_id, qf_entries, mode)
  else
    vim.fn.setqflist(qf_entries, mode)
  end
end

local send_all_to_qf = function(prompt_bufnr, mode, target)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local manager = picker.manager

  local qf_entries = {}
  for entry in manager:iter() do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  actions.close(prompt_bufnr)

  if target == "loclist" then
    vim.fn.setloclist(picker.original_win_id, qf_entries, mode)
  else
    vim.fn.setqflist(qf_entries, mode)
  end
end

--- Sends the selected entries to the quickfix list, replacing the previous entries.
actions.send_selected_to_qflist = function(prompt_bufnr)
  send_selected_to_qf(prompt_bufnr, "r")
end

--- Adds the selected entries to the quickfix list, keeping the previous entries.
actions.add_selected_to_qflist = function(prompt_bufnr)
  send_selected_to_qf(prompt_bufnr, "a")
end

--- Sends all entries to the quickfix list, replacing the previous entries.
actions.send_to_qflist = function(prompt_bufnr)
  send_all_to_qf(prompt_bufnr, "r")
end

--- Adds all entries to the quickfix list, keeping the previous entries.
actions.add_to_qflist = function(prompt_bufnr)
  send_all_to_qf(prompt_bufnr, "a")
end

--- Sends the selected entries to the location list, replacing the previous entries.
actions.send_selected_to_loclist = function(prompt_bufnr)
  send_selected_to_qf(prompt_bufnr, "r", "loclist")
end

--- Adds the selected entries to the location list, keeping the previous entries.
actions.add_selected_to_loclist = function(prompt_bufnr)
  send_selected_to_qf(prompt_bufnr, "a", "loclist")
end

--- Sends all entries to the location list, replacing the previous entries.
actions.send_to_loclist = function(prompt_bufnr)
  send_all_to_qf(prompt_bufnr, "r", "loclist")
end

--- Adds all entries to the location list, keeping the previous entries.
actions.add_to_loclist = function(prompt_bufnr)
  send_all_to_qf(prompt_bufnr, "a", "loclist")
end

local smart_send = function(prompt_bufnr, mode, target)
  local picker = action_state.get_current_picker(prompt_bufnr)
  if table.getn(picker:get_multi_selection()) > 0 then
    send_selected_to_qf(prompt_bufnr, mode, target)
  else
    send_all_to_qf(prompt_bufnr, mode, target)
  end
end

--- Sends the selected entries to the quickfix list, replacing the previous entries.
--- If no entry was selected, sends all entries.
actions.smart_send_to_qflist = function(prompt_bufnr)
  smart_send(prompt_bufnr, "r")
end

--- Adds the selected entries to the quickfix list, keeping the previous entries.
--- If no entry was selected, adds all entries.
actions.smart_add_to_qflist = function(prompt_bufnr)
  smart_send(prompt_bufnr, "a")
end

--- Sends the selected entries to the location list, replacing the previous entries.
--- If no entry was selected, sends all entries.
actions.smart_send_to_loclist = function(prompt_bufnr)
  smart_send(prompt_bufnr, "r", "loclist")
end

--- Adds the selected entries to the location list, keeping the previous entries.
--- If no entry was selected, adds all entries.
actions.smart_add_to_loclist = function(prompt_bufnr)
  smart_send(prompt_bufnr, "a", "loclist")
end

actions.complete_tag = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local tags = current_picker.sorter.tags
  local delimiter = current_picker.sorter._delimiter

  if not tags then
    print "No tag pre-filtering set for this picker"
    return
  end

  -- format tags to match filter_function
  local prefilter_tags = {}
  for tag, _ in pairs(tags) do
    table.insert(prefilter_tags, string.format("%s%s%s ", delimiter, tag:lower(), delimiter))
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
    print "No matches found"
    return
  end

  -- incremental completion by substituting string starting from col - #line byte offset
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  vim.fn.complete(col - #line, filtered_tags)
end

actions.cycle_history_next = function(prompt_bufnr)
  local history = action_state.get_current_history()
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local line = action_state.get_current_line()

  local entry = history:get_next(line, current_picker)
  if entry == false then
    return
  end

  current_picker:reset_prompt()
  if entry ~= nil then
    current_picker:set_prompt(entry)
  end
end

actions.cycle_history_prev = function(prompt_bufnr)
  local history = action_state.get_current_history()
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local line = action_state.get_current_line()

  local entry = history:get_prev(line, current_picker)
  if entry == false then
    return
  end
  if entry ~= nil then
    current_picker:reset_prompt()
    current_picker:set_prompt(entry)
  end
end

--- Open the quickfix list
actions.open_qflist = function(_)
  vim.cmd [[copen]]
end

--- Open the location list
actions.open_loclist = function(_)
  vim.cmd [[lopen]]
end

--- Delete the selected buffer or all the buffers selected using multi selection.
---@param prompt_bufnr number: The prompt bufnr
actions.delete_buffer = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    vim.api.nvim_buf_delete(selection.bufnr, { force = false })
  end)
end

--- Cycle to the next previewer if there is one available.<br>
--- This action is not mapped on default.
---@param prompt_bufnr number: The prompt bufnr
actions.cycle_previewers_next = function(prompt_bufnr)
  action_state.get_current_picker(prompt_bufnr):cycle_previewers(1)
end

--- Cycle to the previous previewer if there is one available.<br>
--- This action is not mapped on default.
---@param prompt_bufnr number: The prompt bufnr
actions.cycle_previewers_prev = function(prompt_bufnr)
  action_state.get_current_picker(prompt_bufnr):cycle_previewers(-1)
end

--- Removes the selected picker in |builtin.pickers|.<br>
--- This action is not mapped by default and only intended for |builtin.pickers|.
---@param prompt_bufnr number: The prompt bufnr
actions.remove_selected_picker = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local selection_index = current_picker:get_index(current_picker:get_selection_row())
  local cached_pickers = state.get_global_key "cached_pickers"
  current_picker:delete_selection(function()
    table.remove(cached_pickers, selection_index)
  end)
  if #cached_pickers == 0 then
    actions.close(prompt_bufnr)
  end
end

--- Display the keymaps of registered actions similar to which-key.nvim.<br>
--- - Notes:
---   - The defaults can be overridden via |action_generate.which_key|.
---@param prompt_bufnr number: The prompt bufnr
actions.which_key = function(prompt_bufnr, opts)
  opts = opts or {}
  opts.max_height = utils.get_default(opts.max_height, 0.4)
  opts.only_show_current_mode = utils.get_default(opts.only_show_current_mode, true)
  opts.mode_width = utils.get_default(opts.mode_width, 1)
  opts.keybind_width = utils.get_default(opts.keybind_width, 7)
  opts.name_width = utils.get_default(opts.name_width, 30)
  opts.line_padding = utils.get_default(opts.line_padding, 1)
  opts.separator = utils.get_default(opts.separator, " -> ")
  opts.close_with_action = utils.get_default(opts.close_with_action, true)
  opts.normal_hl = utils.get_default(opts.normal_hl, "TelescopePrompt")
  opts.border_hl = utils.get_default(opts.border_hl, "TelescopePromptBorder")
  opts.winblend = utils.get_default(opts.winblend, config.values.winblend)
  opts.column_padding = utils.get_default(opts.column_padding, "  ")

  -- Assigning into 'opts.column_indent' would override a number with a string and
  -- cause issues with subsequent calls, keep a local copy of the string instead
  local column_indent = table.concat(utils.repeated_table(utils.get_default(opts.column_indent, 4), " "))

  -- close on repeated keypress
  local km_bufs = (function()
    local ret = {}
    local bufs = a.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
      for _, bufname in ipairs { "_TelescopeWhichKey", "_TelescopeWhichKeyBorder" } do
        if string.find(a.nvim_buf_get_name(buf), bufname) then
          table.insert(ret, buf)
        end
      end
    end
    return ret
  end)()
  if not vim.tbl_isempty(km_bufs) then
    for _, buf in ipairs(km_bufs) do
      utils.buf_delete(buf)
      local win_ids = vim.fn.win_findbuf(buf)
      for _, win_id in ipairs(win_ids) do
        pcall(a.nvim_win_close, win_id, true)
      end
    end
    return
  end

  local displayer = entry_display.create {
    separator = opts.separator,
    items = {
      { width = opts.mode_with },
      { width = opts.keybind_width },
      { width = opts.name_width },
    },
  }

  local make_display = function(mapping)
    return displayer {
      { mapping.mode, utils.get_default(opts.mode_hl, "TelescopeResultsConstant") },
      { mapping.keybind, utils.get_default(opts.keybind_hl, "TelescopeResultsVariable") },
      { mapping.name, utils.get_default(opts.name_hl, "TelescopeResultsFunction") },
    }
  end

  local mappings = {}
  local mode = a.nvim_get_mode().mode
  for _, v in pairs(action_utils.get_registered_mappings(prompt_bufnr)) do
    -- holds true for registered keymaps
    if type(v.func) == "table" then
      local name = ""
      for _, action in ipairs(v.func) do
        if type(action) == "string" then
          name = name == "" and action or name .. " + " .. action
        end
      end
      if name and name ~= "which_key" then
        if not opts.only_show_current_mode or mode == v.mode then
          table.insert(mappings, { mode = v.mode, keybind = v.keybind, name = name })
        end
      end
    end
  end

  table.sort(mappings, function(x, y)
    if x.name < y.name then
      return true
    elseif x.name == y.name then
      -- show normal mode as the standard mode first
      if x.mode > y.mode then
        return true
      else
        return false
      end
    else
      return false
    end
  end)

  local entry_width = #opts.column_padding
    + opts.mode_width
    + opts.keybind_width
    + opts.name_width
    + (3 * #opts.separator)
  local num_total_columns = math.floor((vim.o.columns - #column_indent) / entry_width)
  opts.num_rows = math.min(
    math.ceil(#mappings / num_total_columns),
    resolver.resolve_height(opts.max_height)(_, _, vim.o.lines)
  )
  local total_available_entries = opts.num_rows * num_total_columns
  local winheight = opts.num_rows + 2 * opts.line_padding

  -- place hints at top or bottom relative to prompt
  local win_central_row = function(win_nr)
    return a.nvim_win_get_position(win_nr)[1] + 0.5 * a.nvim_win_get_height(win_nr)
  end
  -- TODO(fdschmidt93|l-kershaw): better generalization of where to put which key float
  local picker = action_state.get_current_picker(prompt_bufnr)
  local prompt_row = win_central_row(picker.prompt_win)
  local results_row = win_central_row(picker.results_win)
  local preview_row = win_central_row(picker.preview_win)
  local prompt_pos = prompt_row < 0.4 * vim.o.lines
    or prompt_row < 0.6 * vim.o.lines and results_row + preview_row < vim.o.lines

  local modes = { n = "Normal", i = "Insert" }
  local title_mode = opts.only_show_current_mode and modes[mode] .. " Mode " or ""
  local title_text = title_mode .. "Keymaps"
  local popup_opts = {
    relative = "editor",
    enter = false,
    minwidth = vim.o.columns,
    maxwidth = vim.o.columns,
    minheight = winheight,
    maxheight = winheight,
    line = prompt_pos == true and vim.o.lines - winheight + 1 or 1,
    col = 0,
    border = { prompt_pos and 1 or 0, 0, not prompt_pos and 1 or 0, 0 },
    borderchars = { prompt_pos and "─" or " ", "", not prompt_pos and "─" or " ", "", "", "", "", "" },
    noautocmd = true,
    title = { { text = title_text, pos = prompt_pos and "N" or "S" } },
  }
  local km_win_id, km_opts = popup.create("", popup_opts)
  local km_buf = a.nvim_win_get_buf(km_win_id)
  a.nvim_buf_set_name(km_buf, "_TelescopeWhichKey")
  a.nvim_buf_set_name(km_opts.border.bufnr, "_TelescopeTelescopeWhichKeyBorder")
  a.nvim_win_set_option(km_win_id, "winhl", "Normal:" .. opts.normal_hl)
  a.nvim_win_set_option(km_opts.border.win_id, "winhl", "Normal:" .. opts.border_hl)
  a.nvim_win_set_option(km_win_id, "winblend", opts.winblend)
  a.nvim_win_set_option(km_win_id, "foldenable", false)

  vim.cmd(string.format(
    "autocmd BufLeave <buffer> ++once lua %s",
    table.concat({
      string.format("pcall(vim.api.nvim_win_close, %s, true)", km_win_id),
      string.format("pcall(vim.api.nvim_win_close, %s, true)", km_opts.border.win_id),
      string.format("require 'telescope.utils'.buf_delete(%s)", km_buf),
    }, ";")
  ))

  a.nvim_buf_set_lines(km_buf, 0, -1, false, utils.repeated_table(opts.num_rows + 2 * opts.line_padding, column_indent))

  local keymap_highlights = a.nvim_create_namespace "telescope_whichkey"
  local highlights = {}
  for index, mapping in ipairs(mappings) do
    local row = utils.cycle(index, opts.num_rows) - 1 + opts.line_padding
    local prev_line = a.nvim_buf_get_lines(km_buf, row, row + 1, false)[1]
    if index == total_available_entries and total_available_entries > #mappings then
      local new_line = prev_line .. "..."
      a.nvim_buf_set_lines(km_buf, row, row + 1, false, { new_line })
      break
    end
    local display, display_hl = make_display(mapping)
    local new_line = prev_line .. display .. opts.column_padding -- incl. padding
    a.nvim_buf_set_lines(km_buf, row, row + 1, false, { new_line })
    table.insert(highlights, { hl = display_hl, row = row, col = #prev_line })
  end

  -- highlighting only after line setting as vim.api.nvim_buf_set_lines removes hl otherwise
  for _, highlight_tbl in pairs(highlights) do
    local highlight = highlight_tbl.hl
    local row_ = highlight_tbl.row
    local col = highlight_tbl.col
    for _, hl_block in ipairs(highlight) do
      a.nvim_buf_add_highlight(km_buf, keymap_highlights, hl_block[2], row_, col + hl_block[1][1], col + hl_block[1][2])
    end
  end

  -- only set up autocommand after showing preview completed
  if opts.close_with_action then
    vim.schedule(function()
      vim.cmd(string.format(
        "autocmd User TelescopeKeymap ++once lua %s",
        table.concat({
          string.format("pcall(vim.api.nvim_win_close, %s, true)", km_win_id),
          string.format("pcall(vim.api.nvim_win_close, %s, true)", km_opts.border.win_id),
          string.format("require 'telescope.utils'.buf_delete(%s)", km_buf),
        }, ";")
      ))
    end)
  end
end

-- ==================================================
-- Transforms modules and sets the correct metatables.
-- ==================================================
actions = transform_mod(actions)
return actions
