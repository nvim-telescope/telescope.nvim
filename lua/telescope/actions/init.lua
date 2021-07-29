---@tag telescope.actions

-- TODO: Add @module to make it so we can have the prefix.
--@module telescope.actions

---@brief [[
--- Actions functions that are useful for people creating their own mappings.
---@brief ]]

local a = vim.api

local log = require "telescope.log"
local utils = require "telescope.utils"
local p_scroller = require "telescope.pickers.scroller"

local action_state = require "telescope.actions.state"
local action_utils = require "telescope.actions.utils"
local action_set = require "telescope.actions.set"

local transform_mod = require("telescope.actions.mt").transform_mod

local Path = require "plenary.path"

local actions = setmetatable({}, {
  __index = function(t, k)
    local cmd_tokens = vim.split(k, "_")

    -- the first key determines how to execute the action
    local smart = vim.tbl_contains(cmd_tokens, "smart")
    local multi = vim.tbl_contains(cmd_tokens, "multi")
    local entries = vim.tbl_contains(cmd_tokens, "entries")

    if #vim.tbl_filter(function(x)
      return x == true
    end, { smart, multi, entries }) > 1 then
      error "Only one of 'smart', 'multi' or 'entries' is valid!"
    end

    if not (smart or multi or entries) then
      error("Key does not exist for 'telescope.actions': " .. tostring(k))
    end
    -- end

    local cmd = table.concat(cmd_tokens, "_", 2)
    if smart or multi then
      return action_utils.with_selections(t[cmd], smart)
    elseif entries then
      return action_utils.with_entries(t[cmd])
    else
      error "Invalidly composed action!"
    end
  end,
})

-- TODO(conni2461): Remove deprecated messages
local action_is_deprecated = function(name, err)
  local messager = err and error or log.info

  return messager(
    string.format("`actions.%s()` is deprecated." .. "Use require('telescope.actions.state').%s() instead", name, name)
  )
end

function actions.get_selected_entry()
  -- TODO(1.0): Remove
  action_is_deprecated "get_selected_entry"
  return action_state.get_selected_entry()
end

function actions.get_current_line()
  -- TODO(1.0): Remove
  action_is_deprecated "get_current_line"
  return action_state.get_current_line()
end

function actions.get_current_picker(prompt_bufnr)
  -- TODO(1.0): Remove
  action_is_deprecated "get_current_picker"
  return action_state.get_current_picker(prompt_bufnr)
end

--- Move the selection to the next entry
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_next(prompt_bufnr, context)
  action_set.shift_selection(prompt_bufnr, context, 1)
end

--- Move the selection to the previous entry
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_previous(prompt_bufnr, context)
  action_set.shift_selection(prompt_bufnr, context, -1)
end

