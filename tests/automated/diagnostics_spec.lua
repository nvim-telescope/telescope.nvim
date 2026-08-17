local diagnostics = require "telescope.builtin.__diagnostics"
local pickers = require "telescope.pickers"

local eq = assert.are.same

describe("builtin diagnostics", function()
  local bufnr
  local ns
  local old_pickers_new
  local previous_bufnr

  before_each(function()
    old_pickers_new = pickers.new
    previous_bufnr = vim.api.nvim_get_current_buf()
    ns = vim.api.nvim_create_namespace "telescope-test-diagnostics"
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".py")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "def example(a, b): pass" })
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    pickers.new = old_pickers_new
    vim.diagnostic.reset(ns, bufnr)

    if previous_bufnr and vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_set_current_buf(previous_bufnr)
    end

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  it("preserves the diagnostic code for custom entry makers", function()
    vim.diagnostic.set(ns, bufnr, {
      {
        lnum = 0,
        col = 4,
        severity = vim.diagnostic.severity.WARN,
        message = "too many arguments",
        code = "PLR0913",
      },
    })

    local captured_entry
    pickers.new = function()
      return { find = function() end }
    end

    diagnostics.get {
      bufnr = 0,
      entry_maker = function(entry)
        captured_entry = entry
        return {
          value = entry,
          ordinal = entry.text,
          display = entry.text,
        }
      end,
    }

    assert.is_not_nil(captured_entry)
    eq("PLR0913", captured_entry.code)
  end)
end)
