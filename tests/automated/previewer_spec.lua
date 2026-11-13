local t = require("test.harness")
local assert = require("test.assert")
local describe, it = t.describe, t.it

local putils = require("telescope.previewers.utils")
local utils = require("telescope.utils")

describe("timed_split_lines", function()
  local expect = {
    "",
    "",
    "line3 of the file",
    "",
    "line5 of the file",
    "",
    "",
    "line8 of the file, last line of file",
  }

  local split_lines = function(s)
    return putils.timed_split_lines(s, {
      start_time = vim.uv.hrtime(),
      preview = {
        timeout = 250, -- should be more than enough time
      },
    })
  end

  if utils.iswin then
    describe("handles files on Windows", function()
      it("reads file ending with \\r\\n (standard Windows line terminator)", function()
        local file = table.concat(expect, "\r\n") .. "\r\n"
        assert.eq(expect, split_lines(file))
      end)

      it("reads file ending with \\n only", function()
        local file = table.concat(expect, "\n") .. "\n"
        assert.eq(expect, split_lines(file))
      end)

      it("reads file with no trailing newline", function()
        local file = table.concat(expect, "\r\n")
        assert.eq(expect, split_lines(file))
      end)
    end)
  else
    describe("handles files on non Windows environment", function()
      it("reads file ending with \\n (standard Unix line terminator)", function()
        local file = table.concat(expect, "\n") .. "\n"
        assert.eq(expect, split_lines(file))
      end)

      it("reads file with no trailing newline", function()
        local file = table.concat(expect, "\n")
        assert.eq(expect, split_lines(file))
      end)
    end)
  end
end)

describe("buffer_previewer_maker", function()
  it("lists a directory like Nvim's directory listing", function()
    local dir = vim.fn.tempname()
    for _, d in ipairs({ "z", "a-b", "a" }) do
      vim.fs.mkdir(vim.fs.joinpath(dir, d), { parents = true })
    end
    for _, f in ipairs({ "c", "b" }) do
      vim.fn.writefile({}, vim.fs.joinpath(dir, f))
    end
    local bufnr = vim.api.nvim_create_buf(false, true)
    local done = false
    require("telescope.previewers").buffer_previewer_maker(dir, bufnr, {
      callback = function()
        done = true
      end,
    })
    vim.wait(1000, function()
      return done
    end)
    assert.eq({ "a/", "a-b/", "z/", "b", "c" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    assert.eq("directory", vim.bo[bufnr].syntax)
    vim.fs.rm(dir, { recursive = true })
  end)
end)
