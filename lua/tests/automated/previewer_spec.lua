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
    "",
  }

  local function get_fake_file(line_ending)
    return table.concat(expect, line_ending)
  end

  local newline_file = get_fake_file "\n"
  local carriage_newline_file = get_fake_file "\r\n"

  local split_lines = function(s)
    return putils.timed_split_lines(s, {
      start_time = vim.loop.hrtime(),
      preview = {
        timeout = 250, -- should be more than enough time
      },
    })
  end

  if utils.iswin then
    describe("handles files on Windows", function()
      it("reads file with newline only", function()
        assert.are.same(expect, split_lines(newline_file))
      end)
      it("reads file with carriage return and newline", function()
        assert.are.same(expect, split_lines(carriage_newline_file))
      end)
    end)
  else
    describe("handles files on non Windows environment", function()
      it("reads file with newline only", function()
        assert.are.same(expect, split_lines(newline_file))
      end)
    end)
  end
end)
