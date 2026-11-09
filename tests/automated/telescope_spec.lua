local picker = require "telescope.pickers"

local eq = assert.eq

describe("telescope", function()
  describe("Picker", function()
    describe("attach_mappings", function()
      local new_picker = function(a, b)
        a.finder = true
        return picker.new(a, b)
      end

      it("should allow for passing in a function", function()
        local p = new_picker({}, {
          attach_mappings = function()
            return 1
          end,
        })
        eq(1, p.attach_mappings())
      end)

      it("should override an attach mappings passed in by opts", function()
        local called_order = {}
        local p = new_picker({
          attach_mappings = function()
            table.insert(called_order, "opts")
          end,
        }, {
          attach_mappings = function()
            table.insert(called_order, "default")
          end,
        })

        p.attach_mappings()

        eq({ "default", "opts" }, called_order)
      end)
    end)
  end)

  describe("Sorters", function()
    describe("generic_fuzzy_sorter", function()
      it("sort matches well", function()
        local sorter = require("telescope.sorters").get_generic_fuzzy_sorter()

        local exact_match = sorter:score("hello", { ordinal = "hello" })
        local no_match = sorter:score("abcdef", { ordinal = "ghijkl" })
        local ok_match = sorter:score("abcdef", { ordinal = "ab" })

        assert(exact_match < no_match, "exact match better than no match")
        assert(exact_match < ok_match, "exact match better than ok match")
        assert(ok_match < no_match, "ok match better than no match")
      end)
    end)

    describe("fuzzy_file", function()
      it("sort matches well", function()
        local sorter = require("telescope.sorters").get_fuzzy_file()

        local exact_match = sorter:score("abcdef", { ordinal = "abcdef" })
        local no_match = sorter:score("abcdef", { ordinal = "ghijkl" })
        local ok_match = sorter:score("abcdef", { ordinal = "ab" })

        assert(exact_match < no_match, string.format("Exact match better than no match: %s %s", exact_match, no_match))
        assert(exact_match < ok_match, string.format("Exact match better than OK match: %s %s", exact_match, ok_match))
        assert(ok_match < no_match, "OK match better than no match")
      end)

      it("sorts matches after last os sep better", function()
        local sorter = require("telescope.sorters").get_fuzzy_file()

        local better_match = sorter:score("aaa", { ordinal = "bbb/aaa" })
        local worse_match = sorter:score("aaa", { ordinal = "aaa/bbb" })

        assert(better_match < worse_match, "Final match should be stronger")
      end)

      it("sorts multiple finds better", function()
        local sorter = require("telescope.sorters").get_fuzzy_file()

        local multi_match = sorter:score("generics", { ordinal = "exercises/generics/generics2.rs" })
        local one_match = sorter:score("generics", { ordinal = "exercises/generics/README.md" })

        assert(multi_match < one_match)
      end)
    end)

    describe("fzy", function()
      local sorter = require("telescope.sorters").get_fzy_sorter()
      local function score(prompt, line)
        return sorter:score(prompt, { ordinal = line }, function(val)
          return val
        end, function()
          return -1
        end)
      end

      describe("matches", function()
        it("exact matches", function()
          assert.is_true(score("a", "a") >= 0)
          assert.is_true(score("a.bb", "a.bb") >= 0)
        end)
        it("ignore case", function()
          assert.is_true(score("AbB", "abb") >= 0)
          assert.is_true(score("abb", "ABB") >= 0)
        end)
        it("partial matches", function()
          assert.is_true(score("a", "ab") >= 0)
          assert.is_true(score("a", "ba") >= 0)
          assert.is_true(score("aba", "baabbaab") >= 0)
        end)
        it("with delimiters between", function()
          assert.is_true(score("abc", "a|b|c") >= 0)
        end)
        it("with empty query", function()
          assert.is_true(score("", "") >= 0)
          assert.is_true(score("", "a") >= 0)
        end)
        it("rejects non-matches", function()
          assert.is_true(score("a", "") < 0)
          assert.is_true(score("a", "b") < 0)
          assert.is_true(score("aa", "a") < 0)
          assert.is_true(score("ba", "a") < 0)
          assert.is_true(score("ab", "a") < 0)
        end)
        it("non-ASCII characters", function()
          assert.is_true(score("ä", "Bär") >= 0)
          assert.is_true(score("bär", "Bär") >= 0) -- ASCII case still ignored
          assert.is_true(score("カナ", "ひらがなカタカナ") >= 0)
        end)
        it("rejects bytes of a character matched across characters", function()
          assert.is_true(score("é", "ö©") < 0) -- C3 A9 vs C3 B6 C2 A9
          assert.is_true(score("あ", "いア") < 0) -- E3 81 82 vs E3 81 84 E3 82 A2
        end)
      end)

      describe("scoring", function()
        it("prefers beginnings of words", function()
          assert.is_true(score("amor", "app/models/order") < score("amor", "app/models/zrder"))
        end)
        it("prefers consecutive letters", function()
          assert.is_true(score("amo", "app/models/foo") < score("amo", "app/m/foo"))
          assert.is_true(score("erf", "perfect") < score("erf", "terrific"))
        end)
        it("prefers contiguous over letter following period", function()
          assert.is_true(score("gemfil", "Gemfile") < score("gemfil", "Gemfile.lock"))
        end)
        it("prefers shorter matches", function()
          assert.is_true(score("abce", "abcdef") < score("abce", "abc de"))
          assert.is_true(score("abc", "    a b c ") < score("abc", " a  b  c "))
          assert.is_true(score("abc", " a b c    ") < score("abc", " a  b  c "))
        end)
        it("prefers shorter candidates", function()
          assert.is_true(score("test", "tests") < score("test", "testing"))
        end)
        it("prefers matches at the beginning", function()
          assert.is_true(score("ab", "abbb") < score("ab", "babb"))
          assert.is_true(score("test", "testing") < score("test", "/testing"))
        end)
        it("counts characters, not bytes", function()
          assert.eq(score("ab", "axb"), score("ab", "aがb"))
          assert.eq(score("bar", "Bar.txt"), score("bär", "Bär.txt"))
        end)
        it("prefers matches at some locations", function()
          assert.is_true(score("a", "/a") < score("a", "ba"))
          assert.is_true(score("a", "bA") < score("a", "ba"))
          assert.is_true(score("a", ".a") < score("a", "ba"))
        end)
      end)

      local function positions(prompt, line)
        return sorter:highlighter(prompt, line)
      end

      describe("positioning", function()
        it("favors consecutive positions", function()
          assert.eq({ 1, 5, 6 }, positions("amo", "app/models/foo"))
        end)
        it("favors word beginnings", function()
          assert.eq({ 1, 5, 12, 13 }, positions("amor", "app/models/order"))
        end)
        it("works when there are no bonuses", function()
          assert.eq({ 2, 4 }, positions("as", "tags"))
          assert.eq({ 3, 8 }, positions("as", "examples.txt"))
        end)
        it("favors smaller groupings of positions", function()
          assert.eq({ 3, 5, 7 }, positions("abc", "a/a/b/c/c"))
          assert.eq({ 3, 5 }, positions("ab", "caacbbc"))
        end)
        it("handles exact matches", function()
          assert.eq({ 1, 2, 3 }, positions("foo", "foo"))
        end)
        it("returns all bytes of matched multi-byte characters", function()
          assert.eq({ 1, 2, 3, 10, 11, 12 }, positions("かな", "かたかな"))
        end)
        it("ignores empty requests", function()
          assert.eq({}, positions("", ""))
          assert.eq({}, positions("", "foo"))
          assert.eq({}, positions("foo", ""))
        end)
      end)
    end)
  end)
end)
