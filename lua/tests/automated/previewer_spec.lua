local putils = require "telescope.previewers.utils"
local utils = require "telescope.utils"

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
        assert.are.same(expect, split_lines(file))
      end)

      it("reads file ending with \\n only", function()
        local file = table.concat(expect, "\n") .. "\n"
        assert.are.same(expect, split_lines(file))
      end)

      it("reads file with no trailing newline", function()
        local file = table.concat(expect, "\r\n")
        assert.are.same(expect, split_lines(file))
      end)
    end)
  else
    describe("handles files on non Windows environment", function()
      it("reads file ending with \\n (standard Unix line terminator)", function()
        local file = table.concat(expect, "\n") .. "\n"
        assert.are.same(expect, split_lines(file))
      end)

      it("reads file with no trailing newline", function()
        local file = table.concat(expect, "\n")
        assert.are.same(expect, split_lines(file))
      end)
    end)
  end
end)
