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

describe("builtin.grep_string", function()
  it("searches open buffers outside of cwd with grep_open_files", function()
    local file = vim.fn.tempname()
    vim.fn.writefile({ "zzqtelescopeword" }, file)
    local bufnr = vim.fn.bufadd(file)
    vim.bo[bufnr].buflisted = true

    eq(true, (pcall(builtin.grep_string, { search = "zzqtelescopeword", grep_open_files = true })))
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
    vim.wait(2000, function()
      return picker.manager and picker.manager:num_results() > 0
    end)
    local results = {}
    for entry in picker.manager:iter() do
      table.insert(results, vim.fs.basename(entry.filename))
    end
    require("telescope.actions").close(prompt_bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })

    eq({ vim.fs.basename(file) }, results)
  end)
end)