--- Move the selection to the entry that has a worse score
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_worse(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  action_set.shift_selection(prompt_bufnr, context, p_scroller.worse(picker.sorting_strategy))
end

--- Move the selection to the entry that has a better score
---@param prompt_bufnr number: The prompt bufnr
function actions.move_selection_better(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  action_set.shift_selection(prompt_bufnr, context, p_scroller.better(picker.sorting_strategy))
end

--- Move to the top of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_top(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  picker:set_selection(p_scroller.top(picker.sorting_strategy, picker.max_results, picker.manager:num_results()))
end

--- Move to the middle of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_middle(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  picker:set_selection(p_scroller.middle(picker.sorting_strategy, picker.max_results, picker.manager:num_results()))
end

--- Move to the bottom of the picker
---@param prompt_bufnr number: The prompt bufnr
function actions.move_to_bottom(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  picker:set_selection(p_scroller.bottom(picker.sorting_strategy, picker.max_results, picker.manager:num_results()))
end

--- Add current entry to multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.add_selection(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  picker:add_selection(picker:get_selection_row())
end

--- Remove current entry from multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.remove_selection(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr)
  picker:remove_selection(picker:get_selection_row())
end

--- Toggle current entry status for multi select
---@param prompt_bufnr number: The prompt bufnr
function actions.toggle_selection(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  picker:toggle_selection(picker:get_selection_row())
end

--- Multi select all entries.
--- - Note: selected entries may include results not visible in the results popup.
---@param prompt_bufnr number: The prompt bufnr
function actions.select_all(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  action_utils.map_entries(prompt_bufnr, function(entry, _, row)
    if not picker._multi:is_selected(entry) then
      picker._multi:add(entry)
      if picker:can_select_row(row) then
        picker.highlighter:hi_multiselect(row, picker._multi:is_selected(entry))
      end
    end
  end)
end

--- Drop all entries from the current multi selection.
---@param prompt_bufnr number: The prompt bufnr
function actions.drop_all(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  action_utils.map_entries(prompt_bufnr, function(entry, _, row)
    picker._multi:drop(entry)
    if picker:can_select_row(row) then
      picker.highlighter:hi_multiselect(row, picker._multi:is_selected(entry))
    end
  end)
end

--- Toggle multi selection for all entries.
--- - Note: toggled entries may include results not visible in the results popup.
---@param prompt_bufnr number: The prompt bufnr
function actions.toggle_all(prompt_bufnr, context)
  local picker = action_state.get_current_picker(prompt_bufnr)
  action_utils.map_entries(prompt_bufnr, function(entry, _, row)
    picker._multi:toggle(entry)
    if picker:can_select_row(row) then
      picker.highlighter:hi_multiselect(row, picker._multi:is_selected(entry))
    end
  end)
end

function actions.preview_scrolling_up(prompt_bufnr)
  action_set.scroll_previewer(prompt_bufnr, -1)
end

function actions.preview_scrolling_down(prompt_bufnr)
  action_set.scroll_previewer(prompt_bufnr, 1)
end

function actions.center(_)
  vim.cmd ":normal! zz"
end

actions.select_default = {
  pre = function(prompt_bufnr, context)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr, context)
    )
  end,
  action = function(prompt_bufnr, context)
    return action_set.select(prompt_bufnr, context, "default")
  end,
}

actions.select_horizontal = {
  pre = function(prompt_bufnr, context)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr, context)
    )
  end,
  action = function(prompt_bufnr, context)
    return action_set.select(prompt_bufnr, context, "horizontal")
  end,
}

actions.select_vertical = {
  pre = function(prompt_bufnr, context)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr, context)
    )
  end,
  action = function(prompt_bufnr, context)
    return action_set.select(prompt_bufnr, context, "vertical")
  end,
}

actions.select_tab = {
  pre = function(prompt_bufnr, context)
    action_state.get_current_history():append(
      action_state.get_current_line(),
      action_state.get_current_picker(prompt_bufnr, context)
    )
  end,
  action = function(prompt_bufnr, context)
    return action_set.select(prompt_bufnr, context, "tab")
  end,
}

-- TODO: consider adding float!
-- https://github.com/nvim-telescope/telescope.nvim/issues/365

function actions.file_edit(prompt_bufnr, context)
  return action_set.edit(prompt_bufnr, context, "edit")
end

function actions.file_split(prompt_bufnr, context)
  return action_set.edit(prompt_bufnr, context, "new")
end

function actions.file_vsplit(prompt_bufnr, context)
  return action_set.edit(prompt_bufnr, context, "vnew")
end

function actions.file_tab(prompt_bufnr, context)
  return action_set.edit(prompt_bufnr, context, "tabedit")
end

function actions.close_pum(_)
  if 0 ~= vim.fn.pumvisible() then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-y>", true, true, true), "n", true)
  end
end

actions._close = function(prompt_bufnr, context, keepinsert)
  action_state.get_current_history():reset()
  local picker = action_state.get_current_picker(prompt_bufnr, context)
  local prompt_win = picker.prompt_win
  local original_win_id = picker.original_win_id

  if picker.previewer then
    for _, v in ipairs(picker.all_previewers) do
      v:teardown()
    end
  end

  actions.close_pum()
  if not keepinsert then
    vim.cmd [[stopinsert]]
  end

  if vim.api.nvim_win_is_valid(prompt_win) then
    vim.api.nvim_win_close(prompt_win, true)
  end
  
  if vim.api.nvim_buf_is_valid(prompt_bufnr) then
    pcall(vim.cmd, string.format([[silent bdelete! %s]], prompt_bufnr))
  end

  pcall(a.nvim_set_current_win, original_win_id)
end

function actions.close(prompt_bufnr, context)
  actions._close(prompt_bufnr, context, false)
end

actions.edit_command_line = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  a.nvim_feedkeys(a.nvim_replace_termcodes(":" .. entry.value, true, false, true), "t", true)
end

actions.set_command_line = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)

  actions.close(prompt_bufnr, context)
  vim.fn.histadd("cmd", entry.value)
  vim.cmd(entry.value)
end

actions.edit_search_line = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. entry.value, true, false, true), "t", true)
end

