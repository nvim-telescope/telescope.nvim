local sorters = require "telescope.sorters"

describe("get_substr_matcher", function()
  local function with_smartcase(smartcase, case)
    local original = vim.o.smartcase
    vim.o.smartcase = smartcase

    describe("scoring_function", function()
      it(case.msg, function()
        local matcher = sorters.get_substr_matcher()
        assert.are.same(case.expected_score, matcher.scoring_function(_, case.prompt, _, case.entry))
      end)
    end)

    describe("highlighter", function()
      it("returns valid highlights", function()
        local matcher = sorters.get_substr_matcher()
        local highlights = matcher.highlighter(_, case.prompt, case.entry.ordinal)
        table.sort(highlights, function(a, b)
          return a.start < b.start
        end)
        assert.are.same(case.expected_highlights, highlights)
      end)
    end)

    vim.o.smartcase = original
  end

  describe("when smartcase=OFF", function()
    for _, case in ipairs {
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
    } do
      with_smartcase(false, case)
    end
  end)

  describe("when smartcase=OFF", function()
    for _, case in ipairs {
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
    } do
      with_smartcase(true, case)
    end
  end)
end)
