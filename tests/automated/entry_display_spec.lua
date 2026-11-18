local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, eq = t.describe, t.it, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

--- `entry_display.truncate(str, len)` with 'ambiwidth' set to `ambiwidth`.
local function truncate(ambiwidth, str, len)
  return exec_lua(function()
    local original = vim.o.ambiwidth
    vim.o.ambiwidth = ambiwidth
    local truncated = require("telescope.pickers.entry_display").truncate(str, len)
    vim.o.ambiwidth = original
    return truncated
  end)
end

describe("truncate", function()
  for _, ambiwidth in ipairs({ "single", "double" }) do
    for _, case in ipairs({
      { args = { "abcde", 6 }, expected = { single = "abcde", double = "abcde" } },
      { args = { "abcde", 5 }, expected = { single = "abcde", double = "abcde" } },
      { args = { "abcde", 4 }, expected = { single = "abc…", double = "ab…" } },
      { args = { "アイウエオ", 11 }, expected = { single = "アイウエオ", double = "アイウエオ" } },
      { args = { "アイウエオ", 10 }, expected = { single = "アイウエオ", double = "アイウエオ" } },
      { args = { "アイウエオ", 9 }, expected = { single = "アイウエ…", double = "アイウ…" } },
      { args = { "アイウエオ", 8 }, expected = { single = "アイウ…", double = "アイウ…" } },
      { args = { "├─┤", 7 }, expected = { single = "├─┤", double = "├─┤" } },
      { args = { "├─┤", 6 }, expected = { single = "├─┤", double = "├─┤" } },
      { args = { "├─┤", 5 }, expected = { single = "├─┤", double = "├…" } },
      { args = { "├─┤", 4 }, expected = { single = "├─┤", double = "├…" } },
      { args = { "├─┤", 3 }, expected = { single = "├─┤", double = "…" } },
      { args = { "├─┤", 2 }, expected = { single = "├…", double = "…" } },
    }) do
      local msg = ("can truncate: ambiwidth = %s, [%s, %d] -> %s"):format(
        ambiwidth,
        case.args[1],
        case.args[2],
        case.expected[ambiwidth]
      )
      it(msg, function()
        eq(case.expected[ambiwidth], truncate(ambiwidth, case.args[1], case.args[2]))
      end)
    end
  end
end)
