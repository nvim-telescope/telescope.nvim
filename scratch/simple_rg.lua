local telescope = require('telescope')

-- Uhh, finder should probably just GET the results
-- and then update some table.
-- When updating the table, we should call filter on those items
-- and then only display ones that pass the filter
local rg_finder = telescope.finders.new {
  fn_command = function(prompt)
    return string.format('rg --vimgrep %s', prompt)
  end,

  responsive = false
}


local p = telescope.pickers.new {
  previewer = telescope.previewers.new(function(preview_win, preview_bufnr, results_bufnr, row)
    assert(preview_bufnr)

    local line = vim.api.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
    local file_name = vim.split(line, ":")[1]

    -- print(file_name)
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
    vim.api.nvim_win_set_option(preview_win, 'winblend', 20)
    vim.api.nvim_win_set_option(preview_win, 'signcolumn', 'no')
    vim.api.nvim_win_set_option(preview_win, 'foldlevel', 100)
  end)
}
p:find(rg_finder)

