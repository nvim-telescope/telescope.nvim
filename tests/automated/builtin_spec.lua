local builtin = require "telescope.builtin"

local eq = assert.are.same

describe("builtin.buffers", function()
  local function listed_buffer(name)
    local bufnr = vim.fn.bufadd(name)
    vim.bo[bufnr].buflisted = true
    return bufnr
  end

  after_each(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(bufnr) ~= "" then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  it("filters buffers outside of cwd with cwd_only", function()
    listed_buffer(vim.fs.joinpath(vim.fs.dirname(vim.uv.cwd()), "outside.txt"))
    local win = vim.api.nvim_get_current_win()
    eq(true, (pcall(builtin.buffers, { cwd_only = true })))
    -- nothing left to show, so no picker was opened
    eq(win, vim.api.nvim_get_current_win())
  end)

  it("keeps buffers inside of cwd with cwd_only", function()
    listed_buffer(vim.fs.joinpath(vim.uv.cwd(), "README.md"))
    local win = vim.api.nvim_get_current_win()
    eq(true, (pcall(builtin.buffers, { cwd_only = true })))
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    eq("TelescopePrompt", vim.bo[prompt_bufnr].filetype)
    require("telescope.actions").close(prompt_bufnr)
    eq(win, vim.api.nvim_get_current_win())
  end)
end)
