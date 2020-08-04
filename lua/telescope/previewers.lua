local log = require('telescope.log')

local previewers = {}

local Previewer = {}
Previewer.__index = Previewer

function Previewer:new(opts)
  opts = opts or {}

  return setmetatable({
    preview_fn = opts.preview_fn,
  }, Previewer)
end

function Previewer:preview(preview_win, preview_bufnr, results_bufnr, row)
  return self.preview_fn(preview_win, preview_bufnr, results_bufnr, row)
end

previewers.new = function(...)
  return Previewer:new(...)
end

previewers.vim_buffer = previewers.new {
  preview_fn = function(preview_win, preview_bufnr, results_bufnr, row)
    local line = vim.api.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
    if line == nil then
      return
    end
    local file_name = vim.split(line, ":")[1]

    log.info("Previewing File: %s", file_name)

    -- vim.fn.termopen(
    --   string.format("bat --color=always --style=grid %s"),
    -- vim.fn.fnamemodify(file_name, ":p")
    local bufnr = vim.fn.bufadd(file_name)
    vim.fn.bufload(bufnr)

    -- TODO: We should probably call something like this because we're not always getting highlight and all that stuff.
    -- api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filename))
    vim.api.nvim_win_set_buf(preview_win, bufnr)
    vim.api.nvim_win_set_option(preview_win, 'wrap', false)
    vim.api.nvim_win_set_option(preview_win, 'winhl', 'Normal:Normal')
    -- vim.api.nvim_win_set_option(preview_win, 'winblend', 20)
    vim.api.nvim_win_set_option(preview_win, 'signcolumn', 'no')
    vim.api.nvim_win_set_option(preview_win, 'foldlevel', 100)
  end,
}


previewers.vim_buffer_or_bat = previewers.new {
  preview_fn = function(preview_win, preview_bufnr, results_bufnr, row)
    local line = vim.api.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
    if line == nil then
      return
    end
    local file_name = vim.split(line, ":")[1]

    log.info("Previewing File: %s", file_name)

    -- vim.fn.termopen(
    --   string.format("bat --color=always --style=grid %s"),
    -- vim.fn.fnamemodify(file_name, ":p")
    local bufnr = vim.fn.bufadd(file_name)

    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)

      -- TODO: We should probably call something like this because we're not always getting highlight and all that stuff.
      -- api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filename))
      vim.api.nvim_win_set_buf(preview_win, bufnr)
      vim.api.nvim_win_set_option(preview_win, 'wrap', false)
      vim.api.nvim_win_set_option(preview_win, 'winhl', 'Normal:Normal')
      -- vim.api.nvim_win_set_option(preview_win, 'winblend', 20)
      vim.api.nvim_win_set_option(preview_win, 'signcolumn', 'no')
      vim.api.nvim_win_set_option(preview_win, 'foldlevel', 100)
    else
      vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, vim.fn.systemlist(string.format('bat %s', file_name)))
    end
  end,
}


previewers.Previewer = Previewer

return previewers
