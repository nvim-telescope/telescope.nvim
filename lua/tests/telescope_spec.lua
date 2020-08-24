require('plenary.test_harness'):setup_busted()

local log = require('telescope.log')
-- log.use_console = false

local pickers = require('telescope.pickers')
local utils = require('telescope.utils')

--[[
require("plenary.test_harness"):test_directory("busted", "./tests/")
--]]

describe('Picker', function()
  describe('window_dimensions', function()
    it('', function()
      assert(true)
    end)
  end)

  describe('process_result', function()
    it('works with one entry', function()
      local lines_manager = pickers.line_manager(5, nil)

      lines_manager:add_result(1, "hello")

      assert.are.same(1, lines_manager:_get_state()[1].score)
    end)

    it('works with two entries', function()
      local lines_manager = pickers.line_manager(5, nil)

      lines_manager:add_result(1, "hello")
      lines_manager:add_result(2, "later")

      assert.are.same("hello", lines_manager:_get_state()[1].line)
      assert.are.same("later", lines_manager:_get_state()[2].line)
    end)

    it('calls functions when inserting', function()
      local called_count = 0
      local lines_manager = pickers.line_manager(5, function() called_count = called_count + 1 end)

      assert(called_count == 0)
      lines_manager:add_result(1, "hello")
      assert(called_count == 1)
    end)

    it('calls functions when inserting twice', function()
      local called_count = 0
      local lines_manager = pickers.line_manager(5, function() called_count = called_count + 1 end)

      assert(called_count == 0)
      lines_manager:add_result(1, "hello")
      lines_manager:add_result(2, "world")
      assert(called_count == 2)
    end)

    it('correctly sorts lower scores', function()
      local called_count = 0
      local lines_manager = pickers.line_manager(5, function() called_count = called_count + 1 end)
      lines_manager:add_result(5, "worse result")
      lines_manager:add_result(2, "better result")

      assert.are.same("better result", lines_manager:_get_state()[1].line)
      assert.are.same("worse result", lines_manager:_get_state()[2].line)

      -- once to insert "worse"
      -- once to insert "better"
      -- and then to move "worse"
      assert.are.same(3, called_count)
    end)

    it('respects max results', function()
      local called_count = 0
      local lines_manager = pickers.line_manager(1, function() called_count = called_count + 1 end)
      lines_manager:add_result(2, "better result")
      lines_manager:add_result(5, "worse result")

      assert.are.same("better result", lines_manager:_get_state()[1].line)

      -- once to insert "worse"
      -- once to insert "better"
      -- and then to move "worse"
      assert.are.same(1, called_count)
    end)

    -- TODO: We should decide if we want to add this or not.
    -- it('should handle no scores', function()
    --   local lines_manager = pickers.line_manager(5, nil)

    --   lines_manager:add_result(nil, 
    -- end)
  end)

  describe('ngrams', function()
    it('should capture intself in the ngram', function()
      local n = utils.new_ngram()

      n:add("hi")
      assert.are.same(n._grams.hi, {hi = 1})
    end)

    it('should have repeated strings count more than once', function()
      local n = utils.new_ngram()

      n:add("llll")
      assert.are.same(n._grams.ll, {llll = 3})
    end)

    describe('_items_sharing_ngrams', function()
      -- it('should be able to find similar strings', function()
      -- end)
      local n
      before_each(function()
        n = utils.new_ngram()

        n:add("SPAM")
        n:add("SPAN")
        n:add("EG")
      end)

      it('should find items at the start', function()
        assert.are.same({ SPAM = 1, SPAN = 1 }, n:_items_sharing_ngrams("SP"))
      end)

      it('should find items at the end', function()
        assert.are.same({ SPAM = 1, }, n:_items_sharing_ngrams("AM"))
      end)

      it('should find items at the end', function()
        assert.are.same({ SPAM = 2, SPAN = 1}, n:_items_sharing_ngrams("PAM"))
      end)
    end)

    describe('search', function()
      describe('for simple strings', function()
        local n
        before_each(function()
          n = utils.new_ngram()

          n:add("SPAM")
          n:add("SPAN")
          n:add("EG")
        end)

        it('should sort for equal cases', function()
          assert.are.same({ "SPAM", "SPAN" }, n:search("SPAM"))
        end)

        it('should sort for obvious cases', function()
          assert.are.same({ "SPAM", "SPAN" }, n:search("PAM"))
        end)
      end)

      describe('for file paths', function()
        local n
        before_each(function()
          n = utils.new_ngram()

          n:add("sho/rt")
          n:add("telescope/init.lua")
          n:add("telescope/utils.lua")
          n:add("telescope/pickers.lua")
          n:add("a/random/file/pickers.lua")
          n:add("microscope/init.lua")
        end)

        it("should find exact match", function()
          assert.are.same(n:find("telescope/init.lua"), "telescope/init.lua")
          assert.are.same(n:score("telescope/init.lua"), 1)
        end)

        it("should find unique match", function()
          assert.are.same(n:find("micro"), "microscope/init.lua")
        end)

        it("should find some match", function()
          assert.are.same(n:find("telini"), "telescope/init.lua")
        end)
      end)
    end)
  end)
end)

describe('Sorters', function()
  describe('norcalli_sorter', function()
    it('sort matches well', function()
      local sorter = require('telescope.sorters').get_norcalli_sorter()

      local exact_match = sorter:score('hello', 'hello')
      local no_match = sorter:score('abcdef', 'ghijkl')
      local ok_match = sorter:score('abcdef', 'ab')

      assert(exact_match < no_match)
      assert(exact_match < ok_match)
      assert(ok_match < no_match)
    end)
  end)
end)


