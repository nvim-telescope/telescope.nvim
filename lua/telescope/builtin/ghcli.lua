
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local pickers = require('telescope.pickers')
local utils = require('telescope.utils')
local conf = require('telescope.config').values
local Job = require('plenary.job')

local GH={ }
actions.gh_pr_checkout = function(prompt_bufnr)
  local selection = actions.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  local val = selection.value
  local tmp_table = vim.split(selection.value,"\t");
  if vim.tbl_isempty(tmp_table) then
    return
  end
  local job = Job:new({
      enable_recording = true ,
      command = "gh",
      args = {"pr", "checkout" ,tmp_table[1]}
    })
  -- need to display result in quickfix
  job:sync()
end

actions.gh_pr_view = function(prompt_bufnr)
  local selection = actions.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  local val = selection.value
  local tmp_table = vim.split(selection.value,"\t");
  if vim.tbl_isempty(tmp_table) then
    return
  end
  os.execute('gh pr view --web ' .. tmp_table[1])
end

actions.gh_issue_view = function(prompt_bufnr)
  local selection = actions.get_selected_entry(prompt_bufnr)
  actions.close(prompt_bufnr)
  local val = selection.value
  local tmp_table = vim.split(selection.value,"\t");
  if vim.tbl_isempty(tmp_table) then
    return
  end
  os.execute('gh issue view --web ' .. tmp_table[1])
end

GH.gh_issue=function(opts)
  opts = opts or {}
  opts.limit = opts.limit or 100
  local cmd = 'gh issue list -L '..opts.limit
  local results = vim.split(utils.get_os_command_output(cmd), '\n')
  pickers.new(opts, {
    prompt_title = 'Issues',
    finder = finders.new_table {
      results = results,
      entry_maker = make_entry.gen_from_string(opts),
    },
    previewer = previewers.new_termopen_previewer{
      get_command = function(entry)
        local tmp_table = vim.split(entry.value,"\t");
        if vim.tbl_isempty(tmp_table) then
          return {"echo", ""}
        end
        return { 'gh' ,'issue' ,'view',tmp_table[1] }
      end
    },
    sorter = conf.file_sorter(opts),
    attach_mappings = function(_,map)
      actions.goto_file_selection_edit:replace(actions.close)
      map('i','<c-t>',actions.gh_issue_view)
      return true
    end
  }):find()  
end

GH.gh_pull_request = function(opts)
  opts = opts or {}
  opts.limit = opts.limit or 100
  local cmd = 'gh pr list -L '..opts.limit
  local results = vim.split(utils.get_os_command_output(cmd), '\n')
  pickers.new(opts, {
    prompt_title = 'Pullrequests' ,
    finder = finders.new_table {
      results = results,
      entry_maker = make_entry.gen_from_string(opts),
    },
    previewer = previewers.new_termopen_previewer{
      get_command = function(entry)
        local sha = entry.value
        local tmp_table = vim.split(entry.value,"\t");
        if vim.tbl_isempty(tmp_table) then
          return {"echo", ""}
        end
        return { 'gh' ,'pr' ,'view',tmp_table[1] }
      end
    },
    sorter = conf.file_sorter(opts),
    attach_mappings = function(_,map)
      actions.goto_file_selection_edit:replace(actions.gh_pr_checkout)
      map('i','<c-t>',actions.gh_pr_view)
      return true
    end
  }):find()  
end
return GH 