actions.set_search_line = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)

  actions.close(prompt_bufnr, context)
  a.nvim_feedkeys(a.nvim_replace_termcodes("/" .. entry.value .. "<CR>", true, false, true), "t", true)
end

actions.edit_register = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)
  local picker = action_state.get_current_picker(prompt_bufnr, context)

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

actions.paste_register = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)

  actions.close(prompt_bufnr, context)

  -- ensure that the buffer can be written to
  if vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "modifiable") then
    print "Paste!"
    vim.api.nvim_paste(entry.content, true, -1)
  end
end

actions.run_builtin = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)

  actions._close(prompt_bufnr, context, true)
  if string.match(entry.text, " : ") then
    -- Call appropriate function from extensions
    local split_string = vim.split(entry.text, " : ")
    local ext = split_string[1]
    local func = split_string[2]
    require("telescope").extensions[ext][func]()
  else
    -- Call appropriate telescope builtin
    require("telescope.builtin")[entry.text]()
  end
end

actions.insert_symbol = function(prompt_bufnr, context)
  local selection = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  vim.api.nvim_put({ selection.value[1] }, "", true, true)
end

-- TODO: Think about how to do this.
actions.insert_value = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)

  vim.schedule(function()
    actions.close(prompt_bufnr, context)
  end)

  return entry.value
end

--- Create and checkout a new git branch if it doesn't already exist
---@param prompt_bufnr number: The prompt bufnr
actions.git_create_branch = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr, context).cwd
  local new_branch = action_state.get_current_line()

  if new_branch == "" then
    print "Please enter the name of the new branch to create"
  else
    local confirmation = vim.fn.input(string.format('Create new branch "%s"? [y/n]: ', new_branch))
    if string.len(confirmation) == 0 or string.sub(string.lower(confirmation), 0, 1) ~= "y" then
      print(string.format('Didn\'t create branch "%s"', new_branch))
      return
    end

    actions.close(prompt_bufnr, context)

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
actions.git_apply_stash = function(prompt_bufnr, context)
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  local _, ret, stderr = utils.get_os_command_output { "git", "stash", "apply", "--index", entry.value }
  if ret == 0 then
    print("applied: " .. entry.value)
  else
    print(string.format('Error when applying: %s. Git returned: "%s"', entry.value, table.concat(stderr, "  ")))
  end
end

--- Checkout an existing git branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_checkout = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr, context).cwd
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  local _, ret, stderr = utils.get_os_command_output({ "git", "checkout", entry.value }, cwd)
  if ret == 0 then
    print("Checked out: " .. entry.value)
  else
    print(string.format('Error when checking out: %s. Git returned: "%s"', entry.value, table.concat(stderr, "  ")))
  end
end

--- Switch to git branch.<br>
--- If the branch already exists in local, switch to that.
--- If the branch is only in remote, create new branch tracking remote and switch to new one.
---@param prompt_bufnr number: The prompt bufnr
actions.git_switch_branch = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  local pattern = "^refs/remotes/%w+/"
  local branch = entry.value
  if string.match(entry.refname, pattern) then
    branch = string.gsub(entry.refname, pattern, "")
  end
  local _, ret, stderr = utils.get_os_command_output({ "git", "switch", branch }, cwd)
  if ret == 0 then
    print("Switched to: " .. branch)
  else
    print(string.format('Error when switching to: %s. Git returned: "%s"', entry.value, table.concat(stderr, "  ")))
  end
end

