local action_state = require("telescope.actions.state")

local M = {}

--- Open the builtin picker `name` with `opts` and return it.
function M.picker(name, opts)
  require("telescope.builtin")[name](opts)
  local picker = action_state.get_current_picker(vim.api.nvim_get_current_buf())
  picker.__completed = 0
  picker:register_completion_callback(function(p)
    p.__completed = p.__completed + 1
  end)
  return picker
end

--- Type `text` into the prompt, one character at a time, waiting for the results after each one.
function M.type(picker, text)
  for char in text:gmatch(".") do
    local completed = picker.__completed
    picker:set_prompt(char, false)
    vim.wait(5000, function()
      return picker.__completed > completed
    end, 10)
  end
end

--- The prompt line.
function M.prompt(picker)
  return vim.api.nvim_buf_get_lines(picker.prompt_bufnr, 0, 1, false)[1]
end

--- The non-empty lines of the results window.
function M.results(picker)
  return vim.tbl_filter(function(line)
    return line ~= ""
  end, vim.api.nvim_buf_get_lines(picker.results_bufnr, 0, -1, false))
end

--- The highest ranked result line.
function M.best_result(picker)
  local results = M.results(picker)
  return picker.sorting_strategy == "ascending" and results[1] or results[#results]
end

--- Select the current entry (`<CR>`) and return the tail of the name of the opened buffer.
function M.select(picker)
  require("telescope.actions").select_default(picker.prompt_bufnr)
  return vim.fs.basename(vim.api.nvim_buf_get_name(0))
end

--- Close all pickers and wipe all buffers.
function M.cleanup()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].filetype == "TelescopePrompt" then
      pcall(require("telescope.actions").close, bufnr)
    end
  end
  vim.cmd("silent! %bwipeout!")
end

return M
