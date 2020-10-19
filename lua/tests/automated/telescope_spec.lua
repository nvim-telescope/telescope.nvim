require('plenary.test_harness'):setup_busted()

local assert = require('luassert')

local log = require('telescope.log')
log.level = 'info'
-- log.use_console = false

local EntryManager = require('telescope.entry_manager')

--[[
lua RELOAD('plenary'); require("plenary.test_harness"):test_directory("busted", "./tests/automated")
--]]

describe('Picker', function()
  describe('window_dimensions', function()
    it('', function()
      assert(true)
    end)
  end)

  describe('process_result', function()
    it('works with one entry', function()
      local manager = EntryManager:new(5, nil)

      manager:add_entry(nil, 1, "hello")

      assert.are.same(1, manager:get_score(1))
    end)

    it('works with two entries', function()
      local manager = EntryManager:new(5, nil)

      manager:add_entry(nil, 1, "hello")
      manager:add_entry(nil, 2, "later")

      assert.are.same("hello", manager:get_entry(1))
      assert.are.same("later", manager:get_entry(2))
    end)

    it('calls functions when inserting', function()
      local called_count = 0
      local manager = EntryManager:new(5, function() called_count = called_count + 1 end)

      assert(called_count == 0)
      manager:add_entry(nil, 1, "hello")
      assert(called_count == 1)
    end)

    it('calls functions when inserting twice', function()
      local called_count = 0
      local manager = EntryManager:new(5, function() called_count = called_count + 1 end)

      assert(called_count == 0)
      manager:add_entry(nil, 1, "hello")
      manager:add_entry(nil, 2, "world")
      assert(called_count == 2)
    end)

    it('correctly sorts lower scores', function()
      local called_count = 0
      local manager = EntryManager:new(5, function() called_count = called_count + 1 end)
      manager:add_entry(nil, 5, "worse result")
      manager:add_entry(nil, 2, "better result")

      assert.are.same("better result", manager:get_entry(1))
      assert.are.same("worse result", manager:get_entry(2))

      -- once to insert "worse"
      -- once to insert "better"
      -- and then to move "worse"
      assert.are.same(3, called_count)
    end)

    it('respects max results', function()
      local called_count = 0
      local manager = EntryManager:new(1, function() called_count = called_count + 1 end)
      manager:add_entry(nil, 2, "better result")
      manager:add_entry(nil, 5, "worse result")

      assert.are.same("better result", manager:get_entry(1))
      assert.are.same(1, called_count)
    end)

    -- TODO: We should decide if we want to add this or not.
    -- it('should handle no scores', function()
    --   local manager = EntryManager:new(5, nil)

    --   manager:add_entry(nil, 
    -- end)

    it('should allow simple entries', function()
      local manager = EntryManager:new(5)

      local counts_executed = 0
      manager:add_entry(nil, 1, setmetatable({}, {
        __index = function(t, k)
          local val = nil
          if k == "ordinal" then
            counts_executed = counts_executed + 1

            -- This could be expensive, only call later
            val = "wow"
          end

          rawset(t, k, val)
          return val
        end,
      }))

      assert.are.same("wow", manager:get_ordinal(1))
      assert.are.same("wow", manager:get_ordinal(1))
      assert.are.same("wow", manager:get_ordinal(1))

      assert.are.same(1, counts_executed)
    end)
  end)

  -- describe('ngrams', function()
  --   it('should capture intself in the ngram', function()
  --     local n = utils.new_ngram()

  --     n:add("hi")
  --     assert.are.same(n._grams.hi, {hi = 1})
  --   end)

  --   it('should have repeated strings count more than once', function()
  --     local n = utils.new_ngram()

  --     n:add("llll")
  --     assert.are.same(n._grams.ll, {llll = 3})
  --   end)

  --   describe('_items_sharing_ngrams', function()
  --     -- it('should be able to find similar strings', function()
  --     -- end)
  --     local n
  --     before_each(function()
  --       n = utils.new_ngram()

  --       n:add("SPAM")
  --       n:add("SPAN")
  --       n:add("EG")
  --     end)

  --     it('should find items at the start', function()
  --       assert.are.same({ SPAM = 1, SPAN = 1 }, n:_items_sharing_ngrams("SP"))
  --     end)

  --     it('should find items at the end', function()
  --       assert.are.same({ SPAM = 1, }, n:_items_sharing_ngrams("AM"))
  --     end)

  --     it('should find items at the end', function()
  --       assert.are.same({ SPAM = 2, SPAN = 1}, n:_items_sharing_ngrams("PAM"))
  --     end)
  --   end)

  --   describe('search', function()
  --     describe('for simple strings', function()
  --       local n
  --       before_each(function()
  --         n = utils.new_ngram()

  --         n:add("SPAM")
  --         n:add("SPAN")
  --         n:add("EG")
  --       end)

  --       it('should sort for equal cases', function()
  --         assert.are.same({ "SPAM", "SPAN" }, n:search("SPAM"))
  --       end)

  --       it('should sort for obvious cases', function()
  --         assert.are.same({ "SPAM", "SPAN" }, n:search("PAM"))
  --       end)
  --     end)

  --     describe('for file paths', function()
  --       local n
  --       before_each(function()
  --         n = utils.new_ngram()

  --         n:add("sho/rt")
  --         n:add("telescope/init.lua")
  --         n:add("telescope/utils.lua")
  --         n:add("telescope/pickers.lua")
  --         n:add("a/random/file/pickers.lua")
  --         n:add("microscope/init.lua")
  --       end)

  --       it("should find exact match", function()
  --         assert.are.same(n:find("telescope/init.lua"), "telescope/init.lua")
  --         assert.are.same(n:score("telescope/init.lua"), 1)
  --       end)

  --       it("should find unique match", function()
  --         assert.are.same(n:find("micro"), "microscope/init.lua")
  --       end)

  --       it("should find some match", function()
  --         assert.are.same(n:find("telini"), "telescope/init.lua")
  --       end)
  --     end)
  --   end)
  -- end)
end)

describe('Sorters', function()
  describe('generic_fuzzy_sorter', function()
    it('sort matches well', function()
      local sorter = require('telescope.sorters').get_generic_fuzzy_sorter()

      local exact_match = sorter:score('hello', {ordinal = 'hello'})
      local no_match = sorter:score('abcdef', {ordinal = 'ghijkl'})
      local ok_match = sorter:score('abcdef', {ordinal = 'ab'})

      assert(exact_match < no_match, "exact match better than no match")
      assert(exact_match < ok_match, "exact match better than ok match")
      assert(ok_match < no_match, "ok match better than no match")
    end)

    it('sorts multiple finds better', function()
      local sorter = require('telescope.sorters').get_generic_fuzzy_sorter()

      local multi_match = sorter:score('generics', 'exercises/generics/generics2.rs')
      local one_match = sorter:score('abcdef', 'exercises/generics/README.md')

      -- assert(multi_match < one_match)
    end)
  end)

  describe('fuzzy_file', function()
    it('sort matches well', function()
      local sorter = require('telescope.sorters').get_fuzzy_file()

      local exact_match = sorter:score('abcdef', {ordinal = 'abcdef'})
      local no_match = sorter:score('abcdef', {ordinal = 'ghijkl'})
      local ok_match = sorter:score('abcdef', {ordinal = 'ab'})

      assert(
        exact_match < no_match,
        string.format("Exact match better than no match: %s %s", exact_match, no_match)
      )
      assert(
        exact_match < ok_match,
        string.format("Exact match better than OK match: %s %s", exact_match, ok_match)
      )
      assert(ok_match < no_match, "OK match better than no match")
    end)

    it('sorts matches after last os sep better', function()
      local sorter = require('telescope.sorters').get_fuzzy_file()

      local better_match = sorter:score('aaa', {ordinal = 'bbb/aaa'})
      local worse_match  = sorter:score('aaa', {ordinal = 'aaa/bbb'})

      assert(better_match < worse_match, "Final match should be stronger")
    end)

    pending('sorts multiple finds better', function()
      local sorter = require('telescope.sorters').get_fuzzy_file()

      local multi_match = sorter:score('generics', {ordinal = 'exercises/generics/generics2.rs'})
      local one_match = sorter:score('abcdef', {ordinal = 'exercises/generics/README.md'})

      assert(multi_match < one_match)
    end)
  end)

  describe('fzy', function()
    local sorter = require'telescope.sorters'.get_fzy_sorter()
    local function score(prompt, line)
      return sorter:score(prompt, {ordinal = line})
    end

    describe("matches", function()
      it("exact matches", function()
        assert.True(score("a", "a") >= 0)
        assert.True(score("a.bb", "a.bb") >= 0)
      end)
      it("ignore case", function()
        assert.True(score("AbB", "abb") >= 0)
        assert.True(score("abb", "ABB") >= 0)
      end)
      it("partial matches", function()
        assert.True(score("a", "ab") >= 0)
        assert.True(score("a", "ba") >= 0)
        assert.True(score("aba", "baabbaab") >= 0)
      end)
      it("with delimiters between", function()
        assert.True(score("abc", "a|b|c") >= 0)
      end)
      it("with empty query", function()
        assert.True(score("", "") >= 0)
        assert.True(score("", "a") >= 0)
      end)
      it("rejects non-matches", function()
        assert.True(score("a", "") < 0)
        assert.True(score("a", "b") < 0)
        assert.True(score("aa", "a") < 0)
        assert.True(score("ba", "a") < 0)
        assert.True(score("ab", "a") < 0)
      end)
    end)

    describe("scoring", function()
      it("prefers beginnings of words", function()
        assert.True(score("amor", "app/models/order") < score("amor", "app/models/zrder"))
      end)
      it("prefers consecutive letters", function()
        assert.True(score("amo", "app/models/foo") < score("amo", "app/m/foo"))
        assert.True(score("erf", "perfect") < score("erf", "terrific"))
      end)
      it("prefers contiguous over letter following period", function()
        assert.True(score("gemfil", "Gemfile") < score("gemfil", "Gemfile.lock"))
      end)
      it("prefers shorter matches", function()
        assert.True(score("abce", "abcdef") < score("abce", "abc de"));
        assert.True(score("abc", "    a b c ") < score("abc", " a  b  c "));
        assert.True(score("abc", " a b c    ") < score("abc", " a  b  c "));
      end)
      it("prefers shorter candidates", function()
        assert.True(score("test", "tests") < score("test", "testing"))
      end)
      it("prefers matches at the beginning", function()
        assert.True(score("ab", "abbb") < score("ab", "babb"))
        assert.True(score("test", "testing") < score("test", "/testing"))
      end)
      it("prefers matches at some locations", function()
        assert.True(score("a", "/a") < score("a", "ba"))
        assert.True(score("a", "bA") < score("a", "ba"))
        assert.True(score("a", ".a") < score("a", "ba"))
      end)
    end)

    local function positions(prompt, line)
      return sorter:highlighter(prompt, line)
    end

    describe("positioning", function()
      it("favors consecutive positions", function()
        assert.same({1, 5, 6}, positions("amo", "app/models/foo"))
      end)
      it("favors word beginnings", function()
        assert.same({1, 5, 12, 13}, positions("amor", "app/models/order"))
      end)
      it("works when there are no bonuses", function()
        assert.same({2, 4}, positions("as", "tags"))
        assert.same({3, 8}, positions("as", "examples.txt"))
      end)
      it("favors smaller groupings of positions", function()
        assert.same({3, 5, 7}, positions("abc", "a/a/b/c/c"))
        assert.same({3, 5}, positions("ab", "caacbbc"))
      end)
      it("handles exact matches", function()
        assert.same({1, 2, 3}, positions("foo", "foo"))
      end)
      it("ignores empty requests", function()
        assert.same({}, positions("", ""))
        assert.same({}, positions("", "foo"))
        assert.same({}, positions("foo", ""))
      end)
    end)
  end)

  describe('layout_strategies', function()
    describe('center', function()
      it('should handle large terminals', function()
        -- TODO: This could call layout_strategies.center w/ some weird edge case.
        -- and then assert stuff about the dimensions.
      end)
    end)
  end)

  -- describe('file_finder', function()
  --   COMPLETED = false
  --   PASSED = false

  --   require('tests.helpers').auto_find_files {
  --     input = 'pickers.lua',

  --     condition = function()
  --       print(vim.api.nvim_buf_get_name(0))
  --       return string.find(vim.api.nvim_buf_get_name(0), 'pickers.lua')
  --     end,
  --   }

  --   print("WAIT:", vim.wait(5000, function() return COMPLETED end))
  --   assert(PASSED)
  -- end)
end)


