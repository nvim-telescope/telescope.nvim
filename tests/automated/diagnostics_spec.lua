local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it = t.describe, t.it
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("builtin diagnostics", function()
  it("preserves the diagnostic code for custom entry makers", function()
    exec_lua(function()
      local diagnostics = require("telescope.builtin.__diagnostics")
      local pickers = require("telescope.pickers")
      local assert = require("test.assert")
      local eq = assert.eq

      local old_pickers_new = pickers.new
      local previous_bufnr = vim.api.nvim_get_current_buf()
      local ns = vim.api.nvim_create_namespace("telescope-test-diagnostics")
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".py")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "def example(a, b): pass" })
      vim.api.nvim_set_current_buf(bufnr)

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

      diagnostics.get({
        bufnr = 0,
        entry_maker = function(entry)
          captured_entry = entry
          return {
            value = entry,
            ordinal = entry.text,
            display = entry.text,
          }
        end,
      })

      assert.neq(nil, captured_entry)
      eq("PLR0913", captured_entry.code)

      pickers.new = old_pickers_new
      vim.diagnostic.reset(ns, bufnr)
      vim.api.nvim_set_current_buf(previous_bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
