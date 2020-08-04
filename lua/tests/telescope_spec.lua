require('plenary.test_harness'):setup_busted()

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


