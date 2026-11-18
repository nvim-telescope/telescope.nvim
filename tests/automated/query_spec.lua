local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, eq = t.describe, t.it, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

local function matches(prompt, line, case_mode)
  return exec_lua(function()
    local query = require("telescope.algos.query")
    return query.score(query.parse(prompt, case_mode), line) ~= nil
  end)
end

describe("query syntax", function()
  it("matches all space-separated terms, in any order", function()
    t.ok(matches("picker lua", "lua/telescope/pickers.lua"))
    t.ok(matches("lua picker", "lua/telescope/pickers.lua"))
    t.ok(not matches("picker go", "lua/telescope/pickers.lua"))
    t.ok(matches("foo\\ bar", "foo = bar")) -- escaped space: one term
    t.ok(not matches("foo\\ bar", "foo_bar"))
  end)

  it("supports exact, boundary, prefix, suffix and equal terms", function()
    t.ok(matches("'tele", "lua/telescope"))
    t.ok(not matches("'tlsc", "lua/telescope"))
    t.ok(matches("'wild'", "a wild cat"))
    t.ok(not matches("'wild'", "wildcat"))
    t.ok(matches("^lua", "  lua/x")) -- leading whitespace of the line is ignored
    t.ok(not matches("^tele", "lua/telescope"))
    t.ok(matches(".lua$", "init.lua "))
    t.ok(not matches(".lua$", "init.luac"))
    t.ok(matches("^init.lua$", "init.lua"))
    t.ok(not matches("^init$", "init.lua"))
  end)

  it("supports inverse terms and alternatives", function()
    t.ok(not matches("!test", "tests/x.lua"))
    t.ok(matches("lua !test", "lua/x.lua"))
    t.ok(not matches("!^lua", "lua/x.lua"))
    t.ok(not matches("!.lua$", "x.lua"))
    t.ok(not matches("!'tst", "test")) -- inverse fuzzy
    t.ok(matches("!'tst", "tea"))
    t.ok(matches("^core go$ | rb$ | py$", "core/x.rb"))
    t.ok(not matches("^core go$ | rb$ | py$", "core/x.lua"))
  end)

  it("treats lone operators like fzf", function()
    eq(
      0,
      exec_lua(function()
        return #require("telescope.algos.query").parse("! ^ '")
      end)
    )
    t.ok(matches("|", "a|b")) -- no term before it: literal
    t.ok(matches("$", "a$b"))
  end)

  it("decides smart case per term", function()
    t.ok(matches("Tele lua", "Telescope/lua", "smart_case"))
    t.ok(not matches("Tele lua", "telescope/lua", "smart_case"))
  end)

  it("knows which edits can only narrow the results", function()
    local function restricts(new, old)
      return exec_lua(function()
        local query = require("telescope.algos.query")
        return query.restricts(query.parse(new), query.parse(old))
      end)
    end
    t.ok(restricts("tele", "tel"))
    t.ok(restricts("tel pick", "tel"))
    t.ok(restricts("tel$", "tel"))
    t.ok(restricts("'wild'", "'wild"))
    t.ok(restricts("lua !test", "lua"))
    t.ok(not restricts("!test", "!tes"))
    t.ok(not restricts("lua | rs", "lua"))
    t.ok(not restricts("lua$x", "lua$"))
    t.ok(not restricts("tel", "tele"))
  end)
end)

describe("fzy sorter with query syntax", function()
  it("scores and highlights all terms", function()
    exec_lua(function()
      local assert = require("test.assert")
      local eq = assert.eq
      local sorter = require("telescope.sorters").get_fzy_sorter()
      local function score(prompt, line)
        return sorter:score(prompt, { ordinal = line }, function(val)
          return val
        end, function()
          return -1
        end)
      end
      assert(score("pick lua", "lua/telescope/pickers.lua") >= 0)
      assert(score("pick lua", "lua/telescope/init.lua") < 0)
      -- a contiguous term and a file extension beat a scattered term and a match at the start
      assert(score("log txt", "docs/LoggingGuide/intro.txt") < score("log txt", "txt/tools/loader/g_tests/notes.txt"))
      eq({ 1, 2, 3, 15, 16, 17, 18 }, sorter:highlighter("lua pick", "lua/telescope/pickers.lua"))
    end)
  end)
end)
