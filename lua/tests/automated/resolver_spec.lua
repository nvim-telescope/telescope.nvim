local eq = function(a, b)
  assert.are.same(a, b)
end

local resolve = require "telescope.config.resolve"

describe("telescope.config.resolve", function()
  describe("win_option", function()
    it("should resolve for percentages", function()
      local height_config = 0.8
      local opt = resolve.win_option(height_config)

      eq(height_config, opt.preview)
      eq(height_config, opt.prompt)
      eq(height_config, opt.results)
    end)

    it("should resolve for percentages with default", function()
      local height_config = 0.8
      local opt = resolve.win_option(nil, height_config)

      eq(height_config, opt.preview)
      eq(height_config, opt.prompt)
      eq(height_config, opt.results)
    end)

    it("should resolve table values", function()
      local table_val = { "a" }
      local opt = resolve.win_option(nil, table_val)

      eq(table_val, opt.preview)
      eq(table_val, opt.prompt)
      eq(table_val, opt.results)
    end)

    it("should allow overrides for different wins", function()
      local prompt_override = { "a", prompt = "b" }
      local opt = resolve.win_option(prompt_override)
      eq("a", opt.preview)
      eq("a", opt.results)
      eq("b", opt.prompt)
    end)

    it("should allow overrides for all wins", function()
      local all_specified = { preview = "a", prompt = "b", results = "c" }
      local opt = resolve.win_option(all_specified)
      eq("a", opt.preview)
      eq("b", opt.prompt)
      eq("c", opt.results)
    end)

    it("should allow some specified with a simple default", function()
      local some_specified = { prompt = "b", results = "c" }
      local opt = resolve.win_option(some_specified, "a")
      eq("a", opt.preview)
      eq("b", opt.prompt)
      eq("c", opt.results)
    end)
  end)

  describe("resolve_height/width", function()
    --TODO(l-kershaw) expand tests and add descriptions
    eq(10, resolve.resolve_height(0.1)(nil, 24, 100))
    eq(2, resolve.resolve_width(0.1)(nil, 24, 100))

    eq(10, resolve.resolve_width(10)(nil, 24, 100))
    eq(24, resolve.resolve_width(50)(nil, 24, 100))
  end)

  describe("resolve_anchor_pos", function()
    local test_sizes = {
      { 6, 7, 8, 9 },
      { 10, 20, 30, 40 },
      { 15, 15, 16, 16 },
      { 17, 19, 23, 31 },
      { 21, 18, 26, 24 },
      { 50, 100, 150, 200 },
    }

    it([[should not adjust when "CENTER" or "" is the anchor]], function()
      for _, s in ipairs(test_sizes) do
        eq({ 0, 0 }, resolve.resolve_anchor_pos("", unpack(s)))
        eq({ 0, 0 }, resolve.resolve_anchor_pos("center", unpack(s)))
        eq({ 0, 0 }, resolve.resolve_anchor_pos("CENTER", unpack(s)))
      end
    end)

    it([[should end up at top when "N" in the anchor]], function()
      local top_test = function(anchor, p_width, p_height, max_columns, max_lines)
        local pos = resolve.resolve_anchor_pos(anchor, p_width, p_height, max_columns, max_lines)
        eq(1, pos[2] + math.floor((max_lines - p_height) / 2))
      end
      for _, s in ipairs(test_sizes) do
        top_test("NW", unpack(s))
        top_test("N", unpack(s))
        top_test("NE", unpack(s))
      end
    end)

    it([[should end up at left when "W" in the anchor]], function()
      local left_test = function(anchor, p_width, p_height, max_columns, max_lines)
        local pos = resolve.resolve_anchor_pos(anchor, p_width, p_height, max_columns, max_lines)
        eq(1, pos[1] + math.floor((max_columns - p_width) / 2))
      end
      for _, s in ipairs(test_sizes) do
        left_test("NW", unpack(s))
        left_test("W", unpack(s))
        left_test("SW", unpack(s))
      end
    end)

    it([[should end up at bottom when "S" in the anchor]], function()
      local bot_test = function(anchor, p_width, p_height, max_columns, max_lines)
        local pos = resolve.resolve_anchor_pos(anchor, p_width, p_height, max_columns, max_lines)
        eq(max_lines - 1, pos[2] + p_height + math.floor((max_lines - p_height) / 2))
      end
      for _, s in ipairs(test_sizes) do
        bot_test("SW", unpack(s))
        bot_test("S", unpack(s))
        bot_test("SE", unpack(s))
      end
    end)

    it([[should end up at right when "E" in the anchor]], function()
      local right_test = function(anchor, p_width, p_height, max_columns, max_lines)
        local pos = resolve.resolve_anchor_pos(anchor, p_width, p_height, max_columns, max_lines)
        eq(max_columns - 1, pos[1] + p_width + math.floor((max_columns - p_width) / 2))
      end
      for _, s in ipairs(test_sizes) do
        right_test("NE", unpack(s))
        right_test("E", unpack(s))
        right_test("SE", unpack(s))
      end
    end)

    it([[should ignore casing of the anchor]], function()
      local case_test = function(a1, a2, p_width, p_height, max_columns, max_lines)
        local pos1 = resolve.resolve_anchor_pos(a1, p_width, p_height, max_columns, max_lines)
        local pos2 = resolve.resolve_anchor_pos(a2, p_width, p_height, max_columns, max_lines)
        eq(pos1, pos2)
      end
      for _, s in ipairs(test_sizes) do
        case_test("ne", "NE", unpack(s))
        case_test("w", "W", unpack(s))
        case_test("sW", "sw", unpack(s))
        case_test("cEnTeR", "CeNtEr", unpack(s))
      end
    end)
  end)
end)
