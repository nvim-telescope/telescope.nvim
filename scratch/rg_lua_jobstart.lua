
local function get_rg_results(bufnr, search_string)
  local start_time = vim.fn.reltime()

  vim.fn.jobstart(string.format('rg %s', search_string), {
    cwd = '/home/tj/build/neovim',

    on_stdout = function(job_id, data, event)
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    end,

    on_exit = function()
      print("Finished in: ", vim.fn.reltimestr(vim.fn.reltime(start_time)))
    end,

    stdout_buffer = true,
  })
end

local bufnr = 14
get_rg_results(bufnr, 'vim.api')
