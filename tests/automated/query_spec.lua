local t = require "test.harness"
local assert = require "test.assert"
local describe, it = t.describe, t.it

local query = require "telescope.algos.query"
local eq = assert.eq

local function matches(prompt, line, case_mode)
  return query.score(query.parse(prompt, case_mode), line) ~= nil
end

describe("query syntax", function()
  it("matches all space-separated terms, in any order", function()
    assert(matches("picker lua", "lua/telescope/pickers.lua"))
    assert(matches("lua picker", "lua/telescope/pickers.lua"))
    assert(not matches("picker go", "lua/telescope/pickers.lua"))
    assert(matches("foo\\ bar", "foo = bar")) -- escaped space: one term
    assert(not matches("foo\\ bar", "foo_bar"))
  end)

  it("supports exact, boundary, prefix, suffix and equal terms", function()
    assert(matches("'tele", "lua/telescope"))
    assert(not matches("'tlsc", "lua/telescope"))
    assert(matches("'wild'", "a wild cat"))
    assert(not matches("'wild'", "wildcat"))
    assert(matches("^lua", "  lua/x")) -- leading whitespace of the line is ignored
    assert(not matches("^tele", "lua/telescope"))
    assert(matches(".lua$", "init.lua "))
    assert(not matches(".lua$", "init.luac"))
    assert(matches("^init.lua$", "init.lua"))
    assert(not matches("^init$", "init.lua"))
  end)

  it("supports inverse terms and alternatives", function()
    assert(not matches("!test", "tests/x.lua"))
    assert(matches("lua !test", "lua/x.lua"))
    assert(not matches("!^lua", "lua/x.lua"))
    assert(not matches("!.lua$", "x.lua"))
    assert(not matches("!'tst", "test")) -- inverse fuzzy
    assert(matches("!'tst", "tea"))
    assert(matches("^core go$ | rb$ | py$", "core/x.rb"))
    assert(not matches("^core go$ | rb$ | py$", "core/x.lua"))
  end)

  it("treats lone operators like fzf", function()
    eq(0, #query.parse "! ^ '")
    assert(matches("|", "a|b")) -- no term before it: literal
    assert(matches("$", "a$b"))
  end)

  it("decides smart case per term", function()
    assert(matches("Tele lua", "Telescope/lua", "smart_case"))
    assert(not matches("Tele lua", "telescope/lua", "smart_case"))
  end)

  it("knows which edits can only narrow the results", function()
    local function restricts(new, old)
      return query.restricts(query.parse(new), query.parse(old))
    end
    assert(restricts("tele", "tel"))
    assert(restricts("tel pick", "tel"))
    assert(restricts("tel$", "tel"))
    assert(restricts("'wild'", "'wild"))
    assert(restricts("lua !test", "lua"))
    assert(not restricts("!test", "!tes"))
    assert(not restricts("lua | rs", "lua"))
    assert(not restricts("lua$x", "lua$"))
    assert(not restricts("tel", "tele"))
  end)
end)

describe("fzy sorter with query syntax", function()
  it("scores and highlights all terms", function()
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