--- Tell git to track the currently selected remote branch in Telescope
---@param prompt_bufnr number: The prompt bufnr
actions.git_track_branch = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr).cwd
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  local _, ret, stderr = utils.get_os_command_output({ "git", "checkout", "--track", entry.value }, cwd)
  if ret == 0 then
    print("Tracking branch: " .. entry.value)
  else
    print(string.format('Error when tracking branch: %s. Git returned: "%s"', entry.value, table.concat(stderr, "  ")))
  end
end

--- Delete the currently selected branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_delete_branch = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr, context).cwd
  local entry = action_state.get_selected_entry(context)

  local confirmation = vim.fn.input("Do you really wanna delete branch " .. entry.value .. "? [Y/n] ")
  if confirmation ~= "" and string.lower(confirmation) ~= "y" then
    return
  end

  actions.close(prompt_bufnr, context)
  local _, ret, stderr = utils.get_os_command_output({ "git", "branch", "-D", entry.value }, cwd)
  if ret == 0 then
    print("Deleted branch: " .. entry.value)
  else
    print(string.format('Error when deleting branch: %s. Git returned: "%s"', entry.value, table.concat(stderr, "  ")))
  end
end

--- Rebase to selected git branch
---@param prompt_bufnr number: The prompt bufnr
actions.git_rebase_branch = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr, context).cwd
  local entry = action_state.get_selected_entry(context)

  local confirmation = vim.fn.input("Do you really wanna rebase branch " .. entry.value .. "? [Y/n] ")
  if confirmation ~= "" and string.lower(confirmation) ~= "y" then
    return
  end

  actions.close(prompt_bufnr, context)
  local _, ret, stderr = utils.get_os_command_output({ "git", "rebase", entry.value }, cwd)
  if ret == 0 then
    print("Rebased branch: " .. entry.value)
  else
    print(string.format('Error when rebasing branch: %s. Git returned: "%s"', entry.value, table.concat(stderr, "  ")))
  end
end

actions.git_checkout_current_buffer = function(prompt_bufnr, context)
  local cwd = actions.get_current_picker(prompt_bufnr, context).cwd
  local entry = action_state.get_selected_entry(context)
  actions.close(prompt_bufnr, context)
  utils.get_os_command_output({ "git", "checkout", entry.value, "--", entry.file }, cwd)
end

--- Stage/unstage selected file
---@param prompt_bufnr number: The prompt bufnr
actions.git_staging_toggle = function(prompt_bufnr, context)
  local cwd = action_state.get_current_picker(prompt_bufnr, context).cwd
  local entry = action_state.get_selected_entry(context)

  if entry.status:sub(2) == " " then
    utils.get_os_command_output({ "git", "restore", "--staged", entry.value }, cwd)
  else
    utils.get_os_command_output({ "git", "add", entry.value }, cwd)
  end
end

local entry_to_qf = function(entry)
  return {
    bufnr = entry.bufnr,
    filename = Path:new(entry.cwd, entry.filename):absolute(),
    lnum = entry.lnum,
    col = entry.col,
    text = entry.text or entry.value.text or entry.value,
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
  local current_picker = actions.get_current_picker(prompt_bufnr)
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
  local current_picker = actions.get_current_picker(prompt_bufnr)
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
    vim.api.nvim_buf_delete(selection.bufnr, { force = true })
  end)
end

--- Cycle to the next previewer if there is one available.<br>
--- This action is not mapped on default.
---@param prompt_bufnr number: The prompt bufnr
actions.cycle_previewers_next = function(prompt_bufnr)
  actions.get_current_picker(prompt_bufnr):cycle_previewers(1)
end

--- Cycle to the previous previewer if there is one available.<br>
--- This action is not mapped on default.
---@param prompt_bufnr number: The prompt bufnr
actions.cycle_previewers_prev = function(prompt_bufnr)
  actions.get_current_picker(prompt_bufnr):cycle_previewers(-1)
end

-- actions.register = function(key, value)
--   if actions[key] ~= nil then
--     print "Action already exists! Please pass a non existing action key"
--   end
--   for _, w in ipairs { "smart", "multi", "entries" } do
--     if string.find(key, w) then
--       print("An action variant with %s will be generated automatically", w)
--       return
--     end
--   end
--   actions[key] = value
-- end

-- ==================================================
-- Transforms modules and sets the corect metatables.
-- ==================================================
actions = transform_mod(actions)
return actions
