local query = require "telescope.algos.query"
local matcher = require "telescope.algos.matcher"
local eq = assert.eq

local function matches(prompt, line, case_mode)
  return query.score(matcher, query.parse(prompt, case_mode), line) ~= nil
end

describe("query syntax", function()
  it("matches all space-separated terms, in any order", function()
    assert.is_true(matches("picker lua", "lua/telescope/pickers.lua"))
    assert.is_true(matches("lua picker", "lua/telescope/pickers.lua"))
    assert.is_false(matches("picker go", "lua/telescope/pickers.lua"))
    assert.is_true(matches("foo\\ bar", "foo = bar")) -- escaped space: one term
    assert.is_false(matches("foo\\ bar", "foo_bar"))
  end)

  it("supports exact, boundary, prefix, suffix and equal terms", function()
    assert.is_true(matches("'tele", "lua/telescope"))
    assert.is_false(matches("'tlsc", "lua/telescope"))
    assert.is_true(matches("'wild'", "a wild cat"))
    assert.is_false(matches("'wild'", "wildcat"))
    assert.is_true(matches("^lua", "  lua/x")) -- leading whitespace of the line is ignored
    assert.is_false(matches("^tele", "lua/telescope"))
    assert.is_true(matches(".lua$", "init.lua "))
    assert.is_false(matches(".lua$", "init.luac"))
    assert.is_true(matches("^init.lua$", "init.lua"))
    assert.is_false(matches("^init$", "init.lua"))
  end)

  it("supports inverse terms and alternatives", function()
    assert.is_false(matches("!test", "tests/x.lua"))
    assert.is_true(matches("lua !test", "lua/x.lua"))
    assert.is_false(matches("!^lua", "lua/x.lua"))
    assert.is_false(matches("!.lua$", "x.lua"))
    assert.is_false(matches("!'tst", "test")) -- inverse fuzzy
    assert.is_true(matches("!'tst", "tea"))
    assert.is_true(matches("^core go$ | rb$ | py$", "core/x.rb"))
    assert.is_false(matches("^core go$ | rb$ | py$", "core/x.lua"))
  end)

  it("treats lone operators like fzf", function()
    eq(0, #query.parse "! ^ '")
    assert.is_true(matches("|", "a|b")) -- no term before it: literal
    assert.is_true(matches("$", "a$b"))
  end)

  it("decides smart case per term", function()
    assert.is_true(matches("Tele lua", "Telescope/lua", "smart_case"))
    assert.is_false(matches("Tele lua", "telescope/lua", "smart_case"))
  end)

  it("knows which edits can only narrow the results", function()
    local function restricts(new, old)
      return query.restricts(query.parse(new), query.parse(old))
    end
    assert.is_true(restricts("tele", "tel"))
    assert.is_true(restricts("tel pick", "tel"))
    assert.is_true(restricts("tel$", "tel"))
    assert.is_true(restricts("'wild'", "'wild"))
    assert.is_true(restricts("lua !test", "lua"))
    assert.is_false(restricts("!test", "!tes"))
    assert.is_false(restricts("lua | rs", "lua"))
    assert.is_false(restricts("lua$x", "lua$"))
    assert.is_false(restricts("tel", "tele"))
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
    assert.is_true(score("pick lua", "lua/telescope/pickers.lua") >= 0)
    assert.is_true(score("pick lua", "lua/telescope/init.lua") < 0)
    eq({ 1, 2, 3, 15, 16, 17, 18 }, sorter:highlighter("lua pick", "lua/telescope/pickers.lua"))
  end)
end)
