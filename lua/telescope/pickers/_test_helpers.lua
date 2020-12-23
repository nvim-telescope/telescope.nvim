local test_helpers = {}

test_helpers.get_picker = function()
  local state = require('telescope.state')
  return state.get_status(vim.api.nvim_get_current_buf()).picker
end

test_helpers.get_results_bufnr = function()
  local state = require('telescope.state')
  return state.get_status(vim.api.nvim_get_current_buf()).results_bufnr
end

test_helpers.get_file = function()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
end

test_helpers.get_prompt = function()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
end

test_helpers.get_results = function()
  return vim.api.nvim_buf_get_lines(test_helpers.get_results_bufnr(), 0, -1, false)
end

test_helpers.get_last_result = function()
  local results = test_helpers.get_results()
  return results[#results]
end

test_helpers.get_selection = function()
  local state = require('telescope.state')
  return state.get_global_key('selected_entry')
end

test_helpers.get_selection_value = function()
  return test_helpers.get_selection().value
end

test_helpers.make_globals = function()
  GetFile           = test_helpers.get_file            -- luacheck: globals GetFile
  GetPrompt         = test_helpers.get_prompt          -- luacheck: globals GetPrompt

  GetResults        = test_helpers.get_results         -- luacheck: globals GetResults
  GetLastResult     = test_helpers.get_last_result     -- luacheck: globals GetLastResult

  GetSelection      = test_helpers.get_selection       -- luacheck: globals GetSelection
  GetSelectionValue = test_helpers.get_selection_value -- luacheck: globals GetSelectionValue
end

return test_helpers
