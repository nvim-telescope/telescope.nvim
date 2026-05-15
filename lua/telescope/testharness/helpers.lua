local M = {}

M.get_picker = function()
  local state = require "telescope.state"
  return state.get_status(vim.api.nvim_get_current_buf()).picker
end

M.get_results_bufnr = function()
  local state = require "telescope.state"
  return state.get_status(vim.api.nvim_get_current_buf()).layout.results.bufnr
end

M.get_file = function()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
end

M.get_prompt = function()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
end

M.get_results = function()
  return vim.api.nvim_buf_get_lines(M.get_results_bufnr(), 0, -1, false)
end

M.get_best_result = function()
  local results = M.get_results()
  local picker = M.get_picker()

  if picker.sorting_strategy == "ascending" then
    return results[1]
  else
    return results[#results]
  end
end

M.get_selection = function()
  local state = require "telescope.state"
  return state.get_global_key "selected_entry"
end

M.get_selection_value = function()
  return M.get_selection().value
end

M.make_globals = function()
  GetFile = M.get_file -- luacheck: globals GetFile
  GetPrompt = M.get_prompt -- luacheck: globals GetPrompt

  GetResults = M.get_results -- luacheck: globals GetResults
  GetBestResult = M.get_best_result -- luacheck: globals GetBestResult

  GetSelection = M.get_selection -- luacheck: globals GetSelection
  GetSelectionValue = M.get_selection_value -- luacheck: globals GetSelectionValue
end

return M
