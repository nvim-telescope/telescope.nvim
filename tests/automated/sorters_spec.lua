local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, before_each, after_each, eq = t.describe, t.it, t.before_each, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("get_substr_matcher", function()
  local function with_smartcase(smartcase, case)
    local original
    before_each(function()
      original = n.api.nvim_get_option_value("smartcase", {})
      n.api.nvim_set_option_value("smartcase", smartcase, {})
    end)
    after_each(function()
      n.api.nvim_set_option_value("smartcase", original, {})
    end)

    describe("scoring_function", function()
      it(case.msg, function()
        local score = exec_lua(function()
          local matcher = require("telescope.sorters").get_substr_matcher()
          return matcher.scoring_function(nil, case.prompt, nil, case.entry)
        end)
        eq(case.expected_score, score)
      end)
    end)

    describe("highlighter", function()
      it("returns valid highlights", function()
        local highlights = exec_lua(function()
          local matcher = require("telescope.sorters").get_substr_matcher()
          return matcher.highlighter(nil, case.prompt, case.entry.ordinal)
        end)
        table.sort(highlights, function(a, b)
          return a.start < b.start
        end)
        eq(case.expected_highlights, highlights)
      end)
    end)
  end

  describe("when smartcase=OFF", function()
    for _, case in ipairs({
      {
        msg = "doesn't match",
        prompt = "abc def",
        entry = { index = 3, ordinal = "abc d" },
        expected_score = -1,
        expected_highlights = { { start = 1, finish = 3 } },
      },
      {
        msg = "matches with lower case letters only",
        prompt = "abc def",
        entry = { index = 3, ordinal = "abc def ghi" },
        expected_score = 3,
        expected_highlights = { { start = 1, finish = 3 }, { start = 5, finish = 7 } },
      },
      {
        msg = "doesn't match with upper case letters",
        prompt = "ABC def",
        entry = { index = 3, ordinal = "ABC def ghi" },
        expected_score = -1,
        expected_highlights = { { start = 5, finish = 7 } },
      },
    }) do
      with_smartcase(false, case)
    end
  end)

  describe("when smartcase=ON", function()
    for _, case in ipairs({
      {
        msg = "doesn't match",
        prompt = "abc def",
        entry = { index = 3, ordinal = "abc d" },
        expected_score = -1,
        expected_highlights = { { start = 1, finish = 3 } },
      },
      {
        msg = "matches with lower case letters only",
        prompt = "abc def",
        entry = { index = 3, ordinal = "abc def ghi" },
        expected_score = 3,
        expected_highlights = { { start = 1, finish = 3 }, { start = 5, finish = 7 } },
      },
      {
        msg = "matches with upper case letters",
        prompt = "ABC def",
        entry = { index = 3, ordinal = "ABC def ghi" },
        expected_score = 3,
        expected_highlights = { { start = 1, finish = 3 }, { start = 5, finish = 7 } },
      },
    }) do
      with_smartcase(true, case)
    end
  end)
end)

describe("prefilter", function()
  it("highlights the prompt without the tag", function()
    local highlights = exec_lua(function()
      local sorters = require("telescope.sorters")
      local sorter = sorters.prefilter({ sorter = sorters.get_fzy_sorter(), tag = "symbol_type" })
      return sorter:highlighter(":function: par", "a:fun ction: parse")
    end)
    eq({ 14, 15, 16 }, highlights)
  end)
end)

describe("Sorter:score", function()
  it("scores an entry on its own without callbacks", function()
    exec_lua(function()
      local assert = require("test.assert")
      local sorters = require("telescope.sorters")
      local sorter = sorters.get_fzy_sorter()
      local entry = { ordinal = "telescope/init.lua" }
      assert.eq(-1, sorter:score("xyz", entry))
      assert(sorter:score("init", entry) > 0)
    end)
  end)
end)
